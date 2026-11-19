import Foundation

/// Swipe mode pure logic: month bucketing, deck queue building, the
/// decision stack (push / pop / undo), batch totals, and the budget
/// pre-check.
///
/// A swipe is the review, not the deletion. Each swipe records one
/// `SwipeDecision`; nothing is deleted until the user confirms the
/// batch, and the commit step reuses `AppState.confirmDelete`, so the
/// same free-budget and Recently Deleted rules apply. Undo is
/// session-scoped and pre-commit only — PhotoKit has no public API to
/// recover from Recently Deleted, so there is no post-commit undo.
///
/// Foundation-only on purpose: this must compile on Linux CI (see
/// Package.swift) and in the Xcode app target. No SwiftUI, no
/// PhotoKit, no UserDefaults here — the session state lives in
/// `AppState`, which owns persistence.
public enum SwipeMode {

    /// Builds the reviewable cards for a scan result: one card per
    /// group, except the screenshots group, which becomes one card
    /// per screenshot. Large videos and Live Photos are not cards —
    /// they stay in their own tabs.
    public static func cards(for result: ScanResult) -> [SwipeCard] {
        var cards: [SwipeCard] = []
        for group in result.groups {
            if group.kind == .screenshots {
                cards.append(contentsOf: group.items.map(SwipeCard.screenshot))
            } else {
                cards.append(.group(group))
            }
        }
        return cards
    }

    /// Months that hold at least one reviewable card, newest first.
    /// A month with only ungrouped singles has no cards and is
    /// omitted, never shown empty.
    public static func months(for result: ScanResult) -> [SwipeMonth] {
        let months = Set(cards(for: result).map(\.month))
        return months.sorted(by: >)
    }

    /// The cards of one month, in scan order.
    public static func cards(for month: SwipeMonth, in result: ScanResult) -> [SwipeCard] {
        cards(for: result).filter { $0.month == month }
    }
}

/// One calendar month that holds reviewable swipe cards. Year and
/// month only — the View formats the "October 2026" label from
/// `startDate`, so this type never depends on a locale. Codable: the
/// swipe session persists its month in UserDefaults.
public struct SwipeMonth: Equatable, Hashable, Comparable, Codable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.year = components.year ?? 0
        self.month = components.month ?? 0
    }

    public static func < (lhs: SwipeMonth, rhs: SwipeMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    /// First day of the month, for the View to format a label.
    public var startDate: Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: year, month: month, day: 1)
        ) ?? Date()
    }
}

/// One month's swipe session: the deck queue plus the decision stack.
///
/// The queue holds the undecided cards, current card first. A swipe
/// pops the current card off the queue and pushes a decision; Skip
/// moves the current card to the end of the queue (it cycles until
/// decided or the user exits); Undo pops the last decision and puts
/// that card back on top. A month is complete only when every card
/// has a decision — skipped cards are undecided, so they do not
/// advance the bar.
public struct SwipeSession {
    public let month: SwipeMonth
    public let totalCards: Int

    private var queue: [SwipeCard]
    private var decisions: [SwipeDecision] = []
    private let cardsByID: [String: SwipeCard]

    public init(month: SwipeMonth, cards: [SwipeCard]) {
        self.month = month
        self.totalCards = cards.count
        self.queue = cards
        self.cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    }

    /// Restores a persisted session: the queue holds only the cards
    /// with no decision yet, in their original order. Decisions for
    /// cards that no longer exist (deleted elsewhere since the
    /// session was saved) are dropped silently. Skip order is not
    /// preserved across a relaunch — skipped cards rejoin the queue
    /// in scan order, still undecided. That is the only state the
    /// restore loses, and it never changes what gets deleted.
    public init(month: SwipeMonth, cards: [SwipeCard], decisions: [SwipeDecision]) {
        self.month = month
        self.totalCards = cards.count
        self.cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        self.decisions = decisions.filter { cardsByID[$0.cardID] != nil }
        let decidedIDs = Set(self.decisions.map(\.cardID))
        self.queue = cards.filter { !decidedIDs.contains($0.id) }
    }

    /// The card on top of the deck. Nil when the month is complete.
    public var currentCard: SwipeCard? { queue.first }

    /// Decisions recorded so far, in swipe order.
    public var allDecisions: [SwipeDecision] { decisions }

    public var decidedCount: Int { decisions.count }

    /// True when every card in the month has a decision.
    public var isComplete: Bool { queue.isEmpty }

    /// Records a decision for the current card and advances the deck.
    /// Returns the recorded decision, or nil when the deck is empty.
    @discardableResult
    public mutating func decide(_ choice: SwipeDecision.Choice) -> SwipeDecision? {
        guard let card = queue.first else { return nil }
        queue.removeFirst()
        let decision = SwipeDecision(
            cardID: card.id, choice: choice, keeperID: card.decisionKeeperID)
        decisions.append(decision)
        return decision
    }

    /// Moves the current card to the end of this month's queue. No
    /// decision is recorded, so the card does not advance progress.
    public mutating func skip() {
        guard let card = queue.first else { return }
        queue.removeFirst()
        queue.append(card)
    }

    /// Pops the last decision and puts that card back on top of the
    /// deck. Returns the undone decision, or nil when there is
    /// nothing to undo.
    @discardableResult
    public mutating func undo() -> SwipeDecision? {
        guard let last = decisions.popLast(),
              let card = cardsByID[last.cardID] else { return nil }
        queue.insert(card, at: 0)
        return last
    }

    /// Discards the pending decision for one card and re-queues the
    /// card on top for re-review. Used when the keeper changed in
    /// `GroupReviewView` after the decision was made: the decision
    /// was for a different keeper, so it must not stand. Returns
    /// false when the card has no pending decision.
    @discardableResult
    public mutating func discardDecision(forCardID cardID: String) -> Bool {
        guard let index = decisions.firstIndex(where: { $0.cardID == cardID }),
              let card = cardsByID[cardID] else { return false }
        decisions.remove(at: index)
        queue.insert(card, at: 0)
        return true
    }

    /// Delete decisions only — the batch the commit step will delete.
    public var deleteDecisions: [SwipeDecision] {
        decisions.filter { $0.choice == .delete }
    }

    /// Photos the batch would delete.
    public var batchDeleteCount: Int {
        deleteDecisions.reduce(0) { $0 + (cardsByID[$1.cardID]?.deletableCount ?? 0) }
    }

    /// Bytes the batch would free (an estimate, like everywhere else).
    public var batchReclaimableBytes: Int64 {
        deleteDecisions.reduce(0) { $0 + (cardsByID[$1.cardID]?.reclaimableBytes ?? 0) }
    }

    /// Cards the user chose to keep.
    public var keptCount: Int {
        decisions.filter { $0.choice == .keep }.count
    }

    /// Budget pre-check: the whole batch must fit the remaining free
    /// deletes (or the user is Pro) before anything is deleted. A
    /// batch that exactly equals the remaining budget is fine; one
    /// over shows the paywall with zero deletions performed.
    public func canCommit(remainingFreeDeletes: Int, isPro: Bool) -> Bool {
        isPro || batchDeleteCount <= remainingFreeDeletes
    }
}
