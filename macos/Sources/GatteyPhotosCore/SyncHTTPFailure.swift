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
        guard let data = text.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let keys = ["error", "message", "detail", "title", "description"]
        for key in keys {
            if let value = obj[key] as? String, !value.isEmpty {
                return value
            }
        }
        if let nested = obj["error"] as? [String: Any] {
            for key in ["message", "detail"] {
                if let value = nested[key] as? String, !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    private static func stripHTMLTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func redactSecrets(in text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?i)Bearer\s+\S+"#,
            with: "Bearer [redacted]",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)(authorization|token|password|secret)\s*[:=]\s*\S+"#,
            with: "$1 [redacted]",
            options: .regularExpression
        )
        return result
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }

    private static func formatByteCount(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
