import XCTest
@testable import GatteyPhotosCore

final class AppSettingsGalleryGridTests: XCTestCase {
    func testClampedGalleryGridColumnCountBounds() {
        XCTAssertEqual(AppSettings.clampedGalleryGridColumnCount(1), 2)
        XCTAssertEqual(AppSettings.clampedGalleryGridColumnCount(9), 8)
        XCTAssertEqual(AppSettings.clampedGalleryGridColumnCount(5), 5)
    }

    func testDecodesNewColumnCountKey() throws {
        let json = """
        {"serverBaseURL":"https://photos.gattey.com","syncSessionToken":"","galleryName":"default","galleryGridColumnCount":3}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(settings.galleryGridColumnCount, 3)
    }

    func testIgnoresUnknownLegacyKeysAndUsesDefaults() throws {
        let json = """
        {"serverBaseURL":"https://photos.gattey.com","syncSessionToken":"","galleryName":"default","galleryThumbnailColumnMin":140,"deviceIP":"1.2.3.4","syncPassword":"x"}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(settings.galleryGridColumnCount, AppSettings.galleryGridColumnCountDefault)
    }
}
