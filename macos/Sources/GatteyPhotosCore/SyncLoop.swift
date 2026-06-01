import Foundation

public enum SyncLoop {
    /// Background sync interval while the user is unlocked (15 minutes).
    public static let intervalNanoseconds: UInt64 = 900_000_000_000

    public static func runForever() async {
        let engine = SyncEngine()
        helperLog(.system, .info, "GatteyPhotosSyncHelper started")
        while true {
            await tick(engine: engine)
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
    }

    public static func tick(engine: SyncEngine = SyncEngine()) async {
        let settings = AppConfig.loadSettings()
        guard settings.syncBearer != nil else {
            helperLog(.sync, .warning, "Sync skipped", detail: "unlock app once to save syncSessionToken in config.json")
            return
        }
        let bloomin8 = settings.bloomin8ApiToken.isEmpty ? "no token" : "Open API"
        helperLog(.sync, .info, "Scheduled sync started", detail: "server \(settings.serverBaseURL) Bloomin8 \(bloomin8)")
        do {
            let (merged, delta) = try await engine.fullSync(settings: settings)
            if let delta {
                GalleryCurrentPhotoActivity.recordChangeIfNeeded(
                    delta: delta,
                    photo: merged.currentPhoto(),
                    skipWhenNewIdEquals: nil
                )
            }
            helperLog(
                .sync,
                .success,
                "Scheduled sync OK",
                detail: "version=\(merged.version) photos=\(merged.activePhotos().count)"
            )
        } catch {
            helperLog(.sync, .error, "Scheduled sync failed", detail: ActivityLogStore.describe(error))
        }
    }

    private static func helperLog(
        _ category: LogCategory,
        _ level: LogLevel,
        _ message: String,
        detail: String? = nil
    ) {
        let entry = LogEntry(category: category, level: level, message: message, detail: detail)
        ActivityLogFile.append(entry)
        fputs("[\(category.rawValue)] \(message)\n", stderr)
        if let detail, !detail.isEmpty { fputs("\(detail)\n", stderr) }
    }
}
