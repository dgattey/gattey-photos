#if os(macOS)
import AppKit
#endif
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import GatteyPhotosCore
@testable import GatteyPhotosUI

final class PerformanceOptimizationTests: XCTestCase {
    @MainActor
    func testGalleryStoreMemoizesActivePhotosAndShowingTag() {
        let store = GalleryStore()
        var photos: [PhotoID: PhotoEntry] = [:]
        var order: [PhotoID] = []
        for i in 0..<50 {
            let id = "photo-\(i)"
            order.append(id)
            photos[id] = PhotoEntry(
                id: id,
                filename: "\(id).jpg",
                blobPath: "photos/\(id).jpg",
                sizeBytes: 1024,
                updatedAt: "2026-01-01T00:00:00.000Z",
                deletedAt: nil,
                uploaderId: "u1"
            )
        }
        store.state = GalleryState(
            updatedAt: "2026-06-01T00:00:00.000Z",
            order: order,
            photos: photos,
            uploaders: ["u1": "Dylan"],
            currentPhotoId: "photo-0"
        )

        XCTAssertEqual(store.activePhotos.count, 50)
        XCTAssertEqual(store.activePhotoIDs.count, 50)
        XCTAssertEqual(store.showingTag(for: "photo-0"), "Showing for today")
        XCTAssertNotNil(store.showingTag(for: "photo-1"))

        // Mutating currentPhotoId without changing updatedAt must invalidate the rotation tag cache.
        var rotated = store.state
        rotated.currentPhotoId = "photo-1"
        store.state = rotated
        XCTAssertEqual(store.showingTag(for: "photo-1"), "Showing for today")
        XCTAssertNotEqual(store.showingTag(for: "photo-0"), "Showing for today")
    }

    func testImageDownsamplerCachesDecodedThumbnailsInMemory() throws {
        ImageDownsampler.clearMemoryCache()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-thumb-cache-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            ImageDownsampler.clearMemoryCache()
            try? FileManager.default.removeItem(at: tempDir)
        }

        let jpegURL = tempDir.appendingPathComponent("test.jpg")
        let ctx = CGContext(
            data: nil,
            width: 600,
            height: 400,
            bitsPerComponent: 8,
            bytesPerRow: 600 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let cg = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(jpegURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)

        XCTAssertNil(ImageDownsampler.cachedThumbnail(from: jpegURL, maxPixelSize: 256))
        let first = try XCTUnwrap(ImageDownsampler.loadThumbnail(from: jpegURL, maxPixelSize: 256))
        let second = try XCTUnwrap(ImageDownsampler.cachedThumbnail(from: jpegURL, maxPixelSize: 256))
        XCTAssertTrue(first === second)

        ImageDownsampler.clearMemoryCache()
        XCTAssertNil(ImageDownsampler.cachedThumbnail(from: jpegURL, maxPixelSize: 256))
    }

    func testPhotoCacheJPEGFilePrefixCheck() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gp-jpeg-prefix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let jpegURL = tempDir.appendingPathComponent("valid.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]).write(to: jpegURL)
        XCTAssertTrue(PhotoCacheJPEG.isJPEGFile(at: jpegURL))

        let pngURL = tempDir.appendingPathComponent("not-jpeg.png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]).write(to: pngURL)
        XCTAssertFalse(PhotoCacheJPEG.isJPEGFile(at: pngURL))
    }

    #if os(macOS)
    @MainActor
    func testAppChromeStateTiltDeadbandSkipsMicroJitter() {
        let chrome = AppChromeState()
        let size = CGSize(width: 1000, height: 800)
        chrome.setDevicePreviewHoverTilt(pointer: CGPoint(x: 800, y: 200), in: size)
        let initial = chrome.devicePreviewHoverTilt
        XCTAssertNotEqual(initial, DevicePreviewHoverTiltAngles())

        // Sub-pixel / tiny cursor movement within 0.05 deg deadband should not mutate state.
        chrome.setDevicePreviewHoverTilt(pointer: CGPoint(x: 801, y: 201), in: size)
        XCTAssertEqual(chrome.devicePreviewHoverTilt, initial)

        chrome.resetDevicePreviewHoverTilt(animated: false)
        XCTAssertEqual(chrome.devicePreviewHoverTilt, DevicePreviewHoverTiltAngles())
    }
    #endif
}
