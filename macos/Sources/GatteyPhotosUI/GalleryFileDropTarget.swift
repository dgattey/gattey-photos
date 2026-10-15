#if os(macOS)
import AppKit
import SwiftUI

/// AppKit drop surface for Finder photo imports (SwiftUI `.onDrop` does not receive drags over grid NSView overlays).
struct GalleryFileDropTarget: NSViewRepresentable {
    var onDrop: ([URL]) -> Bool
    @Binding var isTargeted: Bool

    func makeNSView(context: Context) -> GalleryFileDropNSView {
        let view = GalleryFileDropNSView()
        sync(into: view)
        return view
    }

    func updateNSView(_ nsView: GalleryFileDropNSView, context: Context) {
        sync(into: nsView)
    }

    private func sync(into view: GalleryFileDropNSView) {
        view.onDrop = onDrop
        view.onTargetedChange = { isTargeted = $0 }
    }
}

final class GalleryFileDropNSView: NSView {
    var onDrop: (([URL]) -> Bool)?
    var onTargetedChange: ((Bool) -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(GalleryFilePasteboard.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(GalleryFilePasteboard.draggedTypes)
    }

    /// Pass primary mouse clicks to SwiftUI above; accept Finder drags (nil `currentEvent` during drag hit-test).
    override func hitTest(_ point: NSPoint) -> NSView? {
        switch NSApp.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return nil
        default:
            return self
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard GalleryFilePasteboard.hasCandidateUploadItems(in: sender) else { return [] }
        onTargetedChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        GalleryFilePasteboard.hasCandidateUploadItems(in: sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        GalleryFilePasteboard.hasCandidateUploadItems(in: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let payload = GalleryFilePasteboard.extractDropPayload(from: sender),
            let onDrop
        else { return false }
        onTargetedChange?(false)
        Task { @MainActor in
            let urls = await payload.materializeURLs()
            guard !urls.isEmpty else { return }
            _ = onDrop(urls)
        }
        return true
    }
}
#endif
