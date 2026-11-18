import SwiftUI
import UniformTypeIdentifiers

/// Results tab: every group, in sections by kind, largest reclaim
/// first. Tapping a group opens GroupReviewView. The row identifiers
/// are what the screenshot lane taps:
/// `results-group-duplicates-0`, `results-group-similar-0`, etc.
struct ResultsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @State private var showingPaywall = false
    @State private var showingExporter = false
    @State private var reportDocument = CleanupReportDocument(csv: "")

    /// False when there is nothing to report: no scan yet, or a scan
    /// with no groups and no large videos.
    private var canExport: Bool {
        guard let result = appState.result else { return false }
        return !result.groups.isEmpty || !result.largeVideos.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = appState.result, !result.groups.isEmpty {
                    List {
                        ForEach(GroupKind.allCases, id: \.rawValue) { kind in
                            let groups = result.groups(of: kind)
                            if !groups.isEmpty {
                                Section(kind.sectionTitle) {
                                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                        NavigationLink {
                                            GroupReviewView(group: group)
                                        } label: {
                                            GroupRow(group: group)
                                        }
                                        .accessibilityIdentifier("results-group-\(kindID(kind))-\(index)")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No groups yet",
                        systemImage: "rectangle.stack",
                        description: Text("Scan your photos first. Groups of duplicates, similar shots, blurry photos and screenshots will appear here for review.")
                    )
                }
            }
            .navigationTitle("Results")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if store.isPro {
                            if let result = appState.result {
                                reportDocument = CleanupReportDocument(csv: CleanupReport.csv(for: result))
                                showingExporter = true
                            }
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Label("Export report", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("results-export-button")
                    .disabled(!canExport)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: reportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: CleanupReport.fileName()
            ) { _ in }
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
}

/// One group row: kind, item count, and the reclaimable estimate.
struct GroupRow: View {
    let group: PhotoGroup

    var body: some View {
        HStack(spacing: 12) {
            // First item's thumbnail (or the keeper's).
            if let first = group.keeper {
                PhotoThumbnailView(item: first, sampleHue: SampleImageGenerator.hue(for: first.id))
                    .frame(width: 56, height: 56)
                    .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(group.items.count) photos")
                    .font(.headline)
                Text(group.matchReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Text(StorageEstimator.freesLabel(group.reclaimableBytes))
                .font(.subheadline.bold())
        }
        .padding(.vertical, 4)
    }
}

/// Groups of one kind, reached from a Home category card.
struct CategoryGroupsView: View {
    let kind: GroupKind
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            let groups = appState.groups(of: kind)
            if groups.isEmpty {
                ContentUnavailableView(
                    "Nothing here",
                    systemImage: "checkmark.circle",
                    description: Text("No \(kind.sectionTitle.lowercased()) found in the last scan.")
                )
            } else {
                List(groups) { group in
                    NavigationLink {
                        GroupReviewView(group: group)
                    } label: {
                        GroupRow(group: group)
                    }
                }
            }
        }
        .navigationTitle(kind.sectionTitle)
    }
}

/// Review one group: every photo visible, the keeper marked, tap any
/// photo to make it the keeper. Delete removes every non-keeper item
/// — only after the confirmation alert, and only within the free
/// budget (or Pro). Deleted items go to Recently Deleted.
struct GroupReviewView: View {
    let group: PhotoGroup

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var keeperID: String
    @State private var showingConfirm = false
    @State private var showingPaywall = false
    @State private var deleted = false
    @State private var deleteFailed = false
    @State private var compareItem: PhotoItem?

    init(group: PhotoGroup) {
        self.group = group
        _keeperID = State(initialValue: group.keeperID)
    }

    private var deletable: [PhotoItem] {
        group.items.filter { $0.id != keeperID }
    }

    private var reclaimable: Int64 {
        deletable.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(group.matchReason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Tap a photo to keep it instead. \(deletable.count) of \(group.items.count) will be deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(group.items) { item in
                        ZStack(alignment: .topLeading) {
                            PhotoThumbnailView(item: item, sampleHue: SampleImageGenerator.hue(for: item.id))
                                .frame(height: 110)
                                .cornerRadius(10)
                            if item.id == keeperID {
                                Text("KEEP")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor, in: Capsule())
                                    .foregroundStyle(.white)
                                    .padding(6)
                            } else {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.black.opacity(0.55), in: Circle())
                                    .foregroundStyle(.white)
                                    .padding(6)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            // Compare: side by side with the keeper, so
                            // the user can judge whether the two really
                            // are the same shot before deleting.
                            if item.id != keeperID {
                                Button {
                                    compareItem = item
                                } label: {
                                    Image(systemName: "rectangle.on.rectangle")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.black.opacity(0.55), in: Circle())
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("group-compare-\(item.id)")
                                .accessibilityLabel("Compare this photo with the keeper")
                                .padding(6)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            keeperID = item.id
                        }
                        .accessibilityIdentifier("group-item-\(item.id)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(item.id == keeperID ? "Keep this photo" : "Delete this photo")
                    }
                }
                if deleted {
                    Label("Moved to Recently Deleted. You can undo in Photos for 30 days.", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    if store.isPro || appState.remainingFreeDeletes(isPro: false) >= deletable.count {
                        showingConfirm = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Text("Delete \(deletable.count) photo\(deletable.count == 1 ? "" : "s") - \(StorageEstimator.freesLabel(reclaimable))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(deletable.isEmpty || deleted)
                .accessibilityIdentifier("group-delete-button")
                if !store.isPro {
                    Text("Free: \(appState.remainingFreeDeletes(isPro: false)) of \(AppState.freeDeleteLimit) deletes left. Pro deletes unlimited.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if deleteFailed {
                    Text("Delete failed. Nothing was removed - try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle(group.kind.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Move to Recently Deleted?", isPresented: $showingConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete \(deletable.count)", role: .destructive) {
                Task {
                    let updated = PhotoGroup(id: group.id, kind: group.kind, items: group.items, keeperID: keeperID, matchReason: group.matchReason)
                    let ok = await appState.confirmDelete(group: updated, isPro: store.isPro)
                    if ok {
                        deleted = true
                    } else {
                        deleteFailed = true
                    }
                }
            }
        } message: {
            Text("These \(deletable.count) photos will move to Recently Deleted in Photos, where you can recover them for 30 days. The keeper stays in your library.")
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $compareItem) { item in
            if let keeper = group.items.first(where: { $0.id == keeperID }) {
                CompareView(
                    item: item,
                    keeper: keeper,
                    matchReason: group.matchReason
                ) {
                    keeperID = item.id
                    compareItem = nil
                }
            }
        }
    }
}

/// Side-by-side comparison of one group member with the keeper, so the
/// user can judge whether the two really are the same shot before
/// deleting one of them. The keeper stays on the left; the photo being
/// compared is on the right.
struct CompareView: View {
    let item: PhotoItem
    let keeper: PhotoItem
    let matchReason: String
    let onKeepItem: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(matchReason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 12) {
                        CompareColumn(title: "Keeper", item: keeper, isKeeper: true)
                        CompareColumn(title: "This photo", item: item, isKeeper: false)
                    }
                    Button("Keep this photo instead") {
                        onKeepItem()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("compare-keep-button")
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("compare-sheet")
        }
    }
}

private struct CompareColumn: View {
    let title: String
    let item: PhotoItem
    let isKeeper: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isKeeper ? Color.accentColor : Color.primary)
            PhotoThumbnailView(item: item, sampleHue: SampleImageGenerator.hue(for: item.id))
                .frame(height: 220)
                .cornerRadius(10)
            Text(StorageEstimator.formatted(item.fileSize))
                .font(.subheadline)
            Text("\(item.width) x \(item.height) px")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
