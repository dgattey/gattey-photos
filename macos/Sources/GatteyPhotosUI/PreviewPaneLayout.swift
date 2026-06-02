import GatteyPhotosCore
import SwiftUI

/// Split-column width from device aspect + available height (macOS gallery preview).
enum PreviewPaneLayout {
    #if os(macOS)
    static let macOSPanePaddingLeading: CGFloat = 20
    static let macOSPanePaddingTrailing: CGFloat = 12
    static let macOSPanePaddingVertical: CGFloat = 20

    static var macOSPaneHorizontalPadding: CGFloat {
        macOSPanePaddingLeading + macOSPanePaddingTrailing
    }

    static var macOSPaneVerticalPadding: CGFloat {
        2 * macOSPanePaddingVertical
    }
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
    /// Auto left column width: framed device preview at full content height (no 28% min floor).
    ///
    /// Height-limited intrinsic: unlimited content width, height = `contentHeight − verticalPadding`.
    /// `screenW = (contentHeight − verticalPadding − 2×frameOverhead) × aspect`
    /// `leftW = framed.width + horizontalPadding`, capped at 72% of `totalWidth`.
    static func macOSLeftPaneWidth(
        contentHeight: CGFloat,
        screenAspectRatio: CGFloat,
        totalWidth: CGFloat
    ) -> CGFloat {
        macOSClampedLeftPaneWidth(
            macOSIntrinsicLeftPaneWidth(
                contentHeight: contentHeight,
                screenAspectRatio: screenAspectRatio
            ),
            totalWidth: totalWidth
        )
    }

    static func macOSIntrinsicLeftPaneWidth(
        contentHeight: CGFloat,
        screenAspectRatio: CGFloat
    ) -> CGFloat {
        let availableH = max(0, contentHeight - macOSPaneVerticalPadding)
        let screenW = DevicePreviewChrome.screenWidth(
            for: CGSize(width: .greatestFiniteMagnitude, height: availableH),
            screenAspectRatio: screenAspectRatio
        )
        let framed = DevicePreviewChrome.framedDimensions(
            screenWidth: screenW,
            screenAspectRatio: screenAspectRatio
        )
        return framed.width + macOSPaneHorizontalPadding
    }

    /// Clamps pane width to the configured maximum fraction of `totalWidth`.
    static func macOSClampedLeftPaneWidth(
        _ width: CGFloat,
        totalWidth: CGFloat
    ) -> CGFloat {
        let total = max(totalWidth, 1)
        let maxW = total * CGFloat(AppSettings.previewPaneSplitFractionMax)
        return min(max(width, 0), maxW)
    }
    #endif
}
