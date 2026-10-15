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

    /// Normalizes an on-disk upload to JPEG when needed (HEIC from iPhone, etc.).
    public static func normalizedJPEGData(fromFileURL url: URL) throws -> Data {
        if isJPEGFile(at: url) {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        }
        guard let encoded = encodeAsJPEG(from: url) else {
            throw PhotoCacheJPEGError.unsupportedImageFile(url.lastPathComponent)
        }
        return encoded
    }

    /// Reads and normalizes `url` to JPEG on a background worker (leaving the main actor free).
    public static func normalizedJPEGDataAsync(fromFileURL url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try normalizedJPEGData(fromFileURL: url)
        }.value
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
