import AppKit
import GatteyPhotosCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SyncHelperLauncher.installLaunchAgentIfBundled()
        EmbeddedSyncRunner.shared.startIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        EmbeddedSyncRunner.shared.stop()
    }
}
