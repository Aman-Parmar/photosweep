import Foundation
import XCTest

import PhotoSweepLogic

/// Similarity signals: feature-print distance, exact-hash matching,
/// blurry/dark detection, burst pairing. A missing feature print is
/// never a match — that rule is pinned here.
final class SimilarityEngineTests: XCTestCase {

    private func item(
        id: String,
        hash: String? = nil,
        sharpness: Double = 0.8,
        brightness: Double = 0.7,
        print: [Float]? = nil,
        burst: Bool = false,
        screenshot: Bool = false,
        video: Bool = false,
        dateOffset: TimeInterval = 0
    ) -> PhotoItem {
        PhotoItemFixture.make(
            id: id,
            hash: hash,
            isScreenshot: screenshot,
            isBurst: burst,
            isVideo: video,
            dateOffset: dateOffset,
            sharpness: sharpness,
            brightness: brightness,
            print: print
        )
    }

    // MARK: - Feature distance

    func testDistanceOfIdenticalPrintsIsZero() {
        let print: [Float] = [0.1, 0.2, 0.3, 0.4]
        XCTAssertEqual(SimilarityEngine.featureDistance(print, print), 0)
    }

    func testDistancePythagorean() {
        XCTAssertEqual(
            SimilarityEngine.featureDistance([0, 0], [3, 4]),
            5
        )
    }

    func testDistanceNilWhenPrintMissing() {
        XCTAssertNil(SimilarityEngine.featureDistance(nil, [1, 2]))
        XCTAssertNil(SimilarityEngine.featureDistance([1, 2], nil))
        XCTAssertNil(SimilarityEngine.featureDistance(nil, nil))
    }

    func testDistanceNilWhenLengthsDiffer() {
        XCTAssertNil(SimilarityEngine.featureDistance([1, 2], [1, 2, 3]))
    }

    func testDistanceNilWhenEmpty() {
        XCTAssertNil(SimilarityEngine.featureDistance([], []))
    }

    // MARK: - Exact duplicates

    func testExactDuplicatesShareHash() {
        XCTAssertTrue(SimilarityEngine.areExactDuplicates(
            item(id: "a", hash: "abc"),
            item(id: "b", hash: "abc")
        ))
    }

    func testDifferentHashesAreNotExactDuplicates() {
        XCTAssertFalse(SimilarityEngine.areExactDuplicates(
            item(id: "a", hash: "abc"),
            item(id: "b", hash: "def")
        ))
    }

    func testNilHashIsNeverAnExactDuplicate() {
        XCTAssertFalse(SimilarityEngine.areExactDuplicates(
            item(id: "a", hash: nil),
            item(id: "b", hash: nil)
        ))
        XCTAssertFalse(SimilarityEngine.areExactDuplicates(
            item(id: "a", hash: "abc"),
            item(id: "b", hash: nil)
        ))
    }

    // MARK: - Similar

    func testSimilarWhenDistanceUnderThreshold() {
        let base: [Float] = Array(repeating: 0.5, count: 64)
        let near: [Float] = base.enumerated().map { $0.offset % 2 == 0 ? $0.element + 0.02 : $0.element - 0.02 }
        XCTAssertTrue(SimilarityEngine.areSimilar(
            item(id: "a", print: base),
            item(id: "b", print: near)
        ))
    }

    func testNotSimilarWhenDistanceOverThreshold() {
        let a: [Float] = Array(repeating: 0, count: 64)
        let b: [Float] = Array(repeating: 1, count: 64)
        XCTAssertFalse(SimilarityEngine.areSimilar(
            item(id: "a", print: a),
            item(id: "b", print: b)
        ))
    }

    func testNotSimilarWhenPrintMissing() {
        XCTAssertFalse(SimilarityEngine.areSimilar(
            item(id: "a", print: nil),
            item(id: "b", print: Array(repeating: 0.5, count: 64))
        ))
    }

    // MARK: - Blurry / dark

    func testBlurryWhenSharpnessLow() {
        XCTAssertTrue(SimilarityEngine.isBlurryOrDark(item(id: "a", sharpness: 0.2)))
    }

    func testDarkWhenBrightnessLow() {
        XCTAssertTrue(SimilarityEngine.isBlurryOrDark(item(id: "a", brightness: 0.1)))
    }

    func testNormalPhotoIsNotBlurry() {
        XCTAssertFalse(SimilarityEngine.isBlurryOrDark(item(id: "a")))
    }

    func testScreenshotIsNeverBlurry() {
        XCTAssertFalse(SimilarityEngine.isBlurryOrDark(
            item(id: "a", sharpness: 0.1, screenshot: true)
        ))
    }

    func testVideoIsNeverBlurry() {
        XCTAssertFalse(SimilarityEngine.isBlurryOrDark(
            item(id: "a", sharpness: 0.1, video: true)
        ))
    }

    // MARK: - Burst

    func testBurstPairWithinTenSeconds() {
        XCTAssertTrue(SimilarityEngine.areBurstPair(
            item(id: "a", burst: true, dateOffset: 0),
            item(id: "b", burst: true, dateOffset: 9)
        ))
    }

    func testBurstPairOverTenSecondsIsNotAPair() {
        XCTAssertFalse(SimilarityEngine.areBurstPair(
            item(id: "a", burst: true, dateOffset: 0),
            item(id: "b", burst: true, dateOffset: 11)
        ))
    }

    func testNonBurstPhotosAreNotABurstPair() {
        XCTAssertFalse(SimilarityEngine.areBurstPair(
            item(id: "a", burst: false, dateOffset: 0),
            item(id: "b", burst: true, dateOffset: 1)
        ))
    }
}
