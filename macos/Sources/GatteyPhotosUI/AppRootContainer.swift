import SwiftUI

public struct AppRootContainer: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(AppSession.self) private var session
    @Environment(GalleryStore.self) private var store

    public init() {}

    public var body: some View {
        let root = Group {
            switch session.sessionPhase {
            case .checking:
                LaunchSessionCheckingView()
            case .unlocked:
                RootView()
            case .locked:
                UnlockView()
            }
        }
        .tint(AppBrandColor.accentGreen)
        .background(WindowChromeConfigurator(unlocked: session.sessionPhase == .unlocked))
        .task {
            if chrome.initialView == .unlock || chrome.initialView == .unlockHelp {
                session.showUnlockForPreview()
            } else {
                await session.tryAutoUnlock(store: store)
            }
        }

        #if os(macOS)
        if #available(macOS 15.0, *) {
            root.toolbar(removing: .title)
        } else {
            root
        }
        #else
        root
        #endif
    }
}

/// Mirrors `UnlockView` placement so a locked launch doesn't jump when the form appears.
private struct LaunchSessionCheckingView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var isSideBySide: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        Group {
            if isSideBySide {
                HStack(alignment: .center, spacing: UnlockLayout.regularColumnSpacing) {
                    UnlockWelcomePhotoPanel(framedHeight: UnlockLayout.regularFramedHeight)
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: UnlockLayout.formColumnWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 28) {
                    UnlockWelcomePhotoPanel(
                        framedHeight: UnlockLayout.compactFramedHeight,
                        chromeScale: UnlockLayout.compactChromeScale
                    )
                    ProgressView()
                        .controlSize(.large)
                }
                .padding(.top, UnlockLayout.compactTopPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .background(UnlockGlassBackground())
        .background(TransparentWindowConfigurator())
        #if os(macOS)
        // Hide the titlebar background strip so it blends into the glass (matches login); traffic lights stay.
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }
}
