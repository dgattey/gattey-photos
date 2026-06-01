#if os(macOS)
import Foundation

/// Removes the old macOS LaunchAgent + helper binary workflow (superseded by in-app periodic pull).
enum LegacySyncLaunchAgent {
    private static let label = "com.gattey.photos.sync"

    static func uninstallIfPresent() {
        let uid = getuid()
        let bootout = Process()
        bootout.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        bootout.arguments = ["bootout", "gui/\(uid)", label]
        try? bootout.run()
        bootout.waitUntilExit()

        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
        try? FileManager.default.removeItem(at: plist)
    }
}
#endif
