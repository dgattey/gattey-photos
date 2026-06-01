import XCTest
@testable import GatteyPhotosCore

final class AppSettingsGalleryGridTests: XCTestCase {
    func testClampedGalleryGridColumnCountBounds() {
        XCTAssertEqual(AppSettings.clampedGalleryGridColumnCount(1), 2)
        XCTAssertEqual(AppSettings.clampedGalleryGridColumnCount(9), 8)
        XCTAssertEqual(AppSettings.clampedGalleryGridColumnCount(5), 5)
    }

    func testMigrationFromLegacyColumnMinMatchesReferenceWidth() {
        XCTAssertEqual(AppSettings.galleryGridColumnCount(migratingLegacyColumnMin: 140), 5)
        XCTAssertEqual(AppSettings.galleryGridColumnCount(migratingLegacyColumnMin: 96), 8)
        XCTAssertEqual(AppSettings.galleryGridColumnCount(migratingLegacyColumnMin: 320), 2)
    }

    func testDecodesNewColumnCountKey() throws {
        let json = """
        {"serverBaseURL":"https://photos.gattey.com","syncSessionToken":"","galleryName":"default","galleryGridColumnCount":3}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(settings.galleryGridColumnCount, 3)
    }

    func testDecodesLegacyColumnMinKey() throws {
        let json = """
        {"serverBaseURL":"https://photos.gattey.com","syncSessionToken":"","galleryName":"default","galleryThumbnailColumnMin":140}
        """
        let settings = try JSONDecoder().decode(AppSettings.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(settings.galleryGridColumnCount, 5)
    }
}
