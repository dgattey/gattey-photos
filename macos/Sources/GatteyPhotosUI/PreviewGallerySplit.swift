#if os(macOS)
import GatteyPhotosCore
import SwiftUI

/// Fixed split between device preview and thumbnail grid (intrinsic preview width).
struct PreviewGallerySplit<Right: View>: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(GalleryStore.self) private var store
    @ViewBuilder var right: () -> Right

    var body: some View {
        GeometryReader { geo in
            animatedSplit(in: geo)
        }
        .animation(AppAnimation.bouncy, value: chrome.showDevicePreview)
    }

    @ViewBuilder
    private func animatedSplit(in geo: GeometryProxy) -> some View {
        let totalW = max(geo.size.width, 1)
        let aspect = PreviewPaneLayout.deviceScreenAspectRatio(
            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
            isLandscape: store.deviceScreenIsLandscape
        )
        let intrinsicLeftW = PreviewPaneLayout.macOSLeftPaneWidth(
            contentHeight: geo.size.height,
            screenAspectRatio: aspect,
            totalWidth: totalW
        )
        let showPreview = chrome.showDevicePreview
        let leftW = showPreview ? intrinsicLeftW : 0

        let tiltTrackingEnabled =
            showPreview && store.currentPhoto != nil && !accessibilityReduceMotion

        HStack(alignment: .top, spacing: 0) {
            if showPreview {
                DeviceCurrentPreview()
                    .frame(width: leftW, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }

            right()
                .padding(.leading, showPreview ? DeviceCurrentPreview.splitColumnGutter : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: totalW, height: geo.size.height)
        .overlay {
            DevicePreviewTiltMouseTracker(
                enabled: tiltTrackingEnabled,
                onMove: { pointer, size in
                    chrome.setDevicePreviewHoverTilt(pointer: pointer, in: size)
                },
                onExit: {
                    chrome.resetDevicePreviewHoverTilt()
                }
            )
        }
    }
}
#endif
