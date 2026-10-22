import GatteyPhotosCore
import SwiftUI

struct ActivityLogPaneView: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(ActivityLogStore.self) private var logStore
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        NavigationStack {
            ActivityLogListView()
                .navigationTitle("Activity")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if chrome.showActivityInspector {
                    ToolbarItem(placement: horizontalSizeClass == .compact ? .cancellationAction : .primaryAction) {
                        Button("Clear", role: .destructive) {
                            logStore.clear()
                        }
                    }
                    if horizontalSizeClass == .compact {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                chrome.showActivityInspector = false
                            }
                        }
                    }
                }
            }
                #endif
        }
        .background(WindowGlassBackground())
        #if os(macOS)
        .toolbar {
            if chrome.showActivityInspector {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        logStore.clear()
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }
}
