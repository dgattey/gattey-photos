#if os(macOS)
import GatteyPhotosCore
import SwiftUI

/// Left column: brand title, large preview of the photo on the Bloomin8 device, and its Now Showing caption.
/// The frame is a drop target to set current or upload.
struct DeviceCurrentPreview: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(GalleryStore.self) private var store
    @State private var isDropTargeted = false

    /// Space between preview frame and gallery split (matches grid leading gutter in `PreviewGallerySplit`).
    static let splitColumnGutter: CGFloat = PreviewPaneLayout.macOSPanePaddingTrailing

    private var screenAspectRatio: CGFloat {
        PreviewPaneLayout.deviceScreenAspectRatio(
            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
            isLandscape: store.deviceScreenIsLandscape
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PreviewPaneLayout.macOSPanePaddingLeading) {
            Text("Gattey Photos")
                .font(AppTypography.primaryTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PreviewPaneLayout.macOSPanePaddingVertical)

            GeometryReader { geo in
                let screenW = screenWidth(in: geo.size)
                VStack(alignment: .leading, spacing: PreviewPaneLayout.macOSCaptionSpacing) {
                    framedDevice(screenWidth: screenW)
                    NowShowingCaption()
                        .frame(
                            width: DevicePreviewChrome.framedDimensions(
                                screenWidth: screenW,
                                screenAspectRatio: screenAspectRatio
                            ).width,
                            alignment: .leading
                        )
                }
            }
        }
        .padding(.leading, PreviewPaneLayout.macOSPanePaddingLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: store.currentPhoto?.id) { _, _ in
            if store.currentPhoto == nil {
                chrome.resetDevicePreviewHoverTilt()
            }
        }
    }

    private func screenWidth(in geoSize: CGSize) -> CGFloat {
        let usableH = geoSize.height - PreviewPaneLayout.macOSCaptionBlockHeight
        let available = CGSize(
            width: max(0, geoSize.width),
            height: usableH > 1 ? usableH : .greatestFiniteMagnitude
        )
        return DevicePreviewChrome.screenWidth(
            for: available,
            screenAspectRatio: screenAspectRatio
        )
    }

    private func framedDevice(screenWidth: CGFloat) -> some View {
        DevicePreviewFramed(screenWidth: screenWidth, screenAspectRatio: screenAspectRatio) {
            DeviceScreenContent(photoID: store.currentPhoto?.id)
        }
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
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .strokeBorder(AppBrandColor.accentGreen, lineWidth: 4)
            }
        }
    }
}
#endif
