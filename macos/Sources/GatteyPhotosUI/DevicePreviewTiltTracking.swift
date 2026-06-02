#if os(macOS)
import AppKit
import SwiftUI

/// Normalized cursor tilt for the device preview (yaw/pitch in degrees).
public struct DevicePreviewHoverTiltAngles: Equatable {
    var yaw: Double = 0
    var pitch: Double = 0
}

enum DevicePreviewHoverTilt {
    static let maxYawDegrees: Double = 3
    static let maxPitchDegrees: Double = 2.5
    static let perspective: CGFloat = 0.8

    static func angles(pointer: CGPoint, in size: CGSize) -> DevicePreviewHoverTiltAngles {
        guard size.width > 0, size.height > 0 else {
            return DevicePreviewHoverTiltAngles()
        }
        let nx = (pointer.x / size.width - 0.5) * 2
        let ny = (pointer.y / size.height - 0.5) * 2
        return DevicePreviewHoverTiltAngles(
            yaw: nx * maxYawDegrees,
            pitch: -ny * maxPitchDegrees
        )
    }
}

/// Pass-through mouse tracking over the gallery split (preview + grid) for device preview tilt.
struct DevicePreviewTiltMouseTracker: NSViewRepresentable {
    var enabled: Bool
    var onMove: (CGPoint, CGSize) -> Void
    var onExit: () -> Void

    func makeNSView(context: Context) -> DevicePreviewTiltMouseTrackerNSView {
        let view = DevicePreviewTiltMouseTrackerNSView()
        sync(into: view)
        return view
    }

    func updateNSView(_ nsView: DevicePreviewTiltMouseTrackerNSView, context: Context) {
        sync(into: nsView)
    }

    private func sync(into view: DevicePreviewTiltMouseTrackerNSView) {
        view.enabled = enabled
        view.onMove = onMove
        view.onExit = onExit
        view.syncPointerTrackingAreas()
    }
}

final class DevicePreviewTiltMouseTrackerNSView: NSView {
    var enabled = false
    var onMove: ((CGPoint, CGSize) -> Void)?
    var onExit: (() -> Void)?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard enabled else { return nil }
        switch NSApp.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged,
             .rightMouseDown, .rightMouseUp, .rightMouseDragged,
             .scrollWheel, .smartMagnify, .magnify, .swipe, .rotate:
            return nil
        case .mouseMoved, .mouseEntered, .mouseExited, .cursorUpdate, .none:
            return self
        default:
            return nil
        }
    }

    func syncPointerTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        guard enabled else { return }
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
        guard enabled, let onMove, bounds.width > 0, bounds.height > 0 else { return }
        let location = convert(event.locationInWindow, from: nil)
        onMove(location, bounds.size)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard enabled else { return }
        onExit?()
    }
}
#endif
