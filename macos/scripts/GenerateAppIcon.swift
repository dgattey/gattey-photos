#!/usr/bin/env swift
import AppKit
import Foundation

let size: CGFloat = 1024
let letterColor = NSColor(calibratedWhite: 0.98, alpha: 1)

func serifFont(pointSize: CGFloat) -> NSFont {
    let names = [
        "NewYork-Bold",
        "Georgia-Bold",
        "TimesNewRomanPS-BoldMT",
        "Baskerville-Bold",
    ]
    for name in names {
        if let font = NSFont(name: name, size: pointSize) {
            return font
        }
    }
    return NSFont.systemFont(ofSize: pointSize, weight: .bold)
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fputs("No graphics context\n", stderr)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let clipPath = CGPath(roundedRect: rect, cornerWidth: 220, cornerHeight: 220, transform: nil)
ctx.addPath(clipPath)
ctx.clip()

let gradientColors = [
    NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.12, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.24, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.38, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.35, green: 0.72, blue: 0.52, alpha: 1).cgColor,
] as CFArray
let locations: [CGFloat] = [0, 0.35, 0.7, 1]
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors,
    locations: locations
) {
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size, y: size),
        options: []
    )
}

let font = serifFont(pointSize: 720)
let text = "G" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: letterColor,
    .kern: -8.0,
]

let line = NSMutableParagraphStyle()
line.alignment = .center
var centeredAttrs = attrs
centeredAttrs[.paragraphStyle] = line

let measureAttrs = attrs
let bounds = text.boundingRect(
    with: CGSize(width: size, height: size),
    options: [.usesLineFragmentOrigin, .usesFontLeading],
    attributes: measureAttrs,
    context: nil
)

let drawRect = CGRect(
    x: (size - bounds.width) / 2 - bounds.origin.x,
    y: (size - bounds.height) / 2 - bounds.origin.y,
    width: bounds.width,
    height: bounds.height
)
text.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: centeredAttrs)

image.unlockFocus()

let outArg = CommandLine.arguments.dropFirst().first
let outURL = URL(fileURLWithPath: outArg ?? "AppIcon-1024.png")
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: outURL)
print(outURL.path)
