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
                                PhotoThumbnailView(item: item, sampleHue: SampleImageGenerator.hue(for: item.id))
                                    .frame(width: 56, height: 56)
                                    .cornerRadius(8)
                                VStack(alignment: .leading) {
                                    Text("Live Photo")
                                        .font(.headline)
                                    Text("\(StorageEstimator.formatted(item.fileSize)) · saves ~\(StorageEstimator.formatted(estimate.bytesSaved)) (estimate)")
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

    @State private var phase: Phase = .pick
    @State private var progress: Double = 0
    @State private var outcome: AppState.ConversionOutcome?
    @State private var showingPaywall = false

    private enum Phase {
        case pick
        case converting
        case done
        case failed
    }

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
                    HStack {
                        Text("Original")
                        Spacer()
                        Text("\(StorageEstimator.formatted(item.fileSize)) · \(item.width) x \(item.height)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    HStack {
                        Text("Still photo")
                        Spacer()
                        Text("~\(StorageEstimator.formatted(estimate.estimatedStillBytes)) (estimate)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    if !canConvert {
                        Text("You have used your 20 free deletes. Converting a Live Photo moves the original to Recently Deleted, so it costs one delete. Upgrade to Pro for unlimited deletes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("Saves ~\(StorageEstimator.formatted(estimate.bytesSaved)) (about \(estimate.savingsPercent)% smaller, estimate). The still photo is saved as a new photo first, keeping its date. Then the Live Photo moves to Recently Deleted, where you can recover it for 30 days.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if phase == .converting {
                    Section {
                        SheetProgressView(progress: progress, verb: "Converting", accessibilityIdentifier: "livephoto-convert-progress")
                    }
                    .id("livephoto-convert-progress-section")
                }

                if phase == .done, let outcome {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppCopy.savedLine(bytes: outcome.bytesSaved))
                                .font(.headline)
                                .accessibilityIdentifier("livephoto-convert-done-label")
                            Text("Still photo saved (~\(StorageEstimator.formatted(outcome.stillBytes))). The Live Photo is in Recently Deleted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .id("livephoto-convert-done-section")
                }

                if phase == .failed {
                    Section {
                        Text(appState.scanError ?? "Conversion did not finish. Your Live Photo was not changed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Convert to still")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Short content: open at half height so the sheet fits
            // the estimate instead of leaving a wide blank band below
            // it. The user can drag up to full height.
            .presentationDetents([.medium, .large])
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if phase == .pick || phase == .failed {
                        Button(phase == .failed ? "Try again" : "Convert to still") {
                            startConversion()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("livephoto-convert-start-button")
                    } else if phase == .done {
                        Button(AppCopy.done) { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("livephoto-convert-done-button")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            // At the half-height detent the progress and done sections
            // can sit below the fold. Scroll them into view so the
            // user sees the run and its result without hunting.
            .onChange(of: phase) { _, newPhase in
                let target: String?
                switch newPhase {
                case .converting: target = "livephoto-convert-progress-section"
                case .done: target = "livephoto-convert-done-section"
                default: target = nil
                }
                if let target {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            } // ScrollViewReader
        }
    }

    private func startConversion() {
        guard canConvert else {
            showingPaywall = true
            return
        }
        phase = .converting
        progress = 0
        Task {
            let result = await appState.convertLivePhoto(
                item: item,
                isPro: store.isPro
            ) { value in
                progress = value
            }
            if let result {
                outcome = result
                phase = .done
            } else {
                phase = .failed
            }
        }
    }
}
