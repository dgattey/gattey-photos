import Foundation

public struct SyncEngine: Sendable {
    public init() {}

    public func pullAndMerge(settings: AppSettings) async throws -> GalleryState {
        let client = try SyncClient(settings: settings)
        let remote = try await client.fetchGallery()
        let local = AppConfig.loadLocalState()
        let merged = GalleryMerge.merge(local: local, remote: remote.state)
        try await client.downloadMissing(for: merged)
        try AppConfig.saveLocalState(merged)
        return merged
    }

    public func pushToDevice(settings: AppSettings, state: GalleryState) async throws {
        let device = try Bloomin8Client(settings: settings)
        try await device.syncDevice(from: state)
    }

    public func fullSync(settings: AppSettings) async throws -> GalleryState {
        let merged = try await pullAndMerge(settings: settings)
        try await pushToDevice(settings: settings, state: merged)
        return merged
    }
}
