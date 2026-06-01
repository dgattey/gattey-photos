import GatteyPhotosCore
import SwiftUI

/// Right-click / long-press menu on gallery thumbnails (same rules as selection bar and lightbox).
struct GalleryPhotoContextMenuItems: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest
    let photoID: PhotoID

    private var canSetCurrent: Bool {
        store.canSetAsCurrent(photoID: photoID) && !store.isBusy
    }

    private var canDelete: Bool {
        store.canDeletePhotos(ids: [photoID]) && !store.isBusy
    }

    var body: some View {
        Button("Set as current") {
            Task { await store.setAsCurrent(photoID: photoID) }
        }
        .disabled(!canSetCurrent)

        Button("Download") {
            Task { await store.downloadPhoto(photoID: photoID) }
        }
        .disabled(store.isBusy)

        // Context menus use system destructive styling (red label); not `galleryDestructiveButtonStyle`.
        Button("Delete", role: .destructive) {
            galleryDeleteRequest?(Set([photoID]))
        }
        .disabled(!canDelete)
    }
}

extension View {
    func galleryPhotoContextMenu(photoID: PhotoID) -> some View {
        contextMenu {
            GalleryPhotoContextMenuItems(photoID: photoID)
        }
    }
}
