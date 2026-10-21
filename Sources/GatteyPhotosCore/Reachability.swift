import DylCore
import Foundation

public enum Reachability {
    public static let probeTimeout: TimeInterval = 2

    public static func pingServer(baseURL: String, session: URLSession = .sync) async -> Bool {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed) else { return false }
        if await probeHealth(base: parsed, session: session) { return true }
        if let alt = alternateLoopbackURL(from: parsed) {
            return await probeHealth(base: alt, session: session)
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

    private static func probeHealth(base: URL, session: URLSession) async -> Bool {
        guard let url = healthURL(base: base) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = probeTimeout
        do {
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse, http.statusCode == 200 else { return false }
            return JSONDecoder().decodeOrLog(ServerAck.self, from: data)?.ok == true
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
