import Foundation

/// One confirmed cleanup: what the user deleted, and how much space
/// the deleted items reported. A pure value type so the monthly total
/// is Linux-testable; the SwiftData record lives in Models.swift and
/// maps to and from this. Sizes are estimates, same as everywhere
/// else in the app: space is only actually freed once Recently
/// Deleted is emptied.
///
/// `videosCompressed` counts videos the user compressed (the original
/// moved to Recently Deleted, a smaller copy saved): no photo was
/// deleted, so `photosDeleted` stays 0 for those events and the
/// Settings line says "compressed video" instead of "photo".
/// `livePhotosConverted` counts Live Photos converted to stills the
/// same way: the still was saved first, the original moved to Recently
/// Deleted, and the conversion cost one free delete.
public struct CleanupEvent: Equatable {
    public let date: Date
    public let photosDeleted: Int
    public let videosCompressed: Int
    public let livePhotosConverted: Int
    public let bytesFreed: Int64

    public init(date: Date, photosDeleted: Int, videosCompressed: Int = 0, livePhotosConverted: Int = 0, bytesFreed: Int64) {
        self.date = date
        self.photosDeleted = photosDeleted
        self.videosCompressed = videosCompressed
        self.livePhotosConverted = livePhotosConverted
        self.bytesFreed = bytesFreed
    }
}

public enum CleanupHistory {
    /// Photos deleted, videos compressed, Live Photos converted, and
    /// bytes freed in the calendar month containing `now`. Events from
    /// other months are ignored, so a cleanup from last month never
    /// inflates this month's figure. Counts are clamped at zero: a
    /// negative value is bad data, not a refund.
    public static func freedThisMonth(
        events: [CleanupEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (photos: Int, videos: Int, livePhotos: Int, bytes: Int64) {
        let month = calendar.dateComponents([.year, .month], from: now)
        var photos = 0
        var videos = 0
        var livePhotos = 0
        var bytes: Int64 = 0
        for event in events {
            let components = calendar.dateComponents([.year, .month], from: event.date)
            guard components.year == month.year, components.month == month.month else { continue }
            photos += max(0, event.photosDeleted)
            videos += max(0, event.videosCompressed)
            livePhotos += max(0, event.livePhotosConverted)
            bytes += max(0, event.bytesFreed)
        }
        return (photos, videos, livePhotos, bytes)
    }
}
