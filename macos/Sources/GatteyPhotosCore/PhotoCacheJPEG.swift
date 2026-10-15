import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PhotoCacheJPEGError: Error, LocalizedError {
    case missingCache(PhotoID)
    case invalidCacheFormat(PhotoID)
    case unsupportedImageFile(String)

    public var errorDescription: String? {
        switch self {
        case .missingCache(let id): return "Missing cache for photo \(id)"
        case .invalidCacheFormat(let id): return "Could not read cache as image for \(id)"
        case .unsupportedImageFile(let name): return "Unsupported image: \(name)"
        }
    }
}

/// Local gallery cache bytes normalized to JPEG for upload and display.
public enum PhotoCacheJPEG: Sendable {
    private static let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]

    public static func isJPEG(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return data[0] == jpegMagic[0] && data[1] == jpegMagic[1] && data[2] == jpegMagic[2]
    }

    /// Normalizes raw image bytes to an upright JPEG (converting HEIC, etc., and baking
    /// any non-1 EXIF/TIFF orientation into the pixel buffer).
    public static func normalizedJPEGData(_ raw: Data, name: String = "image") throws -> Data {
        guard let source = CGImageSourceCreateWithData(raw as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = props[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = props[kCGImagePropertyPixelHeight] as? Int,
              pixelWidth > 0,
              pixelHeight > 0
        else {
            throw PhotoCacheJPEGError.unsupportedImageFile(name)
        }
        if isJPEG(raw) && !needsOrientationBake(props) {
            return raw
        }
        guard let encoded = encodeAsJPEG(from: source, maxPixelSize: max(pixelWidth, pixelHeight)) else {
            throw PhotoCacheJPEGError.unsupportedImageFile(name)
        }
        return encoded
    }

    /// Normalizes an on-disk upload to an upright JPEG when needed (HEIC from iPhone, EXIF orientation 2..8, etc.).
    public static func normalizedJPEGData(fromFileURL url: URL) throws -> Data {
        let raw = try Data(contentsOf: url)
        return try normalizedJPEGData(raw, name: url.lastPathComponent)
    }

    private static func needsOrientationBake(_ props: [CFString: Any]) -> Bool {
        let exifOrientation = props[kCGImagePropertyOrientation] as? Int
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let tiffOrientation = tiff?[kCGImagePropertyTIFFOrientation] as? Int
        return (exifOrientation ?? tiffOrientation ?? 1) > 1
    }

    private static func encodeAsJPEG(from source: CGImageSource, maxPixelSize: Int) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
