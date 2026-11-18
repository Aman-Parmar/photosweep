import Foundation
import XCTest

@testable import PhotoSweep

/// Grouping: exact-hash groups, similar/burst groups inside the
/// neighbour window only, screenshot and blurry groups, large-video
/// ranking — and the rule that an item belongs to at most one group.
final class GroupingEngineTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_760_000_000)

    private func item(
        id: String,
        hash: String? = nil,
        size: Int64 = 1_000_000,
        sharpness: Double = 0.8,
        brightness: Double = 0.7,
        print: [Float]? = nil,
        burst: Bool = false,
        screenshot: Bool = false,
        video: Bool = false,
        duration: TimeInterval = 0,
        dateOffset: TimeInterval = 0
    ) -> PhotoItem {
        PhotoItem(
            id: id,
            contentHash: hash,
            fileSize: size,
            width: 4032, height: 3024,
            isScreenshot: screenshot,
            isBurst: burst,
            isVideo: video,
            duration: duration,
            creationDate: base.addingTimeInterval(dateOffset),
            sharpness: sharpness,
            brightness: brightness,
            featurePrint: print
        )
    }

    private func flatPrint(_ value: Float) -> [Float] {
        Array(repeating: value, count: 64)
    }

    /// A deterministic pseudo-random 64-float binary vector, seeded
    /// per item. Two different seeds give vectors ~5.7 apart — far
    /// outside the 0.35 similarity threshold — so fillers built from
    /// this never accidentally group with each other or with the
    /// anchor. (Periodic patterns like alternating bits cycle and
    /// collide; a seeded LCG does not.)
    private func pseudoRandomPrint(seed: Int) -> [Float] {
        var state = UInt64(bitPattern: Int64(seed + 1))
        return (0..<64).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float((state >> 33) & 1)
        }
    }

    // MARK: - Exact duplicates

    func testExactDuplicatesFormOneGroup() {
        let items = [
            item(id: "a", hash: "h1", size: 1_000_000, sharpness: 0.9),
            item(id: "b", hash: "h1", size: 2_000_000, sharpness: 0.5),
            item(id: "c", hash: "h1", size: 3_000_000, sharpness: 0.6),
        ]
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].kind, .exactDuplicate)
        XCTAssertEqual(groups[0].keeperID, "a") // sharpest
        XCTAssertEqual(groups[0].deletableItems.count, 2)
        XCTAssertEqual(groups[0].reclaimableBytes, 5_000_000)
    }

    func testDistinctHashesDoNotGroup() {
        let items = [
            item(id: "a", hash: "h1", print: flatPrint(0.1)),
            item(id: "b", hash: "h2", print: flatPrint(0.9)),
        ]
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertTrue(groups.isEmpty)
    }

    // MARK: - Similar / burst

    func testBurstPhotosFormOneGroup() {
        let print = flatPrint(0.5)
        let items = (0..<3).map { i in
            item(id: "burst-\(i)", print: print, burst: true, dateOffset: TimeInterval(i * 4))
        }
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].kind, .similar)
        XCTAssertEqual(groups[0].items.count, 3)
    }

    func testSimilarPhotosOutsideNeighbourWindowDoNotGroup() {
        // Anchor at t=0, a near-identical photo 26 days later, with 25
        // unrelated fillers between them in creation order. The
        // neighbour window is 20, so the two similar photos are never
        // compared — this is what keeps a 35k-photo library linear.
        var items: [PhotoItem] = [
            item(id: "anchor", print: flatPrint(0.5), dateOffset: 0),
        ]
        for i in 0..<25 {
            items.append(item(
                id: "filler-\(i)",
                hash: "filler-hash-\(i)",
                print: pseudoRandomPrint(seed: i + 1),
                dateOffset: TimeInterval((i + 1) * 86_400)
            ))
        }
        items.append(item(id: "far", print: flatPrint(0.52), dateOffset: 26 * 86_400))
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertTrue(groups.isEmpty, "Similar photos outside the neighbour window must not group")
    }

    func testSimilarPhotosInsideNeighbourWindowDoGroup() {
        let basePrint = flatPrint(0.5)
        let nearPrint: [Float] = basePrint.enumerated().map { $0.offset % 2 == 0 ? $0.element + 0.02 : $0.element - 0.02 }
        let items = [
            item(id: "a", print: basePrint, dateOffset: 0),
            item(id: "b", print: nearPrint, dateOffset: 60),
        ]
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].kind, .similar)
    }

    func testItemBelongsToAtMostOneGroup() {
        // Three identical photos: they form exactly one group, and no
        // item appears in two groups.
        let items = (0..<3).map { i in
            item(id: "dup-\(i)", hash: "h1", print: flatPrint(0.5), dateOffset: TimeInterval(i))
        }
        let (groups, _) = GroupingEngine.group(items)
        let allIDs = groups.flatMap { $0.items.map(\.id) }
        XCTAssertEqual(allIDs.count, Set(allIDs).count)
    }

    // MARK: - Screenshots and blurry

    func testScreenshotsFormOneBulkGroup() {
        let items = (0..<3).map { i in
            item(id: "shot-\(i)", screenshot: true, dateOffset: TimeInterval(i * 86_400))
        }
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].kind, .screenshots)
    }

    func testSingleScreenshotIsNotAGroup() {
        let items = [item(id: "shot-0", screenshot: true)]
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertTrue(groups.isEmpty, "A group of one is never formed — it would inflate the count")
    }

    func testBlurryPhotosFormOneGroup() {
        let items = [
            item(id: "blur-0", sharpness: 0.2, print: flatPrint(0.1)),
            item(id: "blur-1", sharpness: 0.15, print: flatPrint(0.9)),
        ]
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].kind, .blurry)
    }

    func testSingleBlurryPhotoIsNotAGroup() {
        let items = [item(id: "blur-0", sharpness: 0.2)]
        let (groups, _) = GroupingEngine.group(items)
        XCTAssertTrue(groups.isEmpty)
    }

    // MARK: - Large videos

    func testLargeVideosRankedLargestFirst() {
        let items = [
            item(id: "v-small", size: 50_000_000, video: true, duration: 30),
            item(id: "v-mid", size: 850_000_000, video: true, duration: 96),
            item(id: "v-big", size: 1_250_000_000, video: true, duration: 182),
        ]
        let (groups, largeVideos) = GroupingEngine.group(items)
        XCTAssertTrue(groups.isEmpty, "Videos are never photo groups")
        XCTAssertEqual(largeVideos.map(\.id), ["v-big", "v-mid"])
    }

    func testVideosUnderThresholdAreNotListed() {
        let items = [item(id: "v-small", size: 99_000_000, video: true, duration: 30)]
        let (_, largeVideos) = GroupingEngine.group(items)
        XCTAssertTrue(largeVideos.isEmpty)
    }
}
