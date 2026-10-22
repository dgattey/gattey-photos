import Foundation
import Testing

@testable import GatteyPhotosCore
@testable import GatteyPhotosUI

private final class StartupMockURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: Handler?
    private nonisolated(unsafe) static var recordedRequests: [URLRequest] = []

    static func configure(handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        self.recordedRequests = []
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        self.handler = nil
        self.recordedRequests = []
    }

    static func requests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.recordedRequests.append(request)
        let currentHandler = Self.handler
        Self.lock.unlock()

        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try currentHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockURLSession() -> URLSession {
    let config = SyncURLSession.makeConfiguration()
    config.protocolClasses = [StartupMockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
}

@Suite("Startup Latency & Optimistic Unlock", .serialized)
struct StartupLatencyTests {
    @Test("Optimistic unlock transitions immediately when bearer token is saved, without network calls")
    @MainActor
    func optimisticUnlockWithSavedBearerToken() async throws {
        let tempSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-startup-opt-\(UUID().uuidString)", isDirectory: true)
        AppConfig.setSupportFolderForTesting(tempSupport)
        StartupMockURLProtocol.reset()
        defer {
            StartupMockURLProtocol.reset()
            AppConfig.flushPersistence()
            AppConfig.setSupportFolderForTesting(nil)
            try? FileManager.default.removeItem(at: tempSupport)
        }

        StartupMockURLProtocol.configure { _ in
            throw URLError(.notConnectedToInternet)
        }

        var savedSettings = AppSettings.defaults
        savedSettings.displayName = "Dylan"
        savedSettings.syncSessionToken = "valid-session-token"
        try AppConfig.saveSettings(savedSettings)

        let cachedState = GalleryState(
            updatedAt: "2026-10-16T00:00:00.000Z",
            order: ["cached-1"],
            photos: [
                "cached-1": PhotoEntry(
                    id: "cached-1",
                    filename: "cached.jpg",
                    blobPath: "photos/cached-1.jpg",
                    sizeBytes: 512,
                    updatedAt: "2026-10-16T00:00:00.000Z",
                    deletedAt: nil,
                    uploaderId: "u1"
                )
            ],
            uploaders: ["u1": "Dylan"],
            currentPhotoId: "cached-1"
        )
        try AppConfig.saveLocalState(cachedState)

        let store = GalleryStore(urlSession: makeMockURLSession())
        let session = AppSession()
        store.session = session

        await session.tryAutoUnlock(store: store)
        defer { store.stopPeriodicPullWhileUnlocked() }

        #expect(session.sessionPhase == .unlocked)
        #expect(session.isUnlocked == true)
        #expect(store.activePhotoIDs == ["cached-1"])
        #expect(StartupMockURLProtocol.requests().isEmpty)
    }

    @Test("tryAutoUnlock locks immediately when bearer token or display name is missing")
    @MainActor
    func autoUnlockLocksWithoutBearerToken() async throws {
        let tempSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-startup-lock-\(UUID().uuidString)", isDirectory: true)
        AppConfig.setSupportFolderForTesting(tempSupport)
        StartupMockURLProtocol.reset()
        defer {
            StartupMockURLProtocol.reset()
            AppConfig.flushPersistence()
            AppConfig.setSupportFolderForTesting(nil)
            try? FileManager.default.removeItem(at: tempSupport)
        }

        var savedSettings = AppSettings.defaults
        savedSettings.displayName = "Dylan"
        savedSettings.syncSessionToken = ""
        try AppConfig.saveSettings(savedSettings)

        let store = GalleryStore(urlSession: makeMockURLSession())
        let session = AppSession()
        store.session = session

        await session.tryAutoUnlock(store: store)

        #expect(session.sessionPhase == .locked)
        #expect(session.isUnlocked == false)
        #expect(StartupMockURLProtocol.requests().isEmpty)
    }

    @Test("Background revalidation with 401 Unauthorized locks session and clears token and caches")
    @MainActor
    func backgroundRevalidation401LocksAndClearsToken() async throws {
        let tempSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-startup-401-\(UUID().uuidString)", isDirectory: true)
        AppConfig.setSupportFolderForTesting(tempSupport)
        StartupMockURLProtocol.reset()
        defer {
            StartupMockURLProtocol.reset()
            AppConfig.flushPersistence()
            AppConfig.setSupportFolderForTesting(nil)
            try? FileManager.default.removeItem(at: tempSupport)
        }

        var savedSettings = AppSettings.defaults
        savedSettings.displayName = "Dylan"
        savedSettings.syncSessionToken = "expired-token"
        try AppConfig.saveSettings(savedSettings)

        let cachedState = GalleryState(
            updatedAt: "2026-10-16T00:00:00.000Z",
            order: ["cached-1"],
            photos: [
                "cached-1": PhotoEntry(
                    id: "cached-1",
                    filename: "cached.jpg",
                    blobPath: "photos/cached-1.jpg",
                    sizeBytes: 512,
                    updatedAt: "2026-10-16T00:00:00.000Z",
                    deletedAt: nil,
                    uploaderId: "u1"
                )
            ],
            uploaders: ["u1": "Dylan"],
            currentPhotoId: "cached-1"
        )
        try AppConfig.saveLocalState(cachedState)

        let mockSession = makeMockURLSession()
        let store = GalleryStore(urlSession: mockSession)
        let session = AppSession()
        store.session = session

        await session.tryAutoUnlock(store: store)
        #expect(session.isUnlocked == true)

        StartupMockURLProtocol.configure { req in
            let url = req.url!
            if url.path == "/api/health" {
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"ok\":true}".utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 401), Data("{\"error\":\"Unauthorized\"}".utf8))
        }

        await store.updateConnectionStatus()
        AppConfig.flushPersistence()

        #expect(session.sessionPhase == .locked)
        #expect(session.isUnlocked == false)
        #expect(store.settings.syncBearer == nil)
        #expect(store.activePhotoIDs.isEmpty)
        #expect(AppConfig.loadSettings().syncBearer == nil)
    }

    @Test("Background probe failure marks server unreachable and finishes offline bootstrap without locking")
    @MainActor
    func backgroundUnreachableKeepsCachedGalleryUnlocked() async throws {
        let tempSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-startup-offline-\(UUID().uuidString)", isDirectory: true)
        AppConfig.setSupportFolderForTesting(tempSupport)
        StartupMockURLProtocol.reset()
        defer {
            StartupMockURLProtocol.reset()
            AppConfig.flushPersistence()
            AppConfig.setSupportFolderForTesting(nil)
            try? FileManager.default.removeItem(at: tempSupport)
        }

        var savedSettings = AppSettings.defaults
        savedSettings.displayName = "Dylan"
        savedSettings.syncSessionToken = "valid-token"
        try AppConfig.saveSettings(savedSettings)

        let cachedState = GalleryState(
            updatedAt: "2026-10-16T00:00:00.000Z",
            order: ["cached-1"],
            photos: [
                "cached-1": PhotoEntry(
                    id: "cached-1",
                    filename: "cached.jpg",
                    blobPath: "photos/cached-1.jpg",
                    sizeBytes: 512,
                    updatedAt: "2026-10-16T00:00:00.000Z",
                    deletedAt: nil,
                    uploaderId: "u1"
                )
            ],
            uploaders: ["u1": "Dylan"],
            currentPhotoId: "cached-1"
        )
        try AppConfig.saveLocalState(cachedState)

        let mockSession = makeMockURLSession()
        let store = GalleryStore(urlSession: mockSession)
        let session = AppSession()
        store.session = session

        await session.tryAutoUnlock(store: store)
        defer { store.stopPeriodicPullWhileUnlocked() }
        store.markAwaitingInitialGalleryPull()

        StartupMockURLProtocol.configure { _ in
            throw URLError(.cannotConnectToHost)
        }

        await store.updateConnectionStatus()

        #expect(session.sessionPhase == .unlocked)
        #expect(session.isUnlocked == true)
        #expect(store.serverLinkStatus == .down)
        #expect(store.isAwaitingInitialGalleryPull == false)
        #expect(store.activePhotoIDs == ["cached-1"])
    }

    @Test("Initial updateConnectionStatus does not trigger duplicate pull, but true outage recovery does")
    @MainActor
    func initialConnectionCheckSkipsDuplicatePullWhileOutageRecoveryPulls() async throws {
        let tempSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-startup-dedup-\(UUID().uuidString)", isDirectory: true)
        AppConfig.setSupportFolderForTesting(tempSupport)
        StartupMockURLProtocol.reset()
        defer {
            StartupMockURLProtocol.reset()
            AppConfig.flushPersistence()
            AppConfig.setSupportFolderForTesting(nil)
            try? FileManager.default.removeItem(at: tempSupport)
        }

        var savedSettings = AppSettings.defaults
        savedSettings.displayName = "Dylan"
        savedSettings.syncSessionToken = "valid-token"
        try AppConfig.saveSettings(savedSettings)

        let mockSession = makeMockURLSession()
        let store = GalleryStore(urlSession: mockSession)
        let session = AppSession()
        store.session = session

        await session.tryAutoUnlock(store: store)
        defer { store.stopPeriodicPullWhileUnlocked() }

        let emptyGalleryJSON = Data(
            """
            {"state":{"updatedAt":"2026-10-16T01:00:00.000Z","order":[],"photos":{},"uploaders":{},"currentPhotoId":null}}
            """.utf8
        )

        StartupMockURLProtocol.configure { req in
            let url = req.url!
            switch url.path {
            case "/api/health":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"ok\":true}".utf8))
            case "/api/auth/verify":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"ok\":true}".utf8))
            case "/api/devices":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"devices\":[]}".utf8))
            case "/api/devices/status":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"statuses\":[]}".utf8))
            case "/api/gallery":
                return (makeHTTPResponse(url: url, statusCode: 200), emptyGalleryJSON)
            default:
                return (makeHTTPResponse(url: url, statusCode: 404), Data())
            }
        }

        // First connection check on launch: serverLinkStatus starts .down, but hasCompletedInitialConnectionCheck is false.
        // It must NOT fire a duplicate /api/gallery pull (RootView's store.refresh() owns the initial pull).
        await store.updateConnectionStatus()
        #expect(store.serverLinkStatus == .up)
        #expect(store.hasCompletedInitialConnectionCheck == true)

        let initialGalleryHits = StartupMockURLProtocol.requests().filter { $0.url?.path == "/api/gallery" }
        #expect(initialGalleryHits.isEmpty)

        // Simulate an actual outage (failed probe).
        StartupMockURLProtocol.configure { _ in
            throw URLError(.timedOut)
        }
        await store.updateConnectionStatus()
        #expect(store.serverLinkStatus == .down)

        // Now recover from outage: updateConnectionStatus() sees serverWasDown == true and MUST pull /api/gallery.
        StartupMockURLProtocol.configure { req in
            let url = req.url!
            switch url.path {
            case "/api/health":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"ok\":true}".utf8))
            case "/api/auth/verify":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"ok\":true}".utf8))
            case "/api/devices":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"devices\":[]}".utf8))
            case "/api/devices/status":
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"statuses\":[]}".utf8))
            case "/api/gallery":
                return (makeHTTPResponse(url: url, statusCode: 200), emptyGalleryJSON)
            default:
                return (makeHTTPResponse(url: url, statusCode: 404), Data())
            }
        }

        await store.updateConnectionStatus()
        #expect(store.serverLinkStatus == .up)
        let recoveryGalleryHits = StartupMockURLProtocol.requests().filter { $0.url?.path == "/api/gallery" }
        #expect(recoveryGalleryHits.count == 1)
    }

    @Test("Reachability and AuthVerifier set reloadIgnoringLocalCacheData and per-request timeouts")
    func reachabilityAndAuthVerifierRequestConfiguration() async throws {
        StartupMockURLProtocol.reset()
        defer { StartupMockURLProtocol.reset() }

        StartupMockURLProtocol.configure { req in
            let url = req.url!
            if url.path == "/api/auth/session" {
                return (
                    makeHTTPResponse(url: url, statusCode: 200),
                    Data("{\"ok\":true,\"sessionToken\":\"tok-123\"}".utf8)
                )
            }
            return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"ok\":true}".utf8))
        }

        let mockSession = makeMockURLSession()
        var settings = AppSettings.defaults
        settings.syncSessionToken = "tok-123"

        let pingOK = await Reachability.pingServer(
            baseURL: settings.serverBaseURL,
            session: mockSession
        )
        #expect(pingOK == true)

        let verifyResult = await AuthVerifier.verify(
            settings: settings,
            session: mockSession
        )
        #expect(verifyResult == .ok)

        let sessionResult = await AuthVerifier.createSession(
            password: "secret",
            settings: settings,
            session: mockSession
        )
        #expect(sessionResult == .success("tok-123"))

        let requests = StartupMockURLProtocol.requests()
        #expect(requests.count == 3)

        let healthReq = try #require(requests.first { $0.url?.path == "/api/health" })
        #expect(healthReq.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(healthReq.timeoutInterval == Reachability.probeTimeout)

        let verifyReq = try #require(requests.first { $0.url?.path == "/api/auth/verify" })
        #expect(verifyReq.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(verifyReq.timeoutInterval == AuthVerifier.verifyTimeout)
        #expect(verifyReq.value(forHTTPHeaderField: "Authorization") == "Bearer tok-123")

        let createReq = try #require(requests.first { $0.url?.path == "/api/auth/session" })
        #expect(createReq.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(createReq.timeoutInterval == AuthVerifier.createSessionTimeout)
    }

    @Test("PhotoImageModel falls back to cached full-size photo when bucketed thumbnail is absent")
    @MainActor
    func photoImageModelFallsBackToFullSizeCache() async throws {
        let tempSupport = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-cache-fallback-\(UUID().uuidString)", isDirectory: true)
        AppConfig.setSupportFolderForTesting(tempSupport)
        defer {
            AppConfig.flushPersistence()
            AppConfig.setSupportFolderForTesting(nil)
            try? FileManager.default.removeItem(at: tempSupport)
        }

        let photoID = "test-fallback-\(UUID().uuidString)"
        let fullURL = AppConfig.cacheURL(for: photoID)
        let thumb512URL = AppConfig.thumbnailCacheURL(for: photoID, width: 512)

        let welcomeURL = try #require(
            GatteyPhotosUIResources.bundle.url(forResource: "unlock-welcome", withExtension: "png")
        )
        let imageData = try Data(contentsOf: welcomeURL)
        try FileManager.default.createDirectory(
            at: fullURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try imageData.write(to: fullURL, options: .atomic)
        #expect(!FileManager.default.fileExists(atPath: thumb512URL.path))

        let model = PhotoImageModel()
        model.load(photoID: photoID, maxPixelSize: 360, thumbnailWidth: 512)
        for _ in 0..<50 where model.isLoading {
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(!model.isLoading)
        #expect(!model.loadFailed)
        #expect(model.image != nil)
    }
}
