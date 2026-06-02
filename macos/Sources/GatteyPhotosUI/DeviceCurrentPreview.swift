import GatteyPhotosCore
import SwiftUI

/// Left column: large preview of the photo on the Bloomin8 device; drop target to set current.
struct DeviceCurrentPreview: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var isDropTargeted = false
    #if os(macOS)
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var previewHoverTilt = DevicePreviewHoverTiltAngles()
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
        GeometryReader { geo in
            let screenW = screenWidth(in: geo.size)
            let framedSize = DevicePreviewChrome.framedDimensions(
                screenWidth: screenW,
                screenAspectRatio: screenAspectRatio
            )

            framedPreview(screenWidth: screenW)
                .frame(width: framedSize.width, alignment: .topLeading)
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
        framedDevice(screenWidth: screenWidth)
        #if os(macOS)
            .onChange(of: store.currentPhoto?.id) { _, _ in
                if store.currentPhoto == nil {
                    resetPreviewHoverTilt()
                    isPreviewHovered = false
                }
            }
        #endif
    }

    @ViewBuilder
    private func framedDevice(screenWidth: CGFloat) -> some View {
        #if os(macOS)
        let hoverTiltEnabled = store.currentPhoto != nil && !accessibilityReduceMotion
        #endif

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
            .degrees(previewHoverTilt.yaw),
            axis: (x: 0, y: 1, z: 0),
            perspective: DevicePreviewHoverTilt.perspective
        )
        .rotation3DEffect(
            .degrees(previewHoverTilt.pitch),
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
                onPointerMove: hoverTiltEnabled
                    ? { point, size in updatePreviewHoverTilt(pointer: point, in: size) }
                    : nil,
                onPointerExit: hoverTiltEnabled ? resetPreviewHoverTilt : nil,
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
        let cornerTag = store.showingTag(for: photo.id)
        Text(store.devicePreviewCaption(for: photo))
            .font(AppTypography.devicePreviewHoverBadge)
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(cornerTag == "Showing today" ? Color.black : AppBrandColor.accentGreen)
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

    #if os(macOS)
    private func updatePreviewHoverTilt(pointer: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let nx = (pointer.x / size.width - 0.5) * 2
        let ny = (pointer.y / size.height - 0.5) * 2
        let yaw = nx * DevicePreviewHoverTilt.maxYawDegrees
        let pitch = -ny * DevicePreviewHoverTilt.maxPitchDegrees
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
            previewHoverTilt.yaw = yaw
            previewHoverTilt.pitch = pitch
        }
    }

    private func resetPreviewHoverTilt() {
        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.9)) {
            previewHoverTilt = DevicePreviewHoverTiltAngles()
        }
    }
    #endif
}

#if os(macOS)
private struct DevicePreviewHoverTiltAngles: Equatable {
    var yaw: Double = 0
    var pitch: Double = 0
}

private enum DevicePreviewHoverTilt {
    /// Horizontal follow (cursor left/right).
    static let maxYawDegrees: Double = 3
    /// Vertical follow (cursor up/down).
    static let maxPitchDegrees: Double = 2.5
    static let perspective: CGFloat = 0.8
}
#endif
