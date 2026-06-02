import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
// crop <in> <out> <x> <y> <w> <h>  (pixels, origin top-left)
let a = CommandLine.arguments
guard a.count == 7, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { exit(1) }
let x = Int(a[3])!, y = Int(a[4])!, w = Int(a[5])!, h = Int(a[6])!
guard let c = img.cropping(to: CGRect(x: x, y: y, width: w, height: h)) else { exit(1) }
let out = URL(fileURLWithPath: a[2]) as CFURL
guard let dest = CGImageDestinationCreateWithURL(out, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, c, nil)
CGImageDestinationFinalize(dest)
print("cropped \(a[2])")
