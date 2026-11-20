import SwiftUI

/// Screenshots tab: every screenshot found, for bulk review. Tap to
/// select, delete the selected ones. Screenshots are often receipts or
/// confirmations, so the copy reminds the user to check before deleting.
struct ScreenshotsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @State private var selected: Set<String> = []
    @State private var showingConfirm = false
    @State private var showingPaywall = false

    private var screenshots: [PhotoItem] {
        appState.groups(of: .screenshots).flatMap(\.items)
    }

    var body: some View {
        NavigationStack {
            Group {
                if screenshots.isEmpty {
                    ContentUnavailableView(
                        "No screenshots",
                        systemImage: "camera.viewfinder",
                        description: Text("Scan your photos first. Screenshots will appear here for bulk review. Check each one: some may be receipts or confirmations worth keeping.")
                    )
                } else {
                    List {
                        Section {
                            Text(AppCopy.screenshotWarning)
                                .screenshotWarningCaption()
                        }
                        ForEach(screenshots) { item in
                            HStack(spacing: 12) {
                                ListThumbnailView(item: item)
                                VStack(alignment: .leading) {
                                    Text(SwipeCard.screenshotLabel)
                                        .font(.headline)
                                    Text(StorageEstimator.formatted(item.fileSize))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                SelectionCircle(isSelected: selected.contains(item.id))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selected.toggle(item.id)
                            }
                            .accessibilityIdentifier("screenshot-item-\(item.id)")
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if !selected.isEmpty {
                            BulkDeleteButton(count: selected.count, accessibilityIdentifier: "screenshots-delete-button") {
                                if appState.canDelete(count: selected.count, isPro: store.isPro) {
                                    showingConfirm = true
                                } else {
                                    showingPaywall = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Screenshots")
            .deleteConfirmAlert(
                isPresented: $showingConfirm,
                count: selected.count,
                message: AppCopy.recentlyDeletedMessage(noun: "screenshots")
            ) {
                Task {
                    if await appState.confirmDeleteSelected(from: screenshots, selected: selected, isPro: store.isPro) {
                        selected.removeAll()
                    }
                }
            }
            .paywallSheet(isPresented: $showingPaywall)
        }
    }
}

/// Videos tab: large videos, largest first. Deleting videos is a Pro
/// feature — videos are where the gigabytes are, and unlimited video
/// cleanup is the Pro depth. Free users see the list and the paywall.
struct LargeVideosView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @State private var selected: Set<String> = []
    @State private var showingConfirm = false
    @State private var showingPaywall = false
    @State private var compressItem: PhotoItem?

    private var videos: [PhotoItem] {
        appState.largeVideos
    }

    private var totalBytes: Int64 {
        videos.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    ContentUnavailableView(
                        "No large videos",
                        systemImage: "video",
                        description: Text("Scan your photos first. Videos of 100 MB or more will appear here, largest first.")
                    )
                } else {
                    List {
                        Section {
                            Text("\(videos.count) large videos, \(StorageEstimator.approx(totalBytes)) total (estimate). Video cleanup is a Pro feature. Compress shrinks a video instead of deleting it: the smaller copy stays, the original goes to Recently Deleted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(videos) { item in
                            HStack(spacing: 12) {
                                PhotoThumbnailView(item: item)
                                    .frame(width: 84, height: 56)
                                    .cornerRadius(8)
                                VStack(alignment: .leading) {
                                    Text(StorageEstimator.formatted(item.fileSize))
                                        .font(.headline)
                                    Text(CleanupReport.formattedDuration(item.duration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Compress") {
                                    compressItem = item
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityIdentifier("video-compress-button-\(item.id)")
                                if store.isPro {
                                    SelectionCircle(isSelected: selected.contains(item.id))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if store.isPro {
                                    selected.toggle(item.id)
                                } else {
                                    showingPaywall = true
                                }
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if store.isPro && !selected.isEmpty {
                            BulkDeleteButton(count: selected.count, accessibilityIdentifier: "videos-delete-button") {
                                showingConfirm = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Large Videos")
            .sheet(item: $compressItem) { item in
                VideoCompressView(item: item)
            }
            .deleteConfirmAlert(
                isPresented: $showingConfirm,
                count: selected.count,
                message: AppCopy.recentlyDeletedMessage(noun: "videos")
            ) {
                Task {
                    if await appState.confirmDeleteSelected(from: videos, selected: selected, isPro: store.isPro) {
                        selected.removeAll()
                    }
                }
            }
            .paywallSheet(isPresented: $showingPaywall)
        }
    }

}

/// Selection mark: a filled check when the item is selected, a hollow
/// circle otherwise. Shared by the screenshots and large-videos lists
/// and the compress preset picker so every selection mark stays identical.
struct SelectionCircle: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
    }
}

/// Toggles one id in a selection set: removes it when present,
/// inserts it when absent. Shared by the screenshots and large-videos
/// lists so both tap-to-select rows stay identical.
extension Set where Element == String {
    mutating func toggle(_ id: String) {
        if contains(id) {
            remove(id)
        } else {
            insert(id)
        }
    }
}

/// Bottom bulk-delete button for the screenshots and large-videos lists:
/// prominent, full-width, on the system background. Each list keeps its
/// own visibility rule and action; only the button itself is shared.
private struct BulkDeleteButton: View {
    let count: Int
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(AppCopy.deleteSelectedLabel(count: count), action: action)
            .primaryActionButton()
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}
