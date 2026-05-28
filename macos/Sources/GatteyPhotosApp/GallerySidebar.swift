import SwiftUI

struct GallerySidebar: View {
    @EnvironmentObject private var store: GalleryStore

    var body: some View {
        List(selection: $store.selectedID) {
            Section("Shared gallery") {
                Label("\(store.activePhotos.count) photos", systemImage: "photo.stack")
                if store.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            Section("Tips") {
                Text("Drag photos in the grid to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Gattey Photos")
    }
}
