import Combine
import Photos
import SwiftUI

/// Shared app state: the current scan result, deletion flow, and the
/// free-tier delete budget.
///
/// Deletion rules (enforced here, not just in copy):
/// - Nothing is ever deleted without a user-confirmed
///   `DeletionRequest` (`confirmedByUser == true`).
/// - Deletion goes through `PHAssetChangeRequest`, which moves items
///   to Recently Deleted — undoable for 30 days in Photos.
/// - Free tier: 20 deletes total. Pro: unlimited. Large-video
///   cleanup is a Pro feature.
/// - In screenshot mode there is no real library: "deleting" a group
///   just removes it from the sample result and says so.
@MainActor
final class AppState: ObservableObject {
    /// Free-tier delete budget: 20 photos. Pro is unlimited.
    static let freeDeleteLimit = 20

    @Published private(set) var result: ScanResult?
    @Published private(set) var isScanning = false
    @Published private(set) var scanError: String?
    @Published private(set) var deletedCount: Int {
        didSet {
            UserDefaults.standard.set(deletedCount, forKey: "photosweep.deletedCount")
        }
    }

    /// Called with one event per confirmed deletion. Set by the app
    /// (which owns the SwiftData context) so AppState stays free of
    /// persistence details. Nil means "do not record", which is how
    /// unit tests run. Screenshot mode records too: it is test-only
    /// sample data, never a real library.
    var recordCleanup: ((CleanupEvent) -> Void)?

    private let scanner = PhotoScanner()

    init() {
        self.deletedCount = UserDefaults.standard.integer(forKey: "photosweep.deletedCount")
        if ScreenshotMode.isEnabled {
            self.result = SampleScan.result
        }
    }

    /// Groups of a kind, for the Results tab and category rows.
    func groups(of kind: GroupKind) -> [PhotoGroup] {
        result?.groups(of: kind) ?? []
    }

    /// Large videos, largest first.
    var largeVideos: [PhotoItem] {
        result?.largeVideos ?? []
    }

    /// Live Photos, largest first.
    var livePhotos: [PhotoItem] {
        result?.livePhotos ?? []
    }

    /// Runs a real scan (PhotoKit). In screenshot mode this is a no-op:
    /// the sample result is already loaded.
    func runScan() async {
        if ScreenshotMode.isEnabled {
            result = SampleScan.result
            return
        }
        isScanning = true
        scanError = nil
        defer { isScanning = false }
        do {
            result = try await scanner.scan()
        } catch {
            scanError = error.localizedDescription
        }
    }

    /// Remaining free deletes for a non-Pro user. Int.max for Pro.
    func remainingFreeDeletes(isPro: Bool) -> Int {
        isPro ? Int.max : max(0, Self.freeDeleteLimit - deletedCount)
    }

    /// Confirms deletion of a group's deletable items. Returns false
    /// when the free budget does not cover it (caller shows the
    /// paywall). In screenshot mode this only updates the sample.
    @discardableResult
    func confirmDelete(group: PhotoGroup, isPro: Bool) async -> Bool {
        let items = group.deletableItems
        guard !items.isEmpty else { return true }
        guard isPro || remainingFreeDeletes(isPro: false) >= items.count else {
            return false
        }
        if ScreenshotMode.isEnabled {
            removeGroup(group)
            deletedCount += items.count
            noteCleanup(items: items)
            return true
        }
        let request = DeletionRequest(groupID: group.id, itemIDs: items.map(\.id), confirmedByUser: true)
        let assets = fetchAssets(ids: items.map(\.id))
        do {
            try await scanner.delete(request, assets: assets)
        } catch {
            scanError = error.localizedDescription
            return false
        }
        removeGroup(group)
        deletedCount += items.count
        noteCleanup(items: items)
        return true
    }

    /// Confirms deletion of hand-picked items (Screenshots / Videos
    /// tabs). Same rules as `confirmDelete(group:)`.
    @discardableResult
    func confirmDelete(items: [PhotoItem], isPro: Bool) async -> Bool {
        guard !items.isEmpty else { return true }
        guard isPro || remainingFreeDeletes(isPro: false) >= items.count else {
            return false
        }
        if ScreenshotMode.isEnabled {
            removeItems(items)
            deletedCount += items.count
            noteCleanup(items: items)
            return true
        }
        let request = DeletionRequest(groupID: "manual", itemIDs: items.map(\.id), confirmedByUser: true)
        let assets = fetchAssets(ids: items.map(\.id))
        do {
            try await scanner.delete(request, assets: assets)
        } catch {
            scanError = error.localizedDescription
            return false
        }
        removeItems(items)
        deletedCount += items.count
        noteCleanup(items: items)
        return true
    }

    /// Result of a completed compression: the real bytes saved and
    /// the compressed file's real size.
    struct CompressionOutcome {
        let bytesSaved: Int64
        let compressedBytes: Int64
    }

    /// Compresses one large video at the chosen preset. The flow is:
    /// export an HEVC copy on-device, save the copy to Photos, then
    /// move the original to Recently Deleted (undoable for 30 days).
    /// The compressed copy is a new Photos asset; the original
    /// leaves the large-videos list. Pro feature: video cleanup is
    /// Pro depth, so a free user never reaches this (the sheet shows
    /// the paywall instead). Returns nil when the compression could
    /// not run, with `scanError` set.
    ///
    /// In screenshot mode there is no real library, so the export is
    /// simulated from the size estimate: progress animates, then the
    /// sample video leaves the list and the estimated saving is
    /// recorded, exactly as the real flow records the real saving.
    func compressVideo(
        item: PhotoItem,
        preset: CompressionPreset,
        isPro: Bool,
        progress: @escaping (Double) -> Void
    ) async -> CompressionOutcome? {
        guard isPro || ScreenshotMode.isEnabled else { return nil }
        if ScreenshotMode.isEnabled {
            let estimate = VideoCompression.estimate(
                originalBytes: item.fileSize, duration: item.duration, preset: preset)
            for step in 1...6 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                progress(Double(step) / 6.0)
            }
            removeItems([item])
            recordCleanup?(CleanupEvent(
                date: Date(), photosDeleted: 0, videosCompressed: 1, bytesFreed: estimate.bytesSaved))
            return CompressionOutcome(bytesSaved: estimate.bytesSaved, compressedBytes: estimate.estimatedBytes)
        }
        guard let asset = fetchAssets(ids: [item.id]).first else {
            scanError = "Could not find that video in Photos."
            return nil
        }
        do {
            guard let avAsset = await requestAVAsset(for: asset) else {
                scanError = "Could not read that video."
                return nil
            }
            let exported = try await VideoCompressor.export(asset: avAsset, preset: preset, progress: progress)
            defer { try? FileManager.default.removeItem(at: exported.fileURL) }
            try await PHPhotoLibrary.shared().performChanges {
                _ = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: exported.fileURL)
            }
            let request = DeletionRequest(groupID: "compress", itemIDs: [item.id], confirmedByUser: true)
            try await scanner.delete(request, assets: [asset])
            let bytesSaved = max(0, item.fileSize - exported.fileSize)
            removeItems([item])
            recordCleanup?(CleanupEvent(
                date: Date(), photosDeleted: 0, videosCompressed: 1, bytesFreed: bytesSaved))
            return CompressionOutcome(bytesSaved: bytesSaved, compressedBytes: exported.fileSize)
        } catch {
            scanError = error.localizedDescription
            return nil
        }
    }

    /// Result of a completed Live Photo conversion: the real bytes
    /// saved and the still photo's real size.
    struct ConversionOutcome {
        let bytesSaved: Int64
        let stillBytes: Int64
    }

    /// Converts one Live Photo to a still. The flow is: save the still
    /// as a new photo (keeping its date), then move the original Live
    /// Photo to Recently Deleted (undoable for 30 days). The converted
    /// photo leaves the Live Photos list. One conversion deletes one
    /// asset, so it costs one free delete; Pro is unlimited. Returns
    /// nil when the conversion could not run, with `scanError` set.
    ///
    /// In screenshot mode there is no real library, so the conversion
    /// is simulated from the size estimate: progress animates, then
    /// the sample Live Photo leaves the list and the estimated saving
    /// is recorded, exactly as the real flow records the real saving.
    func convertLivePhoto(
        item: PhotoItem,
        isPro: Bool,
        progress: @escaping (Double) -> Void
    ) async -> ConversionOutcome? {
        guard isPro || ScreenshotMode.isEnabled || remainingFreeDeletes(isPro: false) >= 1 else {
            return nil
        }
        if ScreenshotMode.isEnabled {
            let estimate = LivePhotoConversion.estimate(originalBytes: item.fileSize)
            for step in 1...6 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                progress(Double(step) / 6.0)
            }
            removeItems([item])
            deletedCount += 1
            recordCleanup?(CleanupEvent(
                date: Date(), photosDeleted: 0, videosCompressed: 0, livePhotosConverted: 1, bytesFreed: estimate.bytesSaved))
            return ConversionOutcome(bytesSaved: estimate.bytesSaved, stillBytes: estimate.estimatedStillBytes)
        }
        guard let asset = fetchAssets(ids: [item.id]).first else {
            scanError = "Could not find that Live Photo in Photos."
            return nil
        }
        do {
            let converted = try await LivePhotoConverter.convert(asset: asset, progress: progress)
            let request = DeletionRequest(groupID: "livephoto", itemIDs: [item.id], confirmedByUser: true)
            try await scanner.delete(request, assets: [asset])
            let bytesSaved = max(0, item.fileSize - converted.stillFileSize)
            removeItems([item])
            deletedCount += 1
            recordCleanup?(CleanupEvent(
                date: Date(), photosDeleted: 0, videosCompressed: 0, livePhotosConverted: 1, bytesFreed: bytesSaved))
            return ConversionOutcome(bytesSaved: bytesSaved, stillBytes: converted.stillFileSize)
        } catch {
            scanError = error.localizedDescription
            return nil
        }
    }

    /// Records one confirmed cleanup for the "freed this month"
    /// figure. Only called after a deletion actually succeeded, so
    /// a failed or refused delete never counts as freed space.
    private func noteCleanup(items: [PhotoItem]) {
        recordCleanup?(CleanupEvent(
            date: Date(),
            photosDeleted: items.count,
            bytesFreed: StorageEstimator.reclaimableBytes(for: items)
        ))
    }

    // MARK: - Private

    private func requestAVAsset(for asset: PHAsset) async -> AVAsset? {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        // An iCloud-only video downloads first; the sheet says
        // compression may take a while for such clips.
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }

    private func fetchAssets(ids: [String]) -> [PHAsset] {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var found: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in found.append(asset) }
        return found
    }

    private func removeGroup(_ group: PhotoGroup) {
        guard let current = result else { return }
        result = ScanResult(
            groups: current.groups.filter { $0.id != group.id },
            totalScanned: current.totalScanned,
            totalLibraryCount: current.totalLibraryCount,
            largeVideos: current.largeVideos,
            livePhotos: current.livePhotos,
            scannedAt: current.scannedAt
        )
    }

    private func removeItems(_ items: [PhotoItem]) {
        guard let current = result else { return }
        let ids = Set(items.map(\.id))
        let groups = current.groups.compactMap { group -> PhotoGroup? in
            let remaining = group.items.filter { !ids.contains($0.id) }
            guard remaining.count >= 2 else { return nil }
            return PhotoGroup(
                id: group.id,
                kind: group.kind,
                items: remaining,
                keeperID: group.keeperID,
                matchReason: group.matchReason
            )
        }
        result = ScanResult(
            groups: groups,
            totalScanned: current.totalScanned,
            totalLibraryCount: current.totalLibraryCount,
            largeVideos: current.largeVideos.filter { !ids.contains($0.id) },
            livePhotos: current.livePhotos.filter { !ids.contains($0.id) },
            scannedAt: current.scannedAt
        )
    }
}
