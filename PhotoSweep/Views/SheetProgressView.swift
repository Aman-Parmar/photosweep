import SwiftUI

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

/// Shared scroll-to for the compress and convert sheets: at the
/// half-height detent the progress and done sections can sit below
/// the fold, so scroll them into view when the run starts or
/// finishes. The two sheets have different private Phase enums, so
/// the call site passes booleans plus its own section ids; the
/// DispatchQueue hop and the animated scrollTo are identical.
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
