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
        let alexId = GalleryState.uploaderId(forDisplayName: "Alex")
        let samId = GalleryState.uploaderId(forDisplayName: "Sam")
        let json = """
            {
              "updatedAt": "2026-10-15T09:00:00.000Z",
              "order": ["photoA", "photoB"],
              "uploaders": {
                "\(alexId)": "Alex",
                "\(samId)": "Sam"
              },
              "photos": {
                "photoA": {
                  "id": "photoA",
                  "filename": "photoA.jpg",
                  "blobPath": "photos/photoA.jpg",
                  "sizeBytes": 1024,
                  "updatedAt": "2026-06-01T23:51:21.408Z",
                  "deletedAt": null,
                  "uploaderId": "\(alexId)"
                },
                "photoB": {
                  "id": "photoB",
                  "filename": "photoB.jpg",
                  "blobPath": "photos/photoB.jpg",
                  "sizeBytes": 2048,
                  "updatedAt": "2026-09-08T21:27:13.914Z",
                  "deletedAt": null,
                  "uploaderId": "\(samId)"
                }
              }
            }
            """
        let decoded = try JSONDecoder().decode(GalleryState.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded.uploaders[alexId], "Alex")
        XCTAssertEqual(decoded.uploaders[samId], "Sam")
        XCTAssertEqual(decoded.photos["photoA"]?.uploaderId, alexId)
        XCTAssertEqual(decoded.photos["photoB"]?.uploaderId, samId)
    }
}
