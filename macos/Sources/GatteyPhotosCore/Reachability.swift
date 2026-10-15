import Foundation

public enum Reachability {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 2
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    public static func pingServer(baseURL: String) async -> Bool {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed) else { return false }
        if await probeHealth(base: parsed) { return true }
        if let alt = alternateLoopbackURL(from: parsed) {
            return await probeHealth(base: alt)
        }
        return false
    }

    private static func healthURL(base: URL) -> URL? {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        parts.path = "/api/health"
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }

    private static func probeHealth(base: URL) async -> Bool {
        guard let url = healthURL(base: base) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 2
        do {
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse, http.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                json["ok"] as? Bool == true
            else { return false }
            return true
        } catch {
            return false
        }
    }

    private static func alternateLoopbackURL(from url: URL) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        if parts.host == "127.0.0.1" {
            parts.host = "localhost"
        } else if parts.host == "localhost" {
            parts.host = "127.0.0.1"
        } else {
            return nil
        }
        return parts.url
    }
}
