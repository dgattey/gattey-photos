import GatteyPhotosCore
import SwiftUI

/// Right-click / long-press menu on gallery thumbnails (same rules as selection bar and lightbox).
struct GalleryPhotoContextMenuItems: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest
    let photoID: PhotoID

    /// Same batch as the selection bar when the menu target is part of the current selection.
    private var deleteTargetIDs: Set<PhotoID> {
        selection.selectedIDs.contains(photoID) ? selection.selectedIDs : Set([photoID])
    }

    private var canSetCurrent: Bool {
        store.canSetAsCurrent(photoID: photoID) && !store.isBusy
    }

    private var canDelete: Bool {
        store.canDeletePhotos(ids: deleteTargetIDs) && !store.isBusy
    }

    var body: some View {
        Button("Show for today") {
            Task { await store.setAsCurrent(photoID: photoID) }
        }
        .disabled(!canSetCurrent)

        Button("Download") {
            Task { await store.downloadPhoto(photoID: photoID) }
        }
        .disabled(store.isBusy)

        // Context menus use system destructive styling (red label); not `galleryDestructiveButtonStyle`.
        Button("Delete", role: .destructive) {
            galleryDeleteRequest?(deleteTargetIDs)
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
