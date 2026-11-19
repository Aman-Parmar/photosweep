import Foundation

@testable import PhotoSweep

/// Shared factory for the synthetic PhotoItem used across the test
/// suites. Five test files each built the same item inline (same
/// 4032x3024 dimensions, same 0.8 sharpness / 0.7 brightness, same
/// 2025-10-09 base date); the construction now lives here once, and
/// each file keeps a thin `item(...)` wrapper with its own defaults
/// so no call site changes.
enum PhotoItemFixture {

    /// 2025-10-09, the shared sample date for every test item.
    static let baseDate = Date(timeIntervalSince1970: 1_760_000_000)

    static func make(
        id: String,
        hash: String? = nil,
        size: Int64 = 1_000_000,
        width: Int = 4032,
        height: Int = 3024,
        isScreenshot: Bool = false,
        isBurst: Bool = false,
        isVideo: Bool = false,
        duration: TimeInterval = 0,
        date: Date? = nil,
        dateOffset: TimeInterval = 0,
        sharpness: Double = 0.8,
        brightness: Double = 0.7,
        print: [Float]? = nil
    ) -> PhotoItem {
        PhotoItem(
            id: id,
            contentHash: hash,
            fileSize: size,
            width: width, height: height,
            isScreenshot: isScreenshot,
            isBurst: isBurst,
            isVideo: isVideo,
            duration: duration,
            creationDate: date ?? baseDate.addingTimeInterval(dateOffset),
            sharpness: sharpness,
            brightness: brightness,
            featurePrint: print
        )
    }
}
