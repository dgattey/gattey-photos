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
        guard !GalleryFilePasteboard.uploadURLs(from: sender).isEmpty else { return [] }
        onTargetedChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        GalleryFilePasteboard.uploadURLs(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !GalleryFilePasteboard.uploadURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = GalleryFilePasteboard.uploadURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onTargetedChange?(false)
        return onDrop?(urls) ?? false
    }
}
#endif
