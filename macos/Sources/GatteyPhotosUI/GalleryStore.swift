import GatteyPhotosCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

/// One gallery mutation at a time (upload vs reorder vs delete).
private actor GalleryMutationSerial {
    func perform(_ operation: @MainActor @Sendable () async -> Void) async {
        await operation()
    }
}

@MainActor
public final class GalleryStore: ObservableObject {
    public init() {}

    public weak var session: AppSession?

    public let selection = GallerySelectionStore()

    @Published public var settings: AppSettings = AppConfig.loadSettings()
    @Published var state: GalleryState = AppConfig.loadLocalState().withResolvedCurrentPhoto()
    @Published var serverLinkStatus: LinkStatus = .down
    @Published var deviceLinkStatus: LinkStatus = .down
    @Published private(set) var isCheckingConnection = false
    /// Parsed from pasted setup text (`Device:` line); cosmetic only.
    @Published private(set) var registeredFrames: [RegisteredDevicePublic] = []
    /// Normalized width ÷ height from first reachable frame (`Bloomin8Screen.aspectRatio`, always ≤ 1).
    @Published private(set) var deviceScreenAspectRatio: CGFloat = Bloomin8Screen.defaultAspectRatio
    /// Physical panel orientation for preview chrome (portrait default).
    @Published private(set) var deviceScreenIsLandscape = false
    @Published public var isBusy = false
    @Published public var isSyncing = false

    #if os(iOS)
    /// Temp file for `PhotoActivityShareSheet` after `downloadPhoto(photoID:)`.
    @Published public var photoShareItem: PhotoShareItem?
    #endif

    private let engine = SyncEngine()
    private let log = ActivityLogStore.shared
    private var lastServerOK: Date?
    /// While `setAsCurrent` is in flight, skip pull logging for that id (avoids duplicate with "Set as current").
    private var setAsCurrentInFlight: PhotoID?
    private var periodicPullTask: Task<Void, Never>?
    private let galleryMutationSerial = GalleryMutationSerial()

    private enum PullKind {
        case foreground
        case manual
        case periodic
    }

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

    private func makeSyncClient() throws -> SyncClient {
        try SyncClient(settings: settings)
    }

    /// Apply server manifest to UI + disk. Reuse `client` when the caller already has one for this operation.
    private func commitServerState(
        _ serverState: GalleryState,
        client: SyncClient? = nil,
        downloadMissing: Bool = false
    ) async throws {
        if downloadMissing {
            let sync = try client ?? makeSyncClient()
            try await sync.downloadMissing(for: serverState)
        }
        applyState(serverState)
        try AppConfig.saveLocalState(state)
    }

    /// Ensures the on-disk JPEG cache exists for grid/lightbox display.
    func ensurePhotoCached(photoID: PhotoID) async {
        guard session?.isUnlocked == true,
              let photo = state.photos[photoID],
              !photo.isDeleted
        else { return }
        let cacheURL = AppConfig.cacheURL(for: photoID)
        if FileManager.default.fileExists(atPath: cacheURL.path) { return }
        do {
            let client = try makeSyncClient()
            try await client.cachePhotoIfMissing(photo)
        } catch {
            log.log(error: error, category: .gallery, context: "Cache photo \(photoID)")
        }
    }

    func reloadSettings() {
        settings = AppConfig.loadSettings()
    }

    public func setDebugMode(_ enabled: Bool) {
        guard settings.debugMode != enabled else { return }
        let previousURL = settings.serverBaseURL
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
        Task { await updateConnectionStatus() }
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
        settings.galleryName = "default"
        try? AppConfig.saveSettings(settings)
        session?.noteSettingsChanged(store: self, previousServerURL: previousServerURL)
        log.log(.system, level: .info, "Settings saved", detail: settings.serverBaseURL)
        Task { await updateConnectionStatus() }
    }

    public func reloadRegisteredFrames() async {
        guard session?.isUnlocked == true else { return }
        do {
            let client = try makeSyncClient()
            registeredFrames = try await client.listDevices()
        } catch {
            registeredFrames = []
        }
    }

    public func registerFrame(setupText: String) async throws {
        let client = try makeSyncClient()
        let parsed = Bloomin8TokenParser.parseDeviceName(from: setupText)
        let device = try await client.registerDevice(
            setupText: setupText,
            displayName: parsed,
            registeredBy: settings.displayName
        )
        registeredFrames = try await client.listDevices()
        log.log(.device, level: .success, "Frame registered", detail: device.displayName)
        await updateDeviceStatus(using: client)
    }

    public func unregisterFrame(id: String) async throws {
        let client = try makeSyncClient()
        try await client.deleteDevice(id: id)
        registeredFrames = try await client.listDevices()
        log.log(.device, level: .info, "Frame removed")
        await updateDeviceStatus(using: client)
    }

    private func applyDeviceScreenGeometry(from status: DeviceLiveStatus) {
        if let w = status.width, let h = status.height, w > 0, h > 0 {
            deviceScreenAspectRatio = Bloomin8Screen.aspectRatio(width: w, height: h)
        }
        deviceScreenIsLandscape = Bloomin8Screen.isLandscapeDevice(
            orientation: status.orientation,
            width: status.width,
            height: status.height
        )
    }

    private func applyDeviceScreenGeometryIfReachable(from statuses: [DeviceLiveStatus]) {
        if let first = statuses.first(where: \.reachable) {
            applyDeviceScreenGeometry(from: first)
        }
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
        await pullFromServer(kind: .foreground)
    }

    public func syncAll() async {
        await pullFromServer(kind: .manual)
    }

    /// In-app periodic gallery pull while unlocked (macOS, iOS, iPadOS). No sync when locked or quit.
    func startPeriodicPullWhileUnlocked() {
        periodicPullTask?.cancel()
        periodicPullTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: GallerySyncSchedule.periodicIntervalNanoseconds)
                guard !Task.isCancelled else { break }
                await self?.pullFromServer(kind: .periodic)
            }
        }
    }

    func stopPeriodicPullWhileUnlocked() {
        periodicPullTask?.cancel()
        periodicPullTask = nil
    }

    private func pullFromServer(kind: PullKind) async {
        guard session?.isUnlocked == true else { return }
        if isBusy {
            let message = switch kind {
            case .periodic: "Scheduled sync skipped"
            case .foreground: "Refresh skipped"
            case .manual: "Server sync skipped"
            }
            log.log(.sync, level: .info, message, detail: "Gallery busy")
            return
        }

        let failureContext: String
        let logCategory: LogCategory
        switch kind {
        case .foreground:
            failureContext = "Refresh gallery failed"
            logCategory = .gallery
            log.log(.gallery, level: .info, "Refreshing gallery from server")
        case .manual:
            failureContext = "Server sync failed"
            logCategory = .server
            log.log(.sync, level: .info, "Sync started")
        case .periodic:
            failureContext = "Scheduled sync failed"
            logCategory = .sync
            log.log(.sync, level: .info, "Scheduled sync started", detail: settings.serverBaseURL)
        }

        if kind == .manual { isSyncing = true }
        if kind != .periodic { isBusy = true }
        defer {
            if kind == .manual {
                isSyncing = false
                Task { await updateDeviceStatus() }
            }
            if kind != .periodic { isBusy = false }
        }

        let previousCurrentId = state.currentPhotoId
        do {
            let merged = try await engine.pullRemoteMerged(settings: settings)
            try await commitServerState(merged)
            noteServerOK()
            logPulledCurrentPhotoChange(
                delta: CurrentPhotoPullDelta.ifCurrentChanged(from: previousCurrentId, to: state),
                merged: state
            )
            switch kind {
            case .foreground:
                log.log(
                    .gallery,
                    level: .success,
                    "Gallery refreshed",
                    detail: "version=\(state.version) active=\(state.activePhotos().count)"
                )
            case .manual:
                log.log(
                    .server,
                    level: .success,
                    "Server sync OK",
                    detail: "version=\(state.version) photos=\(state.activePhotos().count)"
                )
            case .periodic:
                log.log(
                    .sync,
                    level: .success,
                    "Scheduled sync OK",
                    detail: "version=\(state.version) photos=\(state.activePhotos().count)"
                )
            }
        } catch {
            log.log(error: error, category: logCategory, context: failureContext)
            markServerUnreachableAfterSyncFailure(error)
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
        if case SyncError.http(let failure) = error, failure.statusCode == 401 {
            return true
        }
        return false
    }

    private func isTransientServerConnectionError(_ error: Error) -> Bool {
        if case SyncError.badURL = error { return true }
        if case SyncError.http(let failure) = error {
            let code = failure.statusCode
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

    private func resetDeviceScreenGeometry() {
        deviceScreenAspectRatio = Bloomin8Screen.defaultAspectRatio
        deviceScreenIsLandscape = false
    }

    func updateDeviceStatus(using existing: SyncClient? = nil) async {
        guard session?.isUnlocked == true else {
            deviceLinkStatus = .down
            return
        }
        do {
            let client = try existing ?? makeSyncClient()
            let statuses = try await client.fetchDeviceStatus()
            applyDeviceScreenGeometryIfReachable(from: statuses)
            let anyReachable = statuses.contains(where: \.reachable)
            deviceLinkStatus = statuses.isEmpty ? .down : (anyReachable ? .up : .down)
            if !anyReachable, !statuses.isEmpty {
                for item in statuses where !item.reachable {
                    log.log(
                        .device,
                        level: .warning,
                        "Frame offline",
                        detail: "\(item.displayName): \(item.lastPushError ?? "unreachable")"
                    )
                }
            }
        } catch {
            deviceLinkStatus = .down
        }
    }

    func updateConnectionStatus() async {
        let serverWasDown = serverLinkStatus == .down
        isCheckingConnection = true
        defer { isCheckingConnection = false }
        serverLinkStatus = .checking
        deviceLinkStatus = .checking
        log.log(.system, level: .info, "Checking server and frames")
        let server = await Reachability.pingServer(baseURL: settings.serverBaseURL)
        applyServerStatus(pingSucceeded: server)
        if server, session?.isUnlocked == true {
            await reloadRegisteredFrames()
            await updateDeviceStatus()
        } else if !server {
            deviceLinkStatus = .down
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
                await pullFromServer(kind: .foreground)
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
        guard session?.isUnlocked == true else {
            log.log(.gallery, level: .warning, "Upload skipped", detail: "Unlock the gallery first")
            return
        }
        guard !urls.isEmpty else {
            log.log(.gallery, level: .warning, "Upload skipped", detail: "No supported image files in drop")
            return
        }
        log.log(.gallery, level: .info, "Uploading \(urls.count) file(s)")
        await run(label: "Upload", category: .gallery) {
            let client = try makeSyncClient()
            var latest = state
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try PhotoCacheJPEG.normalizedJPEGData(fromFileURL: url)
                let name = url.lastPathComponent
                let beforeIDs = Set(latest.activePhotos().map(\.id))
                let response = try await client.uploadPhoto(
                    jpegData: data,
                    filename: name,
                    uploadedBy: settings.displayName
                )
                latest = response.state.mergingDownloadURLs(from: response.photos)
                let newIDs = Set(latest.activePhotos().map(\.id)).subtracting(beforeIDs)
                guard !newIDs.isEmpty else {
                    log.log(
                        .gallery,
                        level: .error,
                        "Upload response missing new photo",
                        detail: "\(name) version=\(response.state.version)"
                    )
                    throw SyncError.decode
                }
                for newID in newIDs {
                    try data.write(to: AppConfig.cacheURL(for: newID), options: .atomic)
                }
                log.log(
                    .gallery,
                    level: .info,
                    "Uploaded to server",
                    detail: "\(name) → \(newIDs.sorted().joined(separator: ", "))"
                )
            }
            try await commitServerState(latest, client: client, downloadMissing: true)
            noteServerOK()
            log.log(
                .gallery,
                level: .success,
                "Upload complete",
                detail: "version=\(state.version) photos=\(state.activePhotos().count)"
            )
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
            let client = try makeSyncClient()
            var latest = state
            let orderedIDs = latest.order.filter { ids.contains($0) }
            let trailing = ids.subtracting(orderedIDs)
            for id in orderedIDs + trailing.sorted() {
                let response = try await client.deletePhoto(id: id)
                latest = response.state.mergingDownloadURLs(from: response.photos)
            }
            try await commitServerState(latest)
            selection.subtractSelection(ids)
            noteServerOK()
            log.log(.gallery, level: .success, "Delete complete")
            await updateDeviceStatus()
        }
    }

    func applyOrder(_ order: [PhotoID]) async {
        guard session?.isUnlocked == true else {
            log.log(.gallery, level: .warning, "Reorder skipped", detail: "Unlock the gallery first")
            return
        }
        await run(label: "Reorder", category: .gallery) {
            let snapshot = state
            applyState(snapshot.applyingActiveDisplayOrder(order))
            log.log(
                .gallery,
                level: .info,
                "Reordering gallery",
                detail: "photos=\(order.count) version=\(snapshot.version)"
            )
            do {
                let client = try makeSyncClient()
                let response = try await client.reorder(order)
                try await commitServerState(response.state.mergingDownloadURLs(from: response.photos))
                noteServerOK()
                log.log(
                    .gallery,
                    level: .success,
                    "Reorder saved",
                    detail: "version=\(state.version)"
                )
            } catch {
                applyState(snapshot)
                try? AppConfig.saveLocalState(state)
                throw error
            }
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
        let client = try makeSyncClient()
        try await client.cachePhotoIfMissing(photo)
        return try Data(contentsOf: cacheURL)
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
            let client = try makeSyncClient()
            let response = try await client.setCurrentPhoto(id: photoID)
            try await commitServerState(
                response.state.mergingDownloadURLs(from: response.photos),
                client: client,
                downloadMissing: true
            )
            noteServerOK()
            log.log(
                .gallery,
                level: .success,
                "Set as current",
                detail: "Server pushes the current JPEG to all registered frames."
            )
            await updateDeviceStatus()
        }
    }

    private func logPulledCurrentPhotoChange(delta: CurrentPhotoPullDelta?, merged: GalleryState) {
        guard let delta, delta.didChange, delta.newId != setAsCurrentInFlight else { return }
        guard let pair = GalleryCurrentPhotoActivity.logEntry(delta: delta, photo: merged.currentPhoto()) else { return }
        log.log(.gallery, level: .success, pair.message, detail: pair.detail)
    }

    private func run(
        label: String,
        category: LogCategory,
        _ work: () async throws -> Void
    ) async {
        await galleryMutationSerial.perform { [label, category] in
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
}
