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
