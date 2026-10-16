import Combine
import GatteyPhotosCore
import Sparkle
import SwiftUI

/// While Sparkle is showing update UI or installing, do not quit when its window closes.
@MainActor
final class SparkleUpdateSession {
    static let shared = SparkleUpdateSession()

    private var nesting = 0

    var blocksQuitOnLastWindowClosed: Bool { nesting > 0 }

    func begin() {
        nesting += 1
    }

    func end() {
        nesting = max(0, nesting - 1)
    }

    func reset() {
        nesting = 0
    }
}

@MainActor
final class SparkleStandardUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var onWillShowUpdate: (() -> Void)?

    func handleWillShowUpdate() {
        SparkleUpdateSession.shared.begin()
        onWillShowUpdate?()
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        handleWillShowUpdate()
    }

    func standardUserDriverWillFinishUpdateSession() {
        SparkleUpdateSession.shared.reset()
    }
}

/// Presents Sparkle's update UI when the launch-time probe finds a newer build.
///
/// Sparkle invokes `updater(_:didFindValidUpdate:)` while the `SPUProbingUpdateDriver` session is
/// still in progress (`updater.sessionInProgress == true`), before `abortUpdate` clears the driver
/// and emits `updater(_:didFinishUpdateCycleFor:error:)`. Calling `updater.checkForUpdates()`
/// synchronously inside `didFindValidUpdate` fails Sparkle's `.sessionInProgress` guard and drops
/// the interactive check. Recording the match in `didFindValidUpdate` and escalating inside
/// `didFinishUpdateCycleFor` runs right after `sessionInProgress` resets to `false`.
@MainActor
final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var launchProbeActive = false
    private(set) var launchProbeFoundUpdate = false
    var onProbeFoundUpdate: ((SPUUpdater) -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard launchProbeActive else { return }
        launchProbeFoundUpdate = true
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        let shouldEscalate = launchProbeActive && launchProbeFoundUpdate
        launchProbeActive = false
        launchProbeFoundUpdate = false
        guard shouldEscalate else { return }
        if let onProbeFoundUpdate {
            onProbeFoundUpdate(updater)
        } else {
            updater.checkForUpdates()
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        launchProbeActive = false
        launchProbeFoundUpdate = false
        SparkleUpdateSession.shared.reset()
        ActivityLogStore.shared.log(error: error, category: .system, context: "Sparkle update failed")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        SparkleUpdateSession.shared.begin()
        ActivityLogStore.shared.log(
            .system,
            level: .info,
            "Installing update",
            detail: item.displayVersionString
        )
    }
}

@MainActor
final class AppUpdaterModel: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false
    let isReleaseConfigured: Bool
    private(set) var didCheckOnLaunch = false
    private(set) var didScheduleLaunchCheck = false
    let sparkleDelegate = SparkleUpdaterDelegate()
    let sparkleUserDriverDelegate = SparkleStandardUserDriverDelegate()
    private var launchCheckCancellable: AnyCancellable?

    init(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        startingUpdater: Bool? = nil
    ) {
        let feedURL = infoDictionary?["SUFeedURL"] as? String
        let publicKey = infoDictionary?["SUPublicEDKey"] as? String
        let configured = !(feedURL?.isEmpty ?? true) && !(publicKey?.isEmpty ?? true)
        isReleaseConfigured = configured

        // Start the updater only when release metadata is present so local/dev builds avoid Sparkle config errors.
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater ?? configured,
            updaterDelegate: sparkleDelegate,
            userDriverDelegate: sparkleUserDriverDelegate
        )
        sparkleUserDriverDelegate.onWillShowUpdate = { [weak self] in
            self?.didCheckOnLaunch = true
            self?.launchCheckCancellable = nil
        }
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        didCheckOnLaunch = true
        launchCheckCancellable = nil
        controller.updater.checkForUpdates()
    }

    /// Call once the SwiftUI main window is on screen so a launch probe cannot close the last window and quit.
    ///
    /// `SPUUpdater.startUpdater()` sets `canCheckForUpdates = true` synchronously and then finishes
    /// startup via `DispatchQueue.main.async` (which may immediately begin a scheduled background
    /// check if `SUScheduledCheckInterval` has elapsed). Deferring onto `DispatchQueue.main` and
    /// waiting for `canCheckForUpdates && !sessionInProgress` lets Sparkle's startup turn settle
    /// first and guarantees the launch probe runs whenever Sparkle is idle.
    func mainWindowDidAppear() {
        guard isReleaseConfigured, !didScheduleLaunchCheck else { return }
        didScheduleLaunchCheck = true

        launchCheckCancellable = Publishers.CombineLatest(
            controller.updater.publisher(for: \.canCheckForUpdates),
            controller.updater.publisher(for: \.sessionInProgress)
        )
        .filter { canCheck, sessionInProgress in
            canCheck && !sessionInProgress
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.checkForUpdatesOnLaunch()
        }
    }

    /// Probes the feed once per launch; Sparkle shows the update dialog only when a newer build exists.
    func checkForUpdatesOnLaunch() {
        guard
            isReleaseConfigured,
            !didCheckOnLaunch,
            controller.updater.canCheckForUpdates,
            !controller.updater.sessionInProgress,
            !SparkleUpdateSession.shared.blocksQuitOnLastWindowClosed
        else { return }
        didCheckOnLaunch = true
        launchCheckCancellable = nil
        sparkleDelegate.launchProbeActive = true
        controller.updater.checkForUpdateInformation()
    }
}

struct CheckForUpdatesMenuItem: View {
    @ObservedObject var updater: AppUpdaterModel

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
