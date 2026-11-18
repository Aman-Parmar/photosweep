import Foundation

/// Fixed synthetic scan result for screenshot mode and for the
/// screenshot lane only. Deterministic: same items, same groups, same
/// numbers on every run. No real photos, no real library — the
/// "library" is 24 synthetic items.
///
/// Groups (see `GroupingEngine` for why these form):
/// - Exact duplicates: 3 identical sunset photos (same hash).
/// - Similar burst: 3 frames taken seconds apart.
/// - Blurry: 2 low-sharpness photos.
/// - Screenshots: 4 screenshots for bulk review.
/// - Large videos: 3 clips (1.2 GB, 850 MB, 640 MB), listed separately.
/// - Live Photos: 3 Live Photos (6.4 MB, 5.6 MB, 4.8 MB), listed separately.
/// - 9 ordinary singles that group with nothing.
enum SampleScan {

    /// Fixed base date so grouping (which uses creation order) is
    /// stable across runs. Displayed dates in the UI are relative to
    /// this base, not to "now".
    static let base = Date(timeIntervalSince1970: 1_760_000_000)

    static let result: ScanResult = {
        let (groups, largeVideos) = GroupingEngine.group(allItems)
        let live = allItems
            .filter { $0.isLivePhoto }
            .sorted { $0.fileSize > $1.fileSize }
        return ScanResult(groups: groups, totalScanned: allItems.count, totalLibraryCount: allItems.count, largeVideos: largeVideos, livePhotos: live, scannedAt: base)
    }()

    /// Large videos, largest first — the Videos tab shows this list.
    static var largeVideos: [PhotoItem] {
        result.largeVideos
    }

    /// Live Photos, largest first — the Live Photos list shows this.
    static var livePhotos: [PhotoItem] {
        result.livePhotos
    }

    // MARK: - Items

    static let allItems: [PhotoItem] = {
        var items: [PhotoItem] = []
        items.append(contentsOf: duplicates)
        items.append(contentsOf: burst)
        items.append(contentsOf: blurry)
        items.append(contentsOf: screenshots)
        items.append(contentsOf: videos)
        items.append(contentsOf: livePhotoItems)
        items.append(contentsOf: singles)
        return items
    }()

    private static func day(_ offset: Int) -> Date {
        base.addingTimeInterval(TimeInterval(offset * 86_400))
    }

    /// A 64-float vector of all `value`, used to build deterministic
    /// feature prints. Distinct groups use vectors far apart so they
    /// never accidentally group.
    private static func flatPrint(_ value: Float) -> [Float] {
        Array(repeating: value, count: 64)
    }

    /// A vector close to `base`: every element moved by at most
    /// `delta`. Distance between two such vectors stays under 0.35.
    private static func nearPrint(_ base: [Float], delta: Float) -> [Float] {
        base.enumerated().map { index, value in
            value + (index % 2 == 0 ? delta : -delta)
        }
    }

    private static var duplicates: [PhotoItem] {
        let print = flatPrint(0.8)
        return (0..<3).map { i in
            PhotoItem(
                id: "sample-dup-\(i)",
                contentHash: "hash-beach-sunset",
                fileSize: 4_200_000,
                width: 4032, height: 3024,
                creationDate: day(-12),
                sharpness: [0.80, 0.75, 0.70][i],
                brightness: 0.7,
                featurePrint: print
            )
        }
    }

    private static var burst: [PhotoItem] {
        let basePrint = flatPrint(0.2)
        return (0..<3).map { i in
            PhotoItem(
                id: "sample-burst-\(i)",
                fileSize: 3_800_000,
                width: 4032, height: 3024,
                isBurst: true,
                creationDate: base.addingTimeInterval(TimeInterval(-11 * 86_400 + i * 4)),
                sharpness: [0.90, 0.85, 0.60][i],
                brightness: 0.65,
                featurePrint: nearPrint(basePrint, delta: 0.02)
            )
        }
    }

    private static var blurry: [PhotoItem] {
        (0..<2).map { i in
            PhotoItem(
                id: "sample-blurry-\(i)",
                fileSize: 3_100_000,
                width: 4032, height: 3024,
                creationDate: day(-9 + i),
                sharpness: [0.20, 0.15][i],
                brightness: 0.4,
                featurePrint: flatPrint(i == 0 ? 0.1 : 0.9)
            )
        }
    }

    private static var screenshots: [PhotoItem] {
        (0..<4).map { i in
            PhotoItem(
                id: "sample-shot-\(i)",
                fileSize: 1_200_000,
                width: 1170, height: 2532,
                isScreenshot: true,
                creationDate: day(-6 + i),
                sharpness: 0.85,
                brightness: 0.8,
                featurePrint: flatPrint(Float(i) * 0.2)
            )
        }
    }

    private static var videos: [PhotoItem] {
        [
            PhotoItem(id: "sample-video-0", fileSize: 1_250_000_000, width: 3840, height: 2160, isVideo: true, duration: 182, creationDate: day(-20), sharpness: 0.8, brightness: 0.6),
            PhotoItem(id: "sample-video-1", fileSize: 850_000_000, width: 3840, height: 2160, isVideo: true, duration: 96, creationDate: day(-15), sharpness: 0.8, brightness: 0.6),
            PhotoItem(id: "sample-video-2", fileSize: 640_000_000, width: 1920, height: 1080, isVideo: true, duration: 61, creationDate: day(-3), sharpness: 0.8, brightness: 0.6),
        ]
    }

    /// Three Live Photos: distinct flat prints far apart, good
    /// sharpness, no shared hash — they group with nothing, so the
    /// sample still has exactly 4 groups.
    private static var livePhotoItems: [PhotoItem] {
        [
            PhotoItem(id: "sample-live-0", fileSize: 6_400_000, width: 4032, height: 3024, isLivePhoto: true, creationDate: day(-4), sharpness: 0.75, brightness: 0.7, featurePrint: flatPrint(0.15)),
            PhotoItem(id: "sample-live-1", fileSize: 5_600_000, width: 4032, height: 3024, isLivePhoto: true, creationDate: day(-2), sharpness: 0.75, brightness: 0.7, featurePrint: flatPrint(0.55)),
            PhotoItem(id: "sample-live-2", fileSize: 4_800_000, width: 4032, height: 3024, isLivePhoto: true, creationDate: day(-1), sharpness: 0.75, brightness: 0.7, featurePrint: flatPrint(0.95)),
        ]
    }

    /// Ordinary photos that group with nothing: seeded pseudo-random
    /// feature prints, distinct hashes, good sharpness. (Periodic
    /// patterns like alternating bits cycle and collide — a seeded
    /// LCG does not. Two random 64-bit prints sit ~5.7 apart, far
    /// outside the 0.35 similarity threshold.)
    private static var singles: [PhotoItem] {
        (0..<9).map { i in
            let print: [Float] = {
                var state = UInt64(bitPattern: Int64(i + 101))
                return (0..<64).map { _ in
                    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return Float((state >> 33) & 1)
                }
            }()
            return PhotoItem(
                id: "sample-single-\(i)",
                contentHash: "hash-single-\(i)",
                fileSize: 2_900_000 + Int64(i * 100_000),
                width: 4032, height: 3024,
                creationDate: day(-30 + i * 3),
                sharpness: 0.75,
                brightness: 0.7,
                featurePrint: print
            )
        }
    }
}
