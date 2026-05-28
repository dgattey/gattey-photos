import AppKit
import GatteyPhotosCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class GalleryStore: ObservableObject {
    @Published var settings: AppSettings = AppConfig.loadSettings()
    @Published var state: GalleryState = AppConfig.loadLocalState()
    @Published var selectedID: PhotoID?
    @Published var serverLinkStatus: LinkStatus = .down
    @Published var deviceLinkStatus: LinkStatus = .down
    @Published var isBusy = false
    @Published var isSyncing = false

    private let engine = SyncEngine()
    private var lastServerOK: Date?

    var activePhotos: [PhotoEntry] {
        state.activePhotos()
    }

    func reloadSettings() {
        settings = AppConfig.loadSettings()
    }

    func saveSettings() {
        settings.galleryName = "default"
        try? AppConfig.saveSettings(settings)
        Task { await updateDeviceStatus() }
    }

    func noteServerOK() {
        lastServerOK = Date()
        serverLinkStatus = .up
    }

    func refresh() async {
        await run {
            let merged = try await engine.pullAndMerge(settings: settings)
            state = merged
            noteServerOK()
        }
    }

    /// Pull family gallery from server, then push full gallery to the device.
    func syncAll() async {
        isSyncing = true
        defer {
            isSyncing = false
            Task { await updateDeviceStatus() }
        }
        isBusy = true
        defer { isBusy = false }

        do {
            let merged = try await engine.pullAndMerge(settings: settings)
            state = merged
            noteServerOK()
        } catch {
            markServerUnreachableAfterSyncFailure(error)
            return
        }

        do {
            try await engine.pushToDevice(settings: settings, state: state)
        } catch {
            deviceLinkStatus = .down
        }
    }

    private func markServerUnreachableAfterSyncFailure(_ error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain,
           [NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorNetworkConnectionLost]
            .contains(ns.code) {
            lastServerOK = nil
            serverLinkStatus = .down
        } else {
            Task { await updateConnectionStatus() }
        }
    }

    func updateDeviceStatus() async {
        deviceLinkStatus = await Reachability.pingDevice(ip: settings.deviceIP) ? .up : .down
    }

    func updateConnectionStatus(showChecking: Bool = false) async {
        if showChecking {
            serverLinkStatus = .checking
            deviceLinkStatus = .checking
        }
        async let serverUp = Reachability.pingServer(baseURL: settings.serverBaseURL)
        async let deviceUp = Reachability.pingDevice(ip: settings.deviceIP)
        let (server, device) = await (serverUp, deviceUp)
        applyServerStatus(pingSucceeded: server)
        deviceLinkStatus = device ? .up : .down
    }

    private func applyServerStatus(pingSucceeded: Bool) {
        if pingSucceeded {
            noteServerOK()
            return
        }
        if let lastServerOK, Date().timeIntervalSince(lastServerOK) < 600 {
            serverLinkStatus = .up
            return
        }
        serverLinkStatus = .down
    }

    func uploadFromPanel() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        await uploadFiles(urls: panel.urls)
    }

    func uploadFromDrop(providers: [NSItemProvider]) async {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }
        await uploadFiles(urls: urls)
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        let types = [UTType.fileURL.identifier, UTType.jpeg.identifier, UTType.image.identifier]
        guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let data = item as? Data, let path = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: URL(fileURLWithPath: path))
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    func uploadFiles(urls: [URL]) async {
        await run {
            let client = try SyncClient(settings: settings)
            var latest = state
            for url in urls {
                let data = try Data(contentsOf: url)
                let name = url.lastPathComponent
                let response = try await client.uploadPhoto(jpegData: data, filename: name)
                latest = response.state
            }
            try AppConfig.saveLocalState(latest)
            state = latest
            try await SyncClient(settings: settings).downloadMissing(for: latest)
            noteServerOK()
            await updateDeviceStatus()
        }
    }

    func deleteSelected() async {
        guard let id = selectedID else { return }
        await run {
            let client = try SyncClient(settings: settings)
            let response = try await client.deletePhoto(id: id)
            state = response.state
            try AppConfig.saveLocalState(state)
            selectedID = nil
            noteServerOK()
            await updateDeviceStatus()
        }
    }

    func applyOrder(_ order: [PhotoID]) async {
        await run {
            let client = try SyncClient(settings: settings)
            let response = try await client.reorder(order)
            state = response.state
            try AppConfig.saveLocalState(state)
            noteServerOK()
            await updateDeviceStatus()
        }
    }

    private func run(_ work: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            await updateConnectionStatus()
        }
    }
}
