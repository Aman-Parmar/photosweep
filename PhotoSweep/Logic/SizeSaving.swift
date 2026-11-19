import Foundation

/// Shared before/after size-estimate math for the two actions that
/// shrink a file: video compression and Live Photo to still
/// conversion. Both estimates carry an original size and a saved
/// size, and both answer the same two questions with the same
/// numbers, so the math lives here once instead of once per estimate
/// struct. Pure Foundation-only logic, Linux-testable.
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
