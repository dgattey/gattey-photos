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
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                FloatingGlassPanelBackground(cornerRadius: 12)
            }
            .compositingGroup()
            .clipShape(shape)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 10, y: 3)
    }
}

extension View {
    func floatingActionBarStyle() -> some View {
        modifier(FloatingActionBarStyle())
    }

    /// Primary gallery action (e.g. Set as current).
    @ViewBuilder
    func galleryPrimaryButtonStyle() -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Secondary prominent action (e.g. Download in lightbox).
    func gallerySecondaryButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
            .tint(Color.secondary)
    }

    /// Destructive gallery chrome action (e.g. Delete in selection bar or lightbox).
    /// Red bordered control — same on all OS versions. Pair with `galleryDestructiveChromeOpacity(isEnabled:)`.
    /// Do not combine with `Button(role: .destructive)` (system role overrides fill/border). Alerts and context menus keep `role: .destructive`.
    func galleryDestructiveButtonStyle() -> some View {
        buttonStyle(.bordered)
            .tint(.red)
    }

    /// Disabled dimming for destructive chrome buttons (matches Set as current).
    func galleryDestructiveChromeOpacity(isEnabled: Bool) -> some View {
        opacity(isEnabled ? 1 : 0.45)
    }

    /// Expands bordered macOS buttons to the proposed width (label + outer frame).
    func galleryFullWidthButtonLayout(minHeight: CGFloat = 32) -> some View {
        frame(maxWidth: .infinity, minHeight: minHeight)
    }
}
