import Foundation

/// Groups a flat list of scanned assets into reviewable groups.
///
/// Order of operations (matters — first match wins, an item belongs to
/// at most one group, and a group is never formed from a single item):
///   1. Videos are pulled out first and ranked by size (large videos
///      are a list, not a deletion group).
///   2. Screenshots are grouped together for bulk review.
///   3. Exact duplicates: equal content hash.
///   4. Similar / burst: feature-print distance within threshold, or
///      burst pairs — compared ONLY within a time-sorted neighbour
///      window. Never pairwise over the whole library: 35,000 photos
///      is ~600M pairs. The window is 20 neighbours either side of each
///      item in creation-date order, which covers bursts and
///      re-takes while keeping the work linear.
///   5. Blurry / dark: whatever is left and scores low.
///
/// Every group is built with a keeper pre-selected (see
/// `KeeperPicker`) and a human-readable match reason. Nothing here
/// deletes anything — groups are proposals the user confirms.
public enum GroupingEngine {

    /// How many neighbours either side of an item (in creation-date
    /// order) are compared for similarity. Bursts and re-takes are
    /// taken seconds apart, so they are always neighbours; a photo
    /// taken months later is never compared against it.
    public static let neighbourWindow = 20

    /// Videos at or above this size are listed as large videos.
    /// 100 MB is the v1 cut-off: a 30-second 4K clip is ~150 MB, so
    /// the list catches the clips that actually fill storage.
    public static let largeVideoThresholdBytes: Int64 = 100 * 1024 * 1024

    /// Groups `items` into reviewable groups. Videos are excluded from
    /// photo groups and returned separately, largest first.
    public static func group(
        _ items: [PhotoItem]
    ) -> (groups: [PhotoGroup], largeVideos: [PhotoItem]) {
        let videos = items.filter { $0.isVideo }
        let largeVideos = videos
            .filter { $0.fileSize >= largeVideoThresholdBytes }
            .sorted { $0.fileSize > $1.fileSize }
        let photos = items.filter { !$0.isVideo }

        var groups: [PhotoGroup] = []
        var groupedIDs = Set<String>()

        // 1. Screenshots — one bulk-review group.
        let screenshots = photos.filter { $0.isScreenshot }
        if screenshots.count >= 2 {
            groups.append(makeGroup(
                id: "screenshots",
                kind: .screenshots,
                items: screenshots,
                reason: "Screenshots, grouped for bulk review. Check each one: some may be receipts or confirmations worth keeping."
            ))
            groupedIDs.formUnion(screenshots.map(\.id))
        } else {
            // A single screenshot is not a group. It stays ungrouped.
        }

        // 2. Exact duplicates — equal content hash.
        var byHash: [String: [PhotoItem]] = [:]
        for item in photos where !groupedIDs.contains(item.id) {
            guard let hash = item.contentHash else { continue }
            byHash[hash, default: []].append(item)
        }
        for (hash, members) in byHash where members.count >= 2 {
            groups.append(makeGroup(
                id: "exact-\(hash.prefix(8))",
                kind: .exactDuplicate,
                items: members,
                reason: "Same file contents: exact duplicates."
            ))
            groupedIDs.formUnion(members.map(\.id))
        }

        // 3. Similar / burst — neighbour-window comparison only.
        let remaining = photos.filter { !groupedIDs.contains($0.id) }
        let sorted = remaining.sorted { $0.creationDate < $1.creationDate }
        var visited = Set<String>()
        for (index, item) in sorted.enumerated() {
            guard !visited.contains(item.id) else { continue }
            var members: [PhotoItem] = [item]
            let lower = max(0, index - neighbourWindow)
            let upper = min(sorted.count - 1, index + neighbourWindow)
            for j in lower...upper where j != index {
                let candidate = sorted[j]
                guard !visited.contains(candidate.id) else { continue }
                if SimilarityEngine.areSimilar(item, candidate)
                    || SimilarityEngine.areBurstPair(item, candidate) {
                    members.append(candidate)
                }
            }
            guard members.count >= 2 else { continue }
            // A similar group is anchored on its first item; members are
            // marked visited so no item lands in two groups.
            let reason = members.contains { $0.isBurst }
                ? "Burst photos taken seconds apart. Pick the best frame, delete the rest."
                : "Visually similar photos. Pick the best one, delete the rest."
            groups.append(makeGroup(
                id: "similar-\(item.id)",
                kind: .similar,
                items: members,
                reason: reason
            ))
            visited.formUnion(members.map(\.id))
        }
        groupedIDs.formUnion(visited)

        // 4. Blurry / dark — whatever is left and scores low.
        let blurry = photos.filter {
            !groupedIDs.contains($0.id) && SimilarityEngine.isBlurryOrDark($0)
        }
        if blurry.count >= 2 {
            groups.append(makeGroup(
                id: "blurry",
                kind: .blurry,
                items: blurry,
                reason: "Blurry or very dark photos. Review each one: a blurry photo can still be the only copy of a moment."
            ))
        } else if blurry.count == 1 {
            // A single blurry photo is not a group. It stays ungrouped —
            // the app never invents a group of one to inflate its count.
        }

        // Groups are shown largest-reclaim first, so the most valuable
        // review is at the top.
        groups.sort { $0.reclaimableBytes > $1.reclaimableBytes }
        return (groups, largeVideos)
    }

    // MARK: - Private

    private static func makeGroup(
        id: String,
        kind: GroupKind,
        items: [PhotoItem],
        reason: String
    ) -> PhotoGroup {
        let keeper = KeeperPicker.pickKeeper(from: items)
        return PhotoGroup(
            id: id,
            kind: kind,
            items: items,
            keeperID: keeper.id,
            matchReason: reason
        )
    }
}
