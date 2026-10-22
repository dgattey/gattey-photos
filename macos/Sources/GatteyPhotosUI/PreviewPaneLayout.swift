import GatteyPhotosCore
import SwiftUI

/// Split-column width from device aspect + available height (macOS gallery preview).
enum PreviewPaneLayout {
    #if os(macOS)
    static let macOSPanePaddingLeading: CGFloat = 20
    static let macOSPanePaddingTrailing: CGFloat = 16
    static let macOSPanePaddingVertical: CGFloat = 20
    static let macOSCaptionSpacing: CGFloat = 16

    /// Serif title + its top padding + the VStack spacing before the frame.
    static let macOSTitleBlockHeight: CGFloat = 82

    /// Now Showing caption (eyebrow, attribution, until) + spacing above it + bottom padding.
    static let macOSCaptionBlockHeight: CGFloat = 104
    #endif

    /// SwiftUI width ÷ height for the device preview frame (portrait default; landscape when `isLandscape`).
    static func deviceScreenAspectRatio(
        deviceScreenAspectRatio: CGFloat,
        isLandscape: Bool
    ) -> CGFloat {
        Bloomin8Screen.displayAspectRatio(
            normalizedAspectRatio: deviceScreenAspectRatio,
            isLandscape: isLandscape
        )
    }

    static func portraitScreenAspectRatio(deviceScreenAspectRatio ratio: CGFloat) -> CGFloat {
        Self.deviceScreenAspectRatio(deviceScreenAspectRatio: ratio, isLandscape: false)
    }

    #if os(macOS)
    /// Auto left column width: framed device preview filling the height left over by the title and caption,
    /// capped at the configured fraction of `totalWidth`.
    static func macOSLeftPaneWidth(
        contentHeight: CGFloat,
        screenAspectRatio: CGFloat,
        totalWidth: CGFloat
    ) -> CGFloat {
        let availableH = max(0, contentHeight - macOSTitleBlockHeight - macOSCaptionBlockHeight)
        let screenW = DevicePreviewChrome.screenWidth(
            for: CGSize(width: .greatestFiniteMagnitude, height: availableH),
            screenAspectRatio: screenAspectRatio
        )
        let framed = DevicePreviewChrome.framedDimensions(
            screenWidth: screenW,
            screenAspectRatio: screenAspectRatio
        )
        let maxW = max(totalWidth, 1) * CGFloat(AppSettings.previewPaneSplitFractionMax)
        return min(framed.width + macOSPanePaddingLeading, maxW)
    }
    #endif
}
