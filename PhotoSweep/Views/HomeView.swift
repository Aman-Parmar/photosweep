import SwiftUI

/// Home / Scan tab: the scan button, the summary of the last scan, and
/// one card per category. In screenshot mode the sample result is
/// already loaded, so this screen is the 01 screenshot.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let result = appState.result {
                        summaryCard(result)
                        categoryCards(result)
                        if result.isPartialScan {
                            partialScanNotice(result)
                        }
                    } else {
                        noScanYet
                    }
                    howItWorks
                }
                .padding()
            }
            .navigationTitle("PhotoSweep")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.isPro ? "Pro ✓" : "Get Pro") {
                        showingPaywall = true
                    }
                    .accessibilityIdentifier("home-get-pro-button")
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Free up storage, honestly.")
                .font(.title2.bold())
            Text("Finds duplicates, similar shots, blurry photos, screenshots and large videos — on your phone, nothing uploaded. You review everything before anything is deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var noScanYet: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Your library hasn't been scanned yet.")
                .font(.headline)
            scanButton
            if let error = appState.scanError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Text("Scanning reads your photos on-device. Nothing leaves this phone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var scanButton: some View {
        Button {
            Task { await appState.runScan() }
        } label: {
            if appState.isScanning {
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity)
            } else {
                Label("Scan my photos", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(appState.isScanning)
        .accessibilityIdentifier("scan-button")
    }

    private func summaryCard(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Could free up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("~\(StorageEstimator.formatted(result.totalReclaimableBytes))")
                        .font(.title.bold())
                        .accessibilityIdentifier("reclaimable-total")
                    Text("estimate — \(result.totalDeletableCount) photos across \(result.groups.count) groups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(result.totalScanned)")
                        .font(.title3.bold())
                    Text("photos scanned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            scanButton
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func categoryCards(_ result: ScanResult) -> some View {
        VStack(spacing: 12) {
            ForEach(GroupKind.allCases, id: \.rawValue) { kind in
                let groups = result.groups(of: kind)
                let count: Int
                let frees: Int64
                if kind == .largeVideos {
                    count = result.largeVideos.count
                    frees = result.largeVideos.reduce(0) { $0 + $1.fileSize }
                } else {
                    count = groups.count
                    frees = groups.reduce(0) { $0 + $1.reclaimableBytes }
                }
                NavigationLink {
                    CategoryGroupsView(kind: kind)
                } label: {
                    HStack {
                        Image(systemName: icon(for: kind))
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.sectionTitle)
                                .font(.headline)
                            Text(subtitle(for: kind, groupCount: count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if frees > 0 {
                            Text(StorageEstimator.freesLabel(frees))
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("home-category-\(kindID(kind))")
            }
        }
    }

    private func partialScanNotice(_ result: ScanResult) -> some View {
        Label(
            "Scanned \(result.totalScanned) of \(result.totalLibraryCount) photos — limited photo access. Grant full access in Settings to scan the rest.",
            systemImage: "exclamationmark.triangle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it works")
                .font(.headline)
            ForEach([
                "1. Scan — your photos are compared on-device. Nothing is uploaded.",
                "2. Review — every group shows its photos. Pick the keeper; the rest are proposed for deletion.",
                "3. Delete — only when you confirm. Deleted photos go to Recently Deleted for 30 days, so you can undo.",
            ], id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Apple Photos already finds exact duplicates free (Duplicates album). PhotoSweep finds what it doesn't: similar and burst shots, blurry photos, screenshots, and large videos.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func icon(for kind: GroupKind) -> String {
        switch kind {
        case .exactDuplicate: return "doc.on.doc"
        case .similar: return "square.stack.3d.up"
        case .blurry: return "eye.slash"
        case .screenshots: return "camera.viewfinder"
        case .largeVideos: return "video"
        }
    }

    private func kindID(_ kind: GroupKind) -> String {
        switch kind {
        case .exactDuplicate: return "duplicates"
        case .similar: return "similar"
        case .blurry: return "blurry"
        case .screenshots: return "screenshots"
        case .largeVideos: return "videos"
        }
    }

    private func subtitle(for kind: GroupKind, groupCount: Int) -> String {
        switch kind {
        case .largeVideos:
            return groupCount == 0 ? "No large videos found" : "\(groupCount) large videos"
        default:
            return groupCount == 0 ? "Nothing found" : "\(groupCount) group\(groupCount == 1 ? "" : "s") to review"
        }
    }
}
