import SwiftUI

#if os(macOS)
import AppKit
#endif

struct GridTapModifiers {
    var append: Bool
    var rangeSelect: Bool

    #if os(iOS)
    /// Select mode taps toggle one photo in or out, like Photos.
    static let selectModeToggle = GridTapModifiers(append: true, rangeSelect: false)
    #endif
}

#if os(macOS)
extension GridTapModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        append = flags.contains(.command)
        rangeSelect = flags.contains(.shift)
    }
}
#endif
