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

private struct LaunchSessionCheckingView: View {
    // 420 approximates the login form column height so the photo lands in the same place.
    private let loadingPhotoHeight: CGFloat = 420
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    package var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .center, spacing: 48) {
                    UnlockWelcomePhotoPanel(contentHeight: loadingPhotoHeight)
                        .layoutPriority(-1)
                    spinnerColumn
                }
            } else {
                VStack(spacing: 20) {
                    UnlockWelcomePhotoPanel(contentHeight: loadingPhotoHeight)
                    spinnerColumn
                }
            }
        }
        #if os(iOS)
        .padding(.horizontal, loadingOuterPadding)
        #else
        .padding(loadingOuterPadding)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UnlockGlassBackground())
        .background(TransparentWindowConfigurator())
        #if os(macOS)
        // Hide the titlebar background strip so it blends into the glass (matches login); traffic lights stay.
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }

    private var spinnerColumn: some View {
        // Centered in the same 520-wide slot the login form occupies (the second column).
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: 520, alignment: .center)
    }

    private var loadingOuterPadding: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .regular ? 40 : IOSContentWidth.unlockCompactHorizontalPadding
        #else
        horizontalSizeClass == .regular ? 56 : 20
        #endif
    }
}
