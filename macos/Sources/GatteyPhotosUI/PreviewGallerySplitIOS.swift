#if os(iOS)
import GatteyPhotosCore
import SwiftUI

private enum PreviewGallerySplitLayout {
    static let dividerHitWidth: CGFloat = 12
    static let dividerVisibleWidth: CGFloat = 4
    static let minFraction: CGFloat = 0.28
    static let maxFraction: CGFloat = 0.72
}

struct PreviewGallerySplit<Right: View>: View {
    @Environment(GalleryStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var right: () -> Right

    @State private var dragFraction: CGFloat?

    var body: some View {
        GeometryReader { geo in
            if (horizontalSizeClass == .regular && geo.size.width > 600)
                || geo.size.width > geo.size.height
            {
                horizontalSplit(totalSize: geo.size)
            } else {
                let compactPreviewHeight = min(
                    IOSContentWidth.compactDevicePreviewMaxHeight,
                    max(220, geo.size.height * 0.36)
                )
                VStack(alignment: .leading, spacing: 16) {
                    DeviceCurrentPreview()
                        .frame(maxWidth: .infinity)
                        .frame(height: compactPreviewHeight)
                    right()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func horizontalSplit(totalSize: CGSize) -> some View {
        let totalW = max(totalSize.width, 1)
        let fraction = clampedFraction(
            dragFraction ?? CGFloat(store.settings.previewPaneSplitFraction)
        )
        let leftW = min(totalW * fraction, IOSContentWidth.previewPaneMax)

        HStack(alignment: .top, spacing: 0) {
            DeviceCurrentPreview()
                .frame(width: leftW, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .frame(maxWidth: IOSContentWidth.previewPaneMax, alignment: .leading)
                .clipped()

            splitDivider(totalWidth: totalW, fraction: fraction)
                .frame(width: PreviewGallerySplitLayout.dividerHitWidth)

            right()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func splitDivider(totalWidth: CGFloat, fraction: CGFloat) -> some View {
        SoftColumnSeparator(visibleWidth: PreviewGallerySplitLayout.dividerVisibleWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if dragFraction == nil {
                            dragFraction = fraction
                        }
                        let start = CGFloat(store.settings.previewPaneSplitFraction)
                        let delta = value.translation.width / totalWidth
                        dragFraction = clampedFraction(start + delta)
                    }
                    .onEnded { _ in
                        if let final = dragFraction {
                            persistFraction(final)
                        }
                        dragFraction = nil
                    }
            )
    }

    private func clampedFraction(_ raw: CGFloat) -> CGFloat {
        min(max(raw, PreviewGallerySplitLayout.minFraction), PreviewGallerySplitLayout.maxFraction)
    }

    private func persistFraction(_ fraction: CGFloat) {
        let clamped = Double(clampedFraction(fraction))
        guard store.settings.previewPaneSplitFraction != clamped else { return }
        store.settings.previewPaneSplitFraction = clamped
        AppConfig.saveSettingsAsync(store.settings)
    }
}
#endif
