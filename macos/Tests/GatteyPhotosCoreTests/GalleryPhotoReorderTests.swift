import XCTest
@testable import GatteyPhotosCore

final class GalleryPhotoReorderTests: XCTestCase {
    func testForwardAdjacentMove() {
        let order = ["a", "b", "c"]
        let next = PhotoManifestReorder.applyingMove(draggedID: "a", insertionIndex: 2, in: order)
        XCTAssertEqual(next, ["b", "a", "c"])
    }

    func testBackwardMove() {
        let order = ["a", "b", "c", "d"]
        let next = PhotoManifestReorder.applyingMove(draggedID: "d", insertionIndex: 0, in: order)
        XCTAssertEqual(next, ["d", "a", "b", "c"])
    }

    func testInsertionIndexLeadingHalf() {
        XCTAssertEqual(PhotoManifestReorder.insertionIndex(horizontalFraction: 0.2, photoIndex: 1, photoCount: 3), 1)
    }

    func testInsertionIndexTrailingHalf() {
        XCTAssertEqual(PhotoManifestReorder.insertionIndex(horizontalFraction: 0.8, photoIndex: 1, photoCount: 3), 2)
    }
}
