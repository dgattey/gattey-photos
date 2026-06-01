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
                }
        }
        .defaultSize(width: 900, height: 600)
        .commands {
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
            }
        }
    }
}
