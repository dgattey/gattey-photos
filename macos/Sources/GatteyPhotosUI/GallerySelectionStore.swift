import GatteyPhotosCore
import Observation
import SwiftUI

/// Selection and lightbox state isolated from `GalleryStore` so grid thumbnails do not
/// invalidate when sync, connection, or gallery data updates (and vice versa).
@MainActor
@Observable
public final class GallerySelectionStore {
    public init() {}

    var selectedIDs: Set<PhotoID> = []
    /// Drives `NavigationPath` in `RootView`.
    var lightboxNavigationPhotoID: PhotoID?
    /// Committed when the pushed lightbox appears.
    var lightboxPhotoID: PhotoID?
    /// Anchor for shift-click range selection in grid order.
    private(set) var selectionAnchor: PhotoID?

    var isLightboxOpen: Bool {
        lightboxNavigationPhotoID != nil
    }

    /// Photo currently shown in the lightbox (navigation target or committed presentation).
    var presentedLightboxPhotoID: PhotoID? {
        lightboxNavigationPhotoID ?? lightboxPhotoID
    }

    func isSelected(_ id: PhotoID) -> Bool {
        selectedIDs.contains(id)
    }

    func selectPhoto(
        _ id: PhotoID,
        append: Bool,
        rangeSelect: Bool = false,
        photoOrder: [PhotoID] = []
    ) {
        if rangeSelect, !photoOrder.isEmpty {
            applyRangeSelection(to: id, photoOrder: photoOrder)
            return
        }
        if append {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
            return
        }
        selectedIDs = [id]
        selectionAnchor = id
    }

    private func applyRangeSelection(to id: PhotoID, photoOrder: [PhotoID]) {
        let anchor = selectionAnchor
            ?? selectedIDs.compactMap { photoOrder.firstIndex(of: $0) }.min().flatMap { photoOrder[$0] }
            ?? id
        guard let from = photoOrder.firstIndex(of: anchor),
              let to = photoOrder.firstIndex(of: id)
        else {
            selectedIDs = [id]
            selectionAnchor = id
            return
        }
        let lo = min(from, to)
        let hi = max(from, to)
        selectedIDs = Set(photoOrder[lo...hi])
    }

    func clearSelection() {
        selectedIDs.removeAll()
        selectionAnchor = nil
    }

    /// Photo to show when opening the lightbox from the keyboard (anchor, else first in grid order).
    func preferredLightboxPhotoID(in photoOrder: [PhotoID]) -> PhotoID? {
        guard !selectedIDs.isEmpty else { return nil }
        if let anchor = selectionAnchor, selectedIDs.contains(anchor) {
            return anchor
        }
        if let ordered = photoOrder.first(where: { selectedIDs.contains($0) }) {
            return ordered
        }
        return selectedIDs.first
    }

    func openLightboxFromSelection(photoOrder: [PhotoID]) {
        guard !isLightboxOpen,
              let id = preferredLightboxPhotoID(in: photoOrder)
        else { return }
        openLightbox(id)
    }

    func openLightbox(_ id: PhotoID) {
        lightboxNavigationPhotoID = id
        lightboxPhotoID = nil
        selectedIDs = [id]
        selectionAnchor = id
    }

    func commitLightboxPresentation(_ id: PhotoID) {
        guard lightboxNavigationPhotoID == id else { return }
        lightboxPhotoID = id
    }

    func closeLightbox() {
        lightboxPhotoID = nil
        lightboxNavigationPhotoID = nil
    }

    func subtractSelection(_ ids: Set<PhotoID>) {
        selectedIDs.subtract(ids)
        if let open = presentedLightboxPhotoID, ids.contains(open) {
            lightboxPhotoID = nil
            lightboxNavigationPhotoID = nil
        }
        if let anchor = selectionAnchor, ids.contains(anchor) {
            selectionAnchor = selectedIDs.first
        }
    }
}
