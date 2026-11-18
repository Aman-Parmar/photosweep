import Foundation
import SwiftData

/// Screenshot mode: deterministic, offline, synthetic-sample-only runs
/// for the UITest screenshot lane. Enabled by the `--screenshot-mode`
/// launch argument (set by `UITests/ScreenshotTests.swift`) or the
/// `PHOTOSWEEP_SCREENSHOT_MODE=1` environment variable. Never enabled
/// in a shipping build: the App Store build has no launch argument and
/// no env var.
///
/// In screenshot mode:
/// - The scan result is the fixed synthetic sample (see
///   `SampleData/SampleScan.swift`) — no PhotoKit, no real photos.
/// - Thumbnails are programmatically generated images (see
///   `SampleData/SampleImageGenerator.swift`), never real user photos.
/// - History is seeded with one sample scan record.
///
/// Real simulator screenshots from CI, never mockups. Every sample
/// image is clearly synthetic (flat gradients + a label) so no one
/// mistakes it for a real photo.
enum ScreenshotMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
            || ProcessInfo.processInfo.environment["PHOTOSWEEP_SCREENSHOT_MODE"] == "1"
    }
}

/// Seeds SwiftData with one sample scan record, but only in screenshot
/// mode, and only once per launch.
@MainActor
enum ScreenshotSeeder {
    static func seedIfNeeded(modelContext: ModelContext) {
        guard ScreenshotMode.isEnabled else { return }
        let existing = (try? modelContext.fetchCount(FetchDescriptor<ScanRecord>())) ?? 0
        guard existing == 0 else { return }
        modelContext.insert(ScanRecord(result: SampleScan.result))
        try? modelContext.save()
    }
}
