import Foundation
import Sparkle
import Testing

@testable import GatteyPhotosApp
@testable import GatteyPhotosCore

@Suite("Sparkle Launch Update Check & Session")
struct AppUpdaterTests {
    private static let configuredInfo: [String: Any] = [
        "SUFeedURL": "https://github.com/dgattey/gattey-photos/releases/latest/download/appcast.xml",
        "SUPublicEDKey": "n6Y2D5B8gJ9e0F1H2I3J4K5L6M7N8O9P0Q1R2S3T4U5=",
    ]

    @Test("SparkleUpdaterDelegate defers checkForUpdates until probing cycle finishes")
    @MainActor
    func sparkleUpdaterDelegateEscalatesOnFinishCycle() {
        let model = AppUpdaterModel(infoDictionary: Self.configuredInfo, startingUpdater: false)
        let delegate = model.sparkleDelegate
        let updater = model.controller.updater

        var escalatedCount = 0
        delegate.onProbeFoundUpdate = { _ in
            escalatedCount += 1
        }

        delegate.launchProbeActive = true
        #expect(!delegate.launchProbeFoundUpdate)

        let dummyItem = SUAppcastItem.empty()
        delegate.updater(updater, didFindValidUpdate: dummyItem)

        // While the probing session is still active inside didFindValidUpdate, checkForUpdates()
        // must not run yet because Sparkle's sessionInProgress is still true.
        #expect(delegate.launchProbeActive)
        #expect(delegate.launchProbeFoundUpdate)
        #expect(escalatedCount == 0)

        delegate.updater(updater, didFinishUpdateCycleFor: .updateInformation, error: nil)
        #expect(!delegate.launchProbeActive)
        #expect(!delegate.launchProbeFoundUpdate)
        #expect(escalatedCount == 1)

        // Subsequent cycle completions do not re-escalate.
        delegate.updater(updater, didFinishUpdateCycleFor: .updates, error: nil)
        #expect(escalatedCount == 1)
    }

    @Test("SparkleUpdaterDelegate clears probe state when no update is found or when aborted")
    @MainActor
    func sparkleUpdaterDelegateClearsWhenNoUpdateFound() {
        let model = AppUpdaterModel(infoDictionary: Self.configuredInfo, startingUpdater: false)
        let delegate = model.sparkleDelegate
        let updater = model.controller.updater

        var escalatedCount = 0
        delegate.onProbeFoundUpdate = { _ in
            escalatedCount += 1
        }

        // Cycle finishes without didFindValidUpdate: no escalation.
        delegate.launchProbeActive = true
        delegate.updater(updater, didFinishUpdateCycleFor: .updateInformation, error: nil)
        #expect(!delegate.launchProbeActive)
        #expect(!delegate.launchProbeFoundUpdate)
        #expect(escalatedCount == 0)

        // Cycle aborts after finding an item: state resets without escalating.
        delegate.launchProbeActive = true
        delegate.updater(updater, didFindValidUpdate: SUAppcastItem.empty())
        #expect(delegate.launchProbeFoundUpdate)
        delegate.updater(
            updater,
            didAbortWithError: NSError(domain: "SparkleTest", code: 1)
        )
        #expect(!delegate.launchProbeActive)
        #expect(!delegate.launchProbeFoundUpdate)
        delegate.updater(updater, didFinishUpdateCycleFor: .updateInformation, error: nil)
        #expect(escalatedCount == 0)
    }

    @Test("AppUpdaterModel configuration and session guards")
    @MainActor
    func appUpdaterModelConfigurationAndGuards() {
        SparkleUpdateSession.shared.reset()

        let unconfigured = AppUpdaterModel(infoDictionary: [:], startingUpdater: false)
        #expect(!unconfigured.isReleaseConfigured)
        unconfigured.mainWindowDidAppear()
        #expect(!unconfigured.didScheduleLaunchCheck)
        unconfigured.checkForUpdatesOnLaunch()
        #expect(!unconfigured.didCheckOnLaunch)

        let configured = AppUpdaterModel(infoDictionary: Self.configuredInfo, startingUpdater: false)
        #expect(configured.isReleaseConfigured)
        #expect(!configured.didScheduleLaunchCheck)
        #expect(!configured.didCheckOnLaunch)

        configured.mainWindowDidAppear()
        #expect(configured.didScheduleLaunchCheck)

        // When startingUpdater is false, canCheckForUpdates is false so checkForUpdatesOnLaunch()
        // refuses to fire prematurely while Sparkle is not ready.
        configured.checkForUpdatesOnLaunch()
        #expect(!configured.didCheckOnLaunch)
        #expect(!configured.sparkleDelegate.launchProbeActive)

        // If Sparkle's scheduled background check already presents an update on launch,
        // onWillShowUpdate marks didCheckOnLaunch so no duplicate probe runs afterward.
        configured.sparkleUserDriverDelegate.handleWillShowUpdate()
        #expect(SparkleUpdateSession.shared.blocksQuitOnLastWindowClosed)
        #expect(configured.didCheckOnLaunch)

        configured.sparkleUserDriverDelegate.standardUserDriverWillFinishUpdateSession()
        #expect(!SparkleUpdateSession.shared.blocksQuitOnLastWindowClosed)
    }
}
