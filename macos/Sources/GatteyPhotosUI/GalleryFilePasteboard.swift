#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Finder / Photos drags into the gallery (AppKit pasteboard; not SwiftUI `onDrop`).
enum GalleryFilePasteboard {
    static let draggedTypes: [NSPasteboard.PasteboardType] = {
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.fileURL.identifier),
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.png.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier),
            NSPasteboard.PasteboardType(UTType.image.identifier),
            NSPasteboard.PasteboardType(UTType.tiff.identifier),
        ]
        types.append(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        return types
    }()

    static func urls(from info: NSDraggingInfo) -> [URL] {
        let pb = info.draggingPasteboard
        if let items = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !items.isEmpty {
            return items.filter { $0.isFileURL }
        }
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pb.propertyList(forType: filenamesType) as? [String],
           !paths.isEmpty {
            return paths.map { URL(fileURLWithPath: $0) }
        }
        if let path = pb.string(forType: .fileURL)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return [URL(fileURLWithPath: path)]
        }
        if let temp = writeImageDataToTemporaryFile(from: pb) {
            return [temp]
        }
        return []
    }

    private static func writeImageDataToTemporaryFile(from pb: NSPasteboard) -> URL? {
        let imageTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.png.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier),
            NSPasteboard.PasteboardType(UTType.tiff.identifier),
            NSPasteboard.PasteboardType(UTType.image.identifier),
        ]
        for type in imageTypes {
            guard let data = pb.data(forType: type), !data.isEmpty else { continue }
            let ext = type == NSPasteboard.PasteboardType(UTType.png.identifier) ? "png" : "jpg"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("gallery-drop-\(UUID().uuidString).\(ext)")
            guard (try? data.write(to: url, options: .atomic)) != nil else { continue }
            return url
        }
        return nil
    }
}
#endif
