import SwiftUI

#if os(macOS)
import AppKit

/// Shared vibrancy + brand-green wash (Sudylko `glassMaterialStack` layering).
struct GlassVibrancyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            GlassVibrancyRepresentable(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                colorScheme: colorScheme
            )
            AppBrandColor.glassTint(for: colorScheme)
                .opacity(AppBrandColor.glassTintOpacity)
        }
    }
}

/// Full-window vibrancy plus a subtle brand-green wash.
struct WindowGlassBackground: View {
    var body: some View {
        GlassVibrancyBackground()
            .ignoresSafeArea()
    }
}

/// Navigation-pushed detail surfaces (lightbox). Same brand wash as the gallery; uses
/// `withinWindow` vibrancy so material renders inside NavigationStack destinations.
struct PushedDetailBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            GlassVibrancyRepresentable(
                material: .underWindowBackground,
                blendingMode: .withinWindow,
                colorScheme: colorScheme
            )
            AppBrandColor.glassTint(for: colorScheme)
                .opacity(AppBrandColor.glassTintOpacity)
        }
        .ignoresSafeArea()
    }
}

/// Login screen — stacked vibrancy and a light wash so the desktop shows through.
struct UnlockGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            GlassVibrancyRepresentable(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                colorScheme: colorScheme
            )
            GlassVibrancyRepresentable(
                material: .hudWindow,
                blendingMode: .withinWindow,
                colorScheme: colorScheme
            )
            .opacity(0.85)
            AppBrandColor.glassTint(for: colorScheme)
                .opacity(AppBrandColor.unlockGlassTintOpacity)
        }
        .ignoresSafeArea()
    }
}

/// Hides window title text while locked; keeps titlebar and traffic lights (close/minimize/zoom).
struct WindowChromeConfigurator: NSViewRepresentable {
    var unlocked: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            Self.apply(unlocked: unlocked, to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(unlocked: unlocked, to: nsView.window)
        }
    }

    private static func apply(unlocked: Bool, to window: NSWindow?) {
        guard let window else { return }
        if unlocked {
            window.applyGatteyPhotosGalleryChrome()
        } else {
            window.applyGatteyPhotosUnlockChrome()
        }
        window.subtitle = ""
        if unlocked {
            // Custom leading toolbar title only — non-empty window.title duplicates in unified toolbar.
            window.title = ""
            window.titleVisibility = .hidden
            window.setTitlebarCenteredTitleHidden(true)
        } else {
            window.title = ""
            window.titleVisibility = .hidden
            window.setTitlebarCenteredTitleHidden(true)
        }
    }
}

/// Configures the hosting `NSWindow` for translucent chrome (Sudylko `WindowConfigurator`).
struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            Self.apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(to: nsView.window)
        }
    }

    private static func apply(to window: NSWindow?) {
        window?.applyGatteyPhotosUnlockChrome()
    }
}

public extension NSWindow {
    /// Gallery: translucent unified toolbar; SwiftUI scroll edge + optional toolbar material (not opaque titlebar).
    func applyGatteyPhotosGalleryChrome() {
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        toolbarStyle = .unified
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .automatic
    }

    /// Unlock / launch: full glass titlebar (no toolbar items).
    func applyGatteyPhotosUnlockChrome() {
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        toolbarStyle = .unified
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
    }

    /// @deprecated Use `applyGatteyPhotosGalleryChrome` or `applyGatteyPhotosUnlockChrome`.
    func applyGatteyPhotosGlassChrome() {
        applyGatteyPhotosUnlockChrome()
    }

    /// Hides the centered title label SwiftUI/unified toolbar injects beside the traffic lights.
    func setTitlebarCenteredTitleHidden(_ hidden: Bool) {
        guard let close = standardWindowButton(.closeButton) else { return }
        var container: NSView? = close.superview
        while let view = container {
            hideTitlebarLabelText(in: view, hidden: hidden)
            container = view.superview
            if container?.className.contains("NSTitlebar") == true || container?.className.contains("Titlebar") == true {
                break
            }
        }
    }

    private func hideTitlebarLabelText(in view: NSView, hidden: Bool) {
        if let field = view as? NSTextField, !field.isEditable, !field.isBezeled {
            field.isHidden = hidden
            return
        }
        for subview in view.subviews {
            hideTitlebarLabelText(in: subview, hidden: hidden)
        }
    }
}

private struct GlassVibrancyRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        apply(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        apply(nsView)
    }

    private func apply(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = colorScheme == .light
        view.alphaValue = 1
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }
}

#elseif os(iOS)

struct WindowGlassBackground: View {
    var body: some View {
        AppSurfaceBackground()
    }
}

struct PushedDetailBackground: View {
    var body: some View {
        AppSurfaceBackground()
    }
}

struct UnlockGlassBackground: View {
    var body: some View {
        AppSurfaceBackground()
    }
}

struct SoftColumnSeparator: View {
    var visibleWidth: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: visibleWidth / 2, style: .continuous)
            .fill(Color.primary.opacity(0.14))
            .frame(width: visibleWidth)
            .frame(maxHeight: .infinity)
    }
}

struct WindowChromeConfigurator: View {
    var unlocked: Bool
    var body: some View { EmptyView() }
}

struct TransparentWindowConfigurator: View {
    var body: some View { EmptyView() }
}

struct AppSurfaceBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }
}

#endif
