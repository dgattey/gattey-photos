import GatteyPhotosCore
import SwiftUI

/// Shared sizing so the launch spinner and the unlock form place the welcome frame in the same spot.
enum UnlockLayout {
    /// Side-by-side (iPad, Mac): frame height beside the form column.
    static let regularFramedHeight: CGFloat = 440
    static let regularColumnSpacing: CGFloat = 56
    static let formColumnWidth: CGFloat = 400
    /// iPhone: a smaller frame above the form, with chrome scaled down so it reads as a picture frame.
    static let compactFramedHeight: CGFloat = 200
    static let compactChromeScale: CGFloat = 0.5
    static let compactTopPadding: CGFloat = 24
}

/// Bundled portrait on the unlock screen; same framed chrome as the device preview.
struct UnlockWelcomePhotoPanel: View {
    var framedHeight: CGFloat
    var chromeScale: CGFloat = 1

    @State private var loadedWelcomeImage: PlatformThumbnailImage? = Self.cachedWelcomeImage

    private let screenAspectRatio = Bloomin8Screen.defaultAspectRatio

    private var screenWidth: CGFloat {
        DevicePreviewChrome.screenWidth(
            for: CGSize(width: .greatestFiniteMagnitude, height: framedHeight),
            screenAspectRatio: screenAspectRatio,
            minScreenWidth: 40,
            chromeScale: chromeScale
        )
    }

    var body: some View {
        DevicePreviewFramed(
            screenWidth: screenWidth,
            screenAspectRatio: screenAspectRatio,
            chromeScale: chromeScale
        ) {
            welcomePhoto
        }
        .accessibilityHidden(true)
        .task {
            if loadedWelcomeImage == nil {
                loadedWelcomeImage = await Self.loadBundledWelcomeImage()
            }
        }
    }

    @ViewBuilder
    private var welcomePhoto: some View {
        if let image = loadedWelcomeImage {
            platformImage(image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: screenWidth,
                    height: screenWidth / screenAspectRatio,
                    alignment: .leading
                )
                .clipped()
                .devicePreviewScreenInnerVignette()
        } else {
            Color.secondary.opacity(0.15)
                .devicePreviewScreenInnerVignette()
        }
    }

    private func platformImage(_ image: PlatformThumbnailImage) -> Image {
        #if os(macOS)
        Image(nsImage: image)
        #else
        Image(uiImage: image)
        #endif
    }

    private static var welcomeImageURL: URL? {
        GatteyPhotosUIResources.bundle.url(
            forResource: "unlock-welcome",
            withExtension: "png"
        )
    }

    private static var cachedWelcomeImage: PlatformThumbnailImage? {
        guard let url = welcomeImageURL else { return nil }
        return ImageDownsampler.cachedThumbnail(from: url, maxPixelSize: 1200)
    }

    private static func loadBundledWelcomeImage() async -> PlatformThumbnailImage? {
        guard let url = welcomeImageURL else { return nil }
        if let cached = ImageDownsampler.cachedThumbnail(from: url, maxPixelSize: 1200) {
            return cached
        }
        return await Task.detached(priority: .userInitiated) {
            ImageDownsampler.loadThumbnail(from: url, maxPixelSize: 1200)
        }.value
    }
}
