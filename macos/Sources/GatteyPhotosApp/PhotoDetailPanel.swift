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
                CachedPhotoImage(photoID: photo.id, maxPixelSize: 1200, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .clipped()
                    .cornerRadius(10)

                Text(photo.filename)
                    .font(.title2)
                Text("Updated \(photo.updatedAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Use Sync in the toolbar to refresh the gallery and push it to your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Delete", role: .destructive) {
                    Task { await store.deleteSelected() }
                }
                .disabled(store.isBusy)

                Spacer()
            }
            .padding()
            .navigationTitle("Photo")
        }
    }
}
