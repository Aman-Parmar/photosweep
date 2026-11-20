import Foundation

/// Shared before/after size-estimate math for the two actions that
/// shrink a file: video compression and Live Photo to still
/// conversion. Both estimates carry an original size and a result
/// size, and both answer the same three questions from the same two
/// numbers, so the math lives here once instead of once per estimate
/// struct. Pure Foundation-only logic, Linux-testable.
///
/// The shared shape is the `SizeSavingEstimate` protocol below:
/// conforming structs supply `originalBytes` and `resultBytes`,
/// and `bytesSaved` / `savingsPercent` / `isWorthwhile` come from
/// the protocol defaults.
public protocol SizeSavingEstimate {

    /// The original file size, in bytes.
    var originalBytes: Int64 { get }

    /// The size after the action, in bytes.
    var resultBytes: Int64 { get }
}

public extension SizeSavingEstimate {

    /// Estimated bytes saved. Zero when the action is not expected
    /// to shrink this file.
    var bytesSaved: Int64 { max(0, originalBytes - resultBytes) }

    /// Estimated saving as a whole percent of the original, 0...100.
    var savingsPercent: Int {
        SizeSaving.percentSaved(originalBytes: originalBytes, bytesSaved: bytesSaved)
    }

    /// True when the estimate says the action is worth doing for
    /// this file (saves at least 10%).
    var isWorthwhile: Bool {
        SizeSaving.isWorthwhile(originalBytes: originalBytes, bytesSaved: bytesSaved)
    }
}

public enum SizeSaving {

    /// Saving as a whole percent of the original, 0...100. Zero when
    /// the original size is zero or unknown, rather than inventing a
    /// percent from a division by zero.
    public static func percentSaved(originalBytes: Int64, bytesSaved: Int64) -> Int {
        guard originalBytes > 0 else { return 0 }
        return Int((Double(bytesSaved) / Double(originalBytes) * 100).rounded())
    }

    /// True when the estimate says the action is worth doing for
    /// this file (saves at least 10%).
    public static func isWorthwhile(originalBytes: Int64, bytesSaved: Int64) -> Bool {
        percentSaved(originalBytes: originalBytes, bytesSaved: bytesSaved) >= 10
    }
}
