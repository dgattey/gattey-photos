import Foundation
import ImageIO

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public enum ImageDownsampler {
    public static func loadThumbnail(from url: URL, maxPixelSize: Int) -> PlatformThumbnailImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
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
        #if os(macOS)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
        #elseif os(iOS)
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        #endif
    }
}

#if os(macOS)
public typealias PlatformThumbnailImage = NSImage
#elseif os(iOS)
public typealias PlatformThumbnailImage = UIImage
#endif
