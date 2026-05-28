import Foundation

public enum SyncLoop {
    public static let intervalNanoseconds: UInt64 = 3_600_000_000_000

    public static func runForever() async {
        let engine = SyncEngine()
        fputs("GatteyPhotosSyncHelper started\n", stderr)
        while true {
            await tick(engine: engine)
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
    }

    public static func tick(engine: SyncEngine = SyncEngine()) async {
        let settings = AppConfig.loadSettings()
        guard !settings.syncPassword.isEmpty else {
            fputs("sync password not set; skipping\n", stderr)
            return
        }
        do {
            let merged = try await engine.fullSync(settings: settings)
            fputs("sync ok version=\(merged.version) photos=\(merged.activePhotos().count)\n", stderr)
        } catch {
            fputs("sync error: \(error.localizedDescription)\n", stderr)
        }
    }
}
