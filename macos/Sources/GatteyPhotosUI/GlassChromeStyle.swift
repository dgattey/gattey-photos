import SwiftUI

// MARK: - Floating panels (selection bar, lightbox chrome)

/// Translucent blur + light brand wash for bottom-floating action bars.
struct FloatingGlassPanelBackground: View {
    var cornerRadius: CGFloat = 12
    /// Pill panel for gallery selection chrome; default is rounded rect for other callers.
    var capsule: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if capsule {
            glassPanel(in: Capsule())
        } else {
            glassPanel(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    @ViewBuilder
    private func glassPanel<S: InsettableShape>(in shape: S) -> some View {
        ZStack {
            floatingMaterialLayer(in: shape)
            shape
                .fill(AppBrandColor.glassTint(for: colorScheme))
                .opacity(Self.brandWashOpacity)
        }
    }

    @ViewBuilder
    private func floatingMaterialLayer<S: InsettableShape>(in shape: S) -> some View {
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
