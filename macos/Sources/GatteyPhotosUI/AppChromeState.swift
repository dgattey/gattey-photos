import Observation
import SwiftUI

@MainActor
@Observable
public final class AppChromeState {
    public var showActivityInspector = false
    /// Leading device preview column in the gallery split (session chrome; not persisted).
    public var showDevicePreview = true

    public init() {}

    /// Trailing inspector toggle (toolbar + View menu). Same symbol for show and hide.
    public static let activityInspectorSymbolName = "sidebar.trailing"

    /// Leading preview toggle (`Toggle` + `.toggleStyle(.button)` in toolbar).
    public static let devicePreviewToggleSymbolName = "sidebar.left"

    #if os(macOS)
    /// Device preview 3D hover tilt (driven from the whole gallery split, not only the preview).
    public var devicePreviewHoverTilt = DevicePreviewHoverTiltAngles()

    public func setDevicePreviewHoverTilt(pointer: CGPoint, in size: CGSize) {
        let angles = DevicePreviewHoverTilt.angles(pointer: pointer, in: size)
        let dyaw = abs(angles.yaw - devicePreviewHoverTilt.yaw)
        let dpitch = abs(angles.pitch - devicePreviewHoverTilt.pitch)
        guard dyaw >= 0.05 || dpitch >= 0.05 else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
            devicePreviewHoverTilt = angles
        }
    }

    public func resetDevicePreviewHoverTilt(animated: Bool = true) {
        guard devicePreviewHoverTilt != DevicePreviewHoverTiltAngles() else { return }
        if animated {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.9)) {
                devicePreviewHoverTilt = DevicePreviewHoverTiltAngles()
            }
        } else {
            devicePreviewHoverTilt = DevicePreviewHoverTiltAngles()
        }
    }
    #endif
}
