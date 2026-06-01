import SwiftUI

// MARK: - Floating panels (selection bar, lightbox chrome)

/// Translucent blur + light brand wash for bottom-floating action bars.
struct FloatingGlassPanelBackground: View {
    var cornerRadius: CGFloat = 12
    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            floatingMaterialLayer
            shape
                .fill(AppBrandColor.glassTint(for: colorScheme))
                .opacity(Self.brandWashOpacity)
        }
    }

    @ViewBuilder
    private var floatingMaterialLayer: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            shape.fill(.regularMaterial)
        }
    }

    /// Subtle green wash on top of material (was a flat opaque fill in `FloatingActionBarStyle`).
    static let brandWashOpacity: Double = 0.12
}
