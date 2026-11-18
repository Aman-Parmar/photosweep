# PhotoSweep — Validation

Validated 2026-11-17/18 on three tracks (demand, public APIs / on-device ML, App Store legal). Research only for the validation; the scaffold was built after.

## Verdict

Build it. Biggest money in the other-styles set, soft incumbents, a clear honest-pricing wedge, and no legal blocker. Two honest conflicts, stated plainly:

1. **Retention is a one-off flaw.** Once cleaned, there is no daily habit — screenshots and bursts refill the library, but slowly. A photo cleaner is not a streak app. The price is set accordingly (yearly/lifetime, not a weekly trap that pretends otherwise).
2. **The free floor is real.** Apple Photos Duplicates (iOS 16+) already handles exact duplicates free. The product is only what Apple does NOT do: similar/burst, blurry/dark, screenshots, large videos. The listing and the README say so.

## 1. Demand

- **Money is enormous at the top, and ad-driven:** Cleanup (Phone Storage Cleaner) est. ~$11M/mo on ~2M downloads, 62.5× the Utilities median of $176K, running ~3,800 live Meta ads. Cleaner Neat est. $601K/mo, Clean Manager est. $200K/mo, AI Cleaner est. $80–101K/mo. Third-party estimates (Airbridge, Oct 2026), can be off 30%+ — the order of magnitude is the point.
- **Incumbents are beatable on trust, not scale:** GetAppNiche Utilities (Oct 28, 2026): Cleaner = 1,153 apps, 102 make $1k+/mo, 11 make $10k+/mo, median winner only 220 ratings. Cleanup alone has 751K ratings at 4.65★, Clever Cleaner 4.78★ from 84.5K, Swipewipe 4.69★ from 100K.
- **The repeat 1★ complaint is pricing, not cleaning:** weekly plans $5.95–$11.99, charges after cancelled trials, long unskippable ads, "free" claims that hit a paywall at launch. Clever Cleaner is the most generous free tier (daily limits, no ads); MemeScanr's wedge is $59.99 lifetime.
- **The free floor:** Apple Photos Duplicates handles exact duplicates free. It does not handle similar/blurry photos, screenshots, memes, or large videos — that gap is the whole product.
- **What lost in this set:** PDF scanner ranked #2 (softest incumbents, 71 winners, median 168 ratings; Scaniva proves $12.99-once local-only). Sleep sounds mixer ranked #3 (best retention, nightly habit, but the sounds ARE the product and Apple Background Sounds is free). General flashcards (Anki/Quizlet moat), plain Pomodoro (Forest + free timers, Guideline 4.3(b) named), and packing list ($2.99 once, episodic) were rejected.

Sources: https://www.airbridge.io/en/app-revenue/cleanup, https://getappniche.com/guides/best-utilities-app-niches, https://odoa.app/blog/best-photo-cleaner-apps-iphone/

## 2. Public APIs / on-device ML

- **No backend, no secrets, no paid keyed API** — if scoped honestly. All 8 concepts in the other-styles set work local-only; the traps are built-in iOS free features, not servers.
- **PhotoKit** (`PHPhotoLibrary`, `PHAsset`, `PHCachingImageManager`) for library access; sharpness via gradient energy and brightness via mean luminance (CoreGraphics, see below); similarity via a compact perceptual hash (see below). No Vision call is needed in v1.
- **Why an average hash, not `VNGenerateImageFeaturePrintRequest`:** `VNFeaturePrintObservation` does not expose its vector as `[Float]` on iOS 17, so the observation cannot be cached or compared by the pure-logic engine. The v1 scanner computes an 8×8 average hash (64 floats) instead — same shape, same distance function. A future version can keep observations in memory and use `VNFeaturePrintObservation.computeDistance` directly.
- **Neighbour window, not pairwise:** comparing every pair in a 35k-photo library is ~600M pairs. Grouping compares only within a time-sorted neighbour window (±20), which covers bursts and re-takes while keeping the work linear. The threshold (~0.35) and window are named constants with tests pinning the boundary.
- **The built-in threat:** Photos Duplicates kills exact-dup. The wedge is only similar/burst/screenshots/blurry/large videos, which Apple documents no equivalent for.
- **Real-device gap:** feature-print generation is Neural Engine inference per image; scan wall-clock on a 10,000-photo library can only be verified on a real device, not the simulator.

## 3. App Store legal

- **No TrueSpend-style blocker.** Guideline 5.1.1(ix) (legal entity for highly regulated fields) does not apply — a photo cleaner is not banking, healthcare, gambling, or any listed field.
- **Risk is MEDIUM privacy, not law:** Photos is the most-scrutinised permission. Mitigations in v1: prefer the out-of-process picker where it fits; full-library scan is the core job, so the purpose string says exactly why (`NSPhotoLibraryUsageDescription`: "scan your library on-device to find duplicates for you to review"); no Photos data is used to build a database or for ads; nothing leaves the device.
- **Destructive action:** deletion must be user-initiated per item/group, with a visible review step — never auto-delete. v1 enforces this in code (`DeletionRequest.isExecutable` requires `confirmedByUser == true`) and in UI (confirmation alert + Recently Deleted, undoable for 30 days).
- **Guideline 4.3(b):** photo cleaners are crowded; the review notes must state the differentiator (honest pricing, on-device, review-before-delete, no weekly plan).
- **No account, no analytics, no ads, no third-party SDKs** → privacy label "Data Not Collected" (nothing leaves the device); a privacy policy URL is still mandatory in App Store Connect and in-app.

Sources: https://developer.apple.com/app-store/review/guidelines/ (5.1.1(ix), 5.1.1(ii)/(iii), 5.1.2(iv), 4.3(b))

## Pricing (validated)

- Free scan, **$29.99/yr or $39.99 lifetime** (Clever Cleaner / MemeScanr anchor). Never a weekly plan.
- Free tier: scan + review unlimited, 20 deletes total. Pro: unlimited deletes, large-video cleanup, export.
- 7-day trial on yearly (configured in App Store Connect), none on lifetime — same shape as Clear Days.
