import SwiftUI

/// Swipe mode: review one month's cards, one swipe at a time.
///
/// A card is one reviewable unit — a whole group (keeper large, KEEP
/// badge, up to two more thumbnails) or one screenshot. A swipe is the
/// review, not the deletion: swiping records a decision and nothing is
/// deleted until the user confirms the batch in the summary sheet, so
/// undo is always available until then. Presented as a fullScreenCover
/// with its own Done button: no navigation stack (whose back swipe
/// would fight the card drag) and no tab bar underneath (which has
/// clipped content in this app before). Buttons exist for every
/// gesture — VoiceOver cannot drag, and the screenshot lane drives
/// the deck with buttons only.
///
/// See SWIPE_MODE_DESIGN.md for the full design.
struct SwipeModeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingSummary = false
    @State private var showingPaywall = false
    @State private var commitFailed = false
    @State private var committedTotals: CommittedTotals?
    @State private var reviewingGroup: PhotoGroup?
    @State private var reviewingCardID: String?
    @State private var dragOffset: CGSize = .zero

    /// The totals the done state shows after a successful commit,
    /// captured before the commit clears the session.
    private struct CommittedTotals {
        let month: SwipeMonth
        let deleted: Int
        let kept: Int
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private func monthLabel(_ month: SwipeMonth) -> String {
        Self.monthFormatter.string(from: month.startDate)
    }

    var body: some View {
        Group {
            if let totals = committedTotals {
                doneView(totals)
            } else if appState.swipeSession != nil {
                deckView
            } else {
                monthPickerView
            }
        }
        .sheet(isPresented: $showingSummary) {
            summarySheet
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $reviewingGroup, onDismiss: handleReviewDismiss) { group in
            NavigationStack {
                GroupReviewView(group: group)
            }
        }
    }

    // MARK: - Month picker

    private var monthPickerView: some View {
        NavigationStack {
            List {
                ForEach(appState.swipeMonths, id: \.self) { month in
                    Button {
                        appState.startSwipeSession(month: month)
                    } label: {
                        HStack {
                            Text(monthLabel(month))
                            Spacer()
                            Text(pickerSubtitle(for: month))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("swipe-month-\(month.year)-\(month.month)")
                }
            }
            .navigationTitle("Swipe to review")
            .accessibilityIdentifier("swipe-month-picker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func pickerSubtitle(for month: SwipeMonth) -> String {
        let total = appState.swipeCardCount(for: month)
        if let session = appState.swipeSession, session.month == month, session.decidedCount > 0 {
            return "\(session.decidedCount) of \(total) reviewed"
        }
        return "\(total) cards"
    }

    // MARK: - Deck

    private var deckView: some View {
        VStack(spacing: 16) {
            deckHeader
            if let session = appState.swipeSession {
                ProgressView(value: Double(session.decidedCount), total: Double(max(1, session.totalCards)))
                if session.isComplete {
                    monthCompletePrompt(session)
                } else {
                    deckCards(session)
                    totalsBar(session)
                    actionButtons(session)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var deckHeader: some View {
        ZStack {
            HStack {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("swipe-done-button")
                Spacer()
            }
            if let session = appState.swipeSession {
                VStack(spacing: 2) {
                    Text(monthLabel(session.month))
                        .font(.headline)
                        .accessibilityIdentifier("swipe-month-label")
                    Text("\(session.decidedCount) of \(session.totalCards) reviewed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("swipe-progress-label")
                }
            }
        }
    }

    private func deckCards(_ session: SwipeSession) -> some View {
        ZStack {
            // The next card peeks behind at reduced scale.
            if let next = nextCard(after: session) {
                cardView(next, kindIdentifier: "swipe-next-card-kind")
                    .scaleEffect(0.94)
                    .offset(y: 14)
                    .opacity(0.5)
                    .disabled(true)
                    .accessibilityIdentifier("swipe-next-card")
            }
            if let current = session.currentCard {
                cardView(current, kindIdentifier: "swipe-card-kind")
                    .id(current.id)
                    .offset(x: dragOffset.width, y: dragOffset.height * 0.25)
                    .rotationEffect(.degrees(Double(dragOffset.width / 15)))
                    .accessibilityIdentifier("swipe-card")
                    .onTapGesture { openReview(for: current) }
                    .gesture(
                        DragGesture()
                            .onChanged { value in dragOffset = value.translation }
                            .onEnded { value in
                                if value.translation.width > 120 {
                                    decide(.keep)
                                } else if value.translation.width < -120 {
                                    decide(.delete)
                                } else {
                                    withAnimation(.spring()) { dragOffset = .zero }
                                }
                            }
                    )
            }
        }
    }

    /// The next undecided card in scan order, for the peek behind
    /// the current card. Cosmetic only — skip order is not reflected
    /// here, so this is the next card the deck will show, not a
    /// promise of exact order after a skip.
    private func nextCard(after session: SwipeSession) -> SwipeCard? {
        guard let result = appState.result else { return nil }
        let decided = Set(session.allDecisions.map(\.cardID))
        let remaining = SwipeMode.cards(for: session.month, in: result)
            .filter { !decided.contains($0.id) }
        return remaining.dropFirst().first
    }

    private func cardView(_ card: SwipeCard, kindIdentifier: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let keeper = card.keeper {
                ZStack(alignment: .topLeading) {
                    PhotoThumbnailView(item: keeper, sampleHue: SampleImageGenerator.hue(for: keeper.id))
                        .frame(height: 300)
                        .cornerRadius(16)
                    Text("KEEP")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
            // The keeper first, then up to two more members. Never
            // all members: a 50-frame burst group would cost 50
            // thumbnails for one card.
            HStack(spacing: 8) {
                ForEach(card.thumbnailItems.dropFirst(), id: \.id) { item in
                    PhotoThumbnailView(item: item, sampleHue: SampleImageGenerator.hue(for: item.id))
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)
                }
            }
            Text(card.kindLabel)
                .font(.headline)
                // Identifier for the screenshot lane: a VStack does
                // not surface as an `otherElements` query, so the
                // lane asserts on this text instead (CI run
                // 44450339524: the `swipe-card` container query never
                // matched even though the deck rendered).
                .accessibilityIdentifier(kindIdentifier)
            Text("\(card.countLabel) - \(StorageEstimator.freesLabel(card.reclaimableBytes))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if case .screenshot = card {
                Text("Check each one: some screenshots are receipts, tickets, or confirmations worth keeping.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func totalsBar(_ session: SwipeSession) -> some View {
        Group {
            if session.allDecisions.isEmpty {
                Text("Swipe right to keep, left to delete. Nothing is deleted until you confirm the batch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Button {
                    showingSummary = true
                } label: {
                    HStack {
                        Text("\(session.deleteDecisions.count) to delete, frees ~\(StorageEstimator.formatted(session.batchReclaimableBytes)), \(session.keptCount) kept")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.up")
                    }
                }
                .accessibilityIdentifier("swipe-totals-bar")
            }
        }
    }

    private func actionButtons(_ session: SwipeSession) -> some View {
        HStack(spacing: 12) {
            Button("Undo") {
                appState.swipeUndo()
            }
            .buttonStyle(.bordered)
            .disabled(session.allDecisions.isEmpty)
            .accessibilityIdentifier("swipe-undo-button")
            Button("Skip") {
                appState.swipeSkip()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("swipe-skip-button")
            Button("Keep") {
                decide(.keep)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("swipe-keep-button")
            Button("Delete") {
                decide(.delete)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityIdentifier("swipe-delete-button")
        }
    }

    /// Shown when every card in the month has a decision and the
    /// summary sheet was dismissed without committing: the deck is
    /// empty, so the month needs its summary to proceed.
    private func monthCompletePrompt(_ session: SwipeSession) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("\(monthLabel(session.month)) complete: \(session.decidedCount) reviewed.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button("Review and delete") {
                showingSummary = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("swipe-review-summary-button")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Summary sheet and commit

    private var summarySheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let session = appState.swipeSession {
                    Text("\(monthLabel(session.month)): \(session.deleteDecisions.count) to delete, \(session.keptCount) kept")
                        .font(.headline)
                    Text("Deleted photos move to Recently Deleted in Photos, where you can recover them for 30 days. Undo is available until you confirm below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    List {
                        ForEach(summaryRows(session), id: \.cardID) { row in
                            HStack {
                                Text(row.label)
                                Spacer()
                                Text("\(row.count) - \(StorageEstimator.freesLabel(row.bytes))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    Button("Delete \(session.batchDeleteCount) photo\(session.batchDeleteCount == 1 ? "" : "s")") {
                        Task { await commit() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(session.batchDeleteCount == 0)
                    .accessibilityIdentifier("swipe-commit-button")
                    if commitFailed {
                        Text("Delete failed. Nothing was removed - try again.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Review batch")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("swipe-summary-sheet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showingSummary = false }
                }
            }
        }
    }

    private struct SummaryRow {
        let cardID: String
        let label: String
        let count: Int
        let bytes: Int64
    }

    private func summaryRows(_ session: SwipeSession) -> [SummaryRow] {
        guard let result = appState.result else { return [] }
        let cards = SwipeMode.cards(for: result)
        return session.deleteDecisions.compactMap { decision in
            guard let card = cards.first(where: { $0.id == decision.cardID }) else { return nil }
            return SummaryRow(
                cardID: decision.cardID,
                label: "\(card.kindLabel) - \(card.countLabel)",
                count: card.deletableCount,
                bytes: card.reclaimableBytes)
        }
    }

    private func commit() async {
        guard let session = appState.swipeSession else { return }
        // The free budget must cover the whole batch before anything
        // is deleted; a batch over budget shows the paywall with zero
        // deletions performed.
        guard session.canCommit(
            remainingFreeDeletes: appState.remainingFreeDeletes(isPro: store.isPro),
            isPro: store.isPro
        ) else {
            showingSummary = false
            showingPaywall = true
            return
        }
        let totals = CommittedTotals(
            month: session.month, deleted: session.batchDeleteCount, kept: session.keptCount)
        if await appState.commitSwipeSession(isPro: store.isPro) {
            showingSummary = false
            committedTotals = totals
        } else {
            commitFailed = true
        }
    }

    // MARK: - Done state

    private func doneView(_ totals: CommittedTotals) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("\(monthLabel(totals.month)) done: \(totals.deleted) deleted, \(totals.kept) kept")
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("swipe-month-complete")
            Text("Deleted photos are in Recently Deleted in Photos for 30 days.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let next = nextMonth(after: totals.month) {
                Button("Review \(monthLabel(next))") {
                    committedTotals = nil
                    appState.startSwipeSession(month: next)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("swipe-next-month-button")
            }
            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("swipe-done-button")
            Spacer()
        }
        .padding()
    }

    /// The next older month that still has cards. The committed
    /// month is skipped even though its kept groups still exist:
    /// the month is done, and kept groups stay in Results for
    /// careful review.
    private func nextMonth(after month: SwipeMonth) -> SwipeMonth? {
        appState.swipeMonths.first(where: { $0 < month })
    }

    // MARK: - Decisions and group review

    private func decide(_ choice: SwipeDecision.Choice) {
        appState.swipeDecide(choice)
        withAnimation(.spring()) { dragOffset = .zero }
        // Finishing a month opens the summary sheet.
        if appState.swipeSession?.isComplete == true {
            showingSummary = true
        }
    }

    /// Tapping a group card opens the existing group review, where
    /// the user can change the keeper or delete immediately. A
    /// screenshot card has no group review: it opens nothing.
    private func openReview(for card: SwipeCard) {
        guard case .group(let group) = card else { return }
        reviewingCardID = card.id
        reviewingGroup = group
    }

    /// On return from group review: drop any pending decision for
    /// that group (the keeper may have changed, so the decision was
    /// for a different keeper) and rebuild the deck from the current
    /// scan result, so a group deleted in review drops out.
    private func handleReviewDismiss() {
        if let cardID = reviewingCardID {
            appState.discardSwipeDecision(forCardID: cardID)
        }
        reviewingCardID = nil
        appState.refreshSwipeSession()
    }
}
