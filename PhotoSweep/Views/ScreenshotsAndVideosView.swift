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
                            Text("Check each one: some screenshots are receipts, tickets, or confirmations worth keeping.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(screenshots) { item in
                            HStack(spacing: 12) {
                                PhotoThumbnailView(item: item, sampleHue: SampleImageGenerator.hue(for: item.id))
                                    .frame(width: 56, height: 56)
                                    .cornerRadius(8)
                                VStack(alignment: .leading) {
                                    Text("Screenshot")
                                        .font(.headline)
                                    Text(StorageEstimator.formatted(item.fileSize))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(item.id) ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selected.contains(item.id) {
                                    selected.remove(item.id)
                                } else {
                                    selected.insert(item.id)
                                }
                            }
                            .accessibilityIdentifier("screenshot-item-\(item.id)")
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if !selected.isEmpty {
                            Button("Delete \(selected.count) selected") {
                                if store.isPro || appState.remainingFreeDeletes(isPro: false) >= selected.count {
                                    showingConfirm = true
                                } else {
                                    showingPaywall = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .accessibilityIdentifier("screenshots-delete-button")
                        }
                    }
                }
            }
            .navigationTitle("Screenshots")
            .alert("Move to Recently Deleted?", isPresented: $showingConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete \(selected.count)", role: .destructive) {
                    Task {
                        let items = screenshots.filter { selected.contains($0.id) }
                        let ok = await appState.confirmDelete(items: items, isPro: store.isPro)
                        if ok { selected.removeAll() }
                    }
                }
            } message: {
                Text("These screenshots will move to Recently Deleted in Photos, where you can recover them for 30 days.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
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
                            Text("\(videos.count) large videos, ~\(StorageEstimator.formatted(totalBytes)) total (estimate). Video cleanup is a Pro feature. Compress shrinks a video instead of deleting it: the smaller copy stays, the original goes to Recently Deleted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(videos) { item in
                            HStack(spacing: 12) {
                                PhotoThumbnailView(item: item, sampleHue: SampleImageGenerator.hue(for: item.id))
                                    .frame(width: 84, height: 56)
                                    .cornerRadius(8)
                                VStack(alignment: .leading) {
                                    Text(StorageEstimator.formatted(item.fileSize))
                                        .font(.headline)
                                    Text(formattedDuration(item.duration))
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
                                    Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(item.id) ? Color.accentColor : Color.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if store.isPro {
                                    if selected.contains(item.id) {
                                        selected.remove(item.id)
                                    } else {
                                        selected.insert(item.id)
                                    }
                                } else {
                                    showingPaywall = true
                                }
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        if store.isPro && !selected.isEmpty {
                            Button("Delete \(selected.count) selected") {
                                showingConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .accessibilityIdentifier("videos-delete-button")
                        }
                    }
                }
            }
            .navigationTitle("Large Videos")
            .sheet(item: $compressItem) { item in
                VideoCompressView(item: item)
            }
            .alert("Move to Recently Deleted?", isPresented: $showingConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete \(selected.count)", role: .destructive) {
                    Task {
                        let items = videos.filter { selected.contains($0.id) }
                        let ok = await appState.confirmDelete(items: items, isPro: store.isPro)
                        if ok { selected.removeAll() }
                    }
                }
            } message: {
                Text("These videos will move to Recently Deleted in Photos, where you can recover them for 30 days.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
