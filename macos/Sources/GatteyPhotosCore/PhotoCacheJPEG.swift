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
    public static let defaultMaxPixelSize = 4096
    private static let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]

    public static func isJPEG(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        let start = data.startIndex
        return data[start] == jpegMagic[0]
            && data[data.index(after: start)] == jpegMagic[1]
            && data[data.index(start, offsetBy: 2)] == jpegMagic[2]
    }

    public static func isJPEGFile(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 3) else { return false }
        return isJPEG(prefix)
    }

    /// Normalizes raw image bytes to an upright JPEG capped at `maxPixelSize` on the long edge
    /// (converting HEIC, baking any non-1 EXIF/TIFF orientation into the pixel buffer, and downscaling >4096px images).
    public static func normalizedJPEGData(
        _ raw: Data,
        name: String = "image",
        compressionQuality: Double = 0.88,
        maxPixelSize: Int = defaultMaxPixelSize
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(raw as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = props[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = props[kCGImagePropertyPixelHeight] as? Int,
              pixelWidth > 0,
              pixelHeight > 0
        else {
            throw PhotoCacheJPEGError.unsupportedImageFile(name)
        }
        let fitsWithinMax = max(pixelWidth, pixelHeight) <= maxPixelSize
        if isJPEG(raw) && !needsOrientationBake(props) && fitsWithinMax {
            return raw
        }
        guard let encoded = encodeAsJPEG(
            from: source,
            compressionQuality: compressionQuality,
            maxPixelSize: maxPixelSize
        ) else {
            throw PhotoCacheJPEGError.unsupportedImageFile(name)
        }
        return encoded
    }

    /// Normalizes an on-disk upload to an upright JPEG when needed (HEIC from iPhone, EXIF orientation 2..8, >4096px, etc.).
    public static func normalizedJPEGData(
        fromFileURL url: URL,
        compressionQuality: Double = 0.88,
        maxPixelSize: Int = defaultMaxPixelSize
    ) throws -> Data {
        let raw = try Data(contentsOf: url, options: .mappedIfSafe)
        return try normalizedJPEGData(
            raw,
            name: url.lastPathComponent,
            compressionQuality: compressionQuality,
            maxPixelSize: maxPixelSize
        )
    }

    /// Reads and normalizes `url` to JPEG on a background worker (leaving the main actor free).
    public static func normalizedJPEGDataAsync(
        fromFileURL url: URL,
        compressionQuality: Double = 0.88,
        maxPixelSize: Int = defaultMaxPixelSize
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try normalizedJPEGData(
                fromFileURL: url,
                compressionQuality: compressionQuality,
                maxPixelSize: maxPixelSize
            )
        }.value
    }

    private static func needsOrientationBake(_ props: [CFString: Any]) -> Bool {
        let exifOrientation = props[kCGImagePropertyOrientation] as? Int
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let tiffOrientation = tiff?[kCGImagePropertyTIFFOrientation] as? Int
        return (exifOrientation ?? tiffOrientation ?? 1) > 1
    }

    private static func encodeAsJPEG(
        from source: CGImageSource,
        compressionQuality: Double = 0.88,
        maxPixelSize: Int = defaultMaxPixelSize
    ) -> Data? {
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
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
