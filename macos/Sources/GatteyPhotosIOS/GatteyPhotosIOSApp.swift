import GatteyPhotosCore
import GatteyPhotosUI
import SwiftUI

@main
struct GatteyPhotosIOSApp: App {
    @State private var chrome = AppChromeState()
    @StateObject private var session = AppSession()
    @StateObject private var store = GalleryStore()
    @StateObject private var activityLog = ActivityLogStore.shared

    var body: some Scene {
        WindowGroup {
            AppRootContainer()
                .environment(chrome)
                .environmentObject(session)
                .environmentObject(store)
                .environment(store.selection)
                .environmentObject(activityLog)
                .onAppear {
                    store.session = session
                }
        }
    }
}
