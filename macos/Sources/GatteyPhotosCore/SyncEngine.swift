import Foundation

public struct SyncEngine: Sendable {
    public init() {}

    public func pullAndMerge(settings: AppSettings) async throws -> (state: GalleryState, currentPhotoDelta: CurrentPhotoPullDelta?) {
        let client = try SyncClient(settings: settings)
        let remote = try await client.fetchGallery()
        let local = AppConfig.loadLocalState()
        let previousId = local.currentPhotoId
        let merged = GalleryMerge.merge(local: local, remote: remote.state).withResolvedCurrentPhoto()
        let delta: CurrentPhotoPullDelta? =
            previousId != merged.currentPhotoId
            ? CurrentPhotoPullDelta(
                previousId: previousId,
                newId: merged.currentPhotoId,
                updatedBy: merged.currentPhotoUpdatedBy
            )
            : nil
        try await client.downloadMissing(for: merged)
        try AppConfig.saveLocalState(merged)
        return (merged, delta)
    }

    public func pushToDevice(settings: AppSettings, state: GalleryState) async throws {
        #if os(iOS)
        return
        #else
        guard let photo = state.currentPhoto() else { return }
        _ = try await Bloomin8DevicePush.pushCurrentPhoto(photo, settings: settings)
        #endif
    }

    public func fullSync(settings: AppSettings) async throws -> (state: GalleryState, currentPhotoDelta: CurrentPhotoPullDelta?) {
        let (merged, delta) = try await pullAndMerge(settings: settings)
        try await pushToDevice(settings: settings, state: merged)
        return (merged, delta)
    }
}
