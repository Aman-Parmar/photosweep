import SwiftData
import SwiftUI

/// Settings: Pro status, privacy, how the app works, and scan history.
/// No account anywhere in this app — there is nothing to sign into,
/// and therefore nothing to delete an account for.
struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var history: [ScanRecord]
    @Query(sort: \CleanupEventRecord.date, order: .reverse) private var cleanups: [CleanupEventRecord]
    @State private var showingPaywall = false
    @State private var showingPrivacy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("PhotoSweep Pro")
                        Spacer()
                        Text(store.isPro ? "Active" : "Free")
                            .foregroundStyle(store.isPro ? .green : .secondary)
                    }
                    if !store.isPro {
                        Text("Free: \(appState.remainingFreeDeletes(isPro: false)) of \(AppState.freeDeleteLimit) deletes left.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Get Pro") { showingPaywall = true }
                            .accessibilityIdentifier("settings-get-pro-button")
                    }
                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                }
                Section("Freed this month") {
                    let total = CleanupHistory.freedThisMonth(events: cleanups.map(\.event))
                    if total.photos == 0 && total.videos == 0 && total.livePhotos == 0 {
                        Text("Nothing freed yet this month.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(freedSummary(total: total))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Scan history") {
                    if history.isEmpty {
                        Text("No scans yet. Scan your photos from the Scan tab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(history) { record in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.scannedAt, style: .date)
                                    .font(.headline)
                                Text("\(record.totalScanned) scanned · \(record.totalDeletableCount) photos in \(record.groupsCount) groups · ~\(StorageEstimator.formatted(record.totalReclaimableBytes)) reclaimable (estimate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Clear scan history", role: .destructive) {
                            for record in history {
                                modelContext.delete(record)
                            }
                            try? modelContext.save()
                        }
                    }
                }
                Section("Privacy") {
                    Button("Privacy Policy") { showingPrivacy = true }
                    Text("On-device only. No photos leave this phone, no account, no analytics, no ads. Deleted photos go to Recently Deleted for 30 days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("About") {
                    Text("PhotoSweep 1.0: Free up iPhone storage, honestly. No weekly plan, no auto-delete, no cloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Apple Photos already finds exact duplicates free. PhotoSweep finds what it doesn't: similar and burst shots, blurry photos, screenshots, large videos, and Live Photos to convert to stills.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .paywallSheet(isPresented: $showingPaywall)
            .sheet(isPresented: $showingPrivacy) {
                NavigationStack {
                    ScrollView {
                        Text(privacyText)
                            .font(.body)
                            .padding()
                    }
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppCopy.close) { showingPrivacy = false }
                        }
                    }
                }
            }
        }
    }

    /// The "freed this month" line: "~1.1 GB freed from 3 photos and
    /// 1 compressed video (estimate)...". A plain function, not view
    /// builder code: a bare `if` inside a ViewBuilder builds a view,
    /// so the parts list has to be assembled here.
    private func freedSummary(total: (photos: Int, videos: Int, livePhotos: Int, bytes: Int64)) -> String {
        var parts: [String] = []
        if total.photos > 0 {
            parts.append("\(total.photos) \(total.photos == 1 ? "photo" : "photos")")
        }
        if total.videos > 0 {
            parts.append("\(total.videos) \(total.videos == 1 ? "compressed video" : "compressed videos")")
        }
        if total.livePhotos > 0 {
            parts.append("\(total.livePhotos) \(total.livePhotos == 1 ? "Live Photo converted to still" : "Live Photos converted to still")")
        }
        return "~\(StorageEstimator.formatted(total.bytes)) freed from \(parts.joined(separator: " and ")) (estimate). Space is only actually freed once Recently Deleted is emptied."
    }

    private var privacyText: String {
        """
        PhotoSweep Privacy Policy (short version)

        PhotoSweep scans your photo library on your phone. Your photos, thumbnails, and scan results never leave this device. There is no account, no analytics, no advertising, and no third-party service that receives your data.

        Deletion: nothing is deleted without you reviewing it first and confirming. Deleted photos move to Recently Deleted in Photos, where you can recover them for 30 days.

        Storage estimates are estimates. Photos may report slightly different sizes, and space is only actually freed once Recently Deleted is emptied.

        Questions: support@photosweep.singhsec.com.
        """
    }
}
