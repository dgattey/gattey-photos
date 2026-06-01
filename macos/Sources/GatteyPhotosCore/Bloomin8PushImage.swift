import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders cached gallery JPEGs for `POST /open-api/push` (portrait canvas, letterboxed fit).
public enum Bloomin8PushImage: Sendable {
    private static let jpegQuality: CGFloat = 0.92

    /// Portrait canvas matching device width/height; letterboxes landscape photos with a white mat.
    public static func prepare(jpegData: Data, status: Bloomin8CloudDeviceStatus) -> Data {
        let (canvasW, canvasH) = Bloomin8Screen.portraitCanvasPixels(
            width: status.width,
            height: status.height
        )
        guard canvasW > 0, canvasH > 0 else { return jpegData }
        guard let image = loadOrientedImage(jpegData: jpegData, maxPixelSize: max(canvasW, canvasH)),
              let canvas = letterbox(image: image, canvasWidth: canvasW, canvasHeight: canvasH),
              let out = encodeJPEG(cgImage: canvas, quality: jpegQuality) else {
            return jpegData
        }
        return out
    }

    private static func loadOrientedImage(jpegData: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(jpegData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func letterbox(image: CGImage, canvasWidth: Int, canvasHeight: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        ctx.interpolationQuality = .high

        let iw = CGFloat(image.width)
        let ih = CGFloat(image.height)
        let scale = min(CGFloat(canvasWidth) / iw, CGFloat(canvasHeight) / ih)
        let drawW = iw * scale
        let drawH = ih * scale
        let dx = (CGFloat(canvasWidth) - drawW) / 2
        let dy = (CGFloat(canvasHeight) - drawH) / 2
        ctx.draw(image, in: CGRect(x: dx, y: dy, width: drawW, height: drawH))
        return ctx.makeImage()
    }

    private static func encodeJPEG(cgImage: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(dest, cgImage, options)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
