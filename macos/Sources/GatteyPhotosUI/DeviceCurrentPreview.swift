import GatteyPhotosCore
import SwiftUI

/// Left column: large preview of the photo on the Bloomin8 device; drop target to set current.
struct DeviceCurrentPreview: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(GalleryStore.self) private var store
    @State private var isDropTargeted = false
    #if os(macOS)
    @State private var isPreviewHovered = false
    #endif

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
        #if os(macOS)
        VStack(alignment: .leading, spacing: PreviewPaneLayout.macOSPanePaddingLeading) {
            Text("Gattey Photos")
                .font(AppTypography.primaryTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, PreviewPaneLayout.macOSPanePaddingLeading)
                .padding(.top, PreviewPaneLayout.macOSPanePaddingVertical)

            previewGeometry
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #else
        previewGeometry
        #endif
    }

    private var previewGeometry: some View {
        GeometryReader { geo in
            let screenW = screenWidth(in: geo.size)
            let framedSize = DevicePreviewChrome.framedDimensions(
                screenWidth: screenW,
                screenAspectRatio: screenAspectRatio
            )

            framedPreview(screenWidth: screenW)
                .frame(width: framedSize.width, alignment: .topLeading)
                #if os(macOS)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.leading, PreviewPaneLayout.macOSPanePaddingLeading)
            .padding(.bottom, PreviewPaneLayout.macOSPanePaddingLeading)
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
        let usableH = max(0, geoSize.height - PreviewPaneLayout.macOSPanePaddingLeading)
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
        framedDevice(screenWidth: screenWidth)
            #if os(macOS)
        .onChange(of: store.currentPhoto?.id) { _, _ in
            if store.currentPhoto == nil {
                chrome.resetDevicePreviewHoverTilt()
                isPreviewHovered = false
            }
        }
            #endif
    }

    @ViewBuilder
    private func framedDevice(screenWidth: CGFloat) -> some View {
        DevicePreviewFramed(screenWidth: screenWidth, screenAspectRatio: screenAspectRatio) {
            deviceScreenContent
                #if os(macOS)
            .overlay(alignment: .bottomTrailing) {
                if let photo = store.currentPhoto, isPreviewHovered {
                    devicePreviewHoverBadge(for: photo)
                }
            }
                #endif
        }
        #if os(macOS)
        .rotation3DEffect(
            .degrees(chrome.devicePreviewHoverTilt.yaw),
            axis: (x: 0, y: 1, z: 0),
            perspective: DevicePreviewHoverTilt.perspective
        )
        .rotation3DEffect(
            .degrees(chrome.devicePreviewHoverTilt.pitch),
            axis: (x: 1, y: 0, z: 0),
            perspective: DevicePreviewHoverTilt.perspective
        )
        .overlay {
            PhotoDragDropTarget(
                onDrop: { id in
                    Task { await store.setAsCurrent(photoID: id) }
                    return true
                },
                onFileDrop: { urls in
                    Task { await store.uploadFiles(urls: urls) }
                    return true
                },
                isTargeted: $isDropTargeted
            )
        }
        .onHover { isPreviewHovered = $0 }
        #else
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            Task { await store.setAsCurrent(photoID: id) }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        #endif
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .strokeBorder(AppBrandColor.accentGreen, lineWidth: 4)
            }
        }
    }

    #if os(macOS)
    @ViewBuilder
    private func devicePreviewHoverBadge(for photo: PhotoEntry) -> some View {
        Text(store.devicePreviewCaption(for: photo))
            .font(AppTypography.devicePreviewHoverBadge)
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black)
            .padding(10)
    }
    #endif

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
            .devicePreviewScreenInnerVignette()
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "display")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("No current photo")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.primary)
            Text("Select a photo and choose Show for today, or drag a thumbnail or image file here.")
                .font(AppTypography.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
