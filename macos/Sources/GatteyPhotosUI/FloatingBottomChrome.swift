import SwiftUI

/// Layout insets for bottom-floating gallery chrome (selection bar, lightbox toolbar).
enum BottomFloatingChromeMetrics {
    static let horizontalInset: CGFloat = 16
    static var bottomInset: CGFloat { horizontalInset }
    /// Caps width of selection bar / floating action chrome (fits content below this).
    static let actionBarMaxWidth: CGFloat = 720
}

/// Pins a bottom action bar with the same insets as the gallery selection chrome.
struct BottomFloatingChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: BottomFloatingChromeMetrics.actionBarMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, BottomFloatingChromeMetrics.horizontalInset)
            .padding(.bottom, BottomFloatingChromeMetrics.bottomInset)
    }
}

/// Glass panel styling shared by `GallerySelectionBar` and lightbox toolbar.
struct FloatingActionBarStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                FloatingGlassPanelBackground(capsule: true)
            }
            .compositingGroup()
            .clipShape(Capsule())
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 10, y: 3)
    }
}

extension View {
    func floatingActionBarStyle() -> some View {
        modifier(FloatingActionBarStyle())
    }

    /// Primary gallery action (e.g. Show for Today). Uses bordered prominent (not glass) so corner radius matches Download/Delete.
    func galleryPrimaryButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .galleryChromeButtonBorderShape()
    }

    /// Neutral bordered gallery action (e.g. Download in lightbox) — same chrome as Delete, default tint.
    func galleryBorderedButtonStyle() -> some View {
        buttonStyle(.bordered)
            .galleryChromeButtonBorderShape()
    }

    /// Destructive gallery chrome action (e.g. Delete in selection bar or lightbox).
    /// Red bordered control — same on all OS versions. Pair with `galleryDestructiveChromeOpacity(isEnabled:)`.
    /// Do not combine with `Button(role: .destructive)` (system role overrides fill/border). Alerts and context menus keep `role: .destructive`.
    func galleryDestructiveButtonStyle() -> some View {
        buttonStyle(.bordered)
            .tint(.red)
            .galleryChromeButtonBorderShape()
    }

    /// Capsule corners shared by gallery chrome buttons (selection bar, lightbox actions).
    func galleryChromeButtonBorderShape() -> some View {
        buttonBorderShape(.capsule)
    }

    /// Disabled dimming for destructive chrome buttons (matches Show for Today).
    func galleryDestructiveChromeOpacity(isEnabled: Bool) -> some View {
        opacity(isEnabled ? 1 : 0.45)
    }
}
