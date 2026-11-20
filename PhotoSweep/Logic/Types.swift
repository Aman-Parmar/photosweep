import Foundation

/// PhotoSweep pure-logic types.
///
/// These types are Foundation-only on purpose: they must compile on
/// Linux CI (see Package.swift) and in the Xcode app target. They never
/// hold photo bytes — a `PhotoItem` is metadata about one library asset
/// plus the compact signals the grouping engine needs. The actual image
/// data stays in the user's Photos library; thumbnails are fetched
/// on demand by `ThumbnailLoader` in Services.
public struct PhotoItem: Equatable, Hashable, Identifiable {
    public let id: String
    /// SHA-256 (or equivalent) of the file bytes, when known. Two items
    /// with equal non-nil hashes are exact duplicates.
    public let contentHash: String?
    /// File size in bytes.
    public let fileSize: Int64
    /// Pixel dimensions.
    public let width: Int
    public let height: Int
    /// True for screenshots (PHAsset mediaSubtype screenshot, or a
    /// filename / aspect heuristic in the scanner).
    public let isScreenshot: Bool
    /// True for burst photos (PHAsset representsBurst).
    public let isBurst: Bool
    /// True for videos. Videos are never grouped as photos; they are
    /// ranked by size in the Large Videos section.
    public let isVideo: Bool
    /// True for Live Photos (PHAsset mediaSubtype photoLive). A Live
    /// Photo is a still plus a short video clip, so it runs about
    /// twice the size of its still; converting it to a still is a
    /// separate list, not a deletion group.
    public let isLivePhoto: Bool
    /// Video duration in seconds (0 for photos).
    public let duration: TimeInterval
    /// When the asset was created. Grouping compares only items close
    /// in time — see `GroupingEngine.neighbourWindow`.
    public let creationDate: Date
    /// 0...1, higher is sharper. From gradient-energy sharpness on-device.
    public let sharpness: Double
    /// 0...1, higher is brighter. Mean luminance of a downscale.
    public let brightness: Double
    /// Feature vector (average hash in v1), when computed. Two prints with a
    /// small Euclidean distance are visually similar. Nil means the
    /// print has not been computed (yet) — grouping treats the item as
    /// ungroupable by similarity, never as a match.
    public let featurePrint: [Float]?

    public init(
        id: String,
        contentHash: String? = nil,
        fileSize: Int64,
        width: Int,
        height: Int,
        isScreenshot: Bool = false,
        isBurst: Bool = false,
        isVideo: Bool = false,
        isLivePhoto: Bool = false,
        duration: TimeInterval = 0,
        creationDate: Date,
        sharpness: Double = 0.5,
        brightness: Double = 0.5,
        featurePrint: [Float]? = nil
    ) {
        self.id = id
        self.contentHash = contentHash
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.isScreenshot = isScreenshot
        self.isBurst = isBurst
        self.isVideo = isVideo
        self.isLivePhoto = isLivePhoto
        self.duration = duration
        self.creationDate = creationDate
        self.sharpness = sharpness
        self.brightness = brightness
        self.featurePrint = featurePrint
    }

    /// Pixel count, used by the keeper picker (higher is better).
    public var pixelCount: Int { width * height }

    /// "Original" row detail line for the compress/convert sheets:
    /// "1.2 GB · 3:02 · 4032 x 3024" with a duration, "1.2 GB · 4032 x 3024"
    /// without. One source so the separator and order cannot drift apart
    /// between the two sheets.
    public func originalDetailLine(duration: TimeInterval? = nil) -> String {
        let size = StorageEstimator.formatted(fileSize)
        if let duration {
            return "\(size) · \(CleanupReport.formattedDuration(duration)) · \(width) x \(height)"
        }
        return "\(size) · \(width) x \(height)"
    }
}

/// Why a group of items was put together. Shown in the UI so the user
/// can judge whether the grouping is right before deleting anything.
public enum GroupKind: String, Equatable, Hashable, CaseIterable {
    /// Same file bytes (equal content hash).
    case exactDuplicate = "Exact duplicates"
    /// Visually similar (feature-print distance under threshold) or burst.
    case similar = "Similar photos"
    /// Low sharpness and/or very dark.
    case blurry = "Blurry or dark"
    /// Screenshots, grouped for bulk review.
    case screenshots = "Screenshots"
    /// Large videos, ranked by size (not a deletion group — a list).
    case largeVideos = "Large videos"

    /// The section a group belongs to in the Results tab.
    public var sectionTitle: String { rawValue }

    /// The short slug used in accessibility identifiers (e.g.
    /// `home-category-duplicates`, `results-group-blurry-0`). The
    /// single source for the mapping the Home and Results views used
    /// to duplicate as private `kindID` functions.
    public var categoryID: String {
        switch self {
        case .exactDuplicate: return "duplicates"
        case .similar: return "similar"
        case .blurry: return "blurry"
        case .screenshots: return "screenshots"
        case .largeVideos: return "videos"
        }
    }
}

/// One reviewable group. Deletion is never automatic: a group only
/// becomes deletable when the user confirms it, with a keeper chosen
/// (default: the sharpest / highest-resolution item).
public struct PhotoGroup: Equatable, Identifiable {
    public let id: String
    public let kind: GroupKind
    public let items: [PhotoItem]
    /// The item the user keeps. Defaults to `KeeperPicker`'s choice;
    /// the user can change it in GroupReviewView.
    public let keeperID: String
    /// The rule that formed the group, for the review screen.
    public let matchReason: String

    public init(id: String, kind: GroupKind, items: [PhotoItem], keeperID: String, matchReason: String) {
        self.id = id
        self.kind = kind
        self.items = items
        self.keeperID = keeperID
        self.matchReason = matchReason
    }

    /// Items that would be deleted if the user confirms this group.
    public var deletableItems: [PhotoItem] {
        items.filter { $0.id != keeperID }
    }

    /// Bytes that would be freed if the user confirms this group.
    public var reclaimableBytes: Int64 {
        deletableItems.reduce(0) { $0 + $1.fileSize }
    }

    public var keeper: PhotoItem? {
        items.first { $0.id == keeperID }
    }

    /// "3 photos" for the group row and the swipe card.
    public var countLabel: String {
        "\(items.count) photos"
    }
}

/// The result of one scan: every group found, plus the counts the Home
/// screen shows. `totalScanned` counts assets actually examined (limited
/// photo access may grant fewer than the whole library — the UI says so).
public struct ScanResult: Equatable {
    public let groups: [PhotoGroup]
    /// Large videos, largest first. Videos are a list, not a group —
    /// they are never auto-grouped for deletion.
    public let largeVideos: [PhotoItem]
    /// Live Photos, largest first. Like large videos, a list, not a
    /// group — converting one to a still is a separate action from
    /// deleting it.
    public let livePhotos: [PhotoItem]
    public let totalScanned: Int
    public let totalLibraryCount: Int
    public let scannedAt: Date

    public init(groups: [PhotoGroup], totalScanned: Int, totalLibraryCount: Int, largeVideos: [PhotoItem] = [], livePhotos: [PhotoItem] = [], scannedAt: Date = Date()) {
        self.groups = groups
        self.totalScanned = totalScanned
        self.totalLibraryCount = totalLibraryCount
        self.largeVideos = largeVideos
        self.livePhotos = livePhotos
        self.scannedAt = scannedAt
    }

    public func groups(of kind: GroupKind) -> [PhotoGroup] {
        groups.filter { $0.kind == kind }
    }

    /// Bytes reclaimable across all groups, if the user confirms all of
    /// them. Labelled "estimate" everywhere it is shown.
    public var totalReclaimableBytes: Int64 {
        groups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    /// Items that would be deleted across all groups.
    public var totalDeletableCount: Int {
        groups.reduce(0) { $0 + $1.deletableItems.count }
    }

    /// True when the scan covered only part of the library (limited
    /// photo access). The Home screen must say so plainly.
    public var isPartialScan: Bool { totalScanned < totalLibraryCount }
}

/// A user-confirmed deletion. The app never deletes without one of these:
/// `confirmedByUser` must be true, and the deletion goes through
/// PHAssetChangeRequest, which moves items to Recently Deleted (undoable
/// for 30 days in Photos). This type exists so the "never auto-delete"
/// rule is enforced in code, not just in copy — see the tests.
public struct DeletionRequest: Equatable {
    public let groupID: String
    public let itemIDs: [String]
    public let confirmedByUser: Bool

    public init(groupID: String, itemIDs: [String], confirmedByUser: Bool) {
        self.groupID = groupID
        self.itemIDs = itemIDs
        self.confirmedByUser = confirmedByUser
    }

    /// Only confirmed requests are executable. Anything else is a bug.
    public var isExecutable: Bool { confirmedByUser && !itemIDs.isEmpty }
}

/// One reviewable card in swipe mode: a whole group, or one screenshot.
///
/// A group card keeps the keeper decision front and centre — the
/// keeper is already picked by `KeeperPicker`, and the card deletes
/// only the group's non-keeper items. A screenshot card is a single
/// screenshot: the screenshots group has no per-photo decision today,
/// so each screenshot gets its own card instead of one bulk card.
/// Nothing here deletes anything — a swipe only records a decision;
/// deletion happens in the batch commit step (see `SwipeSession`).
public enum SwipeCard: Equatable, Identifiable {
    case group(PhotoGroup)
    case screenshot(PhotoItem)

    public var id: String {
        switch self {
        case .group(let group): return "swipe-group-\(group.id)"
        case .screenshot(let item): return "swipe-screenshot-\(item.id)"
        }
    }

    /// The month this card belongs to: the keeper's month for a group,
    /// the item's own month for a screenshot.
    public var month: SwipeMonth {
        switch self {
        case .group(let group):
            return SwipeMonth(date: group.keeper?.creationDate ?? group.items[0].creationDate)
        case .screenshot(let item):
            return SwipeMonth(date: item.creationDate)
        }
    }

    /// The PhotoGroup id, for group cards. Nil for screenshot cards —
    /// a screenshot has no group to invalidate.
    public var groupID: String? {
        if case .group(let group) = self { return group.id }
        return nil
    }

    /// The keeper at decision time. A keeper change after the decision
    /// invalidates it (see `SwipeSession.discardDecision`).
    public var decisionKeeperID: String {
        switch self {
        case .group(let group): return group.keeperID
        case .screenshot(let item): return item.id
        }
    }

    /// The label shown for a single screenshot item, in the swipe card
    /// and in the screenshots bulk-review list. One source so the wording
    /// stays identical in both places.
    public static let screenshotLabel = "Screenshot"

    /// The label shown on the card: the group kind, or "Screenshot".
    public var kindLabel: String {
        switch self {
        case .group(let group): return group.kind.sectionTitle
        case .screenshot: return Self.screenshotLabel
        }
    }

    /// The photo shown large on the card: the keeper, or the
    /// screenshot itself.
    public var keeper: PhotoItem? {
        switch self {
        case .group(let group): return group.keeper
        case .screenshot(let item): return item
        }
    }

    /// Items that would be deleted if this card's decision is "delete"
    /// and the batch is committed.
    public var deletableItems: [PhotoItem] {
        switch self {
        case .group(let group): return group.deletableItems
        case .screenshot(let item): return [item]
        }
    }

    public var deletableCount: Int { deletableItems.count }

    public var reclaimableBytes: Int64 {
        StorageEstimator.reclaimableBytes(for: deletableItems)
    }

    /// Thumbnails on the card: the keeper first, then up to two more
    /// members. Never renders all members — a 50-frame burst group
    /// would cost 50 thumbnails for one card.
    public var thumbnailItems: [PhotoItem] {
        switch self {
        case .group(let group):
            guard let keeper = group.keeper else { return [] }
            let others = group.items.filter { $0.id != keeper.id }.prefix(2)
            return [keeper] + others
        case .screenshot(let item):
            return [item]
        }
    }

    /// "3 photos" for a group, "1 screenshot" for a screenshot.
    public var countLabel: String {
        switch self {
        case .group(let group): return group.countLabel
        case .screenshot: return "1 screenshot"
        }
    }
}

/// One recorded swipe decision: which card, keep or delete, and the
/// keeper at decision time. Decisions are the only thing a swipe
/// writes — deletion waits for the batch commit, so a decision can
/// still be undone or discarded. Codable: the session persists
/// decisions in UserDefaults, keyed by the scan's `scannedAt`.
public struct SwipeDecision: Equatable, Codable {
    public enum Choice: String, Equatable, Codable {
        case keep
        case delete
    }

    public let cardID: String
    public let choice: Choice
    public let keeperID: String

    public init(cardID: String, choice: Choice, keeperID: String) {
        self.cardID = cardID
        self.choice = choice
        self.keeperID = keeperID
    }
}
