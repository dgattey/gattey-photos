import SwiftUI

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Text users copy from the Bloomin8 device app, then paste into Settings to register a frame on the server.
enum Bloomin8SetupClipboard {
    static let pasteInstructions = """
    In the Bloomin8 app on your phone, open your frame and copy the full setup block (Device + Token lines). Paste it below to register the frame for the whole family.
    """

    static func copyPasteInstructions() {
        copyToPasteboard(pasteInstructions)
    }

    private static func copyToPasteboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}
