import Foundation

/// Shared HTTP session for gallery sync. Fails promptly when the network or server is down
/// instead of waiting on `URLSession.shared`'s default connectivity wait.
public enum SyncURLSession {
    public static let requestTimeout: TimeInterval = 12
    public static let resourceTimeout: TimeInterval = 180

    public static func makeConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        return config
    }

    public static let shared = URLSession(configuration: makeConfiguration())
}
