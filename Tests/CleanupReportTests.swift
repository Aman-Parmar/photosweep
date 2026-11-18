import Foundation
import XCTest

@testable import PhotoSweep

/// Cleanup report CSV: header, totals, one row per group, large
/// videos, and RFC 4180 field escaping. Pins the exact lines a user
/// sees when they export, so a formatting change is a deliberate
/// test change, not a silent one.
final class CleanupReportTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_760_000_000)

    private func item(
        id: String,
        size: Int64 = 4_200_000,
        isVideo: Bool = false,
        duration: TimeInterval = 0,
        sharpness: Double = 0.8
    ) -> PhotoItem {
        PhotoItem(
            id: id,
            contentHash: isVideo ? nil : "hash-\(id)",
            fileSize: size,
            width: 4032,
            height: 3024,
            isVideo: isVideo,
            duration: duration,
            creationDate: base,
            sharpness: sharpness,
            brightness: 0.7,
            featurePrint: nil
        )
    }

    private func sampleResult() -> ScanResult {
        let dupItems = [item(id: "dup-0"), item(id: "dup-1"), item(id: "dup-2")]
        let dup = PhotoGroup(
            id: "dup",
            kind: .exactDuplicate,
            items: dupItems,
            keeperID: "dup-0",
            matchReason: "Same file contents."
        )
        let simItems = [item(id: "sim-0", size: 3_800_000), item(id: "sim-1", size: 3_800_000)]
        let sim = PhotoGroup(
            id: "sim",
            kind: .similar,
            items: simItems,
            keeperID: "sim-0",
            matchReason: "Visually similar photos."
        )
        let video = item(id: "vid-0", size: 1_250_000_000, isVideo: true, duration: 182)
        return ScanResult(
            groups: [dup, sim],
            totalScanned: 10,
            totalLibraryCount: 10,
            largeVideos: [video],
            scannedAt: base
        )
    }

    func testCSVHasHeaderTotalsAndGroupRows() {
        let csv = CleanupReport.csv(for: sampleResult())
        XCTAssertTrue(csv.hasPrefix("PhotoSweep cleanup report\n"))
        XCTAssertTrue(csv.contains("Photos scanned,10\n"))
        XCTAssertTrue(csv.contains("Photos proposed for deletion,3\n"))
        XCTAssertTrue(csv.contains("Estimated space to reclaim,12 MB\n"))
        XCTAssertTrue(csv.contains("Category,Photos in group,Photos to delete,Space to reclaim (estimate),Why grouped\n"))
        XCTAssertTrue(csv.contains("Exact duplicates,3,2,8 MB,Same file contents.\n"))
        XCTAssertTrue(csv.contains("Similar photos,2,1,4 MB,Visually similar photos.\n"))
        XCTAssertTrue(csv.contains("Large video,Size (estimate),Duration\n"))
        XCTAssertTrue(csv.contains("Video 1,1.2 GB,3:02\n"))
        XCTAssertTrue(csv.contains("Total groups,2\n"))
        XCTAssertTrue(csv.contains("Total large videos,1\n"))
        XCTAssertTrue(csv.contains("All sizes are estimates."))
    }

    func testCSVFieldEscapesCommasQuotesAndNewlines() {
        XCTAssertEqual(CleanupReport.csvField("plain"), "plain")
        XCTAssertEqual(CleanupReport.csvField("a,b"), "\"a,b\"")
        XCTAssertEqual(CleanupReport.csvField("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CleanupReport.csvField("line one\nline two"), "\"line one\nline two\"")
    }

    func testEmptyResultStillProducesAReport() {
        let empty = ScanResult(groups: [], totalScanned: 0, totalLibraryCount: 0, scannedAt: base)
        let csv = CleanupReport.csv(for: empty)
        XCTAssertTrue(csv.contains("Photos scanned,0\n"))
        XCTAssertTrue(csv.contains("Photos proposed for deletion,0\n"))
        XCTAssertTrue(csv.contains("Total groups,0\n"))
        XCTAssertFalse(csv.contains("Large video,"))
    }

    func testFileNameUsesISODate() {
        XCTAssertEqual(
            CleanupReport.fileName(for: Date(timeIntervalSince1970: 0)),
            "photosweep-cleanup-report-1970-01-01.csv"
        )
    }

    func testDurationFormatsAsMinutesAndSeconds() {
        XCTAssertEqual(CleanupReport.formattedDuration(182), "3:02")
        XCTAssertEqual(CleanupReport.formattedDuration(61), "1:01")
        XCTAssertEqual(CleanupReport.formattedDuration(45), "0:45")
    }
}
