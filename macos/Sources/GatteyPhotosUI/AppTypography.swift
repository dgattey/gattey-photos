import SwiftUI

/// Semantic text styles: system text styles where possible; serif matches app icon (Georgia).
enum AppTypography {
    /// Section labels (e.g. "Current", selection bar).
    static let sectionTitle: Font = .headline
    /// Secondary supporting text.
    static let secondary: Font = .subheadline
    /// Small badges on thumbnails.
    static let thumbBadge: Font = .caption.weight(.semibold)
    /// Device preview hover badge on the e-ink opening (larger than grid thumb badges).
    static let devicePreviewHoverBadge: Font = .system(size: 17, weight: .semibold)

    /// Primary app title — unlock welcome (serif matches app icon).
    /// Sized above `.largeTitle` (~38pt) on macOS; semantic on iOS so iPad Dynamic Type stays sane.
    #if os(iOS)
    static let primaryTitle: Font = .system(.largeTitle, design: .serif).weight(.bold)
    #else
    static let primaryTitle: Font = .system(size: 38, weight: .bold, design: .serif)
    #endif
    /// Logged-in toolbar title — standard sans on macOS; serif on iOS principal toolbar.
    #if os(iOS)
    static let toolbarTitle: Font = .system(.title2, design: .serif).weight(.bold)
    #else
    static let toolbarTitle: Font = .headline.weight(.semibold)
    /// Photo count under the macOS leading toolbar title.
    static let toolbarSubtitle: Font = .caption
    #endif
    /// Unlock supporting line — readable, not caption-sized.
    static let unlockSubtitle: Font = .title3
    /// Form labels and inline errors on unlock.
    static let unlockBody: Font = .body

    /// Lightbox "Added by …" — serif matches unlock welcome.
    #if os(iOS)
    static let lightboxAttribution: Font = .system(.title2, design: .serif).weight(.semibold)
    #else
    static let lightboxAttribution: Font = .system(size: 36, weight: .semibold, design: .serif)
    #endif
    /// Lightbox / legacy device preview serif caption (`devicePreviewCaption(for:)`).
    #if os(iOS)
    static let devicePreviewCaption: Font = .system(.title2, design: .serif).weight(.semibold)
    #else
    static let devicePreviewCaption: Font = .system(size: 28, weight: .semibold, design: .serif)
    #endif
    /// Lightbox filename under attribution.
    static let lightboxFilename: Font = .title2.weight(.semibold)
    /// Lightbox supporting line (e.g. updated date).
    static let lightboxMeta: Font = .title3
}
