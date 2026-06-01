import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct GridTapModifiers {
    var append: Bool
    var rangeSelect: Bool

    #if os(iOS)
    /// Touch taps select a single photo; hardware keyboard modifiers are not tracked on iOS yet.
    static var current: GridTapModifiers {
        GridTapModifiers(append: false, rangeSelect: false)
    }
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
