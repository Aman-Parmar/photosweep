import Foundation
import XCTest

@testable import PhotoSweep

/// Keeper picking (sharpest, then most pixels, then largest file, then
/// earliest date), storage estimates, and the never-auto-delete rule.
final class StorageAndKeeperTests: XCTestCase {

    private func item(
        id: String,
        size: Int64 = 1_000_000,
        width: Int = 4032,
        height: Int = 3024,
        sharpness: Double = 0.8,
        dateOffset: TimeInterval = 0
    ) -> PhotoItem {
        PhotoItemFixture.make(
            id: id,
            size: size,
            width: width,
            height: height,
            dateOffset: dateOffset,
            sharpness: sharpness,
            // The old helper relied on the model default (0.5), not
            // the fixture's 0.7, so it is pinned here explicitly.
            brightness: 0.5
        )
    }

    // MARK: - Keeper

    func testKeeperIsSharpest() {
        let items = [
            item(id: "blurry", sharpness: 0.3),
            item(id: "sharp", sharpness: 0.9),
            item(id: "mid", sharpness: 0.6),
        ]
        XCTAssertEqual(KeeperPicker.pickKeeper(from: items).id, "sharp")
    }

    func testKeeperTieBreaksOnPixelCount() {
        let items = [
            item(id: "small", width: 1920, height: 1080, sharpness: 0.8),
            item(id: "big", width: 4032, height: 3024, sharpness: 0.8),
        ]
        XCTAssertEqual(KeeperPicker.pickKeeper(from: items).id, "big")
    }

    func testKeeperTieBreaksOnFileSize() {
        let items = [
            item(id: "compressed", size: 1_000_000, sharpness: 0.8),
            item(id: "full", size: 4_000_000, sharpness: 0.8),
        ]
        XCTAssertEqual(KeeperPicker.pickKeeper(from: items).id, "full")
    }

    func testKeeperTieBreaksOnEarliestDate() {
        let items = [
            item(id: "later", dateOffset: 100),
            item(id: "earlier", dateOffset: 0),
        ]
        XCTAssertEqual(KeeperPicker.pickKeeper(from: items).id, "earlier")
    }

    func testIsKeeper() {
        let group = PhotoGroup(
            id: "g", kind: .exactDuplicate,
            items: [item(id: "a"), item(id: "b")],
            keeperID: "b",
            matchReason: "test"
        )
        XCTAssertTrue(KeeperPicker.isKeeper(item(id: "b"), in: group))
        XCTAssertFalse(KeeperPicker.isKeeper(item(id: "a"), in: group))
    }

    // MARK: - Storage estimates

    func testFormattedGigabytes() {
        XCTAssertEqual(StorageEstimator.formatted(1_250_000_000), "1.2 GB")
        XCTAssertEqual(StorageEstimator.formatted(2_700_000_000), "2.7 GB")
    }

    func testFormattedMegabytes() {
        XCTAssertEqual(StorageEstimator.formatted(850_000_000), "850 MB")
        XCTAssertEqual(StorageEstimator.formatted(4_200_000), "4 MB")
    }

    func testFormattedKilobytesAndBytes() {
        XCTAssertEqual(StorageEstimator.formatted(42_000), "42 KB")
        XCTAssertEqual(StorageEstimator.formatted(500), "500 B")
    }

    func testFreesLabel() {
        XCTAssertEqual(StorageEstimator.freesLabel(1_250_000_000), "Frees ~1.2 GB")
    }

    func testApprox() {
        XCTAssertEqual(StorageEstimator.approx(1_250_000_000), "~1.2 GB")
        XCTAssertEqual(StorageEstimator.approx(500), "~500 B")
    }

    func testOriginalDetailLine() {
        let photo = PhotoItemFixture.make(id: "p", size: 6_000_000)
        XCTAssertEqual(photo.originalDetailLine(), "6 MB · 4032 x 3024")
        let video = PhotoItemFixture.make(id: "v", size: 2_700_000_000, isVideo: true, duration: 182)
        XCTAssertEqual(video.originalDetailLine(duration: video.duration), "2.7 GB · 3:02 · 4032 x 3024")
    }

    func testReclaimableBytesSums() {
        XCTAssertEqual(
            StorageEstimator.reclaimableBytes(for: [item(id: "a", size: 100), item(id: "b", size: 200)]),
            300
        )
        XCTAssertEqual(StorageEstimator.reclaimableBytes(for: []), 0)
    }

    // MARK: - Never auto-delete

    func testUnconfirmedDeletionIsNotExecutable() {
        let request = DeletionRequest(groupID: "g", itemIDs: ["a", "b"], confirmedByUser: false)
        XCTAssertFalse(request.isExecutable)
    }

    func testEmptyDeletionIsNotExecutable() {
        let request = DeletionRequest(groupID: "g", itemIDs: [], confirmedByUser: true)
        XCTAssertFalse(request.isExecutable)
    }

    func testConfirmedNonEmptyDeletionIsExecutable() {
        let request = DeletionRequest(groupID: "g", itemIDs: ["a"], confirmedByUser: true)
        XCTAssertTrue(request.isExecutable)
    }
}
