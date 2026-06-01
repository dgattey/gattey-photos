import GatteyPhotosCore
import SwiftUI

struct ActivityLogPaneView: View {
    @Environment(AppChromeState.self) private var chrome
    @EnvironmentObject private var logStore: ActivityLogStore

    var body: some View {
        NavigationStack {
            ActivityLogListView()
                .navigationTitle("Activity")
        }
        .background(WindowGlassBackground())
        .toolbar {
            if chrome.showActivityInspector {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        logStore.clear()
                    }
                }
            }
        }
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }
}
