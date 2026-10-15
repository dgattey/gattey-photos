#if os(macOS)
import GatteyPhotosCore
import XCTest
@testable import GatteyPhotosUI

final class GalleryThumbnailSizeStepTests: XCTestCase {
    func testSmallerThumbnailsStepAddsAPhotoPerRow() {
        XCTAssertEqual(GalleryThumbnailSizeStep.smaller.help, "Smaller thumbnails")
        XCTAssertEqual(GalleryThumbnailSizeStep.smaller.columnCount(steppingFrom: 5), 6)
    }

    func testLargerThumbnailsStepRemovesAPhotoPerRow() {
        XCTAssertEqual(GalleryThumbnailSizeStep.larger.help, "Larger thumbnails")
        XCTAssertEqual(GalleryThumbnailSizeStep.larger.columnCount(steppingFrom: 5), 4)
    }

    func testStepIsUnavailableOnceTheGridReachesItsBound() {
        XCTAssertNil(GalleryThumbnailSizeStep.smaller.columnCount(steppingFrom: AppSettings.galleryGridColumnCountMax))
        XCTAssertNil(GalleryThumbnailSizeStep.larger.columnCount(steppingFrom: AppSettings.galleryGridColumnCountMin))
    }
}
#endif
