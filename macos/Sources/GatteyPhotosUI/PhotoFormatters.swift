import Foundation
import GatteyPhotosCore

enum PhotoFormatters {
    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain = ISO8601DateFormatter()

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func updatedAt(_ iso: String) -> String {
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        guard let date else { return iso }
        return display.string(from: date)
    }

    static func addedBy(_ photo: PhotoEntry) -> String {
        let raw = photo.uploadedBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = raw.isEmpty ? "Dylan" : raw
        return "Added by \(name)"
    }
}
