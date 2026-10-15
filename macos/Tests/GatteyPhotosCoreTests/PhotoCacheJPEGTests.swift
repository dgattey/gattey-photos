import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import GatteyPhotosCore

final class PhotoCacheJPEGTests: XCTestCase {
    func testIsJPEGRecognizesJFIFHeader() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        XCTAssertTrue(PhotoCacheJPEG.isJPEG(jpeg))
    }

    func testIsJPEGRejectsHEICMagic() {
        let heicPrefix = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70])
        XCTAssertFalse(PhotoCacheJPEG.isJPEG(heicPrefix))
    }

    func testNormalizedJPEGDataRejectsCorruptJPEGHeader() {
        let corrupt = Data([0xFF, 0xD8, 0xFF, 0x00, 0x01])
        XCTAssertThrowsError(try PhotoCacheJPEG.normalizedJPEGData(corrupt, name: "corrupt.jpg"))
    }

    func testNormalizedJPEGDataPreservesUprightJPEGBytes() throws {
        let raw = try Self.makeTestJPEG(width: 40, height: 20, exifOrientation: 1)
        let normalized = try PhotoCacheJPEG.normalizedJPEGData(raw)
        XCTAssertEqual(normalized, raw)
    }

    func testNormalizedJPEGDataBakesOrientation6IntoPortraitPixels() throws {
        let raw = try Self.makeTestJPEG(width: 40, height: 20, exifOrientation: 6)
        let normalized = try PhotoCacheJPEG.normalizedJPEGData(raw)
        let props = try Self.imageProperties(for: normalized)
        XCTAssertEqual(props.width, 20)
        XCTAssertEqual(props.height, 40)
        XCTAssertTrue(props.orientation == nil || props.orientation == 1)
    }

    func testNormalizedJPEGDataBakesOrientation3UpsideDownPixels() throws {
        let raw = try Self.makeTestJPEG(width: 40, height: 20, exifOrientation: 3)
        let normalized = try PhotoCacheJPEG.normalizedJPEGData(raw)
        let props = try Self.imageProperties(for: normalized)
        XCTAssertEqual(props.width, 40)
        XCTAssertEqual(props.height, 20)
        XCTAssertTrue(props.orientation == nil || props.orientation == 1)
        let bottomRightRed = try Self.redChannel(in: normalized, x: 35, y: 15)
        let topLeftRed = try Self.redChannel(in: normalized, x: 5, y: 5)
        XCTAssertGreaterThan(bottomRightRed, 180)
        XCTAssertLessThan(topLeftRed, 80)
    }

    func testNormalizedJPEGDataDownscalesAbove4096AndBakesOrientation() throws {
        let rawPNG = try Self.makeTestImage(
            width: 5000,
            height: 2500,
            exifOrientation: 6,
            utType: UTType.png
        )
        let normalized = try PhotoCacheJPEG.normalizedJPEGData(rawPNG)
        let props = try Self.imageProperties(for: normalized)
        XCTAssertEqual(props.width, 2048)
        XCTAssertEqual(props.height, 4096)
        XCTAssertTrue(props.orientation == nil || props.orientation == 1)
    }

    func testNormalizedJPEGDataDownscalesUprightJPEGAboveMaxPixelSize() throws {
        let rawJPEG = try Self.makeTestJPEG(
            width: 5000,
            height: 2500,
            exifOrientation: 1
        )
        let normalized = try PhotoCacheJPEG.normalizedJPEGData(rawJPEG)
        XCTAssertNotEqual(normalized, rawJPEG)
        let props = try Self.imageProperties(for: normalized)
        XCTAssertEqual(props.width, 4096)
        XCTAssertEqual(props.height, 2048)
        XCTAssertTrue(props.orientation == nil || props.orientation == 1)
    }

    private static func makeTestJPEG(width: Int, height: Int, exifOrientation: Int) throws -> Data {
        try makeTestImage(
            width: width,
            height: height,
            exifOrientation: exifOrientation,
            utType: UTType.jpeg
        )
    }

    private static func makeTestImage(
        width: Int,
        height: Int,
        exifOrientation: Int,
        utType: UTType
    ) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 1)
        }
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2))

        guard let cgImage = ctx.makeImage() else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 2)
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 3)
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.95,
            kCGImagePropertyOrientation: exifOrientation,
        ]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 4)
        }
        return out as Data
    }

    private static func imageProperties(
        for data: Data
    ) throws -> (width: Int, height: Int, orientation: Int?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int
        else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 5)
        }
        let orient = props[kCGImagePropertyOrientation] as? Int
        return (w, h, orient)
    }

    private static func redChannel(in data: Data, x: Int, y: Int) throws -> UInt8 {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 6)
        }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "PhotoCacheJPEGTests", code: 7)
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = (y * width + x) * 4
        return pixels[offset]
    }
}
