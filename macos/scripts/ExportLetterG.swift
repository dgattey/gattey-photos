#!/usr/bin/env swift
import AppKit
import Foundation

/// Renders a centered Georgia "G" path into `AppIcon.icon/Assets/Letter-G.svg`.
let size: CGFloat = 1024
/// Horizontal: serif G reads left when bbox-centered; nudge right.
let opticalDX: CGFloat = 24
/// Vertical: bbox-centered in the square (no extra up-nudge).
let opticalDY: CGFloat = 0

func serifFont(pointSize: CGFloat) -> NSFont {
    for name in ["NewYork-Bold", "Georgia-Bold", "TimesNewRomanPS-BoldMT", "Baskerville-Bold"] {
        if let font = NSFont(name: name, size: pointSize) { return font }
    }
    return NSFont.systemFont(ofSize: pointSize, weight: .bold)
}

let font = serifFont(pointSize: 720)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: -8.0]
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "G", attributes: attrs))
let path = CGMutablePath()
let runs = CTLineGetGlyphRuns(line)
for i in 0..<CFArrayGetCount(runs) {
    let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, i), to: CTRun.self)
    let runAttrs = CTRunGetAttributes(run) as NSDictionary
    let f = runAttrs[NSAttributedString.Key.font] as! NSFont
    for g in 0..<CTRunGetGlyphCount(run) {
        var glyph = CGGlyph()
        var pos = CGPoint.zero
        CTRunGetGlyphs(run, CFRange(location: g, length: 1), &glyph)
        CTRunGetPositions(run, CFRange(location: g, length: 1), &pos)
        if let glyphPath = CTFontCreatePathForGlyph(f, glyph, nil) {
            path.addPath(glyphPath, transform: CGAffineTransform(translationX: pos.x, y: pos.y))
        }
    }
}

var flip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -size)
guard var flipped = path.copy(using: &flip) else {
    fputs("ExportLetterG: flip failed\n", stderr)
    exit(1)
}

let box = flipped.boundingBox
var center = CGAffineTransform(
    translationX: size / 2 - (box.minX + box.maxX) / 2 + opticalDX,
    y: size / 2 - (box.minY + box.maxY) / 2 + opticalDY
)
flipped = flipped.copy(using: &center)!

func pathToSVG(_ p: CGPath) -> String {
    var d = ""
    p.applyWithBlock { el in
        let e = el.pointee
        switch e.type {
        case .moveToPoint:
            d += String(format: "M%.3f %.3f ", e.points[0].x, e.points[0].y)
        case .addLineToPoint:
            d += String(format: "L%.3f %.3f ", e.points[0].x, e.points[0].y)
        case .addQuadCurveToPoint:
            d += String(format: "Q%.3f %.3f %.3f %.3f ", e.points[0].x, e.points[0].y, e.points[1].x, e.points[1].y)
        case .addCurveToPoint:
            d += String(format: "C%.3f %.3f %.3f %.3f %.3f %.3f ", e.points[0].x, e.points[0].y, e.points[1].x, e.points[1].y, e.points[2].x, e.points[2].y)
        case .closeSubpath:
            d += "Z "
        @unknown default:
            break
        }
    }
    return d.trimmingCharacters(in: .whitespaces)
}

let svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <path fill="#FAFAFA" d="\(pathToSVG(flipped))"/>
</svg>
"""

let outArg = CommandLine.arguments.dropFirst().first
let outURL = URL(fileURLWithPath: outArg ?? "AppIcon.icon/Assets/Letter-G.svg")
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try svg.write(to: outURL, atomically: true, encoding: .utf8)
