import DylCore
import Foundation

/// Structured HTTP failure for sync API calls (activity log and alerts).
public struct SyncHTTPFailure: Sendable, Equatable {
    public let statusCode: Int
    public let method: String
    public let url: String
    public let responseBody: String
    public let requestBodyBytes: Int?
    /// Operation-specific context, e.g. `upload: IMG_1234.jpg`.
    public let context: String?

    public init(
        statusCode: Int,
        method: String,
        url: String,
        responseBody: String,
        requestBodyBytes: Int? = nil,
        context: String? = nil
    ) {
        self.statusCode = statusCode
        self.method = method
        self.url = url
        self.responseBody = responseBody
        self.requestBodyBytes = requestBodyBytes
        self.context = context
    }

    /// Short line for alerts and `LocalizedError`.
    public var shortSummary: String {
        let body = Self.summarizeResponseBody(responseBody)
        if statusCode < 0 {
            return ServerConnectivityCopy.serverDown(at: url)
        }
        if body.isEmpty {
            return "HTTP \(statusCode)"
        }
        return "HTTP \(statusCode): \(body)"
    }

    /// Multi-line detail for the activity log (no secrets).
    public var activityLogDetail: String {
        var lines: [String] = []
        if statusCode < 0 {
            lines.append(ServerConnectivityCopy.serverDown(at: url))
        } else {
            lines.append("HTTP \(statusCode)")
        }
        lines.append("\(method) \(url)")
        if let context, !context.isEmpty {
            lines.append(context)
        }
        if let requestBodyBytes {
            lines.append("Request size: \(Self.formatByteCount(requestBodyBytes))")
        }
        let bodySummary = Self.summarizeResponseBody(responseBody)
        if !bodySummary.isEmpty {
            lines.append("Response: \(bodySummary)")
        } else if !responseBody.isEmpty {
            lines.append("Response: (\(responseBody.count) bytes, not UTF-8 text)")
        } else {
            lines.append("Response: (empty body)")
        }
        return lines.joined(separator: "\n")
    }

    public static func summarizeResponseBody(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let jsonMessage = extractJSONErrorMessage(from: trimmed) {
            return redactSecrets(in: jsonMessage)
        }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("<!doctype") || lower.hasPrefix("<html") || trimmed.hasPrefix("<") {
            let stripped = stripHTMLTags(trimmed)
            let snippet = redactSecrets(in: stripped)
            if snippet.isEmpty {
                return "(HTML error page, \(trimmed.count) bytes)"
            }
            return truncate(snippet, limit: 400)
        }

        return truncate(redactSecrets(in: trimmed), limit: 600)
    }

    private static func extractJSONErrorMessage(from text: String) -> String? {
        guard text.hasPrefix("{") else { return nil }
        return JSONDecoder().decodeOrLog(JSONErrorBody.self, from: Data(text.utf8))?.firstMessage
    }

    private static func stripHTMLTags(_ html: String) -> String {
        html.replacing(/<[^>]+>/, with: " ")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func redactSecrets(in text: String) -> String {
        text.replacing(/Bearer\s+\S+/.ignoresCase(), with: "Bearer [redacted]")
            .replacing(/(authorization|token|password|secret)\s*[:=]\s*\S+/.ignoresCase()) { match in
                "\(match.output.1) [redacted]"
            }
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }

    private static func formatByteCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// Error JSON from the sync server or the hosting platform in front of it.
private struct JSONErrorBody: Decodable {
    struct Detail: Decodable {
        let message: String?
        let detail: String?
    }

    /// `error` is a plain string from our routes and an object from some proxies.
    enum ErrorField: Decodable {
        case text(String)
        case detail(Detail)

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            do {
                self = .text(try container.decode(String.self))
            } catch DecodingError.typeMismatch {
                self = .detail(try container.decode(Detail.self))
            }
        }

        var text: String? { if case .text(let value) = self { value } else { nil } }
        var detail: Detail? { if case .detail(let value) = self { value } else { nil } }
    }

    let error: ErrorField?
    let message: String?
    let detail: String?
    let title: String?
    let description: String?

    var firstMessage: String? {
        [error?.text, message, detail, title, description, error?.detail?.message, error?.detail?.detail]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }
}
