import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            GallerySidebar()
        } content: {
            GalleryGridView()
        } detail: {
            if store.selectedID != nil {
                PhotoDetailPanel()
            } else {
                ContentUnavailableView(
                    "Select a photo",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Choose a photo to manage or send to your display.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    Task { await store.uploadFromPanel() }
                }
                .disabled(store.isBusy)
            }
            ToolbarItem(placement: .primaryAction) {
                if store.isSyncing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Sync")
                    }
                    .frame(minWidth: 72)
                } else {
                    Button("Sync", systemImage: "arrow.clockwise") {
                        Task { await store.syncAll() }
                    }
                    .disabled(store.isBusy)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Settings", systemImage: "gearshape") {
                    showSettings.toggle()
                }
                .popover(isPresented: $showSettings, arrowEdge: .top) {
                    SettingsPopover(isPresented: $showSettings)
                        .frame(width: 320)
                }
            }
        }
        .task {
            async let status: Void = store.updateConnectionStatus(showChecking: true)
            async let gallery: Void = store.refresh()
            _ = await (status, gallery)
        }
    }
}
