# Swipe Mode — Design Note

Architect design for the "Swipe mode, month-by-month, with undo + progress" backlog item (ROADMAP.md, Next, large). Design only: no code in this note. The Developer builds from it; QA verifies it independently.

## Decision summary

- **One card is one reviewable unit, not one photo.** A group card (duplicates, similar, blurry) or a single screenshot card. Per-photo cards would throw away the keeper: which photo survives matters, and the keeper is already picked by `KeeperPicker` (sharpest, then highest-res). The deck reuses the scan result as-is; it never re-groups anything.
- **A swipe is the review, not the deletion.** Swipe right keeps everything on the card. Swipe left proposes deletion (a group's non-keeper items, or the one screenshot). Nothing is deleted until the user confirms the batch: the swipe flow is a decision queue, and the commit step is a separate, explicit confirm.
- **Undo is session-scoped and pre-commit.** Undo pops the last decision off the stack and puts the card back on top of the deck. After the batch is committed there is no in-app restore: PhotoKit has no public API to recover from Recently Deleted, so post-commit "undo" is the Photos app (30 days) and the UI must say so plainly. No fake restore button.
- **Swipe mode sits alongside group review, it does not replace it.** Tapping a card opens the existing `GroupReviewView` (change keeper, compare side by side, delete immediately). The deck is the fast path; the group screen is the careful path.
- **Out of scope for v1:** large videos (Pro video cleanup, not deletion) and Live Photos (conversion, not deletion). They stay in their own tabs. Screenshots are in scope as single cards because the screenshots group has no keeper and no per-photo decision today.

## Approach

### Month buckets

- Bucket the scan result's groups and screenshots by the creation month of their items (`Calendar` year-month on `PhotoItem.creationDate`). A group belongs to the month of its keeper; a screenshot to its own month.
- Months are newest first. Only months with at least one reviewable card appear in the picker. A month with only ungrouped singles has no cards and is omitted, never shown empty.
- Month label is "October 2026" style (`DateFormatter`, month + year). No invented labels.

### The deck

- Full-screen cover (not a pushed screen, see Risks). Top card is the current card; the next card peeks behind at reduced scale. Drag horizontally with rotation; past roughly 120pt (or 25% of width) the card flies off, otherwise it springs back.
- **Group card** shows the keeper large with a KEEP badge, up to two more thumbnails in a strip, the kind ("Similar photos"), the count ("3 photos"), and the reclaim ("Frees ~7.6 MB", via `StorageEstimator`). It never renders all members: a 50-frame burst group would cost 50 thumbnails for one card.
- **Screenshot card** shows the single screenshot large with the standing warning ("Check each one: some screenshots are receipts, tickets, or confirmations worth keeping.").
- Below the deck, buttons for every gesture: Keep, Delete, Undo, Skip. Buttons are the accessibility path (VoiceOver cannot drag) and the screenshot-lane path (XCUITest drags are flaky). Buttons and swipes call the same decision function.
- **Skip** moves the card to the end of the current month's queue. A month is complete only when every card has a decision; skipped cards cycle until decided or the user exits. Exiting mid-month keeps the state.

### Decisions and the commit step

- Each swipe records one `SwipeDecision`: card ID, decision (keep / delete), and the `keeperID` at decision time. Decisions live in a stack (for undo) and a per-month list (for progress and the commit summary).
- A persistent bar above the buttons shows the running totals: "12 to delete, frees ~48 MB, 9 kept". Tapping it (or finishing a month) opens a summary sheet listing each delete decision with its count and reclaim, then one confirm button: "Delete 12 photos".
- Commit reuses `AppState.confirmDelete(group:isPro:)` per decided group (and the `confirmDelete(items:isPro:)` overload for screenshots), in queue order. Before deleting anything, pre-check the batch total against `AppState.remainingFreeDeletes`: if the free budget does not cover it, show the paywall first and delete nothing. A half-committed batch followed by a paywall is the failure to avoid.
- After a successful commit the decisions clear, the month shows its done state ("October 2026 done: 12 deleted, 9 kept"), and the deck auto-advances to the next month with cards. The done copy states the recovery path: "Deleted photos are in Recently Deleted in Photos for 30 days."
- **Keeper change invalidates a decision.** If the user opens a group from the deck, changes the keeper in `GroupReviewView`, and returns, any pending decision for that group is discarded and the card re-queues: the decision was made for a different keeper. A group deleted immediately from `GroupReviewView` drops out of the deck on return.

### Progress

- Per-month: "October 2026, 4 of 9 reviewed", a progress bar, and a count of cards left. Per-session overall: "2 months, 9 cards" in the month picker.
- Progress is decided-cards over total cards in the month. Skipped cards are undecided, so they do not advance the bar.

### Persistence (state loss on backgrounding)

- Decisions, the current month, and progress persist after every swipe as a small Codable struct in `UserDefaults` (same pattern as `AppState.deletedCount`), keyed by the scan's `scannedAt`. A rescan clears the swipe session: group IDs are scan-specific and a stale decision must never delete from a new scan.
- On launch, a session whose groups no longer exist (deleted elsewhere) drops those decisions and cards silently. The session is transient review state, not history, so it does not belong in SwiftData next to `ScanRecord` / `CleanupEventRecord`.

### Free tier and Pro gate

- Swipe mode itself is free: scanning and reviewing are never paywalled. Only deletions count, against the same budget as everywhere else: 20 free deletes total (`AppState.freeDeleteLimit`), Pro unlimited. Read the limit from `AppState`; never hardcode 20. PS-2 may change the number; this design must not need a second edit when it does.
- Large-video cleanup stays Pro-gated in its own tab; swipe mode adds no new Pro surface.

### Sample data and the screenshot lane

- The sample must give the lane two months with cards. Today it does not: all four groups are October (`day -12` to `day -3`); September holds only singles. Add one small second group dated in September (a duplicate trio at `day -28`, same pattern as the existing duplicates) so the lane can capture a month switch and a month-complete state.
- Two new UI tests, both button-driven, no drag gestures: `test11SwipeDeck` (open Swipe, assert month header, card, and progress label; tap Keep; assert progress increments and the next card appears) and `test12SwipeMonthComplete` (decide every card in the sample's smaller month via buttons, assert the month-done state and the summary sheet). Screenshot the deck mid-month and the month-done state. New accessibility identifiers: `swipe-month-picker`, `swipe-card`, `swipe-keep-button`, `swipe-delete-button`, `swipe-undo-button`, `swipe-skip-button`, `swipe-progress-label`, `swipe-month-complete`.
- The listing gains two shots (11 swipe deck, 12 month complete); `app-store-listing.md` and README.md need the count updated when the shots land. That is Developer/QA work, not this note.

## Risks

- **Gesture conflicts.** Three of them. (1) The `NavigationStack` back swipe: a leftward drag starting near the left edge pops the screen instead of deleting. (2) The floating iOS 26 tab bar already hid content in shot 01; a deck sitting above it risks the same clipping for the buttons. (3) Vertical scrolling: the deck must not live in a `ScrollView`, or vertical drags fight the card drag. Mitigation for all three: present swipe mode as a `fullScreenCover` with its own Done button, no navigation stack, no tab bar underneath, vertical drags ignored. Do not reach for `interactivePopGestureRecognizer` hacks.
- **Undo after commit is impossible in-app.** `PHAssetChangeRequest.deleteAssets` moves items to Recently Deleted and there is no public API to pull them back. The design handles this by making undo pre-commit only and saying so in the commit confirmation and the done state. If the copy ever implies an in-app restore after commit, that is a defect, not a wording choice.
- **Performance on large months.** A month can hold hundreds of groups. Mitigations: build the queue lazily per month (IDs only, no thumbnails up front); keep at most 3 card views alive; `ThumbnailLoader` prefetches only the next 2 cards; group cards render at most 3 thumbnails. No month cap: capping would silently hide reviewable groups.
- **Decision staleness.** Decisions reference groups from one scan. A rescan, a group deleted from Results, or a keeper changed in `GroupReviewView` can all invalidate them. The session is keyed by `scannedAt`, cleared on rescan, and pruned on open; a keeper change discards that group's decision. Any path that deletes from a stale decision is a data-loss bug.
- **Free-budget edge.** A batch that exactly equals the remaining budget is fine; a batch one over must show the paywall with zero deletions performed. The pre-check must use the same `remainingFreeDeletes` the commit path uses, or the two disagree.
- **Screenshot-lane determinism.** A gesture-driven flow is the least deterministic screen in the app. The lane must drive it with buttons only, on the fixed sample, and assert on the progress label text, not on card positions. If a drag is ever needed in a test, that test is wrong.

## Files touched

- `PhotoSweep/Logic/SwipeMode.swift` (new) — pure logic, Foundation-only, Linux-testable: month bucketing, deck queue building, the decision stack (push / pop / undo), batch totals, and the budget pre-check. No SwiftUI, no PhotoKit, so it joins the `PhotoSweepLogic` package.
- `PhotoSweep/Logic/Types.swift` — `SwipeCard` (group card vs screenshot card), `SwipeDecision` (card ID, keep/delete, keeperID at decision time). Small value types; keep them here with the other shared types.
- `PhotoSweep/Services/AppState.swift` — swipe session state (current month, decisions, persistence), the batch commit that reuses the existing `confirmDelete` paths, and clearing the session in `runScan`. No new deletion primitive: the existing `DeletionRequest` / `PHAssetChangeRequest` path is the only way anything is deleted.
- `PhotoSweep/Views/SwipeModeView.swift` (new) — the deck, month picker, progress bar, action buttons, summary sheet, and month-done state. Presented as a `fullScreenCover`.
- `PhotoSweep/Views/HomeView.swift` — one entry card ("Swipe through October: 9 cards to review") above the category cards. No sixth tab: the tab bar already has five items and the floating bar has caused layout defects twice.
- `PhotoSweep/Views/ResultsView.swift` — a "Swipe" entry in the toolbar, same destination as the Home card. Optional if the Home card alone proves discoverable enough; decide in QA.
- `PhotoSweep/SampleData/SampleScan.swift` — add a September duplicate trio (`day -28`) so the lane has two months with cards. Nothing else in the sample changes; the 27-item total becomes 30 and the group count 4 becomes 5, so update the counts in the file header comment and any test that pins them.
- `Tests/SwipeModeTests.swift` (new) + `LinuxTests/SwipeModeTests.swift` (mirror) — month bucketing order, queue contents, undo restores the card, budget pre-check blocks an over-budget batch, keeper change discards the decision. Same bodies in both suites, per the Package.swift rule.
- `UITests/ScreenshotTests.swift` — `test11SwipeDeck` and `test12SwipeMonthComplete` (button-driven, see above). Shot count 10 becomes 12.
- `PhotoSweep/App/PhotoSweepApp.swift` — no change expected: the cover is presented from `HomeView` / `ResultsView`, which already own the environment objects. If the Developer finds the cover needs state higher up, say so in the run log rather than silently restructuring.
- `project.yml` — no change: the app target sources glob `PhotoSweep`, so new files under it are picked up. Do not add per-file entries.
- `app-store-listing.md`, `README.md` — update the shot count (10 to 12) and shot list when the new screenshots land. Copy for the listing is a separate pass; this note does not draft it.

## Open questions for the PM / Aman

- **Entry point:** Home card plus Results toolbar button, no new tab (recommended above). Is that discoverable enough for the daily habit loop, or does swipe mode earn a sixth tab despite the crowded bar?
- **Undo scope:** session-scoped, pre-commit only (recommended). Is that acceptable, or should undo stay available after commit as a guided "recover in Photos" flow with a deep link into the Photos app?
- **Batch size:** commit at month end, or also offer "Delete reviewed so far" mid-month? Month-end keeps the commit step simple; a mid-month commit adds a second summary path.
- **Skip limit:** unlimited skips that re-queue (recommended) vs a "decide later" parking lot that lets a month complete with undecided cards. The parking lot is friendlier but adds a state (undecided, parked) the progress bar has to explain.
- **Screenshot cards in the same deck:** mixed in with group cards by month (recommended) vs a separate screenshots-only deck. Mixed keeps one queue per month; separate keeps the deck purely about groups.
- **Does swipe mode need a Pro gate of its own?** Recommended: no. Review is free, deletes count against the existing budget. If PS-2 lands "first cleanup free", the batch commit is the place that policy applies, not the deck.
