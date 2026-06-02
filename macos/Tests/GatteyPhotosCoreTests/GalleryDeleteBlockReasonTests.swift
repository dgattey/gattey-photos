import XCTest
@testable import GatteyPhotosCore

final class GalleryDeleteBlockReasonTests: XCTestCase {
    func testBlocksDeletingCurrentPhoto() {
        var state = GalleryState.empty
        state.order = ["a", "b"]
        state.photos = [
            "a": PhotoEntry(id: "a", filename: "a.jpg", blobPath: "a", sizeBytes: 1, updatedAt: "", deletedAt: nil, uploaderId: "u-test", downloadUrl: nil),
            "b": PhotoEntry(id: "b", filename: "b.jpg", blobPath: "b", sizeBytes: 1, updatedAt: "", deletedAt: nil, uploaderId: "u-test", downloadUrl: nil),
        ]
        state.currentPhotoId = "a"

        XCTAssertEqual(state.deleteBlockReason(for: ["a"]), .includesCurrentPhoto)
        XCTAssertEqual(state.deleteBlockReason(for: ["a", "b"]), .includesCurrentPhoto)
        XCTAssertNil(state.deleteBlockReason(for: ["b"]))
    }

    func testBlocksDeletingLastPhoto() {
        var state = GalleryState.empty
        state.order = ["only"]
        state.photos = [
            "only": PhotoEntry(id: "only", filename: "only.jpg", blobPath: "only", sizeBytes: 1, updatedAt: "", deletedAt: nil, uploaderId: "u-test", downloadUrl: nil),
        ]
        state.currentPhotoId = "only"

        XCTAssertEqual(state.deleteBlockReason(for: ["only"]), .includesCurrentPhoto)
    }

    func testBlocksRemovingEveryActivePhoto() {
        var state = GalleryState.empty
        state.order = ["a", "b"]
        state.photos = [
            "a": PhotoEntry(id: "a", filename: "a.jpg", blobPath: "a", sizeBytes: 1, updatedAt: "", deletedAt: nil, uploaderId: "u-test", downloadUrl: nil),
            "b": PhotoEntry(id: "b", filename: "b.jpg", blobPath: "b", sizeBytes: 1, updatedAt: "", deletedAt: nil, uploaderId: "u-test", downloadUrl: nil),
        ]
        state.currentPhotoId = nil

        XCTAssertEqual(state.deleteBlockReason(for: ["a", "b"]), .wouldRemoveAllPhotos)
    }
}
