import Foundation
import Photos
import UIKit

/// The real on-device scanner. Reads the user's Photos library,
/// converts each asset into a compact `PhotoItem` (metadata + signals),
/// and hands the list to `GroupingEngine`.
///
/// Privacy, by design:
/// - Everything runs on-device. No photo, thumbnail, or hash ever
///   leaves the phone. There is no network call anywhere in this file.
/// - Limited photo access is supported: the scanner only sees what the
///   user granted, and `ScanResult.isPartialScan` tells the UI to say
///   so plainly ("Scanned 214 of 12,400 photos — grant full access to
///   scan the rest").
/// - Feature prints are computed in-memory and cached for the scan
///   only; they are not persisted anywhere.
///
/// Real-device note (Phase 1+): the simulator has a tiny, synthetic
/// library, so a 10,000-photo library can only be verified on a real
/// device. The neighbour-window grouping exists precisely so a large
/// library scans in linear time — verify the wall-clock on device
/// before promising a scan time in the listing.
@MainActor
final class PhotoScanner: ObservableObject {

    enum ScanError: LocalizedError {
        case accessDenied
        case accessRestricted

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Photo access is off. Turn it on in Settings to scan your library."
            case .accessRestricted:
                return "Photo access is restricted on this device."
            }
        }
    }

    @Published private(set) var isScanning = false
    @Published private(set) var progress: Double = 0

    /// Requests photo access (read-only, `.readWrite` is only needed
    /// for deletion, which happens later via PHAssetChangeRequest).
    /// Returns the granted status.
    func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Scans the library the user granted access to and returns the
    /// grouped result. Throws when access is denied or restricted.
    /// Feature prints are computed per asset and cached in-memory for
    /// the duration of this call only.
    func scan() async throws -> ScanResult {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .denied, .limited:
            // Limited access is usable — scan what was granted. Denied
            // is not: there is nothing to scan.
            if status == .denied { throw ScanError.accessDenied }
        case .restricted:
            throw ScanError.accessRestricted
        case .notDetermined:
            let granted = await requestAccess()
            if granted == .denied { throw ScanError.accessDenied }
            if granted == .restricted { throw ScanError.accessRestricted }
        case .authorized:
            break
        @unknown default:
            break
        }

        isScanning = true
        progress = 0
        defer {
            isScanning = false
            progress = 1
        }

        let fetchResult = PHAsset.fetchAssets(with: nil)
        let totalLibrary = fetchResult.count
        var items: [PhotoItem] = []
        items.reserveCapacity(totalLibrary)

        // Feature-print cache: one print per asset, computed lazily.
        // Prints are ~1 KB each; even 10,000 assets is ~10 MB in memory.
        let total = max(totalLibrary, 1)
        for index in 0..<totalLibrary {
            let asset = fetchResult.object(at: index)
            if let item = await item(for: asset) {
                items.append(item)
            }
            if index % 50 == 0 {
                progress = Double(index) / Double(total)
            }
        }

        let (groups, largeVideos) = GroupingEngine.group(items)
        let livePhotos = items
            .filter { $0.isLivePhoto }
            .sorted { $0.fileSize > $1.fileSize }
        return ScanResult(
            groups: groups,
            totalScanned: items.count,
            totalLibraryCount: totalLibrary,
            largeVideos: largeVideos,
            livePhotos: livePhotos
        )
    }

    /// Deletes the items in a confirmed request. The request must be
    /// user-confirmed (`DeletionRequest.isExecutable`) — this method
    /// refuses anything else, so a code path can never auto-delete.
    /// Deletion goes through PHAssetChangeRequest, which moves items to
    /// Recently Deleted (undoable for 30 days in Photos).
    func delete(_ request: DeletionRequest, assets: [PHAsset]) async throws {
        guard request.isExecutable else { return }
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }

    // MARK: - Private

    /// Converts one PHAsset into a PhotoItem, computing the image
    /// signals (average hash, gradient sharpness, brightness) from a
    /// downscaled thumbnail.
    /// Returns nil when the asset cannot be read.
    private func item(for asset: PHAsset) async -> PhotoItem? {
        let resources = PHAssetResource.assetResources(for: asset)
        let fileSize = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
        let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        let isBurst = asset.representsBurst
        let isLivePhoto = asset.mediaSubtypes.contains(.photoLive)

        // Downscaled image: 512 px is enough for an average hash and
        // gradient sharpness, and keeps the scan fast.
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        let targetSize = CGSize(width: 512, height: 512)
        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        guard let image, let cgImage = image.cgImage else {
            // No image (e.g. iCloud-only asset that failed to download):
            // still include the item with metadata only. It can be
            // grouped by hash/time, just not by similarity.
            return PhotoItem(
                id: asset.localIdentifier,
                fileSize: fileSize,
                width: asset.pixelWidth,
                height: asset.pixelHeight,
                isScreenshot: isScreenshot,
                isBurst: isBurst,
                isVideo: asset.mediaType == .video,
                isLivePhoto: isLivePhoto,
                duration: asset.duration,
                creationDate: asset.creationDate ?? Date()
            )
        }

        let (print, sharpness, brightness) = visionSignals(for: cgImage)
        return PhotoItem(
            id: asset.localIdentifier,
            fileSize: fileSize,
            width: asset.pixelWidth,
            height: asset.pixelHeight,
            isScreenshot: isScreenshot,
            isBurst: isBurst,
            isVideo: asset.mediaType == .video,
            isLivePhoto: isLivePhoto,
            duration: asset.duration,
            creationDate: asset.creationDate ?? Date(),
            sharpness: sharpness,
            brightness: brightness,
            featurePrint: print
        )
    }

    /// Computes the on-device image signals: an average-hash vector
    /// for similarity, a gradient-energy sharpness score, and mean
    /// brightness. All CoreGraphics, all on-device, no Vision call.
    ///
    /// Why no Vision aesthetics request: `VNGenerateImageAestheticsScoresRequest`
    /// does not exist in the iOS 17 SDK this app targets, so v1
    /// measures sharpness as gradient energy instead — the mean
    /// absolute difference between neighbouring pixels in a 64x64
    /// greyscale downscale, normalised so a mean difference of ~25
    /// grey levels scores 1.0 and ~7.5 scores 0.30 (the blurry
    /// threshold in `SimilarityEngine`). Blurry photos have little
    /// high-frequency energy; sharp photos have a lot. The calibration
    /// is approximate — tune it against real libraries in v1.1 (see
    /// ROADMAP). A dedicated blur detector (Laplacian variance) is a
    /// Phase 1+ refinement.
    private func visionSignals(for cgImage: CGImage) -> ([Float]?, Double, Double) {
        let (hash, brightness) = averageHashAndBrightness(for: cgImage)
        let sharpness = gradientSharpness(for: cgImage)
        return (hash, sharpness, brightness)
    }

    /// Gradient energy: mean absolute difference between horizontally
    /// and vertically adjacent pixels in a 64x64 greyscale downscale,
    /// divided by 25 (see `visionSignals` for the calibration).
    private func gradientSharpness(for cgImage: CGImage) -> Double {
        let width = 64, height = 64
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0.5 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return 0.5 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        var total = 0
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let current = Int(pixels[y * width + x])
                if x + 1 < width {
                    total += abs(current - Int(pixels[y * width + x + 1]))
                    count += 1
                }
                if y + 1 < height {
                    total += abs(current - Int(pixels[(y + 1) * width + x]))
                    count += 1
                }
            }
        }
        guard count > 0 else { return 0.5 }
        return min(1.0, (Double(total) / Double(count)) / 25.0)
    }

    /// Average hash (aHash) + mean brightness from one 8x8 greyscale
    /// downscale: one float per pixel (1.0 above the mean, 0.0 below),
    /// and brightness as the mean luminance (0...1). Two near-identical
    /// images produce near-identical hashes, so Euclidean distance on
    /// these 64 floats works as a similarity signal — the same
    /// `SimilarityEngine.featureDistance` the tests pin.
    private func averageHashAndBrightness(for cgImage: CGImage) -> ([Float], Double) {
        let width = 8, height = 8
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return ([], 0.5) }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return ([], 0.5) }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        var sum = 0
        for i in 0..<(width * height) { sum += Int(pixels[i]) }
        let mean = Double(sum) / Double(width * height)
        let brightness = mean / 255.0
        let hash: [Float] = (0..<(width * height)).map { Double(pixels[$0]) > mean ? 1.0 : 0.0 }.map(Float.init)
        return (hash, brightness)
    }
}
