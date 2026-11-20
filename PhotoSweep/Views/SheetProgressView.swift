import SwiftUI

/// Shared run phase for the compress and convert sheets: picking a
/// preset, running, done, or failed. The two sheets used to carry
/// byte-identical private Phase enums differing only in the running
/// case name (.compressing vs .converting); the verb stays per-sheet
/// in the progress section, so one enum covers both.
enum SheetPhase {
    case pick
    case running
    case done
    case failed
}

/// Shared run driver for the compress and convert sheets: guard on the
/// sheet's Pro/free gate (showing the paywall when it fails), then run
/// the operation with progress, then done with the outcome or failed.
/// The two sheets used to carry byte-identical Task bodies differing
/// only in the AppState operation they awaited; the operation, the
/// outcome type, and the gate stay per-sheet, passed in by the caller.
enum SheetRun {
    static func start<Outcome>(
        phase: Binding<SheetPhase>,
        progress: Binding<Double>,
        outcome: Binding<Outcome?>,
        showingPaywall: Binding<Bool>,
        canRun: Bool,
        operation: @escaping (@escaping (Double) -> Void) async -> Outcome?
    ) {
        guard canRun else {
            showingPaywall.wrappedValue = true
            return
        }
        phase.wrappedValue = .running
        progress.wrappedValue = 0
        Task {
            let result = await operation { value in
                progress.wrappedValue = value
            }
            if let result {
                outcome.wrappedValue = result
                phase.wrappedValue = .done
            } else {
                phase.wrappedValue = .failed
            }
        }
    }
}

/// Shared progress section for the compress and convert sheets: a
/// progress bar plus a percent label. The verb ("Compressing",
/// "Converting") and the accessibility identifier stay per-sheet so
/// the screenshot lane keeps capturing the same elements.
struct SheetProgressView: View {
    let progress: Double
    let verb: String
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .accessibilityIdentifier(accessibilityIdentifier)
            Text("\(verb)... \(Int((progress * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Shared progress section for the compress and convert sheets: the
/// progress bar plus percent label wrapped in a Section carrying the
/// section id the half-height scroll-to targets. The verb, the
/// accessibility identifier, and the section id stay per-sheet so the
/// screenshot lane keeps capturing the same elements.
struct SheetProgressSection: View {
    let progress: Double
    let verb: String
    let accessibilityIdentifier: String
    let sectionIdentifier: String

    var body: some View {
        Section {
            SheetProgressView(
                progress: progress,
                verb: verb,
                accessibilityIdentifier: accessibilityIdentifier
            )
        }
        .id(sectionIdentifier)
    }
}

/// Shared done section for the compress and convert sheets: the
/// "Saved ~X" headline plus one detail line. The detail copy, the
/// accessibility identifier, and the section id stay per-sheet so the
/// screenshot lane keeps capturing the same elements and the
/// half-height scroll-to still targets the same section.
struct SheetDoneSection: View {
    let bytesSaved: Int64
    let detail: String
    let accessibilityIdentifier: String
    let sectionIdentifier: String

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppCopy.savedLine(bytes: bytesSaved))
                    .font(.headline)
                    .accessibilityIdentifier(accessibilityIdentifier)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .id(sectionIdentifier)
    }
}

/// Shared failed section for the compress and convert sheets: the
/// error message when one exists, else the per-sheet fallback saying
/// the original was not changed. The fallback copy stays per-sheet
/// so each sheet keeps its own wording.
struct SheetFailedSection: View {
    let errorMessage: String?
    let fallback: String

    var body: some View {
        Section {
            Text(errorMessage ?? fallback)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Shared label/value row for the compress and convert sheets: the
/// "Original" row in both sheets plus the "Still photo" row in the
/// convert sheet. The label and the detail string stay per-row so
/// each sheet keeps its own wording; the layout, secondary detail
/// style, and subheadline font are identical.
struct SheetDetailRow: View {
    let label: String
    let detail: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

/// Shared scroll-to for the compress and convert sheets: at the
/// half-height detent the progress and done sections can sit below
/// the fold, so scroll them into view when the run starts or
/// finishes. The call site passes booleans plus its own section ids;
/// the DispatchQueue hop and the animated scrollTo are identical.
enum SheetScroll {
    static func scrollToResult(
        proxy: ScrollViewProxy,
        isRunning: Bool,
        isDone: Bool,
        runningSectionId: String,
        doneSectionId: String
    ) {
        let target: String?
        if isRunning {
            target = runningSectionId
        } else if isDone {
            target = doneSectionId
        } else {
            target = nil
        }
        if let target {
            DispatchQueue.main.async {
                withAnimation { proxy.scrollTo(target, anchor: .top) }
            }
        }
    }
}

extension View {
    /// Shared phase-change scroll for the compress and convert sheets:
    /// when the run starts or finishes, scroll the progress or done
    /// section into view. The two sheets carried byte-identical
    /// `.onChange(of: phase)` blocks differing only in their section
    /// ids; the ids stay per-sheet so each sheet keeps its own
    /// scroll targets.
    func sheetScrollOnPhaseChange(
        proxy: ScrollViewProxy,
        phase: SheetPhase,
        runningSectionId: String,
        doneSectionId: String
    ) -> some View {
        onChange(of: phase) { _, _ in
            SheetScroll.scrollToResult(
                proxy: proxy,
                isRunning: phase == .running,
                isDone: phase == .done,
                runningSectionId: runningSectionId,
                doneSectionId: doneSectionId
            )
        }
    }
}

/// Shared bottom action bar for the compress and convert sheets: a
/// primary start button while picking or after a failure ("Try again"
/// when failed), nothing while the run is in progress, and a Done
/// button once it finished. The call site passes booleans plus its
/// own start label, start action, and accessibility identifiers; the
/// bar layout, padding, and background are identical.
struct SheetActionBar: View {
    @Environment(\.dismiss) private var dismiss

    let isDone: Bool
    let isRunning: Bool
    let hasFailed: Bool
    let startLabel: String
    let startAccessibilityIdentifier: String
    let doneAccessibilityIdentifier: String
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if !isDone && !isRunning {
                Button(hasFailed ? AppCopy.tryAgain : startLabel) {
                    onStart()
                }
                .primaryActionButton()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(startAccessibilityIdentifier)
            } else if isDone {
                Button(AppCopy.done) { dismiss() }
                    .primaryActionButton()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(doneAccessibilityIdentifier)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
