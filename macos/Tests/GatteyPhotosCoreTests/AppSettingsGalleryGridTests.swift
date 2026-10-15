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
        XCTAssertEqual(settings.displayName, "")
    }

    func testCoalescingUploadersPreservesServerUploadersAndPhotoUploaderIds() throws {
        let dylanId = GalleryState.uploaderId(forDisplayName: "Dylan")
        let beccaId = GalleryState.uploaderId(forDisplayName: "Becca")
        let json = """
        {
          "updatedAt": "2026-10-15T09:00:00.000Z",
          "order": ["dylanPhoto", "beccaPhoto"],
          "uploaders": {
            "\(dylanId)": "Dylan",
            "\(beccaId)": "Becca"
          },
          "photos": {
            "dylanPhoto": {
              "id": "dylanPhoto",
              "filename": "IMG_4722.jpeg",
              "blobPath": "photos/dylanPhoto.jpg",
              "sizeBytes": 4424947,
              "updatedAt": "2026-06-01T23:51:21.408Z",
              "deletedAt": null,
              "uploaderId": "\(dylanId)"
            },
            "beccaPhoto": {
              "id": "beccaPhoto",
              "filename": "IMG_0873.jpeg",
              "blobPath": "photos/beccaPhoto.jpg",
              "sizeBytes": 372512,
              "updatedAt": "2026-09-08T21:27:13.914Z",
              "deletedAt": null,
              "uploaderId": "\(beccaId)"
            }
          }
        }
        """
        let decoded = try JSONDecoder().decode(GalleryState.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded.uploaders[dylanId], "Dylan")
        XCTAssertEqual(decoded.uploaders[beccaId], "Becca")
        XCTAssertEqual(decoded.photos["dylanPhoto"]?.uploaderId, dylanId)
        XCTAssertEqual(decoded.photos["beccaPhoto"]?.uploaderId, beccaId)
    }
}
