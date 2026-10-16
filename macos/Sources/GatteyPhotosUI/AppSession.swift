import Foundation
import GatteyPhotosCore

public enum SessionPhase {
    case checking
    case locked
    case unlocked
}

@MainActor
public final class AppSession: ObservableObject {
    public init() {}

    @Published public private(set) var sessionPhase: SessionPhase = .checking
    @Published public private(set) var isUnlocked = false
    @Published var unlockError: String?

    private var unlockedServerBaseURL: String?

    /// Treats loopback :3000 hosts as one URL so `localhost` vs `127.0.0.1` does not force re-lock.
    private static func canonicalServerBaseURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
            var parts = URLComponents(url: parsed, resolvingAgainstBaseURL: false),
            let host = parts.host?.lowercased()
        else { return trimmed }
        let localHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]
        guard localHosts.contains(host) else { return trimmed }
        let port = parts.port ?? (parts.scheme == "https" ? 443 : 80)
        guard port == 3000 else { return trimmed }
        parts.host = "127.0.0.1"
        parts.port = 3000
        return parts.string ?? trimmed
    }

    func tryAutoUnlock(store: GalleryStore) async {
        guard sessionPhase == .checking else { return }
        await store.bootstrapFromDiskIfNeeded()
        let url = Self.canonicalServerBaseURL(store.settings.serverBaseURL)
        let hasDisplayName = !store.settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !url.isEmpty, hasDisplayName, store.settings.syncBearer != nil else {
            lock(store: store)
            return
        }
        unlockedServerBaseURL = url
        isUnlocked = true
        sessionPhase = .unlocked
        unlockError = nil
        resumePeriodicPull(store: store)
    }

    @discardableResult
    func unlock(
        password: String,
        store: GalleryStore,
        urlSession: URLSession = SyncURLSession.shared
    ) async -> Bool {
        unlockError = nil
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            unlockError = "Enter the password."
            return false
        }
        let sessionToken: String
        switch await AuthVerifier.createSession(
            password: trimmed,
            settings: store.settings,
            session: urlSession
        ) {
        case .success(let token):
            sessionToken = token
        case .wrongPassword:
            unlockError = "Wrong password. Grab the latest from 1Password."
            return false
        case .unreachable:
            unlockError = ServerConnectivityCopy.serverDown(at: store.settings.serverBaseURL)
            return false
        }
        store.settings.syncSessionToken = sessionToken
        AppConfig.saveSettingsAsync(store.settings)
        unlockedServerBaseURL = Self.canonicalServerBaseURL(store.settings.serverBaseURL)
        isUnlocked = true
        sessionPhase = .unlocked
        unlockError = nil
        resumePeriodicPull(store: store)
        return true
    }

    func lock(store: GalleryStore) {
        isUnlocked = false
        sessionPhase = .locked
        unlockedServerBaseURL = nil
        unlockError = nil
        pausePeriodicPull(store: store)
        clearSessionToken(store: store)
        store.clearLockedGalleryData()
    }

    /// Periodic gallery pull while unlocked (all platforms). No sync when locked or quit.
    private func resumePeriodicPull(store: GalleryStore) {
        store.startPeriodicPullWhileUnlocked()
    }

    private func pausePeriodicPull(store: GalleryStore) {
        store.stopPeriodicPullWhileUnlocked()
    }

    func lockAndClearCaches(store: GalleryStore) {
        lock(store: store)
    }

    private func clearSessionToken(store: GalleryStore) {
        guard !store.settings.syncSessionToken.isEmpty else { return }
        store.settings.syncSessionToken = ""
        AppConfig.saveSettingsAsync(store.settings)
    }

    func noteSettingsChanged(store: GalleryStore, previousServerURL: String) {
        let next = store.settings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let prev = previousServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prev != next else { return }
        guard isUnlocked else { return }
        unlockedServerBaseURL = Self.canonicalServerBaseURL(next)
        Task {
            store.markServerUnreachable()
            await store.updateConnectionStatus()
        }
    }

    func revalidateIfUnlocked(store: GalleryStore, urlSession: URLSession = SyncURLSession.shared) async {
        guard isUnlocked else { return }
        let url = Self.canonicalServerBaseURL(store.settings.serverBaseURL)
        if let unlocked = unlockedServerBaseURL, unlocked != url {
            unlockedServerBaseURL = url
        }
        switch await AuthVerifier.verify(settings: store.settings, session: urlSession) {
        case .ok:
            unlockedServerBaseURL = url
        case .unauthorized:
            lockAndClearCaches(store: store)
        case .unreachable:
            store.markServerUnreachable()
            store.finishOfflineBootstrap()
        }
    }
}
