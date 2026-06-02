import Foundation

public enum GalleryMerge {
    /// Remote wins for shared photo metadata and deletes. Order follows the newer `version`
    /// (so a successful reorder is not undone by a stale gallery GET). Local-only active additions are kept.
    public static func merge(local: GalleryState, remote: GalleryState) -> GalleryState {
        var merged = remote
        let preferLocalOrder = local.version > remote.version

        var order: [PhotoID]
        if preferLocalOrder {
            order = local.order.filter { id in
                guard let photo = local.photos[id], !photo.isDeleted else { return false }
                return true
            }
            merged.version = local.version
        } else {
            order = remote.order.filter { id in
                guard let photo = remote.photos[id], !photo.isDeleted else { return false }
                return true
            }
        }

        for id in local.order {
            guard let localPhoto = local.photos[id], !localPhoto.isDeleted else { continue }
            if remote.photos[id] == nil {
                merged.photos[id] = localPhoto
                if !order.contains(id) {
                    order.append(id)
                }
            }
        }

        merged.order = order
        return merged
    }
}
