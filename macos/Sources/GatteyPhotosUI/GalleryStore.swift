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
    public init() {
        let initialSettings = AppSettings.defaults
        settings = initialSettings
        lastPersistedDisplayName = initialSettings.displayName
        state = .empty
        bootstrapDiskTask = Task { [weak self] in
            async let loadedSettings = AppConfig.loadSettingsAsync()
            async let loadedLocal = AppConfig.loadLocalStateAsync()
            let (diskSettings, diskLocal) = await (loadedSettings, loadedLocal)
            guard let self else { return }
            self.applyInitialDiskBootstrap(settings: diskSettings, local: diskLocal)
        }
    }

    public weak var session: AppSession?

    public let selection = GallerySelectionStore()

    @Published public var settings: AppSettings {
        didSet {
            settingsRevision &+= 1
        }
    }
    @Published var state: GalleryState {
        didSet {
            stateRevision &+= 1
        }
    }
    private var stateRevision: UInt64 = 1
    private var settingsRevision: UInt64 = 1
    private var lastPersistedDisplayName: String
    private var bootstrapDiskTask: Task<Void, Never>?
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

    private let log = ActivityLogStore.shared
    private var lastServerOK: Date?
    /// While `setAsCurrent` is in flight, skip pull logging for that id (avoids duplicate with "Show for today").
    private var setAsCurrentInFlight: PhotoID?
    private var periodicPullTask: Task<Void, Never>?
    private let galleryMutationSerial = GalleryMutationSerial()
    private var pullRetryNotBefore: Date?
    private var pullFailureStreak = 0

    private static let periodicPullNanos: UInt64 = 1_800_000_000_000

    /// True while a gallery fetch is in flight and the grid is still empty (first load after unlock).
    var isBootstrappingGallery: Bool {
        (isBusy && activePhotos.isEmpty) || isAwaitingInitialGalleryPull
    }

    @Published private(set) var isAwaitingInitialGalleryPull = false

    private enum PullKind {
        case foreground
        case manual
        case periodic
    }

    private struct DerivedStateCache {
        var stateRevision: UInt64 = 0
        var activeOrderRevision: UInt64 = 0
        var activePhotos: [PhotoEntry] = []
        var activePhotoIDs: [PhotoID] = []
    }

    private struct RotationPlanCache {
        var activeOrderRevision: UInt64 = 0
        var currentPhotoID: PhotoID?
        var debugMode: Bool = false
        var debugAdvanceIntervalSeconds: Int = -1
        var nextCronBoundary: Date = .distantPast
        var plan: GalleryRotationPlan?
        var formattedTagByPhotoID: [PhotoID: String] = [:]
    }

    private var derivedCache = DerivedStateCache()
    private var rotationCache = RotationPlanCache()

    private func ensureDerivedCache() {
        if derivedCache.stateRevision == stateRevision {
            return
        }
        let active = state.activePhotos()
        let activeIDs = active.map(\.id)
        let orderRevision = activeIDs == derivedCache.activePhotoIDs
            ? max(derivedCache.activeOrderRevision, 1)
            : derivedCache.activeOrderRevision &+ 1
        derivedCache = DerivedStateCache(
            stateRevision: stateRevision,
            activeOrderRevision: orderRevision,
            activePhotos: active,
            activePhotoIDs: activeIDs
        )
    }

    var activePhotos: [PhotoEntry] {
        ensureDerivedCache()
        return derivedCache.activePhotos
    }

    var activePhotoIDs: [PhotoID] {
        ensureDerivedCache()
        return derivedCache.activePhotoIDs
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

    private func ensureRotationPlanCache(now: Date = Date()) {
        ensureDerivedCache()
        let orderRevision = derivedCache.activeOrderRevision
        let currentID = state.currentPhotoId
        let debug = settings.debugMode
        let interval = settings.debugAdvanceIntervalSeconds
        if rotationCache.activeOrderRevision == orderRevision,
           rotationCache.currentPhotoID == currentID,
           rotationCache.debugMode == debug,
           rotationCache.debugAdvanceIntervalSeconds == interval,
           now < rotationCache.nextCronBoundary {
            return
        }
        let order = derivedCache.activePhotoIDs
        let plan = GalleryRotationSchedule.plan(
            activeOrder: order,
            currentPhotoID: currentID,
            now: now,
            kind: GalleryRotationSchedule.kind(
                debugMode: debug,
                debugAdvanceIntervalSeconds: interval
            )
        )
        var tags: [PhotoID: String] = [:]
        if let plan {
            tags.reserveCapacity(plan.showingStartByPhotoID.count)
            for (id, date) in plan.showingStartByPhotoID {
                tags[id] = PhotoFormatters.showingStartDate(date)
            }
        }
        rotationCache = RotationPlanCache(
            activeOrderRevision: orderRevision,
            currentPhotoID: currentID,
            debugMode: debug,
            debugAdvanceIntervalSeconds: interval,
            nextCronBoundary: plan?.nextCron ?? now.addingTimeInterval(60),
            plan: plan,
            formattedTagByPhotoID: tags
        )
    }

    /// Next cron boundary and per-photo slot starts for the active gallery order.
    var rotationPlan: GalleryRotationPlan? {
        ensureRotationPlanCache()
        return rotationCache.plan
    }

    func showingTag(for photoID: PhotoID) -> String? {
        // "Showing for today" follows the server's live current photo, not the local schedule:
        // the cron can advance after local midnight, so a predicted slot may not be live yet.
        if state.currentPhotoId == photoID {
            return PhotoFormatters.showingTodayTag
        }
        ensureRotationPlanCache()
        return rotationCache.formattedTagByPhotoID[photoID]
    }

    func devicePreviewCaption(for photo: PhotoEntry) -> String {
        if let until = rotationPlan?.currentShowingUntil, state.currentPhotoId == photo.id {
            return PhotoFormatters.addedByUntilFriendly(
                photo: photo,
                until: until,
                uploaders: state.uploaders
            )
        }
        return PhotoFormatters.addedBy(photo, uploaders: state.uploaders)
    }

    /// Lightbox secondary line when this photo is the device current (rotation end date).
    func lightboxShowingUntilCaption(for photo: PhotoEntry) -> String? {
        guard state.currentPhotoId == photo.id,
              let until = rotationPlan?.currentShowingUntil
        else { return nil }
        return PhotoFormatters.showingUntil(until)
    }

    public func setDebugAdvanceIntervalSeconds(_ seconds: Int) {
        let clamped = AppSettings.clampedDebugAdvanceIntervalSeconds(seconds)
        guard settings.debugAdvanceIntervalSeconds != clamped else { return }
        settings.debugAdvanceIntervalSeconds = clamped
        AppConfig.saveSettingsAsync(settings)
        log.log(.system, level: .info, "Debug advance interval", detail: "\(clamped)s")
    }

    func bootstrapFromDiskIfNeeded() async {
        await bootstrapDiskTask?.value
    }

    private func applyInitialDiskBootstrap(
        settings diskSettings: AppSettings,
        local diskLocal: AppConfig.LocalStateLoad
    ) {
        if settingsRevision == 1 {
            settings = diskSettings
            lastPersistedDisplayName = diskSettings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if stateRevision == 1 {
            state = diskLocal.state.withResolvedCurrentPhoto()
            if diskLocal.needsServerPull {
                isAwaitingInitialGalleryPull = true
            }
        }
    }

    private func applyState(_ next: GalleryState) {
        state = next.withResolvedCurrentPhoto()
    }

    /// Apply a cheap current-photo poll without a full catalog pull (cron rotations).
    private func applyCurrentPhoto(_ current: CurrentPhotoResponse) {
        guard state.currentPhotoId != current.currentPhotoId else { return }
        var next = state
        next.currentPhotoId = current.currentPhotoId
        next.currentPhotoUpdatedBy = current.currentPhotoUpdatedBy
        applyState(next)
        AppConfig.saveLocalStateAsync(state)
    }

    private func makeSyncClient() throws -> SyncClient {
        try SyncClient(settings: settings)
    }

    private func commit(
        _ response: GalleryResponse,
        client: SyncClient? = nil,
        downloadMissing: Bool = false
    ) async throws {
        let next = response.state
        applyState(next)
        let snapshot = state
        try await AppConfig.saveLocalStateOnBackground(snapshot)
        if downloadMissing {
            let sync = try client ?? makeSyncClient()
            Task {
                try? await sync.downloadMissing(for: snapshot)
            }
        }
    }

    /// Mutation with `baseUpdatedAt`; on 409 applies server body and retries (up to 3 attempts).
    private func mutateGallery(
        client: SyncClient,
        downloadMissing: Bool = false,
        call: (String) async throws -> GalleryResponse
    ) async throws {
        var base = state.updatedAt
        for attempt in 0..<3 {
            do {
                try await commit(try await call(base), client: client, downloadMissing: downloadMissing)
                return
            } catch let error as SyncError {
                guard case .stale(let remote) = error else { throw error }
                try await commit(remote, client: client)
                guard attempt < 2 else { throw error }
                base = state.updatedAt
            }
        }
    }

    private func shouldSkipPeriodicPull(now: Date = Date()) -> Bool {
        guard let pullRetryNotBefore else { return false }
        return now < pullRetryNotBefore
    }

    private func notePullSuccess() {
        pullFailureStreak = 0
        pullRetryNotBefore = nil
    }

    private func notePullFailure(now: Date = Date()) {
        pullFailureStreak += 1
        let seconds = min(300.0, pow(2.0, Double(pullFailureStreak)))
        pullRetryNotBefore = now.addingTimeInterval(seconds)
    }

    /// Ensures the on-disk JPEG cache exists for grid/lightbox display.
    func ensurePhotoCached(photoID: PhotoID) async {
        guard session?.isUnlocked == true,
              let photo = state.photos[photoID],
              !photo.isDeleted
        else { return }
        do {
            let client = try makeSyncClient()
            try await client.cachePhotoIfMissing(photo)
        } catch {
            guard !Self.isCancellation(error) else { return }
            log.log(error: error, category: .gallery, context: "Cache photo \(photoID)")
        }
    }

    /// Ensures a small width-bounded thumbnail is cached for the grid (downloads the resized variant).
    func ensureThumbnailCached(photoID: PhotoID, width: Int) async {
        guard session?.isUnlocked == true,
              let photo = state.photos[photoID],
              !photo.isDeleted
        else { return }
        do {
            let client = try makeSyncClient()
            try await client.cacheThumbnailIfMissing(photo, width: width)
        } catch {
            guard !Self.isCancellation(error) else { return }
            log.log(error: error, category: .gallery, context: "Cache thumbnail \(photoID)")
        }
    }

    /// A superseded image fetch (grid re-rendered at a new size) surfaces as URL cancellation; benign.
    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }

    func reloadSettings() {
        settings = AppConfig.loadSettings()
        lastPersistedDisplayName = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reloadSettingsAsync() async {
        let loaded = await AppConfig.loadSettingsAsync()
        settings = loaded
        lastPersistedDisplayName = loaded.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func setDebugMode(_ enabled: Bool) {
        guard settings.debugMode != enabled else { return }
        let previousURL = settings.serverBaseURL
        settings.debugMode = enabled
        settings.serverBaseURL = AppSettings.syncServerBaseURL(debugMode: enabled)
        AppConfig.saveSettingsAsync(settings)
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
        AppConfig.saveLocalStateAsync(.empty)
        AppConfig.clearPhotoCacheAsync()
        lastServerOK = nil
        serverLinkStatus = .down
        deviceLinkStatus = .down
        pullRetryNotBefore = nil
        pullFailureStreak = 0
    }

    func saveSettings() {
        let previousDisplayName = lastPersistedDisplayName.isEmpty ? nil : lastPersistedDisplayName
        let previousServerURL = settings.serverBaseURL
        settings.serverBaseURL = AppSettings.syncServerBaseURL(debugMode: settings.debugMode)
        settings.galleryName = "default"
        let newDisplayName = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        lastPersistedDisplayName = newDisplayName
        AppConfig.saveSettingsAsync(settings)
        session?.noteSettingsChanged(store: self, previousServerURL: previousServerURL)
        log.log(.system, level: .info, "Settings saved", detail: settings.serverBaseURL)
        if let previousDisplayName,
           previousDisplayName != newDisplayName,
           !newDisplayName.isEmpty,
           session?.isUnlocked == true
        {
            Task { await propagateDisplayNameChange(from: previousDisplayName, to: newDisplayName) }
        }
        Task { await updateConnectionStatus() }
    }

    private func propagateDisplayNameChange(from oldName: String, to newName: String) async {
        await run(label: "Rename uploader", category: .gallery) {
            let client = try makeSyncClient()
            try await mutateGallery(client: client) { base in
                try await client.renameUploader(
                    fromName: oldName,
                    toName: newName,
                    baseUpdatedAt: base
                )
            }
            noteServerOK()
            log.log(
                .gallery,
                level: .success,
                "Updated uploader name on server",
                detail: "\(oldName) → \(newName)"
            )
        }
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
        upsertRegisteredFrame(device)
        log.log(.device, level: .success, "Frame registered", detail: device.displayName)
        Task { await updateDeviceStatus(using: client) }
    }

    public func unregisterFrame(id: String) async throws {
        let client = try makeSyncClient()
        let snapshot = registeredFrames
        registeredFrames.removeAll { $0.id == id }
        do {
            try await client.deleteDevice(id: id)
            log.log(.device, level: .info, "Frame removed")
            Task { await updateDeviceStatus(using: client) }
        } catch {
            registeredFrames = snapshot
            throw error
        }
    }

    private func upsertRegisteredFrame(_ device: RegisteredDevicePublic) {
        if let index = registeredFrames.firstIndex(where: { $0.id == device.id }) {
            registeredFrames[index] = device
        } else {
            registeredFrames.append(device)
        }
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

    func markAwaitingInitialGalleryPull() {
        isAwaitingInitialGalleryPull = true
    }

    func refresh() async {
        defer { isAwaitingInitialGalleryPull = false }
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
                try? await Task.sleep(nanoseconds: Self.periodicPullNanos)
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
        if kind == .periodic {
            #if os(macOS)
            // Only poll while the window is frontmost; on reactivation we trigger a one-off pull.
            guard NSApplication.shared.isActive else { return }
            #endif
            if shouldSkipPeriodicPull() { return }
        }
        await galleryMutationSerial.perform { [weak self] in
            await self?.executePullFromServer(kind: kind)
        }
    }

    /// Fresh pull when the app returns to the foreground (periodic polling pauses while backgrounded).
    func pullOnReactivation() async {
        await pullFromServer(kind: .periodic)
    }

    private func executePullFromServer(kind: PullKind) async {
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
            let client = try makeSyncClient()
            if kind == .periodic {
                // One blob read: the sync token tells us the catalog version + current photo. Only
                // do a full catalog pull when the version actually changed.
                let token = try await client.fetchCurrentPhoto()
                if token.galleryVersion != state.updatedAt,
                   case .modified(let response) = try await client.fetchGallery() {
                    try await commit(response, client: client, downloadMissing: true)
                }
                applyCurrentPhoto(token)
            } else {
                // Foreground / manual: conditionally fetch catalog when we already have local photos;
                // only poll /api/gallery/current separately on 304 Not Modified.
                let conditionalETag = activePhotos.isEmpty ? nil : state.updatedAt
                switch try await client.fetchGallery(ifNoneMatch: conditionalETag) {
                case .modified(let response):
                    try await commit(response, client: client, downloadMissing: true)
                case .notModified:
                    if let token = try? await client.fetchCurrentPhoto() {
                        applyCurrentPhoto(token)
                    }
                }
            }
            notePullSuccess()
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
                    detail: "updatedAt=\(state.updatedAt) active=\(activePhotos.count)"
                )
            case .manual:
                log.log(
                    .server,
                    level: .success,
                    "Server sync OK",
                    detail: "updatedAt=\(state.updatedAt) photos=\(activePhotos.count)"
                )
            case .periodic:
                log.log(
                    .sync,
                    level: .success,
                    "Scheduled sync OK",
                    detail: "updatedAt=\(state.updatedAt) photos=\(activePhotos.count)"
                )
            }
        } catch {
            notePullFailure()
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

    /// Refreshes server + frame reachability. Pass `showCheckingUI: true` when opening Settings so pills can show "Connecting"; background calls keep the last status until the check finishes.
    func updateConnectionStatus(showCheckingUI: Bool = false) async {
        let serverWasDown = serverLinkStatus == .down
        isCheckingConnection = true
        defer { isCheckingConnection = false }
        if showCheckingUI {
            serverLinkStatus = .checking
            deviceLinkStatus = .checking
        }
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
                Task { await self.pullFromServer(kind: .foreground) }
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
        #if os(macOS)
        let uploads = await Task.detached(priority: .userInitiated) {
            urls.filter { GalleryFilePasteboard.isUploadableImageFile($0) }
        }.value
        #else
        let uploads = urls
        #endif
        guard !uploads.isEmpty else {
            log.log(.gallery, level: .warning, "Upload skipped", detail: "No supported image files in drop")
            return
        }
        log.log(.gallery, level: .info, "Uploading \(uploads.count) file(s)")
        await run(label: "Upload", category: .gallery) {
            let client = try makeSyncClient()
            for (index, url) in uploads.enumerated() {
                let data = try await PhotoCacheJPEG.normalizedJPEGDataAsync(fromFileURL: url)
                let name = url.lastPathComponent
                let beforeIDs = Set(activePhotoIDs)
                let isLast = index == uploads.count - 1
                try await mutateGallery(
                    client: client,
                    downloadMissing: isLast
                ) { base in
                    try await client.uploadPhoto(
                        jpegData: data,
                        filename: name,
                        uploadedBy: settings.displayName,
                        baseUpdatedAt: base
                    )
                }
                let newIDs = Set(activePhotoIDs).subtracting(beforeIDs)
                guard !newIDs.isEmpty else {
                    log.log(
                        .gallery,
                        level: .error,
                        "Upload response missing new photo",
                        detail: "\(name) updatedAt=\(state.updatedAt)"
                    )
                    throw SyncError.decode
                }
                let cacheURLs = newIDs.map { AppConfig.cacheURL(for: $0) }
                try await Task.detached(priority: .utility) {
                    for cacheURL in cacheURLs {
                        try data.write(to: cacheURL, options: .atomic)
                    }
                }.value
                log.log(
                    .gallery,
                    level: .info,
                    "Uploaded to server",
                    detail: "\(name) → \(newIDs.sorted().joined(separator: ", "))"
                )
            }
            noteServerOK()
            log.log(
                .gallery,
                level: .success,
                "Upload complete",
                detail: "updatedAt=\(state.updatedAt) photos=\(activePhotos.count)"
            )
            selection.clearSelection()
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
            let orderedIDs = state.order.filter { ids.contains($0) }
            let trailing = ids.subtracting(orderedIDs)
            for id in orderedIDs + trailing.sorted() {
                try await mutateGallery(client: client) { base in
                    try await client.deletePhoto(id: id, baseUpdatedAt: base)
                }
                selection.subtractSelection([id])
            }
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
            let activeIDs = Set(activePhotoIDs)
            guard Set(order) == activeIDs else {
                log.log(
                    .gallery,
                    level: .warning,
                    "Reorder skipped",
                    detail: "stale order (active=\(activeIDs.count) requested=\(order.count))"
                )
                return
            }
            let client = try makeSyncClient()
            log.log(.gallery, level: .info, "Reordering gallery", detail: "photos=\(order.count)")
            try await mutateGallery(client: client) { base in
                try await client.reorder(order, baseUpdatedAt: base)
            }
            noteServerOK()
            log.log(.gallery, level: .success, "Reorder saved", detail: "updatedAt=\(state.updatedAt)")
        }
    }

    /// Full-size JPEG: macOS → Downloads folder; iOS → share sheet with temp file.
    func downloadPhoto(photoID: PhotoID) async {
        await downloadPhotos(ids: [photoID])
    }

    func downloadPhoto(_ photo: PhotoEntry) async {
        await downloadPhotos(ids: [photo.id])
    }

    func downloadPhotos(ids: Set<PhotoID>) async {
        guard session?.isUnlocked == true, !ids.isEmpty else { return }
        let orderedIDs = state.order.filter { ids.contains($0) }
        let trailing = ids.subtracting(orderedIDs)
        let photos = (orderedIDs + trailing.sorted()).compactMap { state.photos[$0] }
        guard !photos.isEmpty else { return }
        let count = photos.count
        log.log(
            .gallery,
            level: .info,
            count == 1 ? "Download photo" : "Downloading \(count) photos",
            detail: count == 1 ? photos[0].filename : "count=\(count)"
        )
        let label = count == 1 ? "Download" : "Download (\(count))"
        await run(label: label, category: .gallery) {
            for photo in photos {
                try await writeFullSizeJPEGDownload(for: photo)
            }
        }
    }

    private func writeFullSizeJPEGDownload(for photo: PhotoEntry) async throws {
        let jpegData = try await fullSizeJPEGData(for: photo)
        let filename = Self.downloadFilename(for: photo)
        #if os(macOS)
        let dest = try await Task.detached(priority: .userInitiated) { () -> URL in
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
            let target = Self.uniqueFileURL(in: downloads, filename: filename)
            try jpegData.write(to: target, options: .atomic)
            return target
        }.value
        log.log(.gallery, level: .success, "Saved to Downloads", detail: dest.lastPathComponent)
        #else
        let temp = try await Task.detached(priority: .userInitiated) { () -> URL in
            let target = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: target)
            try jpegData.write(to: target, options: .atomic)
            return target
        }.value
        photoShareItem = PhotoShareItem(url: temp)
        log.log(.gallery, level: .success, "Ready to share", detail: filename)
        #endif
    }

    #if os(iOS)
    func clearPhotoShareItem() {
        if let url = photoShareItem?.url {
            Task.detached(priority: .utility) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        photoShareItem = nil
    }
    #endif

    private func fullSizeJPEGData(for photo: PhotoEntry) async throws -> Data {
        let cacheURL = AppConfig.cacheURL(for: photo.id)
        if let cached = try? await Task.detached(priority: .userInitiated, operation: { () -> Data? in
            guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
            return try Data(contentsOf: cacheURL, options: .mappedIfSafe)
        }).value {
            return cached
        }
        let client = try makeSyncClient()
        try await client.cachePhotoIfMissing(photo)
        return try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: cacheURL, options: .mappedIfSafe)
        }.value
    }

    private nonisolated static func downloadFilename(for photo: PhotoEntry) -> String {
        let name = photo.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "\(photo.id).jpg" }
        let ext = (name as NSString).pathExtension.lowercased()
        if ext == "jpg" || ext == "jpeg" { return name }
        return (name as NSString).deletingPathExtension + ".jpg"
    }

    private nonisolated static func uniqueFileURL(in directory: URL, filename: String) -> URL {
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
            try await mutateGallery(
                client: client,
                downloadMissing: true
            ) { base in
                try await client.setCurrentPhoto(id: photoID, baseUpdatedAt: base)
            }
            noteServerOK()
            log.log(
                .gallery,
                level: .success,
                "Show for today",
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
                    Task { await self.updateConnectionStatus() }
                }
            }
        }
    }
}
