import Foundation

/// Pull remote gallery, merge with local cache, download missing JPEGs. Does not touch UI or persist — `GalleryStore` owns that.
public struct SyncEngine: Sendable {
    public init() {}

    public func pullRemoteMerged(settings: AppSettings) async throws -> GalleryState {
        let client = try SyncClient(settings: settings)
        let remote = try await client.fetchGallery()
        let local = AppConfig.loadLocalState()
        let merged = GalleryMerge.merge(local: local, remote: remote.state)
        try await client.downloadMissing(for: merged)
        return merged
    }
}
