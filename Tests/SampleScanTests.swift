import Foundation
import XCTest

@testable import PhotoSweep

/// The fixed synthetic sample scan: the screenshot lane's data must
/// group exactly as designed, on every run. If this test fails, the
/// screenshots are wrong too.
final class SampleScanTests: XCTestCase {

    func testSampleScanHasFourGroups() {
        let result = SampleScan.result
        XCTAssertEqual(result.groups.count, 4)
        XCTAssertEqual(result.groups(of: .exactDuplicate).count, 1)
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

    func testSampleScanCounts() {
        let result = SampleScan.result
        XCTAssertEqual(result.totalScanned, 24)
        XCTAssertEqual(result.totalLibraryCount, 24)
        XCTAssertFalse(result.isPartialScan)
        XCTAssertGreaterThan(result.totalReclaimableBytes, 0)
        XCTAssertEqual(result.totalDeletableCount, 2 + 2 + 1 + 3)
    }

    func testSampleScanKeepersAreSharpest() {
        let result = SampleScan.result
        // Duplicates keeper: the 0.80-sharpness item.
        XCTAssertEqual(result.groups(of: .exactDuplicate).first?.keeperID, "sample-dup-0")
        // Burst keeper: the 0.90-sharpness frame.
        XCTAssertEqual(result.groups(of: .similar).first?.keeperID, "sample-burst-0")
    }
}
