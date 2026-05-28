import SwiftUI

@main
struct GatteyPhotosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = GalleryStore()

    var body: some Scene {
        WindowGroup("Gattey Photos") {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Gallery") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
