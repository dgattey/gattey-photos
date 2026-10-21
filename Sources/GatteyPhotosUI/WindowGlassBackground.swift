import SwiftUI

#if os(macOS)
import AppKit

/// Shared vibrancy + brand-green wash (Sudylko `glassMaterialStack` layering).
struct GlassVibrancyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            GlassVibrancyRepresentable(
                material: .sidebar,
                blendingMode: .behindWindow,
                colorScheme: colorScheme
            )
            AppBrandColor.glassTint(for: colorScheme)
                .opacity(AppBrandColor.glassTintOpacity * 0.5)
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

    func makeNSView(context: Context) -> WindowHookView { WindowHookView() }

    func updateNSView(_ view: WindowHookView, context: Context) {
        view.configure { [unlocked] window in Self.apply(unlocked: unlocked, to: window) }
    }

    private static func apply(unlocked: Bool, to window: NSWindow) {
        window.markAsGatteyPhotosMainWindowIfNeeded()
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
    func makeNSView(context: Context) -> WindowHookView { WindowHookView() }

    func updateNSView(_ view: WindowHookView, context: Context) {
        view.configure { window in
            window.markAsGatteyPhotosMainWindowIfNeeded()
            window.applyGatteyPhotosUnlockChrome()
        }
    }
}

/// Runs a window configuration as soon as the view joins its window, and again on each SwiftUI update.
final class WindowHookView: NSView {
    private var apply: (NSWindow) -> Void = { _ in }

    func configure(_ apply: @escaping (NSWindow) -> Void) {
        self.apply = apply
        if let window { apply(window) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { apply(window) }
    }
}

extension NSWindow {
    /// Matches SwiftUI `Window(id: "main")` — used so single-window enforcement ignores Sparkle dialogs.
    public static let gatteyPhotosMainSceneID = NSUserInterfaceItemIdentifier("main")

    public var isGatteyPhotosMainWindow: Bool {
        identifier == Self.gatteyPhotosMainSceneID
    }

    public func markAsGatteyPhotosMainWindowIfNeeded() {
        if identifier != Self.gatteyPhotosMainSceneID {
            identifier = Self.gatteyPhotosMainSceneID
        }
    }

    /// Gallery: translucent, borderless toolbar. `titlebarAppearsTransparent = true` removes the system
    /// toolbar background bar; `isOpaque = false` + clear background let the `WindowGlassBackground`
    /// vibrancy (and desktop) show through the whole window. The scroll edge is faked with a top
    /// `VariableBlurView` strip in the gallery, since the real effect needs the system toolbar bar.
    public func applyGatteyPhotosGalleryChrome() {
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        toolbarStyle = .unified
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
    }

    /// Unlock / launch: full glass titlebar (no toolbar items).
    public func applyGatteyPhotosUnlockChrome() {
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        toolbarStyle = .unified
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
    }

    /// Hides the centered title label SwiftUI/unified toolbar injects beside the traffic lights.
    public func setTitlebarCenteredTitleHidden(_ hidden: Bool) {
        guard let close = standardWindowButton(.closeButton) else { return }
        var container: NSView? = close.superview
        while let view = container {
            hideTitlebarLabelText(in: view, hidden: hidden)
            container = view.superview
            if container?.className.contains("NSTitlebar") == true || container?.className.contains("Titlebar") == true
            {
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

/// Photo detail sits on the plain system background (white / black) so the photo reads as the hero.
struct PushedDetailBackground: View {
    var body: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
    }
}

struct UnlockGlassBackground: View {
    var body: some View {
        AppSurfaceBackground()
    }
}

struct WindowChromeConfigurator: View {
    @Environment(AppChromeState.self) private var chrome
    var unlocked: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: chrome.initialOrientation) {
                guard let orientation = chrome.initialOrientation else { return }
                let mask: UIInterfaceOrientationMask =
                    orientation == .landscape ? .landscapeRight : .portrait
                for scene in UIApplication.shared.connectedScenes {
                    guard let windowScene = scene as? UIWindowScene else { continue }
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
                }
            }
    }
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
