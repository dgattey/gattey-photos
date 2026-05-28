import AppKit
import GatteyPhotosCore
import SwiftUI

struct PhotoDetailPanel: View {
    @EnvironmentObject private var store: GalleryStore

    private var photo: PhotoEntry? {
        guard let id = store.selectedID else { return nil }
        return store.state.photos[id]
    }

    var body: some View {
        if let photo {
            VStack(alignment: .leading, spacing: 16) {
                detailImage(photo: photo)
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .clipped()
                    .cornerRadius(10)

                Text(photo.filename)
                    .font(.title2)
                Text("Updated \(photo.updatedAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Send to display now") {
                        Task { await store.pushSelectedToDevice() }
                    }
                    .disabled(store.isBusy)

                    Button("Delete", role: .destructive) {
                        Task { await store.deleteSelected() }
                    }
                    .disabled(store.isBusy)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Photo")
        }
    }

    @ViewBuilder
    private func detailImage(photo: PhotoEntry) -> some View {
        let url = AppConfig.cacheURL(for: photo.id)
        if let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            ContentUnavailableView("Image not cached", systemImage: "photo")
        }
    }
}
