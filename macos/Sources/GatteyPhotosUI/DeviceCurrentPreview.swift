import GatteyPhotosCore
import SwiftUI

/// Left column: large preview of the photo on the Bloomin8 device; drop target to set current.
struct DeviceCurrentPreview: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var isDropTargeted = false

    #if os(macOS)
    /// Space between preview frame and gallery split (matches grid leading gutter in `PreviewGallerySplit`).
    static let splitColumnGutter: CGFloat = PreviewPaneLayout.macOSPanePaddingTrailing
    #else
    private let panePadding: CGFloat = 20
    #endif

    private var screenAspectRatio: CGFloat {
        PreviewPaneLayout.deviceScreenAspectRatio(
            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
            isLandscape: store.deviceScreenIsLandscape
        )
    }

    var body: some View {
        GeometryReader { geo in
            let screenW = screenWidth(in: geo.size)
            let framedSize = DevicePreviewChrome.framedDimensions(
                screenWidth: screenW,
                screenAspectRatio: screenAspectRatio
            )

            framedPreview(screenWidth: screenW)
                .frame(width: framedSize.width, height: framedSize.height)
            #if os(macOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, PreviewPaneLayout.macOSPanePaddingLeading)
            .padding(.trailing, PreviewPaneLayout.macOSPanePaddingTrailing)
            .padding(.vertical, PreviewPaneLayout.macOSPanePaddingVertical)
            #else
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(panePadding)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Width-first in the macOS split column (pane width is intrinsic from height); height-first on iOS.
    private func screenWidth(in geoSize: CGSize) -> CGFloat {
        #if os(macOS)
        let usableH = max(0, geoSize.height - PreviewPaneLayout.macOSPaneVerticalPadding)
        let available = CGSize(
            width: max(0, geoSize.width - PreviewPaneLayout.macOSPaneHorizontalPadding),
            height: usableH > 1 ? usableH : .greatestFiniteMagnitude
        )
        #else
        let available = CGSize(
            width: max(0, geoSize.width - 2 * panePadding),
            height: max(0, geoSize.height - 2 * panePadding)
        )
        #endif
        return DevicePreviewChrome.screenWidth(
            for: available,
            screenAspectRatio: screenAspectRatio
        )
    }

    @ViewBuilder
    private func framedPreview(screenWidth: CGFloat) -> some View {
        DevicePreviewFramed(screenWidth: screenWidth, screenAspectRatio: screenAspectRatio) {
            deviceScreenContent
        }
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .strokeBorder(AppBrandColor.accentGreen, lineWidth: 4)
            }
        }
        .overlay(alignment: .bottom) {
            if let photo = store.currentPhoto {
                Text(PhotoFormatters.addedBy(photo))
                    .font(AppTypography.secondary)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
                    .frame(height: DevicePreviewChrome.outerFrameWidth)
                    .background(Color.black)
            }
        }
        #if os(macOS)
        .overlay {
            PhotoDragDropTarget(
                onDrop: { id in
                    Task { await store.setAsCurrent(photoID: id) }
                    return true
                },
                isTargeted: $isDropTargeted
            )
        }
        #else
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            Task { await store.setAsCurrent(photoID: id) }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        #endif
    }

    /// E-ink opening: fixed device aspect, photo `.fit` with black letterboxing (matches push canvas).
    @ViewBuilder
    private var deviceScreenContent: some View {
        Color.black
            .overlay {
                if let photo = store.currentPhoto {
                    CachedPhotoImage(
                        photoID: photo.id,
                        maxPixelSize: 1200,
                        contentMode: .fit,
                        showsLoadingSpinner: true
                    )
                } else {
                    emptyPlaceholder
                }
            }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "display")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("No current photo")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.primary)
            Text("Select a photo and choose Set as current, or drag a thumbnail here.")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
