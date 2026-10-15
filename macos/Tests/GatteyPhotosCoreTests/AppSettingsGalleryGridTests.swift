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

    func testCoalescingUploadersRepairsMergedDefaultUploader() {
        let dylanId = GalleryState.uploaderId(forDisplayName: "Dylan")
        let beccaId = GalleryState.uploaderId(forDisplayName: "Becca")
        let rawPhotos: [PhotoID: RawManifestPhoto] = [
            "dylanPhoto": RawManifestPhoto(
                id: "dylanPhoto",
                filename: "IMG_4722.jpeg",
                blobPath: "photos/dylanPhoto.jpg",
                sizeBytes: 4424947,
                updatedAt: "2026-06-01T23:51:21.408Z",
                deletedAt: nil,
                uploaderId: dylanId,
                downloadUrl: nil
            ),
            "beccaPhoto": RawManifestPhoto(
                id: "beccaPhoto",
                filename: "IMG_0873.jpeg",
                blobPath: "photos/beccaPhoto.jpg",
                sizeBytes: 372512,
                updatedAt: "2026-09-08T21:27:13.914Z",
                deletedAt: nil,
                uploaderId: dylanId,
                downloadUrl: nil
            ),
        ]
        let coalesced = GalleryState.coalescingUploaders(
            rawPhotos: rawPhotos,
            rawUploaders: [dylanId: "Becca"]
        )
        XCTAssertEqual(coalesced.uploaders[dylanId], "Dylan")
        XCTAssertEqual(coalesced.uploaders[beccaId], "Becca")
        XCTAssertEqual(coalesced.photos["dylanPhoto"]?.uploaderId, dylanId)
        XCTAssertEqual(coalesced.photos["beccaPhoto"]?.uploaderId, beccaId)
    }
}
