import SwiftUI

/// The scroll targets for the compress sheet: the progress and done
/// sections carry these ids, and `.sheetScrollOnPhaseChange` must pass
/// the same strings, or the scroll-to-result silently finds nothing.
private let compressProgressSectionId = "compress-progress-section"
private let compressDoneSectionId = "compress-done-section"

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
    @State private var phase: SheetPhase = .pick
    @State private var progress: Double = 0
    @State private var outcome: AppState.CompressionOutcome?
    @State private var showingPaywall = false

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
                    SheetDetailRow(
                        label: AppCopy.original,
                        detail: item.originalDetailLine(duration: item.duration)
                    )
                    if !canCompress {
                        Text("Video compression is a Pro feature. Pick a preset to see what it would save, then upgrade to compress.")
                            .secondaryCaption()
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
                                        .secondaryCaption()
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(StorageEstimator.approx(candidateEstimate.estimatedBytes))
                                        .font(.headline)
                                        .foregroundStyle(Color.primary)
                                    Text(candidateEstimate.bytesSaved > 0
                                         ? "Saves \(StorageEstimator.approx(candidateEstimate.bytesSaved)) (\(candidateEstimate.savingsPercent)% smaller, estimate)"
                                         : "About the same size")
                                        .secondaryCaption()
                                }
                                SelectionCircle(isSelected: preset == candidate)
                            }
                        }
                        .accessibilityIdentifier("compress-preset-\(candidate.rawValue)")
                    }
                }

                Section {
                    Text("The compressed copy is saved to Photos. The original moves to Recently Deleted, where you can recover it for 30 days. Sizes are estimates: the real saving depends on the clip.")
                        .secondaryCaption()
                }

                if phase == .running {
                    SheetProgressSection(
                        progress: progress,
                        verb: "Compressing",
                        accessibilityIdentifier: "compress-progress",
                        sectionIdentifier: compressProgressSectionId
                    )
                }

                if phase == .done, let outcome {
                    SheetDoneSection(
                        bytesSaved: outcome.bytesSaved,
                        detail: "Compressed to \(StorageEstimator.approx(outcome.compressedBytes)). The original is in Recently Deleted.",
                        accessibilityIdentifier: "compress-done-label",
                        sectionIdentifier: compressDoneSectionId
                    )
                }

                if phase == .failed {
                    SheetFailedSection(
                        errorMessage: appState.scanError,
                        fallback: "Compression did not finish. Your original video was not changed."
                    )
                }
            }
            .navigationTitle(AppCopy.compressVideo)
            .navigationBarTitleDisplayMode(.inline)
            .cancellationButton(label: AppCopy.cancel) { dismiss() }
            .halfHeightSheet()
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(
                    isDone: phase == .done,
                    isRunning: phase == .running,
                    hasFailed: phase == .failed,
                    startLabel: AppCopy.compressVideo,
                    startAccessibilityIdentifier: "compress-start-button",
                    doneAccessibilityIdentifier: "compress-done-button",
                    onStart: startCompression
                )
            }
            .sheetScrollOnPhaseChange(
                proxy: proxy,
                phase: phase,
                runningSectionId: compressProgressSectionId,
                doneSectionId: compressDoneSectionId
            )
            .paywallSheet(isPresented: $showingPaywall)
            } // ScrollViewReader
        }
    }

    private func startCompression() {
        SheetRun.start(
            phase: $phase,
            progress: $progress,
            outcome: $outcome,
            showingPaywall: $showingPaywall,
            canRun: canCompress,
            operation: { update in
                await appState.compressVideo(
                    item: item,
                    preset: preset,
                    isPro: store.isPro,
                    progress: update
                )
            }
        )
    }

}
