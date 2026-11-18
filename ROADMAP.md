# PhotoSweep — Roadmap (agile, living)

Agile model since 2026-11-18 (Aman: adopt agile, not waterfall). One-week sprints, Monday planning, Friday review. This file is the single source of truth for what gets built: the Researcher scores backlog items by market evidence, the PM picks the Sprint Backlog, the Developer loop builds it in order, QA verifies each item independently. Nothing moves here without evidence — pre-launch the evidence is competitor reviews, pricing, and ASO; post-launch it is real downloads, conversion, retention, and App Store reviews.

## Shipped (v1, code-complete, not yet submitted)

- XcodeGen project (com.singhsec.photosweep, iOS 17+, SwiftUI, iPhone-only)
- Pure-logic layer, Linux-tested: SimilarityEngine, GroupingEngine (neighbour-window grouping, large-video ranking), KeeperPicker, StorageEstimator
- PhotoKit scanner: on-device only, limited-access aware, average-hash similarity + gradient-energy sharpness, deletion via PHAssetChangeRequest to Recently Deleted
- Views: Home scan, Results grouped by category, Group review with keeper pick, side-by-side compare, Screenshots bulk review, Large videos, Paywall, Settings
- StoreKit 2: Pro $29.99/yr (7-day trial) / $39.99 lifetime, no weekly plan, free 20 deletes
- Cleanup report export (CSV, Pro)
- Real 1024x1024 app icon; photosweep.singhsec.com support + privacy pages live
- CI: Linux first, then macOS test + 8-shot screenshot lanes in parallel; docs-only skips CI; cancel in-flight

## Sprint 1 — 2026-11-18 to 2026-11-24 (in progress)

Sprint goal: close the biggest market gaps that cost conversion, without touching the trust wedge.

- **PS-1 Video compression (HEVC, on-device)** — medium. DONE 2026-11-18 (QA-passed, CI run 44384013048 green, 9 shots). Evidence: in every top-5 cleaner; Cleanup's compressor called "genuinely its best tool". Acceptance: 3 presets, size preview before/after, progress UI, original goes to Recently Deleted. Converts without deleting memories.
- **PS-2 Free-tier generosity + trust positioning** — small. DECISION NEEDED from Aman: first full cleanup free, or raise free deletes from 20 to 100. Evidence: 20 deletes is the stingiest honest free tier (Clever Cleaner gives a daily allowance plus unlimited Swipe free); "free" claims that aren't are exactly what 1-star reviews punish. Acceptance: config + paywall copy "No weekly plan. Ever." No weekly plan anywhere, ever.
- **PS-3 Live Photo to still conversion** — small-medium. DONE 2026-11-18 (QA-passed, CI run 44397430404 green, 10 shots). Evidence: listed by Clever Cleaner, CleanMyPhone, Cleanup; Live Photos run 1.5-3x a still. Acceptance: convert keeps the still, original to Recently Deleted, GB saved shown. Build: estimate model (still ~half, midpoint of the 1.5-3x range), on-device still extraction (original file bytes, date/location kept), Live Photos list + convert sheet (test10), one conversion costs one free delete, Pro unlimited. Sample: 3 Live Photos, 27 items total.
- **PS-4 (stretch, pending Aman's call) Vision feature prints** — medium. Replaces the average hash with `VNFeaturePrintObservation.computeDistance`. Evidence: competitors market "AI grouping"; Cleanup mislabels ~3% of flagged duplicates. Offered to Aman 2026-11-18, awaiting his call.

## Next (prioritised backlog, evidence-scored)

- **Swipe mode, month-by-month, with undo + progress** — large. Needs Architect design first (new flow, deck, undo, per-month progress). Evidence: the category's dominant UX; 5-star praise is built on it ("fun", "1,000 photos a day", "use almost daily"). The habit loop. Sequence after PS-1/PS-3.
- **Storage widget + weekly "new clutter" nudge** — small-medium. BLOCKED on enrolment (needs App Group + Team ID). Evidence: widgets shipped by Clean AI, CleanX, Smart Cleaner, Swipewipe; the only honest re-engagement surface for a utility. Build after enrolment.
- **On This Day + streaks** — medium, only after swipe mode. Evidence: Swipewipe's retention engine, 5-star daily use. Pointless without swipe mode first.
- **Real-device verification (v1.1)** — needs Aman's iPhone + enrolment. Scan a real 10,000-photo library: wall-clock, memory, grouping quality. Tune the ~0.35 threshold and neighbour window from real results. Verify keeper picker on real bursts.

## Later / unsequenced

- **Video compression: use the source frame rate, not hardcoded 30 fps (QA-found 2026-11-18, minor, non-blocking)** — FIXED 2026-11-18 in the PS-3 commit: `VideoCompressor.export` now passes `videoTrack.nominalFrameRate` (falling back to 30 when 0/unknown). Real-device verification with a 60 fps clip still pending enrolment.
- **app-store-listing.md "Screenshots" section is stale (QA-found 2026-11-18, minor, non-blocking)** — FIXED 2026-11-18: listing, README, and workflow comment now say 10 shots and list all 10 (08 compare, 09 video compress, 10 live-photo convert).
- **Home "How it works" text sits partly behind the floating tab bar (QA-found 2026-11-18, minor, non-blocking)** — FIXED 2026-11-18, QA-PASSED 2026-11-18 (run 44408458015, commit c4739a4): the rework shortens all three steps to one line each and test01 captures at rest with a hittability assertion on step 3 instead of dragging. Independent QA verified shot 01 by eye: all three steps fully visible above the floating tab bar with clear space below step 3.
- **Shot 01 header text ghosted under the nav bar (QA-found 2026-11-18, minor, non-blocking)** — FIXED 2026-11-18, QA-PASSED 2026-11-18 (run 44408458015, commit c4739a4): the b3f66d2 drag is removed entirely; test01 no longer scrolls. Independent QA verified shot 01 by eye: large "PhotoSweep" title, "Free up storage, honestly." headline and intro paragraph fully clean with no ghosting; summary card (~23 MB, 27 photos) and all 6 category rows in frame; 1320x2868 full-bleed.
- **Paywall / compress / convert sheets leave a large empty band below their content (QA observation 2026-11-18, cosmetic, non-blocking, pre-existing)** — in shots 07, 09, 10 the sheet content ends roughly two-thirds down and the Done button sits at the bottom, leaving a wide blank area. Byte-identical to run 44402903619, so not a regression from the rework; consider tightening sheet height or content spacing in a later polish pass.
- Dedicated blur detector (Laplacian variance) instead of the gradient-energy proxy.
- Live Photos: treat a Live Photo and its still as one item (partly covered by PS-3).
- iCloud-only assets: download-on-demand progress instead of skipping silently.

## Deliberately not building

- **Weekly subscription, ever.** The category's #1 complaint (18-28% of low-star reviews; $310-623/year annualised). It would destroy the trust wedge.
- Auto-delete, scheduled cleaning, or cleaning without review.
- Cloud backup, sync, or any server. Cloud AI enhancement (breaks the on-device privacy promise).
- Email cleanup and contact merge (low real value, highest-risk extra; Cleaner Guru over-deleted contacts).
- Secret vault, system/cache/RAM cleaning claims (impossible on iOS; roundups penalise them).
- Social sharing of "I freed X GB".

## Kill gate

90 days after launch: if weekly active cleaners are near zero and Pro conversion is zero, stop adding features to save it. Do not build swipe mode or any large item to rescue a dead app.
