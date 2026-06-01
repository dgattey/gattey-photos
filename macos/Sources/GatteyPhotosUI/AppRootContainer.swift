import SwiftUI

public struct AppRootContainer: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var store: GalleryStore

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
            await session.tryAutoUnlock(store: store)
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
    package var body: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowGlassBackground())
            .background(TransparentWindowConfigurator())
    }
}
