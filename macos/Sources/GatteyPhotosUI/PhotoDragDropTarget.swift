#if os(macOS)
import AppKit
import GatteyPhotosCore
import SwiftUI

/// AppKit drop surface for photo-id drags (SwiftUI `dropDestination` does not receive AppKit reorder sessions).
struct PhotoDragDropTarget: NSViewRepresentable {
    var onDrop: (PhotoID) -> Bool
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
        view.onTargetedChange = { isTargeted = $0 }
    }
}

final class PhotoDragDropNSView: NSView {
    var onDrop: ((PhotoID) -> Bool)?
    var onTargetedChange: ((Bool) -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(PhotoDragPasteboard.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(PhotoDragPasteboard.draggedTypes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard PhotoDragPasteboard.photoID(from: sender) != nil else { return [] }
        onTargetedChange?(true)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        PhotoDragPasteboard.photoID(from: sender) != nil ? .move : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        PhotoDragPasteboard.photoID(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let id = PhotoDragPasteboard.photoID(from: sender) else { return false }
        onTargetedChange?(false)
        return onDrop?(id) ?? false
    }
}
#endif
