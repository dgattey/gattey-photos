#if os(iOS)
import SwiftUI

/// Centers readable content on iPad regular width without stretching phone-sized columns.
enum IOSContentWidth {
    static let unlockRegularMax: CGFloat = 920
    static let unlockCompactHorizontalPadding: CGFloat = 20
    /// Welcome device preview on iPhone (compact) so the form stays visible with less scroll.
    static let unlockCompactWelcomePhotoMaxHeight: CGFloat = 220
    static let previewPaneMax: CGFloat = 440
}
#endif
