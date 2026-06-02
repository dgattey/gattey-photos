import GatteyPhotosCore
import SwiftUI

/// White mat + black bezel around the e-ink opening (shared by device preview and unlock welcome).
enum DevicePreviewChrome {
    /// White mat between art and outer frame (einkshot-style).
    static let matPadding: CGFloat = 18
    /// Solid black outer frame.
    static let outerFrameWidth: CGFloat = 24
    static let outerFrameColor = Color(red: 0.08, green: 0.08, blue: 0.08)

    static var frameSideOverhead: CGFloat {
        outerFrameWidth + matPadding
    }

    /// Largest e-ink opening width that fits `available` (width ÷ height = `screenAspectRatio`).
    ///
    /// Width-first: `screenW = available.width − 2×overhead` when height allows;
    /// otherwise height binds: `screenW = (available.height − 2×overhead) × screenAspectRatio`.
    /// Screen height: `screenH = screenW / screenAspectRatio`.
    static func screenWidth(
        for available: CGSize,
        screenAspectRatio: CGFloat,
        minScreenWidth: CGFloat = 80
    ) -> CGFloat {
        let overhead = 2 * frameSideOverhead
        let maxByWidth = max(0, available.width - overhead)
        let maxByHeight = max(0, available.height - overhead) * screenAspectRatio
        let fit = min(maxByWidth, maxByHeight)
        return max(minScreenWidth, fit)
    }

    static func framedDimensions(screenWidth: CGFloat, screenAspectRatio: CGFloat) -> CGSize {
        let screenHeight = screenWidth / screenAspectRatio
        let overhead = 2 * frameSideOverhead
        return CGSize(
            width: screenWidth + overhead,
            height: screenHeight + overhead
        )
    }

    static func framedUnitAspectRatio(screenWidth: CGFloat, screenAspectRatio: CGFloat) -> CGFloat {
        let d = framedDimensions(screenWidth: screenWidth, screenAspectRatio: screenAspectRatio)
        return d.height > 0 ? d.width / d.height : screenAspectRatio
    }
}

/// Soft inset shading on the e-ink opening so the mat/bezel reads as recessed (non-interactive).
struct DevicePreviewScreenInnerVignette: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxHeight: 28)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.black.opacity(0.06), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(maxHeight: 18)
            }
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.11), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(maxWidth: 22)
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.black.opacity(0.07), .clear],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                .frame(maxWidth: 18)
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Inner edge shading for device screen content; place before hover/interaction overlays.
    func devicePreviewScreenInnerVignette() -> some View {
        overlay {
            DevicePreviewScreenInnerVignette()
        }
    }
}

struct DevicePreviewFramed<Screen: View>: View {
    let screenWidth: CGFloat
    let screenAspectRatio: CGFloat
    @ViewBuilder var screen: () -> Screen

    private var screenHeight: CGFloat {
        screenWidth / screenAspectRatio
    }

    var body: some View {
        screen()
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
            .padding(DevicePreviewChrome.matPadding)
            .background(Color.white)
            .padding(DevicePreviewChrome.outerFrameWidth)
            .background(DevicePreviewChrome.outerFrameColor)
            .fixedSize()
            .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 7)
    }
}
