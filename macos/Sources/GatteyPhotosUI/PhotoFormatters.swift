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

    private static let cacheLock = NSLock()
    private static var updatedAtCache: [String: String] = [:]
    private static var deviceRegisteredAtCache: [String: String] = [:]
    private static var deviceLastPushAtCache: [String: String] = [:]

    static func updatedAt(_ iso: String) -> String {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = updatedAtCache[iso] { return hit }
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        let formatted = date.map { display.string(from: $0) } ?? iso
        if updatedAtCache.count > 512 { updatedAtCache.removeAll(keepingCapacity: true) }
        updatedAtCache[iso] = formatted
        return formatted
    }

    static func deviceRegisteredAt(_ iso: String) -> String {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = deviceRegisteredAtCache[iso] { return hit }
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        let formatted = date.map { "Added \(dateOnly.string(from: $0))" } ?? "Date unknown"
        if deviceRegisteredAtCache.count > 128 { deviceRegisteredAtCache.removeAll(keepingCapacity: true) }
        deviceRegisteredAtCache[iso] = formatted
        return formatted
    }

    static func deviceLastPushAt(_ iso: String) -> String {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = deviceLastPushAtCache[iso] { return hit }
        let date = isoWithFraction.date(from: iso) ?? isoPlain.date(from: iso)
        let formatted = date.map { "Last push \(display.string(from: $0))" } ?? "Last push unknown"
        if deviceLastPushAtCache.count > 128 { deviceLastPushAtCache.removeAll(keepingCapacity: true) }
        deviceLastPushAtCache[iso] = formatted
        return formatted
    }

    static func addedBy(_ photo: PhotoEntry, uploaders: [UploaderID: String]) -> String {
        let raw = uploaders[photo.uploaderId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = raw.isEmpty ? defaultUploaderDisplayName : raw
        return "Added by \(name)"
    }

    /// Corner badge text for the photo the server is currently showing (shared so grid styling can't drift).
    static let showingTodayTag = "Showing for today"

    /// Upcoming slot start date for a non-current photo. Date only; the live current photo uses
    /// `showingTodayTag` instead, since the schedule can predict a slot before the cron actually advances.
    static func showingStartDate(_ start: Date) -> String {
        showingShort.string(from: start)
    }

    static func showingUntil(_ until: Date) -> String {
        "Showing until \(showingShort.string(from: until))"
    }

    /// Device preview hover: `Added by Dylan / until tomorrow` (single line, `/` separator).
    static func addedByUntilFriendly(
        photo: PhotoEntry,
        until: Date,
        uploaders: [UploaderID: String],
        calendar: Calendar = .current
    ) -> String {
        "\(addedBy(photo, uploaders: uploaders)) / \(untilFriendlyPhrase(until: until, calendar: calendar))"
    }

    private static func untilFriendlyPhrase(until: Date, calendar: Calendar) -> String {
        let untilDay = calendar.startOfDay(for: until)
        let today = calendar.startOfDay(for: Date())
        if untilDay == today {
            return "until today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           untilDay == calendar.startOfDay(for: tomorrow)
        {
            return "until tomorrow"
        }
        return "until \(showingShort.string(from: until))"
    }
}
