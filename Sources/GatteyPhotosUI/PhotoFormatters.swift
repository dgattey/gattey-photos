import Foundation
import GatteyPhotosCore

@MainActor
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

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let showingShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yy"
        return f
    }()

    private static var updatedAtCache: [String: String] = [:]
    private static var deviceRegisteredAtCache: [String: String] = [:]
    private static var deviceLastPushAtCache: [String: String] = [:]

    static func updatedAt(_ iso: String) -> String {
        if let hit = updatedAtCache[iso] { return hit }
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        let formatted = date.map { display.string(from: $0) } ?? iso
        if updatedAtCache.count > 512 { updatedAtCache.removeAll(keepingCapacity: true) }
        updatedAtCache[iso] = formatted
        return formatted
    }

    static func deviceRegisteredAt(_ iso: String, registeredBy: String? = nil) -> String {
        let by = (registeredBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "\(iso)|\(by)"
        if let hit = deviceRegisteredAtCache[cacheKey] { return hit }
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        let knownOwner = (!by.isEmpty && by.caseInsensitiveCompare("Unknown") != .orderedSame) ? by : nil
        let formatted: String
        if let date {
            if let knownOwner {
                formatted = "Added \(dateOnly.string(from: date)) by \(knownOwner)"
            } else {
                formatted = "Added \(dateOnly.string(from: date))"
            }
        } else if let knownOwner {
            formatted = "Added by \(knownOwner)"
        } else {
            formatted = "Date unknown"
        }
        if deviceRegisteredAtCache.count > 128 { deviceRegisteredAtCache.removeAll(keepingCapacity: true) }
        deviceRegisteredAtCache[cacheKey] = formatted
        return formatted
    }

    static func deviceLastPushAt(_ iso: String) -> String {
        if let hit = deviceLastPushAtCache[iso] { return hit }
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        let formatted = date.map { "Last push \(display.string(from: $0))" } ?? "Last push unknown"
        if deviceLastPushAtCache.count > 128 { deviceLastPushAtCache.removeAll(keepingCapacity: true) }
        deviceLastPushAtCache[iso] = formatted
        return formatted
    }

    static func addedBy(_ photo: PhotoEntry, uploaders: [UploaderID: String]) -> String {
        let raw = uploaders[photo.uploaderId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name =
            (!raw.isEmpty && raw.caseInsensitiveCompare("Unknown") != .orderedSame)
            ? raw
            : defaultUploaderDisplayName
        return "Added by \(name)"
    }

    /// Corner badge text for the photo the server is currently showing (shared so grid styling can't drift).
    static let showingTodayTag = "Showing for today"

    /// Upcoming slot start date for a non-current photo. Date only; the live current photo uses
    /// `showingTodayTag` instead, since the schedule can predict a slot before the cron actually advances.
    static func showingStartDate(_ start: Date) -> String {
        showingShort.string(from: start)
    }

    /// Rotation end for the device's current photo: `Until today`, `Until tomorrow`, or `Until 10/22/26`.
    static func showingUntil(_ until: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        let untilDay = calendar.startOfDay(for: until)
        let today = calendar.startOfDay(for: now)
        if untilDay == today {
            return "Until today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
            untilDay == calendar.startOfDay(for: tomorrow)
        {
            return "Until tomorrow"
        }
        return "Until \(showingShort.string(from: until))"
    }
}
