import Foundation

public enum SyncHelperLauncher {
    public static let launchdLabel = "com.gattey.photos.sync"

    #if os(macOS)
    private static let helperName = "GatteyPhotosSyncHelper"

    public static func bundledHelperURL() -> URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/\(helperName)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public static func installLaunchAgentIfBundled() {
        guard let helper = bundledHelperURL() else { return }
        let agentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try? FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        let plistURL = agentsDir.appendingPathComponent("\(launchdLabel).plist")

        let plist: [String: Any] = [
            "Label": launchdLabel,
            "ProgramArguments": [helper.path],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
            "StandardOutPath": "/tmp/gattey-photos-sync.log",
            "StandardErrorPath": "/tmp/gattey-photos-sync.err",
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ) else { return }
        guard (try? data.write(to: plistURL, options: .atomic)) != nil else { return }
        reloadLaunchAgent(plistURL: plistURL)
    }

    /// Stops the background helper (e.g. when the user locks the app).
    public static func stopLaunchAgent() {
        let uid = getuid()
        let bootout = Process()
        bootout.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        bootout.arguments = ["bootout", "gui/\(uid)", launchdLabel]
        try? bootout.run()
        bootout.waitUntilExit()
    }

    private static func reloadLaunchAgent(plistURL: URL) {
        let uid = getuid()
        let domain = "gui/\(uid)"
        let label = launchdLabel
        let bootout = Process()
        bootout.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        bootout.arguments = ["bootout", domain, label]
        try? bootout.run()
        bootout.waitUntilExit()

        let bootstrap = Process()
        bootstrap.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        bootstrap.arguments = ["bootstrap", domain, plistURL.path]
        try? bootstrap.run()
        bootstrap.waitUntilExit()
    }
    #else
    public static func bundledHelperURL() -> URL? { nil }

    public static func installLaunchAgentIfBundled() {}

    public static func stopLaunchAgent() {}
    #endif
}
