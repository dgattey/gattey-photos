import Foundation

/// Client-side model of when each gallery photo will be on the frame.
/// Production matches `server/vercel.json` (`0 11 * * *` = daily 11:00 UTC).
/// Debug mode uses a configurable interval (local `local-advance-cron.sh`).
public enum GalleryRotationScheduleKind: Sendable, Equatable {
    case productionDailyUTC
    case debugInterval(seconds: Int)
}

public struct GalleryRotationPlan: Sendable, Equatable {
    /// When each active photo’s on-device slot begins (calendar day for daily cron).
    public var showingStartByPhotoID: [PhotoID: Date]
    /// End of the current photo’s slot (next cron boundary).
    public var currentShowingUntil: Date?
    /// Next scheduled advance (cron fire).
    public var nextCron: Date
}

public enum GalleryRotationSchedule {
    /// Matches `server/vercel.json`.
    public static let productionCronHourUTC = 11
    public static let productionCronMinuteUTC = 0

    public static let defaultDebugAdvanceIntervalSeconds = 1800
    public static let minDebugAdvanceIntervalSeconds = 60
    public static let maxDebugAdvanceIntervalSeconds = 86_400

    public static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    public static func kind(
        debugMode: Bool,
        debugAdvanceIntervalSeconds: Int
    ) -> GalleryRotationScheduleKind {
        if debugMode {
            return .debugInterval(seconds: clampedDebugInterval(debugAdvanceIntervalSeconds))
        }
        return .productionDailyUTC
    }

    public static func clampedDebugInterval(_ seconds: Int) -> Int {
        min(max(seconds, minDebugAdvanceIntervalSeconds), maxDebugAdvanceIntervalSeconds)
    }

    public static func plan(
        activeOrder: [PhotoID],
        currentPhotoID: PhotoID?,
        now: Date = Date(),
        kind: GalleryRotationScheduleKind,
        calendar: Calendar = utcCalendar
    ) -> GalleryRotationPlan? {
        guard !activeOrder.isEmpty else { return nil }

        let count = activeOrder.count
        let currentIdx: Int
        if let id = currentPhotoID, let idx = activeOrder.firstIndex(of: id) {
            currentIdx = idx
        } else {
            currentIdx = 0
        }

        let nextCron = nextBoundary(after: now, kind: kind, calendar: calendar)
        let period = periodDuration(kind: kind)

        var showingStartByPhotoID: [PhotoID: Date] = [:]
        var currentUntil: Date?

        for (offset, photoID) in activeOrder.enumerated() {
            let slotsFromCurrent = (offset - currentIdx + count) % count
            let start: Date
            if slotsFromCurrent == 0 {
                start = nextCron.addingTimeInterval(-period)
                currentUntil = nextCron
            } else {
                start = nextCron.addingTimeInterval(period * TimeInterval(slotsFromCurrent - 1))
            }
            showingStartByPhotoID[photoID] = start
        }

        return GalleryRotationPlan(
            showingStartByPhotoID: showingStartByPhotoID,
            currentShowingUntil: currentUntil,
            nextCron: nextCron
        )
    }

    public static func nextBoundary(
        after now: Date,
        kind: GalleryRotationScheduleKind,
        calendar: Calendar = utcCalendar
    ) -> Date {
        switch kind {
        case .productionDailyUTC:
            return nextDailyUTCBoundary(
                after: now,
                hour: productionCronHourUTC,
                minute: productionCronMinuteUTC,
                calendar: calendar
            )
        case .debugInterval(let seconds):
            return now.addingTimeInterval(TimeInterval(seconds))
        }
    }

    public static func periodDuration(kind: GalleryRotationScheduleKind) -> TimeInterval {
        switch kind {
        case .productionDailyUTC:
            86_400
        case .debugInterval(let seconds):
            TimeInterval(seconds)
        }
    }

    /// Next daily fire at `hour`:`minute` UTC strictly after `now`.
    public static func nextDailyUTCBoundary(
        after now: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = utcCalendar
    ) -> Date {
        var day = calendar.dateComponents([.year, .month, .day], from: now)
        day.hour = hour
        day.minute = minute
        day.second = 0
        day.nanosecond = 0
        var candidate = calendar.date(from: day) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86_400)
        }
        return candidate
    }
}
