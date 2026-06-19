import Combine
import Sparkle
import SwiftUI

/// Presents Sparkle's update UI when the launch-time probe finds a newer build.
@MainActor
final class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
  var launchProbeActive = false

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    guard launchProbeActive else { return }
    launchProbeActive = false
    updater.checkForUpdates()
  }

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: (any Error)?
  ) {
    launchProbeActive = false
  }
}

@MainActor
final class AppUpdaterModel: ObservableObject {
  let controller: SPUStandardUpdaterController
  @Published var canCheckForUpdates = false
  private let isReleaseConfigured: Bool
  private var didCheckOnLaunch = false
  private let sparkleDelegate = SparkleUpdaterDelegate()
  private var launchCheckCancellable: AnyCancellable?

  init() {
    let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
    let configured = !(feedURL?.isEmpty ?? true) && !(publicKey?.isEmpty ?? true)
    isReleaseConfigured = configured

    // Start the updater only when release metadata is present so local/dev builds avoid Sparkle config errors.
    controller = SPUStandardUpdaterController(
      startingUpdater: configured,
      updaterDelegate: sparkleDelegate,
      userDriverDelegate: nil
    )
    controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)

    if configured {
      scheduleLaunchUpdateCheck()
    }
  }

  func checkForUpdates() {
    controller.updater.checkForUpdates()
  }

  /// Probes the feed once per launch; Sparkle shows the update dialog only when a newer build exists.
  func checkForUpdatesOnLaunch() {
    guard isReleaseConfigured, !didCheckOnLaunch else { return }
    didCheckOnLaunch = true
    sparkleDelegate.launchProbeActive = true
    controller.updater.checkForUpdateInformation()
  }

  private func scheduleLaunchUpdateCheck() {
    launchCheckCancellable = controller.updater.publisher(for: \.canCheckForUpdates)
      .removeDuplicates()
      .filter { $0 }
      .first()
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.checkForUpdatesOnLaunch()
      }
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
