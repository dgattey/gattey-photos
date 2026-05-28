import Foundation

public enum GalleryMerge {
    /// Remote wins for shared photos (order, metadata, deletes). Keep local-only active additions.
    public static func merge(local: GalleryState, remote: GalleryState) -> GalleryState {
        var merged = remote
        var order = remote.order.filter { id in
            guard let p = remote.photos[id] else { return false }
            return !p.isDeleted
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
