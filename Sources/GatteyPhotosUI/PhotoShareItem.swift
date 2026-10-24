import Foundation

#if os(iOS)
/// Identifiable wrapper for UIKit share sheet presentation.
public struct PhotoShareItem: Identifiable {
    public let id = UUID()
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
#endif
