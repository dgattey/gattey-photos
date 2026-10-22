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

    /// Solid brand-green capsule for the main action (Show for Today, Unlock).
    func galleryPrimaryButtonStyle() -> some View {
        buttonStyle(BrandCapsuleButtonStyle(kind: .prominent))
    }

    /// Green-tinted capsule for secondary actions (Share, Download).
    func galleryBorderedButtonStyle() -> some View {
        buttonStyle(BrandCapsuleButtonStyle(kind: .tinted))
    }

    /// Red-tinted capsule for Delete. Alerts and context menus keep system `role: .destructive` styling.
    func galleryDestructiveButtonStyle() -> some View {
        buttonStyle(BrandCapsuleButtonStyle(kind: .destructive))
    }
}

/// Capsule buttons drawn in brand colors rather than system bordered styles: macOS desaturates those in inactive
/// windows and both platforms gray out disabled prominent buttons, which drained the green from the interface.
struct BrandCapsuleButtonStyle: ButtonStyle {
    enum Kind {
        case prominent
        case tinted
        case destructive
    }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, isLarge ? 20 : 14)
            .padding(.vertical, isLarge ? 11 : 7)
            .background(fill(pressed: configuration.isPressed), in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var isLarge: Bool {
        controlSize == .large || controlSize == .extraLarge
    }

    private var foreground: Color {
        switch kind {
        case .prominent: return .white
        case .tinted: return colorScheme == .dark ? Color(red: 0.62, green: 0.88, blue: 0.70) : AppBrandColor.accentGreen
        case .destructive: return colorScheme == .dark ? Color(red: 1.0, green: 0.55, blue: 0.53) : .red
        }
    }

    private func fill(pressed: Bool) -> Color {
        let tintOpacity = colorScheme == .dark ? 0.24 : 0.14
        switch kind {
        case .prominent: return AppBrandColor.accentGreen.opacity(pressed ? 0.8 : 1)
        case .tinted: return AppBrandColor.accentGreen.opacity(pressed ? tintOpacity * 1.8 : tintOpacity)
        case .destructive: return Color.red.opacity(pressed ? tintOpacity * 1.8 : tintOpacity)
        }
    }
}
