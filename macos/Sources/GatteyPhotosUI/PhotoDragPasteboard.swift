#if os(macOS)
import AppKit
import GatteyPhotosCore
import UniformTypeIdentifiers

/// Pasteboard types for gallery thumbnail reorder / set-current drags (AppKit session ↔ AppKit drop).
enum PhotoDragPasteboard {
    static let draggedTypes: [NSPasteboard.PasteboardType] = [
        .string,
        NSPasteboard.PasteboardType(UTType.plainText.identifier),
    ]

    static func write(photoID: PhotoID, to item: NSPasteboardItem) {
        item.setString(photoID, forType: .string)
        item.setString(photoID, forType: NSPasteboard.PasteboardType(UTType.plainText.identifier))
    }

    static func photoID(from info: NSDraggingInfo) -> PhotoID? {
        let pb = info.draggingPasteboard
        for type in draggedTypes {
            if let id = pb.string(forType: type), !id.isEmpty {
                return id
            }
        }
        return nil
    }
}
#endif
