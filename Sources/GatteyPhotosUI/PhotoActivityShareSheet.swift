#if os(iOS)
import SwiftUI
import UIKit

/// Presents a full-size JPEG via the system share sheet (Save to Files, AirDrop, etc.).
struct PhotoActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
