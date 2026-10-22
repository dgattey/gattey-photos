import GatteyPhotosCore
import SwiftUI

/// Eyebrow, attribution, and rotation end for the photo on the family frames.
struct NowShowingCaption: View {
    @Environment(GalleryStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Now Showing")
                .font(AppTypography.eyebrow)
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(AppBrandColor.accentGreen)
            if let photo = store.currentPhoto {
                Text(PhotoFormatters.addedBy(photo, uploaders: store.state.uploaders))
                    .font(AppTypography.nowShowingTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let until = store.showingUntilCaption(for: photo) {
                    Text(until)
                        .font(AppTypography.secondary)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Nothing on the frame yet")
                    .font(AppTypography.nowShowingTitle)
                    .foregroundStyle(.primary)
                Text("Open a photo and choose Show for Today.")
                    .font(AppTypography.secondary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if os(iOS)
/// Top of the iOS gallery: a small framed render of the device's current photo with its caption.
/// Scrolls away with the grid; tap opens the photo, and dropping a thumbnail here sets it as current.
struct NowShowingCard: View {
    @Environment(GalleryStore.self) private var store
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTargeted = false

    private static let chromeScale: CGFloat = 0.3

    private var framedHeight: CGFloat {
        if verticalSizeClass == .compact { return 88 }
        return horizontalSizeClass == .regular ? 168 : 116
    }

    private var screenAspectRatio: CGFloat {
        PreviewPaneLayout.deviceScreenAspectRatio(
            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
            isLandscape: store.deviceScreenIsLandscape
        )
    }

    var body: some View {
        Button {
            guard !selection.isSelecting, let id = store.currentPhoto?.id else { return }
            selection.openLightbox(id)
        } label: {
            HStack(spacing: 16) {
                miniFrame
                NowShowingCaption()
                if store.currentPhoto != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background {
                let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
                shape.fill(Color(uiColor: .secondarySystemGroupedBackground))
                shape.fill(AppBrandColor.accentGreen.opacity(colorScheme == .dark ? 0.22 : 0.12))
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppBrandColor.accentGreen, lineWidth: 3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(store.currentPhoto == nil ? "" : "Opens the photo")
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            Task { await store.setAsCurrent(photoID: id) }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private var miniFrame: some View {
        let screenW = DevicePreviewChrome.screenWidth(
            for: CGSize(width: .greatestFiniteMagnitude, height: framedHeight),
            screenAspectRatio: screenAspectRatio,
            minScreenWidth: 40,
            chromeScale: Self.chromeScale
        )
        return DevicePreviewFramed(
            screenWidth: screenW,
            screenAspectRatio: screenAspectRatio,
            chromeScale: Self.chromeScale
        ) {
            DeviceScreenContent(photoID: store.currentPhoto?.id, maxPixelSize: 480)
        }
    }
}
#endif
