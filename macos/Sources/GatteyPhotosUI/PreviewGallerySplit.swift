#if os(macOS)
import AppKit
import GatteyPhotosCore
import SwiftUI

private enum PreviewGallerySplitLayout {
    /// Wide drag strip; rounded grab bar is centered inside on hover/drag.
    static let dividerHitWidth: CGFloat = 22
    static let dividerVisibleWidth: CGFloat = 5
}

/// Resizable split between device preview and thumbnail grid; divider appears on hover or while dragging.
struct PreviewGallerySplit<Right: View>: View {
    @Environment(AppChromeState.self) private var chrome
    @EnvironmentObject private var store: GalleryStore
    @ViewBuilder var right: () -> Right

    @State private var dividerActive = false
    @State private var isDragging = false
    @State private var dragLeftWidth: CGFloat?
    @State private var dragStartLeftWidth: CGFloat?

    var body: some View {
        GeometryReader { geo in
            animatedSplit(in: geo)
        }
        .animation(AppAnimation.bouncy, value: chrome.showDevicePreview)
    }

    @ViewBuilder
    private func animatedSplit(in geo: GeometryProxy) -> some View {
        let totalW = max(geo.size.width, 1)
        let aspect = PreviewPaneLayout.deviceScreenAspectRatio(
            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
            isLandscape: store.deviceScreenIsLandscape
        )
        let intrinsicLeftW = PreviewPaneLayout.macOSLeftPaneWidth(
            contentHeight: geo.size.height,
            screenAspectRatio: aspect,
            totalWidth: totalW
        )
        let showPreview = chrome.showDevicePreview
        let leftW = showPreview ? (dragLeftWidth ?? intrinsicLeftW) : 0
        let previewColumnWidth = showPreview
            ? leftW + PreviewGallerySplitLayout.dividerHitWidth
            : 0

        HStack(alignment: .top, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                DeviceCurrentPreview()
                    .frame(width: leftW, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                splitDivider(totalWidth: totalW, leftWidth: max(leftW, intrinsicLeftW))
                    .frame(width: PreviewGallerySplitLayout.dividerHitWidth)
            }
            .frame(width: previewColumnWidth, alignment: .leading)
            .clipped()
            .allowsHitTesting(showPreview && leftW > 0)

            right()
                .padding(.leading, showPreview ? DeviceCurrentPreview.splitColumnGutter : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func splitDivider(totalWidth: CGFloat, leftWidth: CGFloat) -> some View {
        let showLine = dividerActive || isDragging
        ZStack {
            if showLine {
                SoftColumnSeparator(visibleWidth: PreviewGallerySplitLayout.dividerVisibleWidth)
            }
            SplitPaneDividerRepresentable(
                onHoverChange: { dividerActive = $0 },
                onDragBegin: {
                    dragStartLeftWidth = leftWidth
                    isDragging = true
                    dividerActive = true
                },
                onDragTranslation: { translation in
                    let start = dragStartLeftWidth ?? leftWidth
                    dragLeftWidth = PreviewPaneLayout.macOSClampedLeftPaneWidth(
                        start + translation,
                        totalWidth: totalWidth,
                        enforceMinimumFraction: true
                    )
                },
                onDragEnd: {
                    dragLeftWidth = nil
                    dragStartLeftWidth = nil
                    isDragging = false
                }
            )
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - AppKit divider (blocks movable-by-window-background)

/// Mouse target that refuses window drag so resize wins over `isMovableByWindowBackground`.
private struct SplitPaneDividerRepresentable: NSViewRepresentable {
    var onHoverChange: (Bool) -> Void
    var onDragBegin: () -> Void
    var onDragTranslation: (CGFloat) -> Void
    var onDragEnd: () -> Void

    func makeNSView(context: Context) -> SplitPaneDividerNSView {
        let view = SplitPaneDividerNSView()
        syncHandlers(into: view)
        return view
    }

    func updateNSView(_ nsView: SplitPaneDividerNSView, context: Context) {
        syncHandlers(into: nsView)
    }

    private func syncHandlers(into view: SplitPaneDividerNSView) {
        view.onHoverChange = onHoverChange
        view.onDragBegin = onDragBegin
        view.onDragTranslation = onDragTranslation
        view.onDragEnd = onDragEnd
    }
}

private final class SplitPaneDividerNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var onDragBegin: (() -> Void)?
    var onDragTranslation: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?

    private var dragStartX: CGFloat?

    override var isFlipped: Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard dragStartX == nil else { return }
        onHoverChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartX = event.locationInWindow.x
        onDragBegin?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startX = dragStartX else { return }
        let translation = event.locationInWindow.x - startX
        onDragTranslation?(translation)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartX = nil
        onDragEnd?()
        if !bounds.contains(convert(event.locationInWindow, from: nil)) {
            onHoverChange?(false)
        }
    }
}
#endif
