import AppKit
import GatteyPhotosCore
import GatteyPhotosUI
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var extraWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureGlassWindows()
        observeExtraWindows()
        DispatchQueue.main.async { [weak self] in
            self?.enforceSingleMainWindow()
        }
        Task { @MainActor in
            let log = ActivityLogStore.shared
            log.reload()
            log.log(.system, level: .info, "Gattey Photos started")
            log.startLiveReload()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let extraWindowObserver {
            NotificationCenter.default.removeObserver(extraWindowObserver)
        }
        EmbeddedSyncRunner.shared.stop()
        ActivityLogStore.shared.stopLiveReload()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let main = Self.preferredMainWindow {
            main.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        enforceSingleMainWindow()
        return true
    }

    /// Ensures windows created before SwiftUI mounts still get translucent chrome.
    private func configureGlassWindows() {
        for window in NSApp.windows {
            window.applyGatteyPhotosGlassChrome()
        }
    }

    private func observeExtraWindows() {
        extraWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.enforceSingleMainWindow()
        }
    }

    /// Closes duplicate app windows; keeps the key window or the first main candidate.
    private func enforceSingleMainWindow() {
        let candidates = Self.mainWindowCandidates
        guard candidates.count > 1 else { return }
        let keeper = candidates.first(where: \.isKeyWindow) ?? candidates[0]
        for window in candidates where window !== keeper {
            window.close()
        }
    }

    private static var preferredMainWindow: NSWindow? {
        mainWindowCandidates.first(where: \.isKeyWindow) ?? mainWindowCandidates.first
    }

    private static var mainWindowCandidates: [NSWindow] {
        NSApp.windows.filter { window in
            window.canBecomeMain && !window.isSheet && window.level == .normal
        }
    }
}
