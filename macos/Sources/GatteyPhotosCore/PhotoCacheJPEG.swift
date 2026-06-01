import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Local gallery cache bytes normalized to JPEG for Bloomin8 Open API (`POST /open-api/push`).
public enum PhotoCacheJPEG: Sendable {
    private static let jpegMagic: [UInt8] = [0xFF, 0xD8, 0xFF]

    public static func isJPEG(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return data[0] == jpegMagic[0] && data[1] == jpegMagic[1] && data[2] == jpegMagic[2]
    }

    /// Reads `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg` and returns JPEG bytes.
    /// Converts HEIC/PNG/etc. when the file was stored under a `.jpg` name (upload without transcoding).
    public static func jpegDataForDevicePush(photoID: PhotoID) throws -> Data {
        let url = AppConfig.cacheURL(for: photoID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Bloomin8OpenAPIError.missingCache(photoID)
        }
        let raw = try Data(contentsOf: url)
        if isJPEG(raw) { return raw }
        guard let encoded = encodeAsJPEG(from: url) else {
            throw Bloomin8OpenAPIError.invalidCacheFormat(photoID)
        }
        try? encoded.write(to: url, options: .atomic)
        return encoded
    }

    /// Normalizes an on-disk upload to JPEG when needed (HEIC from iPhone, etc.).
    public static func normalizedJPEGData(fromFileURL url: URL) throws -> Data {
        let raw = try Data(contentsOf: url)
        if isJPEG(raw) { return raw }
        guard let encoded = encodeAsJPEG(from: url) else {
            throw Bloomin8OpenAPIError.unsupportedImageFile(url.lastPathComponent)
        }
        return encoded
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
