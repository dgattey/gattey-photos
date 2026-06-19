import AppKit
import GatteyPhotosCore
import GatteyPhotosUI
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var extraWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureInitialWindowChrome()
        observeExtraWindows()
        DispatchQueue.main.async { [weak self] in
            self?.configureInitialWindowChrome()
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

    /// Sparkle closes its alert when installing; without this, a single-window app can quit before download/install runs.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !SparkleUpdateSession.shared.blocksQuitOnLastWindowClosed
    }

    /// Applies translucent chrome before SwiftUI mounts so the window never flashes the default opaque
    /// titlebar while the session is loading. `WindowChromeConfigurator` refines it per session phase
    /// once the UI is up (gallery and unlock chrome are both transparent, so there is no conflict).
    private func configureInitialWindowChrome() {
        for window in Self.mainWindowCandidates {
            window.applyGatteyPhotosUnlockChrome()
            window.titleVisibility = .hidden
            window.title = ""
        }
    }

    private func observeExtraWindows() {
        extraWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow, window.isGatteyPhotosMainWindow else {
                return
            }
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

    /// Only the SwiftUI main scene — not Sparkle or other auxiliary windows.
    private static var mainWindowCandidates: [NSWindow] {
        NSApp.windows.filter { window in
            window.isGatteyPhotosMainWindow
                && window.canBecomeMain
                && !window.isSheet
                && window.level == .normal
        }
    }
}
