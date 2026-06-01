import CoreGraphics

/// Manifest order moves for gallery thumbnail drag-reorder (macOS + iOS).
public enum PhotoManifestReorder {
    /// Moves `draggedID` so it sits at gap `insertionIndex` (0 = before first photo, `count` = after last).
    public static func applyingMove(
        draggedID: PhotoID,
        insertionIndex: Int,
        in order: [PhotoID]
    ) -> [PhotoID] {
        guard let fromIndex = order.firstIndex(of: draggedID) else { return order }
        var next = order
        next.remove(at: fromIndex)
        var index = insertionIndex
        if fromIndex < index { index -= 1 }
        index = max(0, min(index, next.count))
        if index == fromIndex { return order }
        next.insert(draggedID, at: index)
        return next
    }

    /// Gap index from pointer position within a cell (LTR grid: left half = before, right half = after).
    public static func insertionIndex(
        horizontalFraction: CGFloat,
        photoIndex: Int,
        photoCount: Int
    ) -> Int {
        let after = horizontalFraction >= 0.5
        let raw = photoIndex + (after ? 1 : 0)
        return max(0, min(raw, photoCount))
    }
}
