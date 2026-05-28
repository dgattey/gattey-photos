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
        guard let data = try? Data(contentsOf: settingsURL),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaults
        }
        return decoded
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
