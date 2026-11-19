import Foundation
import XCTest

@testable import PhotoSweep

/// Swipe mode logic: month bucketing, deck queue, decision stack
/// (decide / skip / undo), keeper-change invalidation, batch totals,
/// and the free-budget pre-check. Dates are mid-month so the month
/// bucketing does not depend on the runner's timezone.
final class SwipeModeTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_760_000_000) // 2025-10-09

    private func day(_ offset: Int) -> Date {
        base.addingTimeInterval(TimeInterval(offset * 86_400))
    }

    private func item(
        id: String,
        size: Int64 = 1_000_000,
        date: Date,
        sharpness: Double = 0.8,
        screenshot: Bool = false,
        hash: String? = nil
    ) -> PhotoItem {
        PhotoItem(
            id: id,
            contentHash: hash,
            fileSize: size,
            width: 4032, height: 3024,
            isScreenshot: screenshot,
            creationDate: date,
            sharpness: sharpness,
            brightness: 0.7,
            featurePrint: nil
        )
    }

    private func group(id: String, kind: GroupKind, items: [PhotoItem], keeperID: String) -> PhotoGroup {
        PhotoGroup(id: id, kind: kind, items: items, keeperID: keeperID, matchReason: "test")
    }

    private func result(_ groups: [PhotoGroup]) -> ScanResult {
        ScanResult(groups: groups, totalScanned: 10, totalLibraryCount: 10, scannedAt: base)
    }

    /// Two groups (one September, one October) plus a screenshots
    /// group with two October screenshots.
    private func mixedResult() -> ScanResult {
        let september = group(
            id: "similar-sep",
            kind: .similar,
            items: [
                item(id: "sep-0", date: day(-24)),
                item(id: "sep-1", date: day(-24), sharpness: 0.6),
            ],
            keeperID: "sep-0")
        let october = group(
            id: "similar-oct",
            kind: .similar,
            items: [
                item(id: "oct-0", date: day(6)),
                item(id: "oct-1", date: day(6), sharpness: 0.6),
            ],
            keeperID: "oct-0")
        let screenshots = group(
            id: "screenshots",
            kind: .screenshots,
            items: [
                item(id: "shot-0", date: day(3), screenshot: true),
                item(id: "shot-1", date: day(4), screenshot: true),
            ],
            keeperID: "shot-0")
        return result([september, october, screenshots])
    }

    // MARK: - Cards and months

    func testScreenshotsGroupBecomesOneCardPerScreenshot() {
        let cards = SwipeMode.cards(for: mixedResult())
        // Two group cards plus two screenshot cards, not one bulk card.
        XCTAssertEqual(cards.count, 4)
        XCTAssertEqual(cards.filter { if case .group = $0 { return true } else { return false } }.count, 2)
        XCTAssertEqual(cards.filter { if case .screenshot = $0 { return true } else { return false } }.count, 2)
    }

    func testMonthsAreNewestFirstAndOmitEmptyMonths() {
        let months = SwipeMode.months(for: mixedResult())
        XCTAssertEqual(months.count, 2)
        XCTAssertEqual(months[0].year, 2025)
        XCTAssertEqual(months[0].month, 10)
        XCTAssertEqual(months[1].month, 9)
    }

    func testGroupBelongsToItsKeeperMonth() {
        let months = SwipeMode.months(for: mixedResult())
        let september = months[1]
        let cards = SwipeMode.cards(for: september, in: mixedResult())
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].id, "swipe-group-similar-sep")
    }

    func testScreenshotCardBelongsToItsOwnMonth() {
        let months = SwipeMode.months(for: mixedResult())
        let october = months[0]
        let cards = SwipeMode.cards(for: october, in: mixedResult())
        XCTAssertEqual(cards.count, 3)
    }

    func testEmptyScanHasNoMonths() {
        XCTAssertEqual(SwipeMode.months(for: result([])), [])
    }

    // MARK: - Card facts

    func testGroupCardDeletableCountExcludesKeeper() {
        let cards = SwipeMode.cards(for: mixedResult())
        let groupCard = cards.first { $0.id == "swipe-group-similar-sep" }!
        XCTAssertEqual(groupCard.deletableCount, 1)
        XCTAssertEqual(groupCard.reclaimableBytes, 1_000_000)
        XCTAssertEqual(groupCard.countLabel, "2 photos")
        XCTAssertEqual(groupCard.kindLabel, "Similar photos")
    }

    func testScreenshotCardDeletesOneItem() {
        let cards = SwipeMode.cards(for: mixedResult())
        let shotCard = cards.first { if case .screenshot = $0 { return true } else { return false } }!
        XCTAssertEqual(shotCard.deletableCount, 1)
        XCTAssertEqual(shotCard.countLabel, "1 screenshot")
        XCTAssertEqual(shotCard.kindLabel, "Screenshot")
    }

    func testGroupCardShowsAtMostThreeThumbnails() {
        let members = (0..<5).map { i in
            item(id: "big-\(i)", date: day(-24), sharpness: 0.9 - Double(i) * 0.1)
        }
        let big = group(id: "similar-big", kind: .similar, items: members, keeperID: "big-0")
        let card = SwipeCard.group(big)
        XCTAssertEqual(card.thumbnailItems.count, 3)
        XCTAssertEqual(card.thumbnailItems[0].id, "big-0")
    }

    // MARK: - Deck decisions

    func testDecideAdvancesDeckAndUndoRestoresCard() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[0], cards: SwipeMode.cards(for: months[0], in: mixedResult()))
        XCTAssertEqual(session.totalCards, 3)
        let first = session.currentCard
        let decision = session.decide(.keep)
        XCTAssertEqual(decision?.cardID, first?.id)
        XCTAssertEqual(decision?.choice, .keep)
        XCTAssertEqual(session.decidedCount, 1)
        XCTAssertNotEqual(session.currentCard?.id, first?.id)
        XCTAssertFalse(session.isComplete)

        let undone = session.undo()
        XCTAssertEqual(undone?.cardID, first?.id)
        XCTAssertEqual(session.decidedCount, 0)
        XCTAssertEqual(session.currentCard?.id, first?.id)
    }

    func testSkipCyclesCardToEndWithoutDeciding() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[0], cards: SwipeMode.cards(for: months[0], in: mixedResult()))
        let first = session.currentCard
        session.skip()
        XCTAssertEqual(session.decidedCount, 0)
        XCTAssertNotEqual(session.currentCard?.id, first?.id)
        XCTAssertFalse(session.isComplete)
        // Decide the other two, then the skipped card is back on top.
        _ = session.decide(.keep)
        _ = session.decide(.keep)
        XCTAssertEqual(session.currentCard?.id, first?.id)
        XCTAssertFalse(session.isComplete)
        _ = session.decide(.delete)
        XCTAssertTrue(session.isComplete)
    }

    func testUndoWithNoDecisionsReturnsNil() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[0], cards: SwipeMode.cards(for: months[0], in: mixedResult()))
        XCTAssertNil(session.undo())
    }

    func testDecideOnEmptyDeckReturnsNil() {
        var session = SwipeSession(month: SwipeMonth(year: 2025, month: 10), cards: [])
        XCTAssertNil(session.decide(.keep))
        XCTAssertTrue(session.isComplete)
    }

    // MARK: - Keeper change invalidation

    func testKeeperChangeDiscardsDecisionAndRequeuesCard() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[1], cards: SwipeMode.cards(for: months[1], in: mixedResult()))
        let card = session.currentCard!
        _ = session.decide(.delete)
        XCTAssertEqual(session.decidedCount, 1)
        XCTAssertTrue(session.isComplete)

        // The keeper changed in GroupReviewView after the decision.
        XCTAssertTrue(session.discardDecision(forCardID: card.id))
        XCTAssertEqual(session.decidedCount, 0)
        XCTAssertEqual(session.currentCard?.id, card.id)
        XCTAssertFalse(session.isComplete)
    }

    func testDiscardDecisionWithNoDecisionReturnsFalse() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[1], cards: SwipeMode.cards(for: months[1], in: mixedResult()))
        XCTAssertFalse(session.discardDecision(forCardID: session.currentCard!.id))
    }

    // MARK: - Batch totals and budget

    func testBatchTotalsCountOnlyDeleteDecisions() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[0], cards: SwipeMode.cards(for: months[0], in: mixedResult()))
        // October: one 2-item group (1 deletable) + two screenshots.
        _ = session.decide(.delete) // the group: 1 photo, 1 MB
        _ = session.decide(.keep)   // a screenshot
        _ = session.decide(.delete) // a screenshot: 1 photo, 1 MB
        XCTAssertEqual(session.batchDeleteCount, 2)
        XCTAssertEqual(session.batchReclaimableBytes, 2_000_000)
        XCTAssertEqual(session.keptCount, 1)
        XCTAssertTrue(session.isComplete)
    }

    func testBudgetPreCheckBlocksOverBudgetBatch() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[0], cards: SwipeMode.cards(for: months[0], in: mixedResult()))
        _ = session.decide(.delete)
        _ = session.decide(.keep)
        _ = session.decide(.delete)
        XCTAssertEqual(session.batchDeleteCount, 2)
        XCTAssertFalse(session.canCommit(remainingFreeDeletes: 1, isPro: false))
        XCTAssertTrue(session.canCommit(remainingFreeDeletes: 2, isPro: false))
        XCTAssertTrue(session.canCommit(remainingFreeDeletes: 0, isPro: true))
    }

    func testEmptyBatchAlwaysCommits() {
        let months = SwipeMode.months(for: mixedResult())
        var session = SwipeSession(month: months[1], cards: SwipeMode.cards(for: months[1], in: mixedResult()))
        _ = session.decide(.keep)
        XCTAssertEqual(session.batchDeleteCount, 0)
        XCTAssertTrue(session.canCommit(remainingFreeDeletes: 0, isPro: false))
    }

    func testRestoreKeepsDecisionsAndDropsMissingCards() {
        let months = SwipeMode.months(for: mixedResult())
        let octoberCards = SwipeMode.cards(for: months[0], in: mixedResult())
        XCTAssertEqual(octoberCards.count, 3)
        var session = SwipeSession(month: months[0], cards: octoberCards)
        let first = session.decide(.delete)
        XCTAssertNotNil(first)
        // A decision for a card that no longer exists is dropped.
        let stale = SwipeDecision(cardID: "swipe-group-gone", choice: .delete, keeperID: "gone")
        let restored = SwipeSession(
            month: months[0], cards: octoberCards, decisions: session.allDecisions + [stale])
        XCTAssertEqual(restored.decidedCount, 1)
        XCTAssertEqual(restored.currentCard, octoberCards[1])
        XCTAssertFalse(restored.isComplete)
        XCTAssertEqual(restored.batchDeleteCount, 1)
    }
}
