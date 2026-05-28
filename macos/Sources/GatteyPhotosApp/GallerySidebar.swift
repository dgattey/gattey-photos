import SwiftUI

struct GallerySidebar: View {
    @EnvironmentObject private var store: GalleryStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selectedID) {
                Section("Gattey Photos") {
                    Label("\(store.activePhotos.count) photos", systemImage: "photo.stack")
                }
            }
            .listStyle(.sidebar)

            ConnectionStatusPill(
                serverStatus: store.serverLinkStatus,
                deviceStatus: store.deviceLinkStatus
            )
            .padding(12)
        }
        .navigationTitle("Gattey Photos")
    }
}
