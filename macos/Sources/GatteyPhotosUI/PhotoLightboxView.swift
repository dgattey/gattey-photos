import GatteyPhotosCore
import SwiftUI

/// Photo detail: the photo is the hero. iPhone pairs it with a bottom toolbar; iPad and Mac add a
/// trailing details column with attribution, schedule status, and actions.
struct PhotoLightboxView: View {
    @Environment(GalleryStore.self) private var store
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @FocusState private var isFocused: Bool
    let photoID: PhotoID

    private static let detailsColumnMaxWidth: CGFloat = 360
    private static let detailsColumnMinWidth: CGFloat = 280

    private var photo: PhotoEntry? {
        store.state.photos[photoID]
    }

    /// Trailing details column width: roughly a third of the window, clamped so text never gets cramped.
    static func detailsColumnWidth(forContainerWidth width: CGFloat) -> CGFloat {
        min(detailsColumnMaxWidth, max(detailsColumnMinWidth, floor(width * 0.3)))
    }

    private var usesDetailsColumn: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        Group {
            if let photo {
                if usesDetailsColumn {
                    detailsColumnLayout(photo: photo)
                } else {
                    heroImage(photo: photo)
                }
            } else {
                ContentUnavailableView("Photo Unavailable", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .galleryLightboxCrossFade()
        .background {
            PushedDetailBackground()
        }
        #if os(macOS)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Back", systemImage: "chevron.backward") {
                    store.selection.closeLightbox()
                }
                .help("Back to gallery")
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .modifier(LightboxMacOSToolbarTitleRemoval())
        #else
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let photo, !usesDetailsColumn {
                ToolbarItem(placement: .principal) {
                    titleStack(photo: photo)
                }
                phoneBottomBar(photo: photo)
            }
        }
        #endif
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            store.selection.commitLightboxPresentation(photoID)
        }
        .onDisappear { isFocused = false }
        .onKeyPress(.escape) {
            store.selection.closeLightbox()
            return .handled
        }
        .galleryLightboxArrowKeyboard()
        #if os(macOS)
        .onExitCommand { store.selection.closeLightbox() }
        #endif
    }

    // MARK: - Hero

    private func heroImage(photo: PhotoEntry) -> some View {
        CachedPhotoImage(
            photoID: photo.id,
            maxPixelSize: 4096,
            contentMode: .fit,
            showsLoadingSpinner: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(nil, value: photo.id)
        .contentShape(Rectangle())
        #if os(iOS)
        .gesture(swipeToNavigate)
        #endif
        .focusable(false)
        .accessibilityLabel(PhotoFormatters.addedBy(photo, uploaders: store.state.uploaders))
    }

    #if os(iOS)
    private var swipeToNavigate: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) else { return }
                withAnimation(AppAnimation.smooth) {
                    _ = store.selection.navigateLightbox(
                        by: dx < 0 ? 1 : -1,
                        photoOrder: store.activePhotoIDs
                    )
                }
            }
    }
    #endif

    // MARK: - iPad / Mac details column

    private func detailsColumnLayout(photo: PhotoEntry) -> some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                heroImage(photo: photo)
                    .padding(24)
                ScrollView {
                    detailsColumn(photo: photo)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .frame(minHeight: geo.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .frame(width: Self.detailsColumnWidth(forContainerWidth: geo.size.width))
            }
        }
    }

    private func detailsColumn(photo: PhotoEntry) -> some View {
        let isCurrent = store.state.currentPhotoId == photo.id
        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                if isCurrent {
                    nowShowingChip(photo: photo)
                }
                Text(PhotoFormatters.addedBy(photo, uploaders: store.state.uploaders))
                    .font(AppTypography.lightboxTitle)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.filename)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Updated \(PhotoFormatters.updatedAt(photo.updatedAt))")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                if !isCurrent {
                    Button {
                        Task { await store.setAsCurrent(photoID: photo.id) }
                    } label: {
                        Label("Show for Today", systemImage: "photo.artframe")
                            .frame(maxWidth: .infinity)
                    }
                    .galleryPrimaryButtonStyle()
                    .disabled(store.isBusy || !store.canSetAsCurrent(photoID: photo.id))
                }
                HStack(spacing: 10) {
                    Button {
                        Task { await store.downloadPhoto(photo) }
                    } label: {
                        Label(Self.downloadTitle, systemImage: Self.downloadSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .galleryBorderedButtonStyle()
                    .disabled(store.isBusy)

                    Button(role: .destructive) {
                        galleryDeleteRequest?(Set([photo.id]))
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .galleryDestructiveButtonStyle()
                    .disabled(!canDelete(photo))
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(macOS)
        .animation(nil, value: photo.id)
        #endif
    }

    private func nowShowingChip(photo: PhotoEntry) -> some View {
        Label(nowShowingText(photo: photo), systemImage: "photo.artframe")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppBrandColor.accentGreen, in: Capsule())
    }

    private func nowShowingText(photo: PhotoEntry) -> String {
        guard let until = store.showingUntilCaption(for: photo) else { return "On the frame" }
        return "On the frame · \(until)"
    }

    private func canDelete(_ photo: PhotoEntry) -> Bool {
        !store.isBusy && store.canDeletePhotos(ids: [photo.id])
    }

    #if os(iOS)
    private static let downloadTitle = "Share"
    private static let downloadSymbol = "square.and.arrow.up"
    #else
    private static let downloadTitle = "Download"
    private static let downloadSymbol = "arrow.down.circle"
    #endif

    // MARK: - iPhone chrome

    #if os(iOS)
    private func titleStack(photo: PhotoEntry) -> some View {
        VStack(spacing: 1) {
            Text(PhotoFormatters.addedBy(photo, uploaders: store.state.uploaders))
                .font(.headline)
            Text(store.showingUntilCaption(for: photo) ?? PhotoFormatters.updatedAt(photo.updatedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }

    @ToolbarContentBuilder
    private func phoneBottomBar(photo: PhotoEntry) -> some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button {
                Task { await store.downloadPhoto(photo) }
            } label: {
                Label(Self.downloadTitle, systemImage: Self.downloadSymbol)
            }
            .disabled(store.isBusy)
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .bottomBar)
        } else {
            ToolbarItem(placement: .bottomBar) { Spacer() }
        }
        ToolbarItem(placement: .bottomBar) {
            if store.canSetAsCurrent(photoID: photo.id) {
                Button {
                    Task { await store.setAsCurrent(photoID: photo.id) }
                } label: {
                    Label("Show for Today", systemImage: "photo.artframe")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy)
            } else {
                Label("On the Frame", systemImage: "photo.artframe")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppBrandColor.accentGreen, in: Capsule())
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.flexible, placement: .bottomBar)
        } else {
            ToolbarItem(placement: .bottomBar) { Spacer() }
        }
        ToolbarItem(placement: .bottomBar) {
            Button(role: .destructive) {
                galleryDeleteRequest?(Set([photo.id]))
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!canDelete(photo))
        }
    }
    #endif
}

#if os(macOS)
private struct LightboxMacOSToolbarTitleRemoval: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
#endif
