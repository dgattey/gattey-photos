import GatteyPhotosCore
import SwiftUI

struct PhotoLightboxView: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isFocused: Bool
    let photoID: PhotoID

    private static let sideColumnPreferredWidth: CGFloat = 400
    private static let sideBySideClusterSpacing: CGFloat = 44
    private static let lightboxAttributionBlockSpacing: CGFloat = 16
    private static let lightboxAttributionInnerSpacing: CGFloat = 6
    private static let macOSSideColumnMinWidth: CGFloat = 640

    private var photo: PhotoEntry? {
        store.state.photos[photoID]
    }

    var body: some View {
        Group {
            if let photo {
                lightboxContent(photo: photo)
            } else {
                ContentUnavailableView("Photo unavailable", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .galleryLightboxCrossFade()
        .background {
            PushedDetailBackground()
        }
        #if os(macOS)
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .modifier(LightboxMacOSToolbarTitleRemoval())
        #else
        .navigationTitle(photo?.filename ?? "Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    @ViewBuilder
    private func lightboxContent(photo: PhotoEntry) -> some View {
        // GeometryReader must expand inside NavigationStack destinations; otherwise it
        // collapses to zero and the hero Image shows macOS's broken-image caution icon.
        GeometryReader { geo in
            let sideBySide = usesSideColumn(forWidth: geo.size.width)
            Group {
                if sideBySide {
                    lightboxSideBySideLayout(photo: photo, geo: geo)
                } else {
                    VStack(spacing: 0) {
                        lightboxHeroImage(photo: photo, sideBySide: false)
                            .frame(width: geo.size.width, height: max(240, geo.size.height * 0.62))
                        lightboxDetailsColumn(photo: photo, sideBySide: false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .ignoresSafeArea(edges: .top)
        #endif
    }

    @ViewBuilder
    private func lightboxSideBySideLayout(photo: PhotoEntry, geo: GeometryProxy) -> some View {
        let heroMaxHeight = lightboxHeroMaxHeight(in: geo)
        #if os(macOS)
        HStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: Self.sideBySideClusterSpacing) {
                lightboxDetailsColumn(
                    photo: photo,
                    sideBySide: true,
                    clusterHeight: heroMaxHeight
                )
                .frame(width: Self.sideColumnPreferredWidth)
                .frame(maxHeight: heroMaxHeight, alignment: .center)
                .zIndex(1)
                lightboxHeroImage(photo: photo, sideBySide: true)
                    .frame(maxHeight: heroMaxHeight, alignment: .trailing)
                    .ignoresSafeArea(edges: .top)
                    .zIndex(0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        #else
        HStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: Self.sideBySideClusterSpacing) {
                lightboxDetailsColumn(
                    photo: photo,
                    sideBySide: true,
                    clusterHeight: heroMaxHeight
                )
                .frame(width: Self.sideColumnPreferredWidth)
                .frame(maxHeight: heroMaxHeight, alignment: .center)
                lightboxHeroImage(photo: photo, sideBySide: true)
                    .frame(maxHeight: heroMaxHeight, alignment: .center)
            }
            .fixedSize(horizontal: true, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        #endif
    }

    /// Max hero height for side-by-side; width follows photo aspect ratio inside the hero container.
    private func lightboxHeroMaxHeight(in geo: GeometryProxy) -> CGFloat {
        #if os(macOS)
        max(0, geo.size.height + geo.safeAreaInsets.top)
        #else
        max(0, geo.size.height)
        #endif
    }

    private var lightboxHeroAspectRatio: CGFloat {
        let r = store.deviceScreenAspectRatio
        return r > 0 ? min(r, 1) : Bloomin8Screen.defaultAspectRatio
    }

    private func usesSideColumn(forWidth width: CGFloat) -> Bool {
        #if os(macOS)
        return width >= Self.macOSSideColumnMinWidth
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    private func lightboxHeroImage(photo: PhotoEntry, sideBySide: Bool) -> some View {
        CachedPhotoImage(
            photoID: photo.id,
            maxPixelSize: 4096,
            contentMode: .fit,
            showsLoadingSpinner: true
        )
        .aspectRatio(lightboxHeroAspectRatio, contentMode: .fit)
        .frame(maxHeight: sideBySide ? .infinity : nil)
        .clipped()
        .animation(nil, value: photo.id)
        .padding(sideBySide ? lightboxHeroPaddingWide : lightboxHeroPaddingCompact)
        .modifier(LightboxHeroWidthModifier(
            expandsHorizontally: !sideBySide,
            horizontalAlignment: lightboxHeroHorizontalAlignment(sideBySide: sideBySide)
        ))
        .allowsHitTesting(false)
        .focusable(false)
        #if os(macOS)
        .ignoresSafeArea(edges: .top)
        #endif
    }

    private func lightboxHeroHorizontalAlignment(sideBySide: Bool) -> HorizontalAlignment {
        #if os(macOS)
        sideBySide ? .trailing : .center
        #else
        .center
        #endif
    }

    private var lightboxHeroPaddingWide: EdgeInsets {
        #if os(macOS)
        EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        #else
        EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 40)
        #endif
    }

    private var lightboxHeroPaddingCompact: EdgeInsets {
        #if os(macOS)
        EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20)
        #else
        EdgeInsets(top: 48, leading: 20, bottom: 12, trailing: 20)
        #endif
    }

    @ViewBuilder
    private func lightboxDetailsColumn(
        photo: PhotoEntry,
        sideBySide: Bool,
        clusterHeight: CGFloat? = nil
    ) -> some View {
        if sideBySide, let clusterHeight {
            ScrollView {
                lightboxDetailsBody(photo: photo, sideBySide: true)
                    .frame(minHeight: clusterHeight, alignment: .center)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: clusterHeight)
            .focusEffectDisabled()
        } else {
            ScrollView {
                lightboxDetailsBody(photo: photo, sideBySide: false)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .focusEffectDisabled()
        }
    }

    private func lightboxDetailsBody(photo: PhotoEntry, sideBySide: Bool) -> some View {
        let metaAlignment: HorizontalAlignment = sideBySide ? .trailing : .leading
        let textAlignment: TextAlignment = sideBySide ? .trailing : .leading
        return VStack(alignment: metaAlignment, spacing: 20) {
                VStack(alignment: metaAlignment, spacing: Self.lightboxAttributionBlockSpacing) {
                    VStack(alignment: metaAlignment, spacing: Self.lightboxAttributionInnerSpacing) {
                        Text(PhotoFormatters.addedBy(photo))
                            .font(AppTypography.lightboxAttribution)
                            .multilineTextAlignment(textAlignment)
                        if let showingUntil = store.lightboxShowingUntilCaption(for: photo) {
                            Text(showingUntil)
                                .font(AppTypography.lightboxMeta)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(textAlignment)
                        }
                    }
                    Text(photo.filename)
                        .font(AppTypography.lightboxFilename)
                        .multilineTextAlignment(textAlignment)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(
                            maxWidth: sideBySide ? Self.sideColumnPreferredWidth : .infinity,
                            alignment: sideBySide ? .trailing : .leading
                        )
                    Text("Updated \(PhotoFormatters.updatedAt(photo.updatedAt))")
                        .font(AppTypography.lightboxMeta)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(textAlignment)
                }

                VStack(alignment: metaAlignment, spacing: 6) {
                    Button {
                        Task { await store.setAsCurrent(photoID: photo.id) }
                    } label: {
                        Text(lightboxShowTodayButtonLabel(for: photo))
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .galleryPrimaryButtonStyle()
                    .galleryFullWidthButtonLayout(minHeight: 56)
                    #if os(macOS)
                    .controlSize(.large)
                    #endif
                    .disabled(store.isBusy || !store.canSetAsCurrent(photoID: photo.id))
                    .opacity(lightboxShowTodayButtonOpacity(for: photo))

                    HStack(spacing: 12) {
                        Button {
                            Task { await store.downloadPhoto(photo) }
                        } label: {
                            Text("Download")
                                .frame(maxWidth: .infinity)
                        }
                        .galleryBorderedButtonStyle()
                        .frame(maxWidth: .infinity, minHeight: 42)
                        #if os(macOS)
                        .controlSize(.regular)
                        #endif
                        .disabled(store.isBusy)

                        Button {
                            galleryDeleteRequest?(Set([photo.id]))
                        } label: {
                            Text("Delete")
                                .frame(maxWidth: .infinity)
                        }
                        .galleryDestructiveButtonStyle()
                        .frame(maxWidth: .infinity, minHeight: 42)
                        #if os(macOS)
                        .controlSize(.regular)
                        #endif
                        .disabled(store.isBusy || !store.canDeletePhotos(ids: [photo.id]))
                        .galleryDestructiveChromeOpacity(
                            isEnabled: !store.isBusy && store.canDeletePhotos(ids: [photo.id])
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: sideBySide ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: sideBySide ? .trailing : .leading)
            .padding(lightboxDetailsPadding(sideBySide: sideBySide))
            #if os(macOS)
            .animation(nil, value: photo.id)
            #endif
    }

    private func lightboxShowTodayButtonLabel(for photo: PhotoEntry) -> String {
        if store.canSetAsCurrent(photoID: photo.id) {
            return "Show for today"
        }
        return store.lightboxShowingUntilCaption(for: photo) ?? "Show for today"
    }

    private func lightboxShowTodayButtonOpacity(for photo: PhotoEntry) -> Double {
        if store.canSetAsCurrent(photoID: photo.id) && !store.isBusy {
            return 1
        }
        if !store.canSetAsCurrent(photoID: photo.id) {
            return 1
        }
        return 0.45
    }

    private func lightboxDetailsPadding(sideBySide: Bool) -> EdgeInsets {
        if sideBySide {
            return EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 0)
        }
        return EdgeInsets(top: 0, leading: 20, bottom: 28, trailing: 20)
    }
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
