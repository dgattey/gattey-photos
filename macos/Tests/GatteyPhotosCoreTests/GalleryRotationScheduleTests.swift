import XCTest
@testable import GatteyPhotosCore

final class GalleryRotationScheduleTests: XCTestCase {
    private var calendar: Calendar { GalleryRotationSchedule.utcCalendar }

    func testNextDailyUTCBoundarySameDay() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 1
        comps.hour = 10
        comps.minute = 0
        let now = try XCTUnwrap(calendar.date(from: comps))
        let next = GalleryRotationSchedule.nextDailyUTCBoundary(after: now, hour: 11, minute: 0, calendar: calendar)
        var expected = comps
        expected.hour = 11
        let expectedDate = try XCTUnwrap(calendar.date(from: expected))
        XCTAssertEqual(next, expectedDate)
    }

    func testNextDailyUTCBoundaryRollsToTomorrow() throws {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 1
        comps.hour = 12
        let now = try XCTUnwrap(calendar.date(from: comps))
        let next = GalleryRotationSchedule.nextDailyUTCBoundary(after: now, hour: 11, minute: 0, calendar: calendar)
        var tomorrow = comps
        tomorrow.day = 2
        tomorrow.hour = 11
        tomorrow.minute = 0
        let expected = try XCTUnwrap(calendar.date(from: tomorrow))
        XCTAssertEqual(next, expected)
    }

    func testPlanStaggersShowingStarts() throws {
        let order = ["a", "b", "c"]
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 1
        comps.hour = 10
        let now = try XCTUnwrap(calendar.date(from: comps))
        let plan = try XCTUnwrap(
            GalleryRotationSchedule.plan(
                activeOrder: order,
                currentPhotoID: "a",
                now: now,
                kind: .productionDailyUTC,
                calendar: calendar
            )
        )
        let next = plan.nextCron
        XCTAssertEqual(plan.currentShowingUntil, next)
        XCTAssertEqual(plan.showingStartByPhotoID["a"], next.addingTimeInterval(-86_400))
        XCTAssertEqual(plan.showingStartByPhotoID["b"], next)
        XCTAssertEqual(plan.showingStartByPhotoID["c"], next.addingTimeInterval(86_400))
    }

    func testDebugIntervalNextCron() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let next = GalleryRotationSchedule.nextBoundary(
            after: now,
            kind: .debugInterval(seconds: 1800)
        )
        XCTAssertEqual(next.timeIntervalSince1970, now.timeIntervalSince1970 + 1800, accuracy: 0.001)
    }
}
