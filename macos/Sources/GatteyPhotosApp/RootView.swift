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
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.uploadFromPanel() }
                } label: {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }
                .disabled(store.isBusy)

                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isBusy)

                Button {
                    showSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .popover(isPresented: $showSettings, arrowEdge: .top) {
                    SettingsPopover(isPresented: $showSettings)
                        .frame(width: 320)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .task {
            await store.refresh()
        }
    }
}
