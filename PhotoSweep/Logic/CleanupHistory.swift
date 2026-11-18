import Foundation

/// One confirmed cleanup: what the user deleted, and how much space
/// the deleted items reported. A pure value type so the monthly total
/// is Linux-testable; the SwiftData record lives in Models.swift and
/// maps to and from this. Sizes are estimates, same as everywhere
/// else in the app: space is only actually freed once Recently
/// Deleted is emptied.
public struct CleanupEvent: Equatable {
    public let date: Date
    public let photosDeleted: Int
    public let bytesFreed: Int64

    public init(date: Date, photosDeleted: Int, bytesFreed: Int64) {
        self.date = date
        self.photosDeleted = photosDeleted
        self.bytesFreed = bytesFreed
    }
}

public enum CleanupHistory {
    /// Photos deleted and bytes freed in the calendar month containing
    /// `now`. Events from other months are ignored, so a cleanup from
    /// last month never inflates this month's figure. Counts are
    /// clamped at zero: a negative value is bad data, not a refund.
    public static func freedThisMonth(
        events: [CleanupEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (photos: Int, bytes: Int64) {
        let month = calendar.dateComponents([.year, .month], from: now)
        var photos = 0
        var bytes: Int64 = 0
        for event in events {
            let components = calendar.dateComponents([.year, .month], from: event.date)
            guard components.year == month.year, components.month == month.month else { continue }
            photos += max(0, event.photosDeleted)
            bytes += max(0, event.bytesFreed)
        }
        return (photos, bytes)
    }
}
