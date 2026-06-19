import Combine
import Sparkle
import SwiftUI

@MainActor
final class AppUpdaterModel: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false
    private let isReleaseConfigured: Bool
    private var didCheckOnLaunch = false

    init() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let configured = !(feedURL?.isEmpty ?? true) && !(publicKey?.isEmpty ?? true)
        isReleaseConfigured = configured

        // Start the updater only when release metadata is present so local/dev builds avoid Sparkle config errors.
        controller = SPUStandardUpdaterController(
            startingUpdater: configured,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// Background feed check once per process when release keys are embedded (packaged builds).
    func checkForUpdatesOnLaunch() {
        guard isReleaseConfigured, !didCheckOnLaunch else { return }
        didCheckOnLaunch = true
        controller.updater.checkForUpdatesInBackground()
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
