import Foundation
import SwiftData

/// Persisted scan history. Only scan *metadata* is stored — counts,
/// dates, and reclaimable bytes. Photo bytes never leave the Photos
/// library, and no image data is ever written to SwiftData.
@Model
final class ScanRecord {
    var id: UUID
    var scannedAt: Date
    var totalScanned: Int
    var totalLibraryCount: Int
    var totalReclaimableBytes: Int64
    var totalDeletableCount: Int
    var groupsCount: Int

    init(result: ScanResult) {
        self.id = UUID()
        self.scannedAt = result.scannedAt
        self.totalScanned = result.totalScanned
        self.totalLibraryCount = result.totalLibraryCount
        self.totalReclaimableBytes = result.totalReclaimableBytes
        self.totalDeletableCount = result.totalDeletableCount
        self.groupsCount = result.groups.count
    }
}
