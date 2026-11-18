import Foundation

/// Live Photo to still conversion: size estimates. Pure Foundation-only
/// logic, Linux-testable (see Package.swift).
///
/// A Live Photo is a still photo plus a short video clip, so it runs
/// 1.5-3x the size of the still alone (ROADMAP evidence). Converting
/// keeps the still and drops the video: the still is saved as a new
/// photo, and the Live Photo moves to Recently Deleted, where it can
/// be recovered for 30 days. The estimate uses the midpoint of the
/// evidence range (2x), so the still is about half the Live Photo and
/// the saving is about half. Real files vary with the clip length; the
/// sheet shows the estimate before converting and the real saving
/// after.
public struct LivePhotoEstimate: Equatable {
    /// The Live Photo file size, in bytes.
    public let originalBytes: Int64
    /// The estimated still-photo size, in bytes.
    public let estimatedStillBytes: Int64

    public init(originalBytes: Int64, estimatedStillBytes: Int64) {
        self.originalBytes = originalBytes
        self.estimatedStillBytes = estimatedStillBytes
    }

    /// Estimated bytes saved. Zero when conversion is not expected
    /// to shrink this photo.
    public var bytesSaved: Int64 { max(0, originalBytes - estimatedStillBytes) }

    /// Estimated saving as a whole percent of the original, 0...100.
    public var savingsPercent: Int {
        guard originalBytes > 0 else { return 0 }
        return Int((Double(bytesSaved) / Double(originalBytes) * 100).rounded())
    }

    /// True when the estimate says conversion is worth doing for
    /// this photo (saves at least 10%).
    public var isWorthwhile: Bool { savingsPercent >= 10 }
}

public enum LivePhotoConversion {

    /// Size estimate for converting a Live Photo of this size to a
    /// still. The still is about half the Live Photo: the evidence
    /// range is 1.5-3x, and the midpoint (2x) is the estimate. A zero
    /// or negative size estimates as no saving rather than inventing
    /// one.
    public static func estimate(originalBytes: Int64) -> LivePhotoEstimate {
        guard originalBytes > 0 else {
            return LivePhotoEstimate(originalBytes: originalBytes, estimatedStillBytes: originalBytes)
        }
        return LivePhotoEstimate(originalBytes: originalBytes, estimatedStillBytes: originalBytes / 2)
    }
}
