import GatteyPhotosCore
import SwiftUI

/// White mat + black bezel around the e-ink opening (shared by device preview, Now Showing card, and unlock welcome).
///
/// `chromeScale` shrinks the mat and bezel with the frame so small renderings still read as a picture frame
/// instead of a thick black box around a postage stamp.
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
        minScreenWidth: CGFloat = 80,
        chromeScale: CGFloat = 1
    ) -> CGFloat {
        let overhead = 2 * frameSideOverhead * chromeScale
        let maxByWidth = max(0, available.width - overhead)
        let maxByHeight = max(0, available.height - overhead) * screenAspectRatio
        let fit = min(maxByWidth, maxByHeight)
        return max(minScreenWidth, fit)
    }

    static func framedDimensions(
        screenWidth: CGFloat,
        screenAspectRatio: CGFloat,
        chromeScale: CGFloat = 1
    ) -> CGSize {
        let screenHeight = screenWidth / screenAspectRatio
        let overhead = 2 * frameSideOverhead * chromeScale
        return CGSize(
            width: screenWidth + overhead,
            height: screenHeight + overhead
        )
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
    var chromeScale: CGFloat = 1
    @ViewBuilder var screen: () -> Screen

    private var screenHeight: CGFloat {
        screenWidth / screenAspectRatio
    }

    var body: some View {
        screen()
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
            .padding(DevicePreviewChrome.matPadding * chromeScale)
            .background(Color.white)
            .padding(DevicePreviewChrome.outerFrameWidth * chromeScale)
            .background(DevicePreviewChrome.outerFrameColor)
            .fixedSize()
            .shadow(
                color: .black.opacity(0.24),
                radius: max(4, 14 * chromeScale),
                x: 0,
                y: max(2, 7 * chromeScale)
            )
    }
}

/// What the e-ink opening shows: the device's current photo letterboxed on black (matches the push canvas),
/// or an empty frame glyph.
struct DeviceScreenContent: View {
    let photoID: PhotoID?
    var maxPixelSize: Int = 1200

    var body: some View {
        Color.black
            .overlay {
                if let photoID {
                    CachedPhotoImage(
                        photoID: photoID,
                        maxPixelSize: maxPixelSize,
                        contentMode: .fit,
                        showsLoadingSpinner: true
                    )
                } else {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .devicePreviewScreenInnerVignette()
    }
}
