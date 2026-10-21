import GatteyPhotosCore
import SwiftUI

/// Right-click / long-press menu on gallery thumbnails (same rules as selection bar and lightbox).
struct GalleryPhotoContextMenuItems: View {
    @Environment(GalleryStore.self) private var store
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest
    let photoID: PhotoID

    /// Same batch as the selection bar when the menu target is part of the current selection.
    private var actionTargetIDs: Set<PhotoID> {
        selection.selectedIDs.contains(photoID) ? selection.selectedIDs : Set([photoID])
    }

    private var canSetCurrent: Bool {
        store.canSetAsCurrent(photoID: photoID) && !store.isBusy
    }

    private var canDelete: Bool {
        store.canDeletePhotos(ids: actionTargetIDs) && !store.isBusy
    }

    #if os(iOS)
    private static let downloadTitle = "Share…"
    private static let downloadSymbol = "square.and.arrow.up"
    #else
    private static let downloadTitle = "Download"
    private static let downloadSymbol = "arrow.down.circle"
    #endif

    var body: some View {
        Button("Show for Today", systemImage: "photo.artframe") {
            Task { await store.setAsCurrent(photoID: photoID) }
        }
        .disabled(!canSetCurrent)

        Button(Self.downloadTitle, systemImage: Self.downloadSymbol) {
            Task { await store.downloadPhotos(ids: actionTargetIDs) }
        }
        .disabled(store.isBusy)

        // Context menus use system destructive styling (red label); not `galleryDestructiveButtonStyle`.
        Button("Delete", systemImage: "trash", role: .destructive) {
            galleryDeleteRequest?(actionTargetIDs)
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
