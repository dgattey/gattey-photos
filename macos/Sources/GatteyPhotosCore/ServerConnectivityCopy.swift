import Foundation

public enum ServerConnectivityCopy {
    /// User-facing message when the sync server cannot be reached.
    public static func serverDown(at baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "your server" : trimmed
        return "Looks like the server is down (\(label)). Please try again."
    }
}
