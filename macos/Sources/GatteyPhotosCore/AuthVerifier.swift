import Foundation

public enum AuthVerifyOutcome: Sendable {
    case ok
    case unauthorized
    case unreachable
}

public enum AuthVerifier {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Verifies Bearer auth against `GET /api/auth/verify`. Uses `bearer` when set, else `settings.syncSessionToken`.
    public static func verify(settings: AppSettings, bearer: String? = nil) async -> AuthVerifyOutcome {
        let trimmedURL = settings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = (bearer ?? settings.syncBearer)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedURL.isEmpty, !token.isEmpty else {
            return .unauthorized
        }
        guard let base = URL(string: trimmedURL) else {
            return .unreachable
        }
        if let outcome = await probeVerify(base: base, bearer: token) {
            return outcome
        }
        if let alt = alternateLoopbackURL(from: base),
           let outcome = await probeVerify(base: alt, bearer: token) {
            return outcome
        }
        return .unreachable
    }

    public enum CreateSessionOutcome: Sendable {
        case success(String)
        case wrongPassword
        case unreachable
    }

    /// `POST /api/auth/session` with password Bearer; returns opaque session token on success.
    public static func createSession(password: String, settings: AppSettings) async -> CreateSessionOutcome {
        let trimmedURL = settings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedPassword.isEmpty,
              let base = URL(string: trimmedURL) else {
            return .unreachable
        }
        switch await probeCreateSession(base: base, password: trimmedPassword) {
        case .success(let token):
            return .success(token)
        case .wrongPassword:
            return .wrongPassword
        case .unreachable:
            break
        }
        if let alt = alternateLoopbackURL(from: base) {
            switch await probeCreateSession(base: alt, password: trimmedPassword) {
            case .success(let token):
                return .success(token)
            case .wrongPassword:
                return .wrongPassword
            case .unreachable:
                break
            }
        }
        return .unreachable
    }

    private static func verifyURL(base: URL) -> URL? {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        parts.path = "/api/auth/verify"
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }

    private static func sessionURL(base: URL) -> URL? {
        guard var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        parts.path = "/api/auth/session"
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }

    private static func probeVerify(base: URL, bearer: String) async -> AuthVerifyOutcome? {
        guard let url = verifyURL(base: base) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        do {
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse else { return .unreachable }
            if http.statusCode == 401 {
                return .unauthorized
            }
            if http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["ok"] as? Bool == true {
                return .ok
            }
            if (200...299).contains(http.statusCode) {
                return .unauthorized
            }
            return .unreachable
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                return .unreachable
            }
            return .unreachable
        }
    }

    private enum ProbeCreateSessionResult {
        case success(String)
        case wrongPassword
        case unreachable
    }

    private static func probeCreateSession(base: URL, password: String) async -> ProbeCreateSessionResult {
        guard let url = sessionURL(base: base) else { return .unreachable }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(password)", forHTTPHeaderField: "Authorization")
        do {
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse else { return .unreachable }
            if http.statusCode == 401 {
                return .wrongPassword
            }
            guard http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true,
                  let token = json["sessionToken"] as? String,
                  !token.isEmpty else {
                return .unreachable
            }
            return .success(token)
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                return .unreachable
            }
            return .unreachable
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
