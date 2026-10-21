import Foundation
import ImageIO
import os

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public enum ImageDownsampler {
    /// `NSCache` isn't `Sendable`, so a static one needs a lock to be shared across threads in Swift 6.
    private static let cache = OSAllocatedUnfairLock(
        uncheckedState: {
            let cache = NSCache<NSString, PlatformThumbnailImage>()
            cache.countLimit = 256
            cache.totalCostLimit = 96 * 1024 * 1024
            return cache
        }()
    )

    public static func cachedThumbnail(from url: URL, maxPixelSize: Int) -> PlatformThumbnailImage? {
        let key = cacheKey(url: url, maxPixelSize: maxPixelSize)
        return cache.withLockUnchecked { $0.object(forKey: key) }
    }

    public static func clearMemoryCache() {
        cache.withLockUnchecked { $0.removeAllObjects() }
    }

    public static func loadThumbnail(from url: URL, maxPixelSize: Int) -> PlatformThumbnailImage? {
        if let hit = cachedThumbnail(from: url, maxPixelSize: maxPixelSize) {
            return hit
        }
        let key = cacheKey(url: url, maxPixelSize: maxPixelSize)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        else { return nil }
        #if os(macOS)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        #elseif os(iOS)
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        #endif
        let cost = max(1, cgImage.bytesPerRow * cgImage.height)
        cache.withLockUnchecked { $0.setObject(image, forKey: key, cost: cost) }
        return image
    }

    private static func cacheKey(url: URL, maxPixelSize: Int) -> NSString {
        "\(url.path)#\(maxPixelSize)" as NSString
    }
}

#if os(macOS)
public typealias PlatformThumbnailImage = NSImage
#elseif os(iOS)
public typealias PlatformThumbnailImage = UIImage
#endif
