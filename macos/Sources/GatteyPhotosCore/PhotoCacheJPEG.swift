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

    /// Normalizes an on-disk upload to JPEG when needed (HEIC from iPhone, etc.)
    /// and bakes any non-upright EXIF orientation into the pixel buffer.
    public static func normalizedJPEGData(fromFileURL url: URL) throws -> Data {
        let raw = try Data(contentsOf: url)
        if isJPEG(raw) && !needsOrientationBake(at: url) {
            return raw
        }
        guard let encoded = encodeAsJPEG(from: url) else {
            throw PhotoCacheJPEGError.unsupportedImageFile(url.lastPathComponent)
        }
        return encoded
    }

    private static func needsOrientationBake(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return false }
        if let orientation = props[kCGImagePropertyOrientation] as? Int, orientation > 1 {
            return true
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let orientation = tiff[kCGImagePropertyTIFFOrientation] as? Int,
           orientation > 1 {
            return true
        }
        return false
    }

    private static func encodeAsJPEG(from url: URL, maxPixelSize: Int = 4096) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
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
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.88]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
