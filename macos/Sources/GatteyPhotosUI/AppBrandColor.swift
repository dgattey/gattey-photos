import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Brand greens aligned with `macos/AppIcon.icon/icon.json` canvas gradient (top → bottom).
enum AppBrandColor {
    /// Mid blend for glass wash, unlock accent, and app-wide control tint (focus rings, selection, toggles).
    static let accentGreen = Color(
        red: 0.2745,
        green: 0.4922,
        blue: 0.3804
    )

    /// Matches Sudylko `glassMaterialTintOpacity` in `VisualEffectBackground.swift`.
    static let glassTintOpacity: Double = 0.22

    /// Unlock screen — lighter wash so vibrancy reads as glass.
    static let unlockGlassTintOpacity: Double = 0.10

    /// Blended wash for glass panels using icon gradient mid-tone.
    static func glassTint(for colorScheme: ColorScheme) -> Color {
        let amount: CGFloat = colorScheme == .dark ? 0.28 : 0.18
        let base =
            colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.09)
            : Color(red: 0.95, green: 0.95, blue: 0.94)
        return blend(base: base, accent: accentGreen, amount: amount)
    }

    private static func blend(base: Color, accent: Color, amount: CGFloat) -> Color {
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        #if os(macOS)
        guard let b = NSColor(base).usingColorSpace(.deviceRGB),
            let a = NSColor(accent).usingColorSpace(.deviceRGB)
        else { return base }
        b.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        a.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        #elseif os(iOS)
        guard UIColor(base).getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
            UIColor(accent).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        else { return base }
        #endif
        return Color(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount
        )
    }
}
