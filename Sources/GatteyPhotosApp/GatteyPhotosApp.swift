import DylCore
import DylUpdates
import GatteyPhotosCore
import GatteyPhotosUI
import SwiftUI

@main
struct GatteyPhotosApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @State private var chrome = AppChromeState(
        initialViewRawValue: LaunchOverrides.current.initialView,
        initialOrientationRawValue: LaunchOverrides.current.value("orientation")
    )
    @State private var session = AppSession()
    @State private var store = GalleryStore()

    var body: some Scene {
        #if os(macOS)
        Window("", id: "main") {
            root.frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 900, height: 600)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) { CheckForUpdatesButton() }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                Button("Sync") {
                    Task { await store.syncAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!session.isUnlocked || store.isBusy || store.isSyncing)
            }
            CommandGroup(replacing: .sidebar) {
                Button(
                    chrome.showActivityInspector ? "Hide Activity" : "Show Activity",
                    systemImage: AppChromeState.activityInspectorSymbolName
                ) {
                    chrome.showActivityInspector.toggle()
                }
                .keyboardShortcut("b", modifiers: .command)
            }
            CommandMenu("Debug") {
                Toggle(
                    "Toggle Debug Mode",
                    isOn: Binding(
                        get: { store.settings.debugMode },
                        set: { store.setDebugMode($0) }
                    )
                )
                if store.settings.debugMode {
                    Divider()
                    Picker(
                        "Advance interval",
                        selection: Binding(
                            get: { store.settings.debugAdvanceIntervalSeconds },
                            set: { store.setDebugAdvanceIntervalSeconds($0) }
                        )
                    ) {
                        Text("1 min").tag(60)
                        Text("5 min").tag(300)
                        Text("30 min").tag(1800)
                        Text("1 hour").tag(3600)
                        Text("6 hours").tag(21_600)
                    }
                }
            }
        }
        #else
        WindowGroup { root }
        #endif
    }

    private var root: some View {
        AppRootContainer()
            .environment(chrome)
            .environment(session)
            .environment(store)
            .environment(store.selection)
            .environment(ActivityLogStore.shared)
            .preferredColorScheme(LaunchOverrides.current.appearance.map { $0 == .dark ? .dark : .light })
            .onAppear {
                store.session = session
                AppUpdater.shared.mainWindowDidAppear()
            }
    }
}
