import XCTest
@testable import GatteyPhotosUI

final class GalleryToolbarCopyTests: XCTestCase {
    func testSyncTooltipShowsProgressWhileSyncing() {
        XCTAssertEqual(GalleryToolbarCopy.sync(isSyncing: false), "Sync photos")
        XCTAssertEqual(GalleryToolbarCopy.sync(isSyncing: true), "Syncing photos…")
    }

    func testActivityTooltipNamesTheToggleResult() {
        XCTAssertEqual(GalleryToolbarCopy.activityLog(isShown: false), "Show activity log")
        XCTAssertEqual(GalleryToolbarCopy.activityLog(isShown: true), "Hide activity log")
    }
}
