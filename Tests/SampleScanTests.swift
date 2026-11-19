import Foundation
import XCTest

@testable import PhotoSweep

/// The fixed synthetic sample scan: the screenshot lane's data must
/// group exactly as designed, on every run. If this test fails, the
/// screenshots are wrong too.
final class SampleScanTests: XCTestCase {

    func testSampleScanHasFiveGroups() {
        let result = SampleScan.result
        XCTAssertEqual(result.groups.count, 5)
        XCTAssertEqual(result.groups(of: .exactDuplicate).count, 2)
        XCTAssertEqual(result.groups(of: .similar).count, 1)
        XCTAssertEqual(result.groups(of: .blurry).count, 1)
        XCTAssertEqual(result.groups(of: .screenshots).count, 1)
    }

    func testSampleScanGroupSizes() {
        let result = SampleScan.result
        XCTAssertEqual(result.groups(of: .exactDuplicate).first?.items.count, 3)
        XCTAssertEqual(result.groups(of: .similar).first?.items.count, 3)
        XCTAssertEqual(result.groups(of: .blurry).first?.items.count, 2)
        XCTAssertEqual(result.groups(of: .screenshots).first?.items.count, 4)
    }

    func testSampleScanLargeVideosLargestFirst() {
        let videos = SampleScan.largeVideos
        XCTAssertEqual(videos.count, 3)
        XCTAssertEqual(videos.map(\.id), ["sample-video-0", "sample-video-1", "sample-video-2"])
        XCTAssertEqual(videos[0].fileSize, 1_250_000_000)
    }

    func testSampleScanLivePhotosLargestFirst() {
        let livePhotos = SampleScan.livePhotos
        XCTAssertEqual(livePhotos.count, 3)
        XCTAssertEqual(livePhotos.map(\.id), ["sample-live-0", "sample-live-1", "sample-live-2"])
        XCTAssertEqual(livePhotos[0].fileSize, 6_400_000)
        XCTAssertTrue(livePhotos.allSatisfy { $0.isLivePhoto })
    }

    func testSampleScanCounts() {
        let result = SampleScan.result
        XCTAssertEqual(result.totalScanned, 30)
        XCTAssertEqual(result.totalLibraryCount, 30)
        XCTAssertFalse(result.isPartialScan)
        XCTAssertGreaterThan(result.totalReclaimableBytes, 0)
        XCTAssertEqual(result.totalDeletableCount, 2 + 2 + 1 + 3 + 2)
    }

    func testSampleScanKeepersAreSharpest() {
        let result = SampleScan.result
        // Duplicates keeper: the 0.80-sharpness item.
        XCTAssertEqual(result.groups(of: .exactDuplicate).first?.keeperID, "sample-dup-0")
        // Burst keeper: the 0.90-sharpness frame.
        XCTAssertEqual(result.groups(of: .similar).first?.keeperID, "sample-burst-0")
    }

    func testSampleScanSwipeMonths() {
        let result = SampleScan.result
        // September: duplicates, September duplicates, burst, blurry.
        // October: the 4 screenshots as single cards. The two months
        // tie at 4 cards each, so there is no smaller month — the
        // month-complete lane test uses October.
        let months = SwipeMode.months(for: result)
        XCTAssertEqual(months.count, 2)
        XCTAssertEqual(months[0].year, 2025)
        XCTAssertEqual(months[0].month, 10)
        XCTAssertEqual(months[1].month, 9)
        XCTAssertEqual(SwipeMode.cards(for: months[0], in: result).count, 4)
        XCTAssertEqual(SwipeMode.cards(for: months[1], in: result).count, 4)
        XCTAssertEqual(SwipeMode.cards(for: result).count, 8)
    }
}
