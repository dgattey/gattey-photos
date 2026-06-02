#if os(macOS)
import AppKit
import GatteyPhotosCore
import SwiftUI

/// AppKit drop surface for photo-id drags (SwiftUI `dropDestination` does not receive AppKit reorder sessions).
struct PhotoDragDropTarget: NSViewRepresentable {
    var onDrop: (PhotoID) -> Bool
    var onFileDrop: (([URL]) -> Bool)?
    /// Normalized pointer in view bounds (for hover effects on the same surface).
    var onPointerMove: ((CGPoint, CGSize) -> Void)?
    var onPointerExit: (() -> Void)?
    @Binding var isTargeted: Bool

    func makeNSView(context: Context) -> PhotoDragDropNSView {
        let view = PhotoDragDropNSView()
        sync(into: view)
        return view
    }

    func updateNSView(_ nsView: PhotoDragDropNSView, context: Context) {
        sync(into: nsView)
    }

    private func sync(into view: PhotoDragDropNSView) {
        view.onDrop = onDrop
        view.onFileDrop = onFileDrop
        view.onPointerMove = onPointerMove
        view.onPointerExit = onPointerExit
        view.onTargetedChange = { isTargeted = $0 }
        view.syncPointerTrackingAreas()
    }
}

final class PhotoDragDropNSView: NSView {
    var onDrop: ((PhotoID) -> Bool)?
    var onFileDrop: (([URL]) -> Bool)?
    var onPointerMove: ((CGPoint, CGSize) -> Void)?
    var onPointerExit: (() -> Void)?
    var onTargetedChange: ((Bool) -> Void)?

    override var isFlipped: Bool { true }

    func syncPointerTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        guard onPointerMove != nil || onPointerExit != nil else { return }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .inVisibleRect,
            .enabledDuringMouseDrag,
        ]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        syncPointerTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let onPointerMove, bounds.width > 0, bounds.height > 0 else { return }
        let location = convert(event.locationInWindow, from: nil)
        onPointerMove(location, bounds.size)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerExit?()
    }

    private static var draggedTypes: [NSPasteboard.PasteboardType] {
        PhotoDragPasteboard.draggedTypes + GalleryFilePasteboard.draggedTypes
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(Self.draggedTypes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !GalleryFilePasteboard.urls(from: sender).isEmpty, onFileDrop != nil {
            onTargetedChange?(true)
            return .copy
        }
        guard PhotoDragPasteboard.photoID(from: sender) != nil else { return [] }
        onTargetedChange?(true)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !GalleryFilePasteboard.urls(from: sender).isEmpty, onFileDrop != nil { return .copy }
        return PhotoDragPasteboard.photoID(from: sender) != nil ? .move : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !GalleryFilePasteboard.urls(from: sender).isEmpty && onFileDrop != nil
            || PhotoDragPasteboard.photoID(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let fileURLs = GalleryFilePasteboard.urls(from: sender)
        if !fileURLs.isEmpty, let onFileDrop {
            onTargetedChange?(false)
            return onFileDrop(fileURLs)
        }
        guard let id = PhotoDragPasteboard.photoID(from: sender) else { return false }
        onTargetedChange?(false)
        return onDrop?(id) ?? false
    }
}
#endif
