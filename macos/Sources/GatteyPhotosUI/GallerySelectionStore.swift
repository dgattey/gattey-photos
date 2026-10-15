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
        let anchor =
            selectionAnchor
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

    /// Moves grid selection along gallery order (horizontal) or by row (vertical × `columnCount`).
    /// Wraps at ends. With no selection, right/down start at the first photo; left/up at the last.
    @discardableResult
    func navigateGridSelection(
        horizontalDelta: Int = 0,
        verticalDelta: Int = 0,
        photoOrder: [PhotoID],
        columnCount: Int
    ) -> Bool {
        guard !isLightboxOpen, !photoOrder.isEmpty else { return false }
        let cols = max(1, columnCount)
        let linearDelta = horizontalDelta + verticalDelta * cols
        guard linearDelta != 0 else { return false }

        let count = photoOrder.count
        let startIndex: Int
        if let id = preferredLightboxPhotoID(in: photoOrder),
            let index = photoOrder.firstIndex(of: id)
        {
            startIndex = index
        } else if linearDelta > 0 {
            startIndex = -1
        } else {
            startIndex = count
        }

        let nextIndex = ((startIndex + linearDelta) % count + count) % count
        let nextID = photoOrder[nextIndex]
        selectedIDs = [nextID]
        selectionAnchor = nextID
        return true
    }

    /// Previous/next photo in gallery order while the lightbox is open (wraps at ends).
    @discardableResult
    func navigateLightbox(by delta: Int, photoOrder: [PhotoID]) -> Bool {
        guard isLightboxOpen, photoOrder.count > 1,
            let current = presentedLightboxPhotoID,
            let index = photoOrder.firstIndex(of: current)
        else { return false }
        let count = photoOrder.count
        let nextIndex = ((index + delta) % count + count) % count
        let nextID = photoOrder[nextIndex]
        guard nextID != current else { return false }
        lightboxNavigationPhotoID = nextID
        lightboxPhotoID = nil
        selectedIDs = [nextID]
        selectionAnchor = nextID
        return true
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
