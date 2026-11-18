import Foundation
import XCTest

import PhotoSweepLogic

/// The Live Photo estimate: the still is about half the Live Photo
/// (the evidence range is 1.5-3x, midpoint 2x), so converting saves
/// about half. The sheet shows this estimate before converting and
/// the real saving after.
final class LivePhotoConversionTests: XCTestCase {

    func testEstimateIsHalfTheOriginal() {
        let estimate = LivePhotoConversion.estimate(originalBytes: 6_400_000)
        XCTAssertEqual(estimate.estimatedStillBytes, 3_200_000)
        XCTAssertEqual(estimate.bytesSaved, 3_200_000)
        XCTAssertEqual(estimate.savingsPercent, 50)
        XCTAssertTrue(estimate.isWorthwhile)
    }

    func testEstimateNeverExceedsOriginal() {
        // A tiny Live Photo still estimates a still half its size:
        // the estimate is a fraction, never above the original.
        let estimate = LivePhotoConversion.estimate(originalBytes: 100)
        XCTAssertEqual(estimate.estimatedStillBytes, 50)
        XCTAssertEqual(estimate.bytesSaved, 50)
    }

    func testZeroSizeEstimatesNoSaving() {
        let estimate = LivePhotoConversion.estimate(originalBytes: 0)
        XCTAssertEqual(estimate.bytesSaved, 0)
        XCTAssertEqual(estimate.savingsPercent, 0)
        XCTAssertFalse(estimate.isWorthwhile)
    }

    func testNegativeSizeEstimatesNoSaving() {
        let estimate = LivePhotoConversion.estimate(originalBytes: -5)
        XCTAssertEqual(estimate.bytesSaved, 0)
        XCTAssertEqual(estimate.savingsPercent, 0)
        XCTAssertFalse(estimate.isWorthwhile)
    }
}
