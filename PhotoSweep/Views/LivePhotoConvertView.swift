import SwiftUI

/// Live Photos list: every Live Photo found, largest first. A Live
/// Photo is a still photo plus a short video clip, so it runs about
/// twice the size of its still. Converting keeps the still and drops
/// the clip. The still is saved as a new photo first; only then does
/// the original move to Recently Deleted, where it can be recovered
/// for 30 days.
///
/// One conversion deletes one asset, so it costs one free delete
/// (Pro is unlimited). That is the same budget as deleting a photo,
/// and the sheet says so.
struct LivePhotosView: View {
    @EnvironmentObject private var appState: AppState
    @State private var convertItem: PhotoItem?

    private var livePhotos: [PhotoItem] {
        appState.livePhotos
    }

    var body: some View {
        NavigationStack {
            Group {
                if livePhotos.isEmpty {
                    ContentUnavailableView(
                        "No Live Photos",
                        systemImage: "livephoto",
                        description: Text("Scan your photos first. Live Photos will appear here: each one is a still photo plus a short video clip, so converting one to a still frees about half its size.")
                    )
                } else {
                    List {
                        Section {
                            Text("\(livePhotos.count) Live Photos. Converting one keeps the still photo and drops the video clip, saving about half its size (estimate). The still is saved first, then the original moves to Recently Deleted, where you can recover it for 30 days.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(livePhotos) { item in
                            let estimate = LivePhotoConversion.estimate(originalBytes: item.fileSize)
                            HStack(spacing: 12) {
                                ListThumbnailView(item: item)
                                VStack(alignment: .leading) {
                                    Text("Live Photo")
                                        .font(.headline)
                                    Text("\(StorageEstimator.formatted(item.fileSize)) · saves \(StorageEstimator.approx(estimate.bytesSaved)) (estimate)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Convert") {
                                    convertItem = item
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityIdentifier("livephoto-convert-button-\(item.id)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Live Photos")
            .sheet(item: $convertItem) { item in
                LivePhotoConvertView(item: item)
            }
        }
    }
}

/// Live Photo conversion sheet: see the estimated still size, then
/// convert. The sheet shows the estimate to everyone, free or Pro:
/// it is the honest preview of what conversion would save. The action
/// itself costs one free delete (the original is deleted) — a free
/// user with no deletes left sees the paywall instead. In screenshot
/// mode the run is simulated from the estimate (no real library), so
/// the screenshot lane can capture the sheet, the progress, and the
/// done state.
struct LivePhotoConvertView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    let item: PhotoItem

    @State private var phase: SheetPhase = .pick
    @State private var progress: Double = 0
    @State private var outcome: AppState.ConversionOutcome?
    @State private var showingPaywall = false

    /// In screenshot mode the simulated run is allowed without Pro:
    /// sample data only, no purchase, no real library.
    private var canConvert: Bool {
        ScreenshotMode.isEnabled || store.isPro || appState.remainingFreeDeletes(isPro: false) >= 1
    }

    private var estimate: LivePhotoEstimate {
        LivePhotoConversion.estimate(originalBytes: item.fileSize)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    SheetDetailRow(
                        label: AppCopy.original,
                        detail: "\(StorageEstimator.formatted(item.fileSize)) · \(item.width) x \(item.height)"
                    )
                    SheetDetailRow(
                        label: "Still photo",
                        detail: "\(StorageEstimator.approx(estimate.estimatedStillBytes)) (estimate)"
                    )
                    if !canConvert {
                        Text("You have used your \(AppState.freeDeleteLimit) free deletes. Converting a Live Photo moves the original to Recently Deleted, so it costs one delete. Upgrade to Pro for unlimited deletes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("Saves \(StorageEstimator.approx(estimate.bytesSaved)) (about \(estimate.savingsPercent)% smaller, estimate). The still photo is saved as a new photo first, keeping its date. Then the Live Photo moves to Recently Deleted, where you can recover it for 30 days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if phase == .running {
                    SheetProgressSection(
                        progress: progress,
                        verb: "Converting",
                        accessibilityIdentifier: "livephoto-convert-progress",
                        sectionIdentifier: "livephoto-convert-progress-section"
                    )
                }

                if phase == .done, let outcome {
                    SheetDoneSection(
                        bytesSaved: outcome.bytesSaved,
                        detail: "Still photo saved (\(StorageEstimator.approx(outcome.stillBytes))). The Live Photo is in Recently Deleted.",
                        accessibilityIdentifier: "livephoto-convert-done-label",
                        sectionIdentifier: "livephoto-convert-done-section"
                    )
                }

                if phase == .failed {
                    SheetFailedSection(
                        errorMessage: appState.scanError,
                        fallback: "Conversion did not finish. Your Live Photo was not changed."
                    )
                }
            }
            .navigationTitle("Convert to still")
            .navigationBarTitleDisplayMode(.inline)
            .cancellationButton(label: AppCopy.cancel) { dismiss() }
            .halfHeightSheet()
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(
                    isDone: phase == .done,
                    isRunning: phase == .running,
                    hasFailed: phase == .failed,
                    startLabel: "Convert to still",
                    startAccessibilityIdentifier: "livephoto-convert-start-button",
                    doneAccessibilityIdentifier: "livephoto-convert-done-button",
                    onStart: startConversion
                )
            }
            .sheetScrollOnPhaseChange(
                proxy: proxy,
                phase: phase,
                runningSectionId: "livephoto-convert-progress-section",
                doneSectionId: "livephoto-convert-done-section"
            )
            .paywallSheet(isPresented: $showingPaywall)
            } // ScrollViewReader
        }
    }

    private func startConversion() {
        SheetRun.start(
            phase: $phase,
            progress: $progress,
            outcome: $outcome,
            showingPaywall: $showingPaywall,
            canRun: canConvert,
            operation: { update in
                await appState.convertLivePhoto(
                    item: item,
                    isPro: store.isPro,
                    progress: update
                )
            }
        )
    }
}
