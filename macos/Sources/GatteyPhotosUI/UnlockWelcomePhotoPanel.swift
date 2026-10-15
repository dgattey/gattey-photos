import GatteyPhotosCore
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Bundled portrait on the unlock screen; same framed chrome as `DeviceCurrentPreview`.
struct UnlockWelcomePhotoPanel: View {
    /// Matches the unlock form column height (from layout preferences).
    var contentHeight: CGFloat

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var loadedWelcomeImage: PlatformWelcomeImage? = Self.cachedWelcomeImage

    private let screenAspectRatio = Bloomin8Screen.defaultAspectRatio
    private let maxPaneWidth: CGFloat = 420

    var body: some View {
        GeometryReader { geo in
            let height = panelLayoutHeight(fallback: geo.size.height)
            let available = CGSize(
                width: min(geo.size.width, maxPaneWidth),
                height: height
            )
            let screenW = DevicePreviewChrome.screenWidth(
                for: available,
                screenAspectRatio: screenAspectRatio
            )
            let framedSize = DevicePreviewChrome.framedDimensions(
                screenWidth: screenW,
                screenAspectRatio: screenAspectRatio
            )

            DevicePreviewFramed(screenWidth: screenW, screenAspectRatio: screenAspectRatio) {
                welcomePhoto(screenWidth: screenW)
            }
            .aspectRatio(
                DevicePreviewChrome.framedUnitAspectRatio(
                    screenWidth: screenW,
                    screenAspectRatio: screenAspectRatio
                ),
                contentMode: .fit
            )
            .frame(width: framedSize.width, height: framedSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: panelContentAlignment)
        }
        .frame(maxWidth: panelOuterMaxWidth)
        .frame(height: panelFrameHeight)
        .task {
            if loadedWelcomeImage == nil {
                loadedWelcomeImage = await Self.loadBundledWelcomeImage()
            }
        }
    }

    private var panelContentAlignment: Alignment {
        #if os(iOS)
        horizontalSizeClass == .compact ? .center : .trailing
        #else
        .trailing
        #endif
    }

    private var panelOuterMaxWidth: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .compact ? .infinity : maxPaneWidth
        #else
        maxPaneWidth
        #endif
    }

    private var panelFrameHeight: CGFloat? {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return IOSContentWidth.unlockCompactWelcomePhotoMaxHeight
        }
        #endif
        return contentHeight > 0 ? contentHeight : nil
    }

    private func panelLayoutHeight(fallback: CGFloat) -> CGFloat {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return IOSContentWidth.unlockCompactWelcomePhotoMaxHeight
        }
        #endif
        return contentHeight > 0 ? contentHeight : fallback
    }

    @ViewBuilder
    private func welcomePhoto(screenWidth: CGFloat) -> some View {
        let screenHeight = screenWidth / screenAspectRatio
        if let image = loadedWelcomeImage {
            welcomeImageView(image, screenWidth: screenWidth, screenHeight: screenHeight)
                .devicePreviewScreenInnerVignette()
        } else {
            Color.secondary.opacity(0.15)
                .devicePreviewScreenInnerVignette()
        }
    }

    @ViewBuilder
    private func welcomeImageView(_ image: PlatformWelcomeImage, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: screenWidth, height: screenHeight, alignment: .leading)
            .clipped()
        #elseif os(iOS)
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: screenWidth, height: screenHeight, alignment: .leading)
            .clipped()
        #endif
    }

    private typealias PlatformWelcomeImage = PlatformThumbnailImage

    private static var welcomeImageURL: URL? {
        GatteyPhotosUIResources.bundle.url(
            forResource: "unlock-welcome",
            withExtension: "png"
        )
    }

    private static var cachedWelcomeImage: PlatformWelcomeImage? {
        guard let url = welcomeImageURL else { return nil }
        return ImageDownsampler.cachedThumbnail(from: url, maxPixelSize: 1200)
    }

    private static func loadBundledWelcomeImage() async -> PlatformWelcomeImage? {
        guard let url = welcomeImageURL else { return nil }
        if let cached = ImageDownsampler.cachedThumbnail(from: url, maxPixelSize: 1200) {
            return cached
        }
        return await Task.detached(priority: .userInitiated) {
            ImageDownsampler.loadThumbnail(from: url, maxPixelSize: 1200)
        }.value
    }
}
