import Foundation
import XCTest

import PhotoSweepLogic

/// Video compression presets and estimates: the three presets are
/// ordered by saving, estimates never exceed the original, and the
/// target frame size preserves aspect ratio without upscaling.
final class VideoCompressionTests: XCTestCase {

    /// A 4K clip, 3 minutes, 1.25 GB: the sample video-0 shape.
    private let originalBytes: Int64 = 1_250_000_000
    private let duration: TimeInterval = 182

    func testPresetsAreOrderedBySaving() {
        let high = VideoCompression.estimate(originalBytes: originalBytes, duration: duration, preset: .high)
        let balanced = VideoCompression.estimate(originalBytes: originalBytes, duration: duration, preset: .balanced)
        let small = VideoCompression.estimate(originalBytes: originalBytes, duration: duration, preset: .small)
        XCTAssertGreaterThan(high.estimatedBytes, balanced.estimatedBytes)
        XCTAssertGreaterThan(balanced.estimatedBytes, small.estimatedBytes)
        XCTAssertGreaterThan(small.bytesSaved, 0)
    }

    func testEstimateMathForSampleClip() {
        // Balanced: 4 Mbps * 182 s / 8 = 91 MB estimated, ~93% saving.
        let estimate = VideoCompression.estimate(originalBytes: originalBytes, duration: duration, preset: .balanced)
        XCTAssertEqual(estimate.estimatedBytes, 91_000_000)
        XCTAssertEqual(estimate.bytesSaved, 1_159_000_000)
        XCTAssertEqual(estimate.savingsPercent, 93)
        XCTAssertTrue(estimate.isWorthwhile)
    }

    func testEstimateNeverExceedsOriginal() {
        // A tiny clip whose bitrate estimate is bigger than the file:
        // the estimate clamps to the original, saving zero.
        let estimate = VideoCompression.estimate(originalBytes: 500_000, duration: 2, preset: .high)
        XCTAssertEqual(estimate.estimatedBytes, 500_000)
        XCTAssertEqual(estimate.bytesSaved, 0)
        XCTAssertEqual(estimate.savingsPercent, 0)
        XCTAssertFalse(estimate.isWorthwhile)
    }

    func testZeroDurationEstimatesNoSaving() {
        let estimate = VideoCompression.estimate(originalBytes: originalBytes, duration: 0, preset: .small)
        XCTAssertEqual(estimate.estimatedBytes, originalBytes)
        XCTAssertEqual(estimate.bytesSaved, 0)
    }

    func testTargetSizePreservesAspectAndCapsLongSide() {
        // 4K landscape at Balanced (1280 cap): 3840x2160 -> 1280x720.
        let balanced = VideoCompression.targetSize(originalWidth: 3840, originalHeight: 2160, preset: .balanced)
        XCTAssertEqual(balanced.width, 1280)
        XCTAssertEqual(balanced.height, 720)
        // Same clip at High (1920 cap): 3840x2160 -> 1920x1080.
        let high = VideoCompression.targetSize(originalWidth: 3840, originalHeight: 2160, preset: .high)
        XCTAssertEqual(high.width, 1920)
        XCTAssertEqual(high.height, 1080)
    }

    func testTargetSizeNeverUpscales() {
        // A 720p original under the High preset keeps its own size.
        let size = VideoCompression.targetSize(originalWidth: 1280, originalHeight: 720, preset: .high)
        XCTAssertEqual(size.width, 1280)
        XCTAssertEqual(size.height, 720)
    }

    func testTargetSizeRoundsDownToEven() {
        // Odd dimensions round down to even (HEVC requirement), and a
        // portrait clip caps its long side.
        let size = VideoCompression.targetSize(originalWidth: 1081, originalHeight: 1921, preset: .balanced)
        XCTAssertEqual(size.width, 720)
        XCTAssertEqual(size.height, 1280)
        XCTAssertEqual(size.width % 2, 0)
        XCTAssertEqual(size.height % 2, 0)
    }
}
