import AppKit
import GatteyPhotosCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class GalleryStore: ObservableObject {
    @Published var settings: AppSettings = AppConfig.loadSettings()
    @Published var state: GalleryState = AppConfig.loadLocalState()
    @Published var selectedID: PhotoID?
    @Published var statusMessage: String = "Ready"
    @Published var isBusy = false

    private let engine = SyncEngine()

    var activePhotos: [PhotoEntry] {
        state.activePhotos()
    }

    func reloadSettings() {
        settings = AppConfig.loadSettings()
    }

    func saveSettings() {
        try? AppConfig.saveSettings(settings)
        reloadSettings()
    }

    func refresh() async {
        await run("Refreshing…") {
            let merged = try await engine.pullAndMerge(settings: settings)
            state = merged
            statusMessage = "Synced v\(merged.version)"
        }
    }

    func refreshAndPushDevice() async {
        await run("Syncing gallery and device…") {
            let merged = try await engine.fullSync(settings: settings)
            state = merged
            statusMessage = "Synced to server and device"
        }
    }

    func uploadFromPanel() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }

        await run("Uploading…") {
            let client = try SyncClient(settings: settings)
            var latest = state
            for url in panel.urls {
                let data = try Data(contentsOf: url)
                let name = url.lastPathComponent
                let response = try await client.uploadPhoto(jpegData: data, filename: name)
                latest = response.state
            }
            try AppConfig.saveLocalState(latest)
            state = latest
            try await SyncClient(settings: settings).downloadMissing(for: latest)
            statusMessage = "Upload complete"
        }
    }

    func deleteSelected() async {
        guard let id = selectedID else { return }
        await run("Deleting…") {
            let client = try SyncClient(settings: settings)
            let response = try await client.deletePhoto(id: id)
            state = response.state
            try AppConfig.saveLocalState(state)
            selectedID = nil
            statusMessage = "Deleted"
        }
    }

    func applyOrder(_ order: [PhotoID]) async {
        await run("Saving order…") {
            let client = try SyncClient(settings: settings)
            let response = try await client.reorder(order)
            state = response.state
            try AppConfig.saveLocalState(state)
            statusMessage = "Order saved"
        }
    }

    func pushSelectedToDevice() async {
        guard let id = selectedID,
              let photo = state.photos[id],
              let data = try? Data(contentsOf: AppConfig.cacheURL(for: id)) else { return }
        await run("Sending to device…") {
            let device = try Bloomin8Client(settings: settings)
            try await device.upload(jpegData: data, filename: photo.filename, showNow: true)
            statusMessage = "Sent to Bloomin8"
        }
    }

    private func run(_ label: String, _ work: () async throws -> Void) async {
        isBusy = true
        statusMessage = label
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
