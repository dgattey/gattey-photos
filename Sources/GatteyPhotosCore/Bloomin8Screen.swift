import CoreGraphics

/// Bloomin8 E-Ink Canvas display geometry (see product specs and `/deviceInfo` `width`/`height`).
public enum Bloomin8Screen: Sendable {
    /// Bloomin8 Eink Canvas 13.3" panel resolution (width × height), portrait.
    /// Source: https://bloomin8.com/products/bloomin8-eink-canvas
    public static let default13Width = 1200
    public static let default13Height = 1600

    /// Width ÷ height for the default 13.3" panel (portrait).
    public static var defaultAspectRatio: CGFloat {
        aspectRatio(width: default13Width, height: default13Height)
    }

    /// SwiftUI `.aspectRatio` ratio (width ÷ height). Portrait panels are below 1 (e.g. 1200÷1600 = 0.75).
    public static func aspectRatio(width: Int, height: Int) -> CGFloat {
        guard width > 0, height > 0 else { return defaultAspectRatio }
        let w = CGFloat(width)
        let h = CGFloat(height)
        if w > h { return h / w }
        return w / h
    }

    /// Whether the physical panel is in landscape (Open API `"L"` or width > height).
    public static func isLandscapeDevice(
        orientation: String?,
        width: Int?,
        height: Int?
    ) -> Bool {
        if let o = orientation?.uppercased() {
            if o == "L" { return true }
            if o == "P" { return false }
        }
        if let width, let height, width > 0, height > 0 {
            return width > height
        }
        return false
    }

    /// SwiftUI width ÷ height for the e-ink opening in the given orientation.
    ///
    /// `normalizedAspectRatio` is from `aspectRatio(width:height:)` (always ≤ 1). Portrait uses it;
    /// landscape uses its reciprocal so `.aspectRatio` matches a wide frame.
    public static func displayAspectRatio(
        normalizedAspectRatio: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        let r = normalizedAspectRatio > 0 ? normalizedAspectRatio : defaultAspectRatio
        if isLandscape {
            return 1 / r
        }
        return min(r, 1)
    }

    /// Target push canvas in portrait (width ≤ height), using device status or defaults.
    public static func portraitCanvasPixels(width: Int?, height: Int?) -> (width: Int, height: Int) {
        var w = width ?? default13Width
        var h = height ?? default13Height
        guard w > 0, h > 0 else { return (default13Width, default13Height) }
        if w > h { swap(&w, &h) }
        return (w, h)
    }
}
