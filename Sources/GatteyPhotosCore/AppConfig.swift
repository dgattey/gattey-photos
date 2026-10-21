import DylCore
import Foundation
import os

public enum AppConfig {
    private static let persistenceQueue = DispatchQueue(
        label: "com.gattey.photos.app-config-persistence",
        qos: .utility
    )

    private static let defaultSupportFolder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("GatteyPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let supportFolderOverride = OSAllocatedUnfairLock<URL?>(initialState: nil)

    public static var supportFolder: URL {
        if let override = supportFolderOverride.withLock({ $0 }) {
            try? FileManager.default.createDirectory(at: override, withIntermediateDirectories: true)
            return override
        }
        return defaultSupportFolder
    }

    public static func setSupportFolderForTesting(_ url: URL?) {
        persistenceQueue.sync {
            supportFolderOverride.withLock { $0 = url }
            if let url {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    public static var settingsURL: URL {
        supportFolder.appendingPathComponent("config.json")
    }

    public static var cacheFolder: URL {
        let dir = supportFolder.appendingPathComponent("cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var localStateURL: URL {
        supportFolder.appendingPathComponent("local-gallery.json")
    }

    public static func loadSettings() -> AppSettings {
        persistenceQueue.sync {
            loadSettingsFromDisk()
        }
    }

    public static func loadSettingsAsync() async -> AppSettings {
        await withCheckedContinuation { continuation in
            persistenceQueue.async {
                continuation.resume(returning: loadSettingsFromDisk())
            }
        }
    }

    private static func loadSettingsFromDisk() -> AppSettings {
        var settings: AppSettings
        if let data = try? Data(contentsOf: settingsURL),
            let decoded = JSONDecoder().decodeOrLog(AppSettings.self, from: data)
        {
            settings = decoded
        } else {
            settings = .defaults
        }
        let expected = AppSettings.syncServerBaseURL(debugMode: settings.debugMode)
        if settings.serverBaseURL != expected {
            settings.serverBaseURL = expected
            try? writeSettingsToDisk(settings)
        }
        return settings
    }

    /// Removes JPEG cache files under Application Support.
    public static func clearPhotoCache() {
        ImageDownsampler.clearMemoryCache()
        persistenceQueue.sync {
            removePhotoCacheFilesFromDisk()
        }
    }

    /// Removes in-memory thumbnails immediately and deletes JPEG cache files on the background persistence queue.
    public static func clearPhotoCacheAsync() {
        ImageDownsampler.clearMemoryCache()
        persistenceQueue.async {
            removePhotoCacheFilesFromDisk()
        }
    }

    private static func removePhotoCacheFilesFromDisk() {
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: cacheFolder,
                includingPropertiesForKeys: nil
            )
        else { return }
        for url in entries {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public static func saveSettings(_ settings: AppSettings) throws {
        try persistenceQueue.sync {
            try writeSettingsToDisk(settings)
        }
    }

    public static func saveSettingsAsync(_ settings: AppSettings) {
        persistenceQueue.async {
            try? writeSettingsToDisk(settings)
        }
    }

    private static func writeSettingsToDisk(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public struct LocalStateLoad: Sendable {
        public var state: GalleryState
        /// Local manifest exists but failed to decode; replace from server on unlock.
        public var needsServerPull: Bool
    }

    public static func loadLocalState() -> LocalStateLoad {
        persistenceQueue.sync {
            loadLocalStateFromDisk()
        }
    }

    public static func loadLocalStateAsync() async -> LocalStateLoad {
        await withCheckedContinuation { continuation in
            persistenceQueue.async {
                continuation.resume(returning: loadLocalStateFromDisk())
            }
        }
    }

    private static func loadLocalStateFromDisk() -> LocalStateLoad {
        guard FileManager.default.fileExists(atPath: localStateURL.path) else {
            return LocalStateLoad(state: .empty, needsServerPull: false)
        }
        guard let data = try? Data(contentsOf: localStateURL),
            let decoded = JSONDecoder().decodeOrLog(GalleryState.self, from: data)
        else {
            try? FileManager.default.removeItem(at: localStateURL)
            return LocalStateLoad(state: .empty, needsServerPull: true)
        }
        return LocalStateLoad(state: decoded, needsServerPull: false)
    }

    public static func saveLocalState(_ state: GalleryState) throws {
        try persistenceQueue.sync {
            try writeLocalStateToDisk(state)
        }
    }

    public static func saveLocalStateAsync(_ state: GalleryState) {
        persistenceQueue.async {
            try? writeLocalStateToDisk(state)
        }
    }

    public static func saveLocalStateOnBackground(_ state: GalleryState) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistenceQueue.async {
                do {
                    try writeLocalStateToDisk(state)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public static func flushPersistence() {
        persistenceQueue.sync {}
    }

    private static func writeLocalStateToDisk(_ state: GalleryState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: localStateURL, options: .atomic)
    }

    public static func cacheURL(for photoID: PhotoID) -> URL {
        cacheFolder.appendingPathComponent("\(photoID).jpg")
    }

    /// Cache path for a width-bounded thumbnail variant (grid). Distinct from the full-size cache.
    public static func thumbnailCacheURL(for photoID: PhotoID, width: Int) -> URL {
        cacheFolder.appendingPathComponent("\(photoID)_w\(width).jpg")
    }
}
