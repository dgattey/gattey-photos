import GatteyPhotosCore
import GatteyPhotosUI
import SwiftUI

@main
struct GatteyPhotosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var chrome = AppChromeState()
    @StateObject private var session = AppSession()
    @StateObject private var store = GalleryStore()
    @StateObject private var activityLog = ActivityLogStore.shared
    @StateObject private var updater = AppUpdaterModel()

    var body: some Scene {
        Window("", id: "main") {
            AppRootContainer()
                .environment(chrome)
                .environmentObject(session)
                .environmentObject(store)
                .environment(store.selection)
                .environmentObject(activityLog)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    store.session = session
                    updater.mainWindowDidAppear()
                }
        }
        .defaultSize(width: 900, height: 600)
        #if os(macOS)
        .windowToolbarStyle(.unified)
        #endif
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesMenuItem(updater: updater)
            }
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
    }
}
