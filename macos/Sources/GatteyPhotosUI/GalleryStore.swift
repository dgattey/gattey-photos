import GatteyPhotosCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

@MainActor
public final class GalleryStore: ObservableObject {
    public init() {}

    public weak var session: AppSession?

    public let selection = GallerySelectionStore()

    @Published public var settings: AppSettings = AppConfig.loadSettings()
    @Published var state: GalleryState = AppConfig.loadLocalState()
    @Published var serverLinkStatus: LinkStatus = .down
    @Published var deviceLinkStatus: LinkStatus = .down
    @Published private(set) var isCheckingConnection = false
    /// Parsed from pasted setup text (`Device:` line); cosmetic only.
    @Published private(set) var bloomin8DeviceLabel: String?
    @Published private(set) var bloomin8SettingsStatus: String?
    /// Normalized width ÷ height from device pixels (`Bloomin8Screen.aspectRatio`, always ≤ 1).
    @Published private(set) var deviceScreenAspectRatio: CGFloat = Bloomin8Screen.defaultAspectRatio
    /// Physical panel orientation for preview chrome (portrait default).
    @Published private(set) var deviceScreenIsLandscape = false
    @Published public var isBusy = false
    @Published public var isSyncing = false
    @Published public var isManagingLocalServer = false

    #if os(iOS)
    /// Temp file for `PhotoActivityShareSheet` after `downloadPhoto(photoID:)`.
    @Published public var photoShareItem: PhotoShareItem?
    #endif

    public var canControlLocalServer: Bool {
        #if os(macOS)
        LocalSyncServer.isLocalURL(settings.serverBaseURL) && LocalSyncServer.repoRoot() != nil
        #else
        false
        #endif
    }

    public var localServerShowsStop: Bool {
        #if os(macOS)
        LocalSyncServer.isSupervisorRunning() || serverLinkStatus == .up
        #else
        false
        #endif
    }

    /// macOS pushes to Bloomin8; iPhone/iPad use the family server only.
    private var bloomin8DeviceSyncEnabled: Bool {
        #if os(iOS)
        false
        #else
        true
        #endif
    }

    private let engine = SyncEngine()
    private let log = ActivityLogStore.shared
    private var lastServerOK: Date?
    /// While `setAsCurrent` is in flight, skip pull logging for that id (avoids duplicate with "Set as current").
    private var setAsCurrentInFlight: PhotoID?

    var activePhotos: [PhotoEntry] {
        state.activePhotos()
    }

    var currentPhoto: PhotoEntry? {
        state.currentPhoto()
    }

    func canDeletePhotos(ids: Set<PhotoID>) -> Bool {
        state.canDeletePhotos(ids: ids)
    }

    func canSetAsCurrent(photoID: PhotoID) -> Bool {
        state.canSetAsCurrent(photoID: photoID)
    }

    private func applyState(_ next: GalleryState) {
        state = next.withResolvedCurrentPhoto()
    }

    func reloadSettings() {
        settings = AppConfig.loadSettings()
    }

    public func setDebugMode(_ enabled: Bool) {
        guard settings.debugMode != enabled else { return }
        let previousURL = settings.serverBaseURL
        let shouldStopLocal = !enabled && canControlLocalServer && localServerShowsStop
        settings.debugMode = enabled
        settings.serverBaseURL = AppSettings.syncServerBaseURL(debugMode: enabled)
        try? AppConfig.saveSettings(settings)
        session?.noteSettingsChanged(store: self, previousServerURL: previousURL)
        log.log(
            .system,
            level: .info,
            enabled ? "Debug mode on" : "Debug mode off",
            detail: settings.serverBaseURL
        )
        Task {
            if shouldStopLocal {
                await stopLocalServer()
            } else {
                await updateConnectionStatus()
            }
        }
    }

    /// Clears in-memory gallery state, local manifest, and JPEG disk cache (used when locking).
    func clearLockedGalleryData() {
        state = .empty
        selection.clearSelection()
        selection.closeLightbox()
        try? AppConfig.saveLocalState(.empty)
        AppConfig.clearPhotoCache()
        lastServerOK = nil
        serverLinkStatus = .down
        deviceLinkStatus = .down
    }

    func saveSettings() {
        let previousServerURL = settings.serverBaseURL
        settings.serverBaseURL = AppSettings.syncServerBaseURL(debugMode: settings.debugMode)
        applyBloomin8TokenFromPaste()
        settings.galleryName = "default"
        try? AppConfig.saveSettings(settings)
        session?.noteSettingsChanged(store: self, previousServerURL: previousServerURL)
        let tokenSet = !settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        log.log(
            .system,
            level: .info,
            "Settings saved",
            detail: "Server \(settings.serverBaseURL), Bloomin8 token \(tokenSet ? "set" : "missing")"
        )
        Task {
            await refreshBloomin8SettingsStatus()
            await updateDeviceStatus()
            await updateConnectionStatus()
        }
    }

    /// Parses pasted setup block into `bloomin8ApiToken` and optional device label.
    func applyBloomin8TokenFromPaste() {
        let raw = settings.bloomin8ApiToken
        bloomin8DeviceLabel = Bloomin8TokenParser.parseDeviceName(from: raw)
        if let token = Bloomin8TokenParser.parseToken(from: raw) {
            settings.bloomin8ApiToken = token
        }
    }

    func refreshBloomin8SettingsStatus() async {
        guard bloomin8DeviceSyncEnabled else {
            bloomin8SettingsStatus = nil
            return
        }
        let tok = settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else {
            bloomin8SettingsStatus = "Paste Bloomin8 token from the device app"
            return
        }
        do {
            let client = try Bloomin8OpenAPIClient(settings: settings)
            let status = try await client.fetchDeviceStatus()
            let name = status.name ?? bloomin8DeviceLabel
            var parts: [String] = []
            if let name, !name.isEmpty { parts.append(name) }
            if let interval = status.remoteImageInterval { parts.append("wake \(interval)") }
            if status.remoteImageOn == false {
                parts.append("enable remote push on device")
            }
            bloomin8SettingsStatus = parts.isEmpty ? "Token OK" : parts.joined(separator: " · ")
            applyDeviceScreenGeometry(from: status)
        } catch {
            bloomin8SettingsStatus = "Token saved — could not reach Open API"
        }
    }

    private func applyDeviceScreenGeometry(from status: Bloomin8CloudDeviceStatus) {
        if let w = status.width, let h = status.height, w > 0, h > 0 {
            deviceScreenAspectRatio = Bloomin8Screen.aspectRatio(width: w, height: h)
        }
        deviceScreenIsLandscape = Bloomin8Screen.isLandscapeDevice(
            orientation: status.orientation,
            width: status.width,
            height: status.height
        )
    }

    public func toggleLocalServer() async {
        guard canControlLocalServer else {
            log.log(.server, level: .warning, "Cannot control server", detail: "Use a local URL and run ./scripts/dev.sh to register repo path.")
            return
        }
        if localServerShowsStop {
            await stopLocalServer()
        } else {
            await startLocalServer()
        }
    }

    func startLocalServer() async {
        #if os(macOS)
        isManagingLocalServer = true
        defer { isManagingLocalServer = false }
        log.log(.server, level: .info, "Starting local sync server…")
        do {
            try await LocalSyncServer.start()
            log.log(.server, level: .success, "Local sync server started")
        } catch {
            log.log(error: error, category: .server, context: "Start server failed")
        }
        await updateConnectionStatus()
        #endif
    }

    func stopLocalServer() async {
        #if os(macOS)
        isManagingLocalServer = true
        defer { isManagingLocalServer = false }
        log.log(.server, level: .info, "Stopping local sync server…")
        do {
            try await LocalSyncServer.stop()
            markServerUnreachable()
            log.log(.server, level: .success, "Local sync server stopped")
        } catch {
            log.log(error: error, category: .server, context: "Stop server failed")
        }
        await updateConnectionStatus()
        #endif
    }

    func noteServerOK() {
        lastServerOK = Date()
        serverLinkStatus = .up
    }

    /// Marks sync server down without locking (e.g. local server stopped or unreachable).
    func markServerUnreachable() {
        lastServerOK = nil
        serverLinkStatus = .down
    }

    func refresh() async {
        guard session?.isUnlocked == true else { return }
        log.log(.gallery, level: .info, "Refreshing gallery from server")
        await run(label: "Refresh gallery", category: .gallery) {
            let previousCurrent = state.currentPhotoId
            let (merged, delta) = try await engine.pullAndMerge(settings: settings)
            let currentChanged = previousCurrent != merged.currentPhotoId
            applyState(merged)
            noteServerOK()
            logPulledCurrentPhotoChange(delta: delta, merged: merged)
            log.log(
                .gallery,
                level: .success,
                "Gallery refreshed",
                detail: "version=\(merged.version) active=\(merged.activePhotos().count)"
            )
            if currentChanged {
                await pushCurrentToDeviceBestEffort()
            }
        }
    }

    /// Pull family gallery from server, then push full gallery to the device.
    public func syncAll() async {
        guard session?.isUnlocked == true else { return }
        isSyncing = true
        defer {
            isSyncing = false
            Task { await updateDeviceStatus() }
        }
        isBusy = true
        defer { isBusy = false }

        log.log(.sync, level: .info, "Sync started")

        do {
            let (merged, delta) = try await engine.pullAndMerge(settings: settings)
            applyState(merged)
            noteServerOK()
            logPulledCurrentPhotoChange(delta: delta, merged: merged)
            log.log(
                .server,
                level: .success,
                "Server sync OK",
                detail: "version=\(merged.version) photos=\(merged.activePhotos().count)"
            )
        } catch {
            markServerUnreachableAfterSyncFailure(error)
            log.log(error: error, category: .server, context: "Server sync failed")
            return
        }

        guard bloomin8DeviceSyncEnabled else { return }

        do {
            try await engine.pushToDevice(settings: settings, state: state)
            if let photo = currentPhoto {
                log.log(.device, level: .success, "Queued for device", detail: photo.filename)
            }
        } catch {
            deviceLinkStatus = .down
            log.log(error: error, category: .device, context: "Bloomin8 push failed")
        }
    }

    private func markServerUnreachableAfterSyncFailure(_ error: Error) {
        if shouldLockForSyncError(error) {
            session?.lockAndClearCaches(store: self)
            return
        }
        if isTransientServerConnectionError(error) {
            markServerUnreachable()
        } else {
            Task { await updateConnectionStatus() }
        }
    }

    private func shouldLockForSyncError(_ error: Error) -> Bool {
        if case SyncError.http(let code, _, _) = error, code == 401 {
            return true
        }
        return false
    }

    private func isTransientServerConnectionError(_ error: Error) -> Bool {
        if case SyncError.badURL = error { return true }
        if case SyncError.http(let code, _, _) = error {
            if code == 401 { return false }
            if code < 0 { return true }
            if [408, 502, 503, 504].contains(code) { return true }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return ns.code != NSURLErrorCancelled
        }
        return false
    }

    func refreshDeviceScreenAspectRatio() async {
        guard bloomin8DeviceSyncEnabled else { return }
        let tok = settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else {
            resetDeviceScreenGeometry()
            return
        }
        do {
            let client = try Bloomin8OpenAPIClient(settings: settings)
            let status = try await client.fetchDeviceStatus()
            applyDeviceScreenGeometry(from: status)
        } catch {
            resetDeviceScreenGeometry()
        }
    }

    private func resetDeviceScreenGeometry() {
        deviceScreenAspectRatio = Bloomin8Screen.defaultAspectRatio
        deviceScreenIsLandscape = false
    }

    func updateDeviceStatus() async {
        guard bloomin8DeviceSyncEnabled else {
            deviceLinkStatus = .notApplicable
            bloomin8SettingsStatus = nil
            return
        }
        let tok = settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else {
            deviceLinkStatus = .down
            bloomin8SettingsStatus = "Paste Bloomin8 token from the device app"
            return
        }
        let up = await Bloomin8OpenAPIClient.pingDevice(settings: settings)
        deviceLinkStatus = up ? .up : .down
        if up {
            await refreshDeviceScreenAspectRatio()
            await refreshBloomin8SettingsStatus()
        }
        log.log(
            .device,
            level: up ? .success : .error,
            up ? "Bloomin8 token OK" : "Bloomin8 unreachable",
            detail: "GET /open-api/device/status"
        )
    }

    func updateConnectionStatus() async {
        let serverWasDown = serverLinkStatus == .down
        isCheckingConnection = true
        defer { isCheckingConnection = false }
        serverLinkStatus = .checking
        if bloomin8DeviceSyncEnabled {
            deviceLinkStatus = .checking
        } else {
            deviceLinkStatus = .notApplicable
        }
        log.log(
            .system,
            level: .info,
            bloomin8DeviceSyncEnabled ? "Checking server and device" : "Checking server"
        )
        let server = await Reachability.pingServer(baseURL: settings.serverBaseURL)
        applyServerStatus(pingSucceeded: server)
        if bloomin8DeviceSyncEnabled {
            let device = await Bloomin8OpenAPIClient.pingDevice(settings: settings)
            deviceLinkStatus = device ? .up : .down
            if device {
                await refreshDeviceScreenAspectRatio()
                await refreshBloomin8SettingsStatus()
            } else if settings.bloomin8ApiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bloomin8SettingsStatus = "Paste Bloomin8 token from the device app"
            }
            log.log(
                .device,
                level: device ? .success : .error,
                device ? "Bloomin8 token OK" : "Bloomin8 unreachable or token missing",
                detail: "GET /open-api/device/status"
            )
        }
        log.log(
            .server,
            level: server ? .success : .error,
            server ? "Server reachable" : "Server unreachable",
            detail: "\(settings.serverBaseURL)/api/health"
        )
        if session?.isUnlocked == true, server {
            await session?.revalidateIfUnlocked(store: self)
            if serverWasDown {
                await refresh()
            }
        }
    }

    private func applyServerStatus(pingSucceeded: Bool) {
        if pingSucceeded {
            noteServerOK()
            return
        }
        if let lastServerOK, Date().timeIntervalSince(lastServerOK) < 600 {
            serverLinkStatus = .up
            return
        }
        serverLinkStatus = .down
    }

    #if os(macOS)
    func uploadFromPanel() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        await uploadFiles(urls: panel.urls)
    }

    func uploadFromDrop(providers: [NSItemProvider]) async {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }
        await uploadFiles(urls: urls)
    }
    #endif

    #if os(macOS)
    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        let types = [UTType.fileURL.identifier, UTType.jpeg.identifier, UTType.image.identifier]
        guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let data = item as? Data, let path = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: URL(fileURLWithPath: path))
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }
    #endif

    func uploadFiles(urls: [URL]) async {
        guard session?.isUnlocked == true else { return }
        log.log(.gallery, level: .info, "Uploading \(urls.count) file(s)")
        await run(label: "Upload", category: .gallery) {
            let client = try SyncClient(settings: settings)
            var latest = state
            for url in urls {
                let data = try PhotoCacheJPEG.normalizedJPEGData(fromFileURL: url)
                let name = url.lastPathComponent
                let response = try await client.uploadPhoto(
                    jpegData: data,
                    filename: name,
                    uploadedBy: settings.displayName
                )
                latest = response.state
            }
            try AppConfig.saveLocalState(latest.withResolvedCurrentPhoto())
            try await SyncClient(settings: settings).downloadMissing(for: latest)
            applyState(latest)
            noteServerOK()
            log.log(.gallery, level: .success, "Upload complete", detail: "version=\(latest.version)")
            await updateDeviceStatus()
        }
    }

    func deletePhotos(ids: Set<PhotoID>) async {
        guard !ids.isEmpty else { return }
        guard canDeletePhotos(ids: ids) else {
            let detail = state.deleteBlockReason(for: ids).map { String(describing: $0) } ?? "unknown"
            log.log(.gallery, level: .warning, "Delete blocked", detail: detail)
            return
        }
        log.log(.gallery, level: .info, "Deleting \(ids.count) photo(s)")
        await run(label: "Delete", category: .gallery) {
            let client = try SyncClient(settings: settings)
            var latest = state
            let orderedIDs = latest.order.filter { ids.contains($0) }
            let trailing = ids.subtracting(orderedIDs)
            for id in orderedIDs + trailing.sorted() {
                let response = try await client.deletePhoto(id: id)
                latest = response.state
            }
            applyState(latest)
            try AppConfig.saveLocalState(state)
            selection.subtractSelection(ids)
            noteServerOK()
            log.log(.gallery, level: .success, "Delete complete")
            await updateDeviceStatus()
        }
    }

    func applyOrder(_ order: [PhotoID]) async {
        await run(label: "Reorder", category: .gallery) {
            let client = try SyncClient(settings: settings)
            let response = try await client.reorder(order)
            applyState(response.state)
            try AppConfig.saveLocalState(state)
            noteServerOK()
        }
    }

    /// Full-size JPEG: macOS → Downloads folder; iOS → share sheet with temp file.
    func downloadPhoto(photoID: PhotoID) async {
        guard let photo = state.photos[photoID] else { return }
        await downloadPhoto(photo)
    }

    func downloadPhoto(_ photo: PhotoEntry) async {
        guard session?.isUnlocked == true else { return }
        log.log(.gallery, level: .info, "Download photo", detail: photo.filename)
        await run(label: "Download", category: .gallery) {
            let jpegData = try await fullSizeJPEGData(for: photo)
            let filename = Self.downloadFilename(for: photo)
            #if os(macOS)
            guard let downloads = FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            ).first else {
                throw NSError(
                    domain: "GatteyPhotos",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Downloads folder unavailable"]
                )
            }
            let dest = Self.uniqueFileURL(in: downloads, filename: filename)
            try jpegData.write(to: dest, options: .atomic)
            log.log(.gallery, level: .success, "Saved to Downloads", detail: dest.lastPathComponent)
            #else
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: temp)
            try jpegData.write(to: temp, options: .atomic)
            photoShareItem = PhotoShareItem(url: temp)
            log.log(.gallery, level: .success, "Ready to share", detail: filename)
            #endif
        }
    }

    #if os(iOS)
    func clearPhotoShareItem() {
        if let url = photoShareItem?.url {
            try? FileManager.default.removeItem(at: url)
        }
        photoShareItem = nil
    }
    #endif

    private func fullSizeJPEGData(for photo: PhotoEntry) async throws -> Data {
        let cacheURL = AppConfig.cacheURL(for: photo.id)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            return try Data(contentsOf: cacheURL)
        }
        let client = try SyncClient(settings: settings)
        var req = URLRequest(url: client.imageURL(for: photo))
        req.setValue("Bearer \(client.bearer)", forHTTPHeaderField: "Authorization")
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (res as? HTTPURLResponse)?.statusCode ?? -1
            throw SyncError.http(code, "image download failed", baseURL: client.baseURL.absoluteString)
        }
        try data.write(to: cacheURL, options: .atomic)
        return data
    }

    private static func downloadFilename(for photo: PhotoEntry) -> String {
        let name = photo.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "\(photo.id).jpg" }
        let ext = (name as NSString).pathExtension.lowercased()
        if ext == "jpg" || ext == "jpeg" { return name }
        return (name as NSString).deletingPathExtension + ".jpg"
    }

    private static func uniqueFileURL(in directory: URL, filename: String) -> URL {
        var candidate = directory.appendingPathComponent(filename)
        var duplicateIndex = 1
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        while FileManager.default.fileExists(atPath: candidate.path) {
            let stem = "\(base) (\(duplicateIndex))"
            let next = ext.isEmpty ? stem : "\(stem).\(ext)"
            candidate = directory.appendingPathComponent(next)
            duplicateIndex += 1
        }
        return candidate
    }

    func setAsCurrent(photoID: PhotoID) async {
        guard state.canSetAsCurrent(photoID: photoID) else { return }
        setAsCurrentInFlight = photoID
        defer { setAsCurrentInFlight = nil }
        await run(label: "Set current", category: .gallery) {
            let client = try SyncClient(settings: settings)
            let response = try await client.setCurrentPhoto(id: photoID)
            applyState(response.state)
            try AppConfig.saveLocalState(state)
            noteServerOK()
            try await client.downloadMissing(for: response.state)
            let pushOutcome = await pushCurrentToDeviceBestEffort(logSuccess: false)
            logSetAsCurrentSuccess(pushOutcome: pushOutcome)
        }
    }

    private func logPulledCurrentPhotoChange(delta: CurrentPhotoPullDelta?, merged: GalleryState) {
        guard let delta, delta.didChange, delta.newId != setAsCurrentInFlight else { return }
        guard let pair = GalleryCurrentPhotoActivity.logEntry(delta: delta, photo: merged.currentPhoto()) else { return }
        log.log(.gallery, level: .success, pair.message, detail: pair.detail)
    }

    private func logSetAsCurrentSuccess(pushOutcome: Bloomin8PushOutcome?) {
        var detail = "Saved as current photo."
        if bloomin8DeviceSyncEnabled {
            if pushOutcome != nil {
                detail += " Your device will update on its next scheduled wake."
            } else {
                detail += " Saved on the server; use Sync to update your device."
            }
        }
        log.log(.gallery, level: .success, "Set as current", detail: detail)
    }

    /// Server `currentPhotoId` is already saved; device push is best-effort (Open API queue).
    @discardableResult
    private func pushCurrentToDeviceBestEffort(logSuccess: Bool = true) async -> Bloomin8PushOutcome? {
        guard bloomin8DeviceSyncEnabled else { return nil }
        guard let photo = currentPhoto else { return nil }
        do {
            let outcome = try await Bloomin8DevicePush.pushCurrentPhoto(photo, settings: settings)
            if logSuccess {
                switch outcome {
                case .queuedRemote(let eta, let rid):
                    log.log(
                        .device,
                        level: .success,
                        "Queued for device",
                        detail: [eta.map { "wake \($0)" }, rid.map { "id \($0)" }, photo.filename]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                }
            }
            return outcome
        } catch {
            log.log(error: error, category: .device, context: "Device push skipped (current saved on server)")
            await updateDeviceStatus()
            return nil
        }
    }

    private func run(
        label: String,
        category: LogCategory,
        _ work: () async throws -> Void
    ) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            log.log(error: error, category: category, context: "\(label) failed")
            if shouldLockForSyncError(error) {
                session?.lockAndClearCaches(store: self)
            } else {
                if isTransientServerConnectionError(error) {
                    markServerUnreachable()
                }
                await updateConnectionStatus()
            }
        }
    }
}
