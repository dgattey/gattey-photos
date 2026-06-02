import GatteyPhotosCore
import SwiftUI

// MARK: - Whole lightbox cross-fade

/// Opacity fade for the entire pushed `PhotoLightboxView` (background, hero, metadata).
struct GalleryLightboxCrossFadeModifier: ViewModifier {
    @Environment(GallerySelectionStore.self) private var selection
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                opacity = 0
                withAnimation(AppAnimation.bouncy) {
                    opacity = 1
                }
            }
            .onDisappear {
                opacity = 0
            }
            .onChange(of: selection.lightboxNavigationPhotoID) { _, openID in
                guard openID == nil else { return }
                withAnimation(AppAnimation.smooth) {
                    opacity = 0
                }
            }
    }
}

extension View {
    func galleryLightboxCrossFade() -> some View {
        modifier(GalleryLightboxCrossFadeModifier())
    }
}

/// Compact layout: hero fills width. Side-by-side: hero keeps natural width (macOS cluster is trailing-aligned).
struct LightboxHeroWidthModifier: ViewModifier {
    let expandsHorizontally: Bool
    var horizontalAlignment: HorizontalAlignment = .center

    func body(content: Content) -> some View {
        if expandsHorizontally {
            content.frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: Alignment(horizontal: horizontalAlignment, vertical: .center)
            )
        } else {
            content
        }
    }
}
