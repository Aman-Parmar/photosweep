import Foundation

/// Picks the keeper of a group: the one photo worth keeping.
///
/// Rule, in order:
///   1. Highest sharpness (a sharp photo beats a blurry one).
///   2. Highest pixel count (more detail beats less).
///   3. Largest file size (a proxy for less compression).
///   4. Earliest creation date (stable tie-break — the original, not
///      a later re-save).
///
/// The keeper is a default, not a decision: the user can change it in
/// GroupReviewView before confirming anything. The picker is pure so
/// the tests can pin it — see `KeeperPickerTests` in Tests/.
public enum KeeperPicker {

    public static func pickKeeper(from items: [PhotoItem]) -> PhotoItem {
        precondition(!items.isEmpty, "KeeperPicker needs at least one item")
        return items.sorted { a, b in
            if a.sharpness != b.sharpness { return a.sharpness > b.sharpness }
            if a.pixelCount != b.pixelCount { return a.pixelCount > b.pixelCount }
            if a.fileSize != b.fileSize { return a.fileSize > b.fileSize }
            return a.creationDate < b.creationDate
        }.first!
    }

    /// True when `item` is the keeper of `group`.
    public static func isKeeper(_ item: PhotoItem, in group: PhotoGroup) -> Bool {
        item.id == group.keeperID
    }
}

/// Storage estimates. Every number the app shows is an estimate —
/// Photos may report slightly different sizes, and Recently Deleted
/// holds deleted items for 30 days before the space is actually freed.
/// The UI must say "estimate" next to every figure this produces.
public enum StorageEstimator {

    /// Bytes reclaimed by deleting `items` (the deletable members of a
    /// group, or a hand-picked set). Zero when the list is empty.
    public static func reclaimableBytes(for items: [PhotoItem]) -> Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }

    /// Human-readable estimate: "1.2 GB", "850 MB", "42 KB". One
    /// decimal place, SI-style (1 GB = 1,000,000,000 bytes) to match
    /// how iOS reports storage in Settings.
    public static func formatted(_ bytes: Int64) -> String {
        let value = Double(bytes)
        switch value {
        case 1_000_000_000...:
            return String(format: "%.1f GB", value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.0f MB", value / 1_000_000)
        case 1_000...:
            return String(format: "%.0f KB", value / 1_000)
        default:
            return "\(bytes) B"
        }
    }

    /// Short estimate label used on group rows: "Frees ~1.2 GB".
    public static func freesLabel(_ bytes: Int64) -> String {
        "Frees ~\(formatted(bytes))"
    }
}
