import Foundation

/// Video compression: presets and size estimates. Pure Foundation-only
/// logic, Linux-testable (see Package.swift).
///
/// Compression is on-device HEVC (see Services/VideoCompressor.swift):
/// the compressed copy is saved to Photos and the original moves to
/// Recently Deleted, where it can be recovered for 30 days. Nothing is
/// auto-deleted, and compression never runs without the user picking a
/// preset and tapping Compress.
///
/// The estimate model is deliberately conservative and labelled as an
/// estimate everywhere it is shown: a nominal HEVC bitrate per preset
/// times the duration, clamped so the estimate never exceeds the
/// original file. Real files vary with content; the sheet shows the
/// estimate before compressing and the real saving after.
public enum CompressionPreset: String, CaseIterable, Equatable {
    /// 1080p cap, highest HEVC bitrate. Best quality, least saving.
    case high
    /// 720p cap, mid bitrate. The default: visibly the same on a phone
    /// screen, roughly half the size of a 4K original.
    case balanced
    /// 480p cap, lowest bitrate. Smallest file, for clips kept only as
    /// a memory rather than to watch.
    case small

    /// Display name shown in the preset picker.
    public var displayName: String {
        switch self {
        case .high: return "High quality"
        case .balanced: return "Balanced"
        case .small: return "Smallest file"
        }
    }

    /// Short factual detail shown under the preset name.
    public var detail: String {
        switch self {
        case .high: return "Up to 1080p, HEVC"
        case .balanced: return "Up to 720p, HEVC"
        case .small: return "Up to 480p, HEVC"
        }
    }

    /// Longest side of the exported frame, in pixels. The export
    /// never upscales: a 720p original stays 720p under the High
    /// preset.
    public var maxDimension: Int {
        switch self {
        case .high: return 1920
        case .balanced: return 1280
        case .small: return 854
        }
    }

    /// Nominal HEVC bitrate used for the before/after estimate, in
    /// bits per second. HEVC at these rates is roughly half the size
    /// of the H.264 originals iPhones record.
    public var nominalBitrateBitsPerSecond: Int64 {
        switch self {
        case .high: return 8_000_000
        case .balanced: return 4_000_000
        case .small: return 1_500_000
        }
    }
}

/// The before/after size estimate for one video at one preset.
/// Conforms to `SizeSavingEstimate`: the result size is the
/// estimated compressed size, and `bytesSaved` / `savingsPercent` /
/// `isWorthwhile` come from the shared defaults.
public struct CompressionEstimate: Equatable, SizeSavingEstimate {
    public let preset: CompressionPreset
    /// The original file size, in bytes.
    public let originalBytes: Int64
    /// The estimated compressed size, in bytes. Never above the
    /// original: a short or already-small clip estimates as "about
    /// the same" rather than a false saving.
    public let estimatedBytes: Int64

    public init(preset: CompressionPreset, originalBytes: Int64, estimatedBytes: Int64) {
        self.preset = preset
        self.originalBytes = originalBytes
        self.estimatedBytes = estimatedBytes
    }

    /// The size after compression, for the shared estimate math.
    public var resultBytes: Int64 { estimatedBytes }
}

public enum VideoCompression {

    /// Frame size the export targets for an original of the given
    /// pixel dimensions at this preset. Preserves aspect ratio, never
    /// upscales, and rounds each side down to an even number (HEVC
    /// requires even dimensions). The longer side caps at the preset's
    /// maxDimension; the shorter side scales proportionally.
    public static func targetSize(
        originalWidth: Int,
        originalHeight: Int,
        preset: CompressionPreset
    ) -> (width: Int, height: Int) {
        let maxSide = max(originalWidth, originalHeight)
        guard maxSide > preset.maxDimension, maxSide > 0 else {
            return (even(originalWidth), even(originalHeight))
        }
        let scale = Double(preset.maxDimension) / Double(maxSide)
        // Round to nearest, not floor: a float scale of 1280/3840 is
        // a hair under 1/3, so flooring 3840 * scale gives 1279
        // instead of 1280. `even` then rounds down, so the result
        // never exceeds the cap.
        return (
            width: even(Int((Double(originalWidth) * scale).rounded())),
            height: even(Int((Double(originalHeight) * scale).rounded()))
        )
    }

    /// Size estimate for compressing a clip of this size and duration
    /// at this preset. Bitrate times duration, clamped to the
    /// original size. A zero or negative duration estimates as no
    /// saving rather than inventing one.
    public static func estimate(
        originalBytes: Int64,
        duration: TimeInterval,
        preset: CompressionPreset
    ) -> CompressionEstimate {
        guard originalBytes > 0, duration > 0 else {
            return CompressionEstimate(preset: preset, originalBytes: originalBytes, estimatedBytes: originalBytes)
        }
        let byBitrate = Int64((Double(preset.nominalBitrateBitsPerSecond) * duration / 8.0).rounded())
        let estimated = min(originalBytes, byBitrate)
        return CompressionEstimate(preset: preset, originalBytes: originalBytes, estimatedBytes: estimated)
    }

    // MARK: - Private

    /// Rounds down to an even number, minimum 2 (a zero dimension
    /// is not a frame).
    private static func even(_ value: Int) -> Int {
        max(2, value - (value % 2))
    }
}
