import Foundation

public enum AppConfig {
    public static let supportFolder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("GatteyPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

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
        var settings: AppSettings
        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaults
        }
        let expected = AppSettings.syncServerBaseURL(debugMode: settings.debugMode)
        if settings.serverBaseURL != expected {
            settings.serverBaseURL = expected
            try? saveSettings(settings)
        }
        if settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.displayName = AppSettings.defaultDisplayName
            try? saveSettings(settings)
        }
        return settings
    }

    /// Removes JPEG cache files under Application Support.
    public static func clearPhotoCache() {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: cacheFolder,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in entries {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public static func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public static func loadLocalState() -> GalleryState {
        guard let data = try? Data(contentsOf: localStateURL),
              let decoded = try? JSONDecoder().decode(GalleryState.self, from: data) else {
            return .empty
        }
        return decoded
    }

    public static func saveLocalState(_ state: GalleryState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: localStateURL, options: .atomic)
    }

    public static func cacheURL(for photoID: PhotoID) -> URL {
        cacheFolder.appendingPathComponent("\(photoID).jpg")
    }
}
