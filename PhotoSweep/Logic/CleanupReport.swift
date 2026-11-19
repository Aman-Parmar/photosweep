import Foundation

/// Builds the cleanup report (CSV) the paywall promises Pro users:
/// one row per group plus the large videos, with the scan totals.
/// Foundation-only so Linux CI can test it.
///
/// The report holds counts and sizes only. No photo bytes, no
/// filenames, no library identifiers: a real asset's local identifier
/// is an opaque string a user cannot act on, so large videos are
/// labelled "Video 1", "Video 2" in size order. Sizes are estimates,
/// and the file says so.
public enum CleanupReport {

    /// CSV text for `result`. An empty result (no groups, no videos)
    /// still produces the header and totals, so the export never
    /// fails on an empty scan.
    public static func csv(for result: ScanResult) -> String {
        var lines: [String] = []
        lines.append("PhotoSweep cleanup report")
        lines.append("Scan date,\(isoDate(result.scannedAt))")
        lines.append("Photos scanned,\(result.totalScanned)")
        lines.append("Photos proposed for deletion,\(result.totalDeletableCount)")
        lines.append("Estimated space to reclaim,\(StorageEstimator.formatted(result.totalReclaimableBytes))")
        lines.append("")
        lines.append("Category,Photos in group,Photos to delete,Space to reclaim (estimate),Why grouped")
        for group in result.groups {
            lines.append([
                group.kind.rawValue,
                String(group.items.count),
                String(group.deletableItems.count),
                StorageEstimator.formatted(group.reclaimableBytes),
                group.matchReason,
            ].map(csvField).joined(separator: ","))
        }
        if !result.largeVideos.isEmpty {
            lines.append("")
            lines.append("Large video,Size (estimate),Duration")
            for (index, video) in result.largeVideos.enumerated() {
                lines.append([
                    "Video \(index + 1)",
                    StorageEstimator.formatted(video.fileSize),
                    formattedDuration(video.duration),
                ].map(csvField).joined(separator: ","))
            }
        }
        lines.append("")
        lines.append("Total groups,\(result.groups.count)")
        lines.append("Total large videos,\(result.largeVideos.count)")
        lines.append("All sizes are estimates. Deleted photos go to Recently Deleted for 30 days.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Suggested filename: photosweep-cleanup-report-2026-11-18.csv
    public static func fileName(for date: Date = Date()) -> String {
        "photosweep-cleanup-report-\(isoDate(date)).csv"
    }

    // MARK: - Private

    /// Shared ISO date formatter: building one per call is wasteful
    /// and the POSIX/UTC setup is easy to get wrong twice. Same
    /// pattern as SwipeMode.monthTitleFormatter.
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func isoDate(_ date: Date) -> String {
        isoDateFormatter.string(from: date)
    }

    /// "3:02" for 182 seconds. Public so the tests can pin it.
    public static func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    /// RFC 4180 field escaping: quote when the field holds a comma,
    /// quote, or newline, and double any quotes inside. Public so the
    /// tests can pin it.
    public static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
