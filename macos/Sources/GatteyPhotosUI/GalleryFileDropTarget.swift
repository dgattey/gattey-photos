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

    /// `hitTest` returns `nil` for mouse so taps reach SwiftUI; set while a file drag is over so drops register.
    private var isFileDragHovering = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(GalleryFilePasteboard.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(GalleryFilePasteboard.draggedTypes)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isFileDragHovering ? self : nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !GalleryFilePasteboard.urls(from: sender).isEmpty else { return [] }
        isFileDragHovering = true
        onTargetedChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        GalleryFilePasteboard.urls(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isFileDragHovering = false
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !GalleryFilePasteboard.urls(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = GalleryFilePasteboard.urls(from: sender)
        guard !urls.isEmpty else { return false }
        isFileDragHovering = false
        onTargetedChange?(false)
        return onDrop?(urls) ?? false
    }
}
#endif
