#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Finder / Photos drags into the gallery (AppKit pasteboard; not SwiftUI `onDrop`).
enum GalleryFilePasteboard {
    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "gif", "webp",
    ]

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        NSPasteboard.PasteboardType(UTType.png.identifier),
        NSPasteboard.PasteboardType(UTType.heic.identifier),
        NSPasteboard.PasteboardType(UTType.tiff.identifier),
        NSPasteboard.PasteboardType(UTType.image.identifier),
    ]

    static let draggedTypes: [NSPasteboard.PasteboardType] = {
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.fileURL.identifier),
        ]
        types.append(contentsOf: imageTypes)
        types.append(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        return types
    }()

    /// Fast pasteboard metadata check for `draggingEntered` / `draggingUpdated` / `prepareForDragOperation`
    /// with zero filesystem `stat()` or temporary file writes on the main thread.
    static func hasCandidateUploadItems(in info: NSDraggingInfo) -> Bool {
        let pb = info.draggingPasteboard
        if let items = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           items.contains(where: { $0.isFileURL && hasSupportedImageExtension($0) }) {
            return true
        }
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pb.propertyList(forType: filenamesType) as? [String],
           paths.contains(where: { hasSupportedImageExtension(URL(fileURLWithPath: $0)) }) {
            return true
        }
        if let path = pb.string(forType: .fileURL)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty,
           hasSupportedImageExtension(URL(fileURLWithPath: path)) {
            return true
        }
        return pb.availableType(from: imageTypes) != nil
    }

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

    /// Extracts file URLs or raw image pasteboard data synchronously on the main thread (as required by
    /// `NSPasteboard` during `performDragOperation`), deferring any temporary file write or filesystem check.
    static func extractDropPayload(from info: NSDraggingInfo) -> DropPayload? {
        let pb = info.draggingPasteboard
        if let items = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let fileURLs = items.filter { $0.isFileURL && hasSupportedImageExtension($0) }
            if !fileURLs.isEmpty {
                return .fileURLs(fileURLs)
            }
        }
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let paths = pb.propertyList(forType: filenamesType) as? [String] {
            let fileURLs = paths.map { URL(fileURLWithPath: $0) }.filter(hasSupportedImageExtension)
            if !fileURLs.isEmpty {
                return .fileURLs(fileURLs)
            }
        }
        if let path = pb.string(forType: .fileURL)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if hasSupportedImageExtension(url) {
                return .fileURLs([url])
            }
        }
        for type in imageTypes {
            if let data = pb.data(forType: type), !data.isEmpty {
                let ext = type == NSPasteboard.PasteboardType(UTType.png.identifier) ? "png" : "jpg"
                return .rawImageData(data, fileExtension: ext)
            }
        }
        return nil
    }

    enum DropPayload: Sendable {
        case fileURLs([URL])
        case rawImageData(Data, fileExtension: String)

        func materializeURLs() async -> [URL] {
            switch self {
            case .fileURLs(let urls):
                return urls
            case .rawImageData(let data, let ext):
                return await Task.detached(priority: .userInitiated) {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("gallery-drop-\(UUID().uuidString).\(ext)")
                    guard (try? data.write(to: url, options: .atomic)) != nil else { return [] }
                    return [url]
                }.value
            }
        }
    }

    static func uploadURLs(from info: NSDraggingInfo) -> [URL] {
        urls(from: info).filter(isUploadableImageFile)
    }

    static func hasSupportedImageExtension(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return true }
        return supportedExtensions.contains(ext)
    }

    nonisolated static func isUploadableImageFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else { return false }
        return hasSupportedImageExtension(url)
    }

    private static func writeImageDataToTemporaryFile(from pb: NSPasteboard) -> URL? {
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
