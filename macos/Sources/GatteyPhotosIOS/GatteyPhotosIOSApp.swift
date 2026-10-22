import GatteyPhotosCore
import GatteyPhotosUI
import SwiftUI

@main
struct GatteyPhotosIOSApp: App {
    @State private var chrome = AppChromeState()
    @State private var session = AppSession()
    @State private var store = GalleryStore()

    var body: some Scene {
        WindowGroup {
            AppRootContainer()
                .environment(chrome)
                .environment(session)
                .environment(store)
                .environment(store.selection)
                .environment(ActivityLogStore.shared)
                .onAppear {
                    store.session = session
                }
        }
    }
}
