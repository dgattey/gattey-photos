import Foundation

public final class EmbeddedSyncRunner: @unchecked Sendable {
    public static let shared = EmbeddedSyncRunner()
    private var task: Task<Void, Never>?

    private init() {}

    public func startIfNeeded() {
        guard SyncHelperLauncher.bundledHelperURL() == nil else { return }
        guard task == nil else { return }
        task = Task.detached(priority: .utility) {
            await SyncLoop.runForever()
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
