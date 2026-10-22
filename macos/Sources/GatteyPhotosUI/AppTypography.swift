import SwiftUI

/// Semantic text styles: system text styles where possible; serif matches app icon (Georgia).
enum AppTypography {
    /// Section labels (e.g. selection bar count).
    static let sectionTitle: Font = .headline
    /// Secondary supporting text.
    static let secondary: Font = .subheadline
    /// Small badges on thumbnails.
    static let thumbBadge: Font = .caption2.weight(.semibold)
    /// Small uppercase label above a title (e.g. "Now Showing"). Pair with `.textCase(.uppercase)`.
    static let eyebrow: Font = .caption.weight(.semibold)

    /// Brand title: unlock welcome and the macOS gallery pane.
    #if os(iOS)
    static let primaryTitle: Font = .system(.largeTitle, design: .serif).weight(.bold)
    #else
    static let primaryTitle: Font = .system(size: 34, weight: .bold, design: .serif)
    #endif

    /// "Added by …" under the Now Showing eyebrow.
    #if os(iOS)
    static let nowShowingTitle: Font = .system(.title3, design: .serif).weight(.semibold)
    #else
    static let nowShowingTitle: Font = .system(size: 20, weight: .semibold, design: .serif)
    #endif

    /// Lightbox inspector "Added by …" (iPad and macOS).
    #if os(iOS)
    static let lightboxTitle: Font = .system(.title, design: .serif).weight(.bold)
    #else
    static let lightboxTitle: Font = .system(size: 26, weight: .bold, design: .serif)
    #endif

    #if os(macOS)
    /// Photo count in the leading unified-toolbar slot.
    static let toolbarTitle: Font = .headline.weight(.semibold)
    #endif

    /// Unlock supporting line.
    #if os(iOS)
    static let unlockSubtitle: Font = .body
    #else
    static let unlockSubtitle: Font = .title3
    #endif
}
