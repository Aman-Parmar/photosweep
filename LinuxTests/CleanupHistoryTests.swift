import Foundation
import XCTest

import PhotoSweepLogic

/// "Freed this month" only ever counts cleanups from the current
/// calendar month, so last month's work never inflates this month.
final class CleanupHistoryTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testSumsEventsInSameMonth() {
        let events = [
            CleanupEvent(date: date(year: 2026, month: 11, day: 3), photosDeleted: 2, bytesFreed: 8_000_000),
            CleanupEvent(date: date(year: 2026, month: 11, day: 17), photosDeleted: 3, bytesFreed: 4_000_000),
        ]
        let total = CleanupHistory.freedThisMonth(
            events: events, now: date(year: 2026, month: 11, day: 18), calendar: calendar)
        XCTAssertEqual(total.photos, 5)
        XCTAssertEqual(total.videos, 0)
        XCTAssertEqual(total.bytes, 12_000_000)
    }

    func testSumsCompressedVideosSeparatelyFromPhotos() {
        let events = [
            CleanupEvent(date: date(year: 2026, month: 11, day: 5), photosDeleted: 0, videosCompressed: 1, bytesFreed: 1_159_000_000),
            CleanupEvent(date: date(year: 2026, month: 11, day: 6), photosDeleted: 2, bytesFreed: 8_000_000),
        ]
        let total = CleanupHistory.freedThisMonth(
            events: events, now: date(year: 2026, month: 11, day: 18), calendar: calendar)
        XCTAssertEqual(total.photos, 2)
        XCTAssertEqual(total.videos, 1)
        XCTAssertEqual(total.bytes, 1_167_000_000)
    }

    func testSumsConvertedLivePhotosSeparatelyFromPhotos() {
        let events = [
            CleanupEvent(date: date(year: 2026, month: 11, day: 5), photosDeleted: 0, livePhotosConverted: 2, bytesFreed: 6_400_000),
            CleanupEvent(date: date(year: 2026, month: 11, day: 6), photosDeleted: 1, bytesFreed: 4_000_000),
        ]
        let total = CleanupHistory.freedThisMonth(
            events: events, now: date(year: 2026, month: 11, day: 18), calendar: calendar)
        XCTAssertEqual(total.photos, 1)
        XCTAssertEqual(total.videos, 0)
        XCTAssertEqual(total.livePhotos, 2)
        XCTAssertEqual(total.bytes, 10_400_000)
    }

    func testIgnoresOtherMonthsAndYears() {
        let events = [
            CleanupEvent(date: date(year: 2026, month: 10, day: 31), photosDeleted: 10, bytesFreed: 100_000_000),
            CleanupEvent(date: date(year: 2025, month: 11, day: 18), photosDeleted: 7, bytesFreed: 70_000_000),
            CleanupEvent(date: date(year: 2026, month: 11, day: 1), photosDeleted: 1, bytesFreed: 1_000_000),
        ]
        let total = CleanupHistory.freedThisMonth(
            events: events, now: date(year: 2026, month: 11, day: 18), calendar: calendar)
        XCTAssertEqual(total.photos, 1)
        XCTAssertEqual(total.bytes, 1_000_000)
    }

    func testEmptyEventsAreZero() {
        let total = CleanupHistory.freedThisMonth(
            events: [], now: date(year: 2026, month: 11, day: 18), calendar: calendar)
        XCTAssertEqual(total.photos, 0)
        XCTAssertEqual(total.bytes, 0)
    }

    func testNegativeValuesClampToZero() {
        let events = [
            CleanupEvent(date: date(year: 2026, month: 11, day: 5), photosDeleted: -2, videosCompressed: -1, livePhotosConverted: -1, bytesFreed: -500),
        ]
        let total = CleanupHistory.freedThisMonth(
            events: events, now: date(year: 2026, month: 11, day: 18), calendar: calendar)
        XCTAssertEqual(total.photos, 0)
        XCTAssertEqual(total.videos, 0)
        XCTAssertEqual(total.livePhotos, 0)
        XCTAssertEqual(total.bytes, 0)
    }
}
