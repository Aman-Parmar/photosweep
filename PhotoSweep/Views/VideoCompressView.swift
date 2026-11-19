import SwiftUI

/// Video compression sheet: pick one of three HEVC presets, see the
/// estimated size before and after, then compress.
///
/// The sheet shows the estimate to everyone, free or Pro: it is the
/// honest preview of what compression would save. The action itself
/// is Pro (video cleanup is Pro depth) — a free user tapping Compress
/// sees the paywall. In screenshot mode the run is simulated from the
/// estimate (no real library), so the screenshot lane can capture the
/// sheet, the progress, and the done state.
struct VideoCompressView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    let item: PhotoItem

    @State private var preset: CompressionPreset = .balanced
    @State private var phase: Phase = .pick
    @State private var progress: Double = 0
    @State private var outcome: AppState.CompressionOutcome?
    @State private var showingPaywall = false

    private enum Phase {
        case pick
        case compressing
        case done
        case failed
    }

    /// In screenshot mode the simulated run is allowed without Pro:
    /// sample data only, no purchase, no real library.
    private var canCompress: Bool {
        store.isPro || ScreenshotMode.isEnabled
    }

    private var estimate: CompressionEstimate {
        VideoCompression.estimate(originalBytes: item.fileSize, duration: item.duration, preset: preset)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    HStack {
                        Text(AppCopy.original)
                        Spacer()
                        Text("\(StorageEstimator.formatted(item.fileSize)) · \(CleanupReport.formattedDuration(item.duration)) · \(item.width) x \(item.height)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    if !canCompress {
                        Text("Video compression is a Pro feature. Pick a preset to see what it would save, then upgrade to compress.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Preset") {
                    ForEach(CompressionPreset.allCases, id: \.self) { candidate in
                        let candidateEstimate = VideoCompression.estimate(
                            originalBytes: item.fileSize, duration: item.duration, preset: candidate)
                        Button {
                            preset = candidate
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.displayName)
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                    Text(candidate.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("~\(StorageEstimator.formatted(candidateEstimate.estimatedBytes))")
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                    Text(candidateEstimate.bytesSaved > 0
                                         ? "Saves ~\(StorageEstimator.formatted(candidateEstimate.bytesSaved)) (\(candidateEstimate.savingsPercent)% smaller, estimate)"
                                         : "About the same size")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                SelectionCircle(isSelected: preset == candidate)
                            }
                        }
                        .accessibilityIdentifier("compress-preset-\(candidate.rawValue)")
                    }
                }

                Section {
                    Text("The compressed copy is saved to Photos. The original moves to Recently Deleted, where you can recover it for 30 days. Sizes are estimates: the real saving depends on the clip.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if phase == .compressing {
                    Section {
                        SheetProgressView(progress: progress, verb: "Compressing", accessibilityIdentifier: "compress-progress")
                    }
                    .id("compress-progress-section")
                }

                if phase == .done, let outcome {
                    SheetDoneSection(
                        bytesSaved: outcome.bytesSaved,
                        detail: "Compressed to ~\(StorageEstimator.formatted(outcome.compressedBytes)). The original is in Recently Deleted.",
                        accessibilityIdentifier: "compress-done-label",
                        sectionIdentifier: "compress-done-section"
                    )
                }

                if phase == .failed {
                    Section {
                        Text(appState.scanError ?? "Compression did not finish. Your original video was not changed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Compress video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.cancel) { dismiss() }
                }
            }
            .halfHeightSheet()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if phase == .pick || phase == .failed {
                        Button(phase == .failed ? AppCopy.tryAgain : "Compress video") {
                            startCompression()
                        }
                        .primaryActionButton()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("compress-start-button")
                    } else if phase == .done {
                        Button(AppCopy.done) { dismiss() }
                            .primaryActionButton()
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("compress-done-button")
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
                case .compressing: target = "compress-progress-section"
                case .done: target = "compress-done-section"
                default: target = nil
                }
                if let target {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                    }
                }
            }
            .paywallSheet(isPresented: $showingPaywall)
            } // ScrollViewReader
        }
    }

    private func startCompression() {
        guard canCompress else {
            showingPaywall = true
            return
        }
        phase = .compressing
        progress = 0
        Task {
            let result = await appState.compressVideo(
                item: item,
                preset: preset,
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
