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
            scannedAt: current.scannedAt
        )
    }
}
