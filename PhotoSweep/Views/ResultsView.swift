import SwiftUI
import UniformTypeIdentifiers

/// Corner radius shared by the photo thumbnails in the results flow
/// (group grid and compare columns), so the two presentations stay in
/// sync instead of drifting as separate magic numbers.
private let thumbnailCornerRadius: CGFloat = 10

/// Outer padding shared by the trash and compare overlay icons on
/// group-review photo tiles, so both icons sit the same distance from
/// the tile edge. The 6pt padding inside `thumbnailOverlayIcon` itself
/// is separate by design: that one sizes the icon circle, this one
/// positions the icon on the tile.
private let tileOverlayPadding: CGFloat = 6

/// Results tab: every group, in sections by kind, largest reclaim
/// first. Tapping a group opens GroupReviewView. The row identifiers
/// are what the screenshot lane taps:
/// `results-group-duplicates-0`, `results-group-similar-0`, etc.
struct ResultsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @State private var showingPaywall = false
    @State private var showingExporter = false
    @State private var showingSwipeMode = false
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
                                        .accessibilityIdentifier("results-group-\(kind.categoryID)-\(index)")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No groups yet",
                        systemImage: AppIcons.resultsStack,
                        description: Text("Scan your photos first. Groups of duplicates, similar shots, blurry photos and screenshots will appear here for review.")
                    )
                }
            }
            .navigationTitle(AppCopy.results)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSwipeMode = true
                    } label: {
                        Label("Swipe", systemImage: AppIcons.resultsStack)
                    }
                    .accessibilityIdentifier("results-swipe-button")
                    .disabled(appState.swipeMonths.isEmpty)
                }
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
            .swipeModeCover(isPresented: $showingSwipeMode)
            .paywallSheet(isPresented: $showingPaywall)
            .fileExporter(
                isPresented: $showingExporter,
                document: reportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: CleanupReport.fileName()
            ) { _ in }
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
                ListThumbnailView(item: first)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(group.countLabel)
                    .font(.headline)
                Text(group.matchReason)
                    .secondaryCaption()
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
                    systemImage: AppIcons.checkmarkCircle,
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
                    .secondaryCaption()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(group.items) { item in
                        ZStack(alignment: .topLeading) {
                            Button {
                                keeperID = item.id
                            } label: {
                                ZStack(alignment: .topLeading) {
                                    PhotoThumbnailView(item: item)
                                        .frame(height: 110)
                                        .cornerRadius(thumbnailCornerRadius)
                                    if item.id == keeperID {
                                        KeepBadgeLabel(horizontal: 6, vertical: 3, outer: 6)
                                    } else {
                                        Image(systemName: "trash")
                                            .thumbnailOverlayIcon()
                                            .padding(tileOverlayPadding)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("group-item-\(item.id)")
                            .accessibilityLabel(item.id == keeperID ? "Keep this photo" : "Delete this photo")
                        }
                        // Compare: side by side with the keeper, so the
                        // user can judge whether the two really are the
                        // same shot before deleting. A sibling overlay,
                        // not nested in the tile button: a Button inside
                        // a Button is invisible to the accessibility
                        // tree, which broke test08Compare (CI run
                        // 44310359566).
                        .overlay(alignment: .bottomTrailing) {
                            if item.id != keeperID {
                                Button {
                                    compareItem = item
                                } label: {
                                    Image(systemName: "rectangle.on.rectangle")
                                        .thumbnailOverlayIcon()
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("group-compare-\(item.id)")
                                .accessibilityLabel("Compare this photo with the keeper")
                                .padding(tileOverlayPadding)
                            }
                        }
                    }
                }
                if deleted {
                    Label("Moved to Recently Deleted. You can undo in Photos for 30 days.", systemImage: AppIcons.checkmarkCircle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    if appState.canDelete(count: deletable.count, isPro: store.isPro) {
                        showingConfirm = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Text("\(AppCopy.deletePhotosLabel(count: deletable.count)) - \(StorageEstimator.freesLabel(reclaimable))")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionButton()
                .disabled(deletable.isEmpty || deleted)
                .accessibilityIdentifier("group-delete-button")
                if !store.isPro {
                    Text("\(AppCopy.freeDeletesLeft(remaining: appState.remainingFreeDeletes(isPro: false))). Pro deletes unlimited.")
                        .secondaryCaption()
                }
                if deleteFailed {
                    Text(AppCopy.deleteFailed)
                        .deleteFailedCaption()
                }
            }
            .padding()
        }
        .navigationTitle(group.kind.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .deleteConfirmAlert(
            isPresented: $showingConfirm,
            count: deletable.count,
            message: "These \(deletable.count) photos will move to Recently Deleted in Photos, where you can recover them for 30 days. The keeper stays in your library."
        ) {
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
        .paywallSheet(isPresented: $showingPaywall)
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
                    .primaryActionButton()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("compare-keep-button")
                    Button(AppCopy.close) {
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
            // The thumbnail must compress below the image's ideal
            // width: two 240pt-wide sample images plus spacing exceed
            // the sheet width, which pushed the whole sheet off screen
            // on both sides (verified in the 08-compare capture from
            // CI run 44315313305). minWidth 0 lets each column shrink
            // to half the sheet. The image keeps its square aspect
            // (contentMode .fit): a fixed 220pt-tall fill frame used
            // to crop the square image left and right, slicing the
            // "SAMPLE" tag in the 08 capture from run 44330202685.
            PhotoThumbnailView(item: item)
                .aspectRatio(1, contentMode: .fit)
                .frame(minWidth: 0, maxWidth: .infinity)
                .cornerRadius(thumbnailCornerRadius)
            Text(StorageEstimator.formatted(item.fileSize))
                .font(.subheadline)
            Text("\(item.width) x \(item.height) px")
                .secondaryCaption()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
