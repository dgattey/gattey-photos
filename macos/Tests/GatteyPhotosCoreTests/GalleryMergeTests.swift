import XCTest
@testable import GatteyPhotosCore

final class GalleryMergeTests: XCTestCase {
    func testPrefersLocalOrderWhenLocalVersionIsNewer() {
        let local = Self.state(
            version: 5,
            order: ["c", "a", "b"],
            photos: Self.activePhotos(ids: ["a", "b", "c"])
        )
        let remote = Self.state(
            version: 4,
            order: ["a", "b", "c"],
            photos: Self.activePhotos(ids: ["a", "b", "c"])
        )

        let merged = GalleryMerge.merge(local: local, remote: remote)
        XCTAssertEqual(merged.order.filter { merged.photos[$0]?.isDeleted == false }, ["c", "a", "b"])
        XCTAssertEqual(merged.version, 5)
    }

    func testApplyingActiveDisplayOrderBumpsVersion() {
        var state = Self.state(
            version: 2,
            order: ["a", "b"],
            photos: Self.activePhotos(ids: ["a", "b"])
        )
        state = state.applyingActiveDisplayOrder(["b", "a"])
        XCTAssertEqual(state.order.filter { state.photos[$0]?.isDeleted == false }, ["b", "a"])
        XCTAssertEqual(state.version, 3)
    }

    func testUsesRemoteOrderWhenRemoteVersionIsNewer() {
        let local = Self.state(
            version: 3,
            order: ["b", "a"],
            photos: Self.activePhotos(ids: ["a", "b"])
        )
        let remote = Self.state(
            version: 4,
            order: ["a", "b"],
            photos: Self.activePhotos(ids: ["a", "b"])
        )

        let merged = GalleryMerge.merge(local: local, remote: remote)
        XCTAssertEqual(merged.order, ["a", "b"])
        XCTAssertEqual(merged.version, 4)
    }

    private static func state(version: Int, order: [PhotoID], photos: [PhotoID: PhotoEntry]) -> GalleryState {
        GalleryState(version: version, order: order, photos: photos, currentPhotoId: order.first, currentPhotoUpdatedBy: nil)
    }

    private static func activePhotos(ids: [PhotoID]) -> [PhotoID: PhotoEntry] {
        Dictionary(uniqueKeysWithValues: ids.map { id in
            (id, PhotoEntry(
                id: id,
                filename: "\(id).jpg",
                blobPath: id,
                sizeBytes: 1,
                updatedAt: "",
                deletedAt: nil,
                uploadedBy: nil,
                downloadUrl: nil
            ))
        })
    }
}
