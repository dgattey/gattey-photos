import Foundation

/// Parses Bloomin8 setup text pasted from the device app or OpenClaw skill output.
public enum Bloomin8TokenParser: Sendable {
    private static let hexScalars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

    /// Returns the device API token, or nil if the input does not contain a recognizable token.
    public static func parseToken(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for line in trimmed.components(separatedBy: .newlines) {
            let lineTrim = line.trimmingCharacters(in: .whitespaces)
            if let value = valueAfterLabel("Token:", in: lineTrim), looksLikeToken(value) {
                return value
            }
        }

        let collapsed = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !isSetupHeaderLine($0) }
            .joined()

        if looksLikeToken(collapsed) {
            return collapsed
        }

        if looksLikeToken(trimmed) {
            return trimmed
        }

        return nil
    }

    /// Cosmetic label from a `Device:` line (text before `|` if present).
    public static func parseDeviceName(from text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let lineTrim = line.trimmingCharacters(in: .whitespaces)
            guard let raw = valueAfterLabel("Device:", in: lineTrim), !raw.isEmpty else { continue }
            let name = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? raw
            return name.isEmpty ? nil : name
        }
        return nil
    }

    public static func looksLikeToken(_ value: String) -> Bool {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.contains(".") else { return false }
        let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count >= 8, parts[1].count >= 32 else { return false }
        return parts[0].unicodeScalars.allSatisfy { hexScalars.contains($0) }
            && parts[1].unicodeScalars.allSatisfy { hexScalars.contains($0) }
    }

    private static func valueAfterLabel(_ label: String, in line: String) -> String? {
        let lower = line.lowercased()
        let labelLower = label.lowercased()
        guard lower.hasPrefix(labelLower) else { return nil }
        return String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func isSetupHeaderLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.hasPrefix("device:") || lower.hasPrefix("token:") || lower.hasPrefix("interval:") {
            return true
        }
        return lower.contains("bloomin8") && lower.contains("token")
    }
}
