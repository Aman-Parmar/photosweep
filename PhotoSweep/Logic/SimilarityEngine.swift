import Foundation

/// Similarity signals for photo grouping — pure math, no Vision import.
///
/// The on-device image work (average hash, gradient-energy sharpness,
/// mean brightness) happens in `Services/PhotoScanner`, which converts
/// each asset into the compact signals on `PhotoItem` (feature print,
/// sharpness, brightness). This file only decides, from those signals,
/// whether two items are the same, similar, blurry, or unrelated — so
/// it runs on Linux CI.
///
/// Apple Photos Duplicates (iOS 16+) already merges exact and
/// near-exact duplicates for free. PhotoSweep's job is what Apple does
/// NOT do: similar / burst shots, blurry / dark photos, screenshots,
/// and large videos. Exact-hash grouping is kept anyway, because a
/// user with limited photo access may have exact duplicates outside
/// the Duplicates album's reach, and because the tests pin the rule.
public enum SimilarityEngine {

    /// Feature-print distance at or below this is "visually similar".
    /// ~0.35 is the value reported for a 35k-photo cleanup using
    /// `VNFeaturePrintObservation.computeDistance`; it is a starting
    /// point, not a constant — looser groups unrelated same-scene
    /// photos, stricter misses recompressed copies. The threshold is
    /// one named constant so tuning it is a one-line change, and the
    /// tests pin the boundary behaviour.
    public static let similarDistanceThreshold: Float = 0.35

    /// Sharpness at or below this counts as blurry.
    public static let blurrySharpnessThreshold: Double = 0.30

    /// Brightness at or below this counts as dark.
    public static let darkBrightnessThreshold: Double = 0.15

    /// Euclidean distance between two feature-print vectors.
    /// Returns nil when the vectors are missing or of different lengths
    /// — a missing print is never a match (see `Types.PhotoItem`).
    public static func featureDistance(_ a: [Float]?, _ b: [Float]?) -> Float? {
        guard let a, let b, a.count == b.count, !a.isEmpty else { return nil }
        var sum: Float = 0
        for i in a.indices {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sum.squareRoot()
    }

    /// True when two items are visually similar: both have feature
    /// prints and their distance is at or below the threshold.
    /// Burst photos are similar by construction (same moment, tiny
    /// framing changes) — the caller also groups bursts by time.
    public static func areSimilar(_ a: PhotoItem, _ b: PhotoItem) -> Bool {
        guard let distance = featureDistance(a.featurePrint, b.featurePrint) else {
            return false
        }
        return distance <= similarDistanceThreshold
    }

    /// True when an item is blurry or dark enough to surface for review.
    /// Screenshots and videos are never "blurry" — they are categorised
    /// elsewhere, so a dark screenshot is not double-counted.
    public static func isBlurryOrDark(_ item: PhotoItem) -> Bool {
        guard !item.isScreenshot, !item.isVideo else { return false }
        return item.sharpness <= blurrySharpnessThreshold
            || item.brightness <= darkBrightnessThreshold
    }

    /// True when two items are part of one burst: both flagged burst and
    /// taken within 10 seconds of each other. Burst detection is a
    /// time rule, not a similarity rule — burst frames can look quite
    /// different (a person mid-jump) and still belong together.
    public static func areBurstPair(_ a: PhotoItem, _ b: PhotoItem) -> Bool {
        guard a.isBurst, b.isBurst else { return false }
        return abs(a.creationDate.timeIntervalSince(b.creationDate)) <= 10
    }
}
