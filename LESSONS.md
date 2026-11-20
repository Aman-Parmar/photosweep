# PhotoSweep — Lessons Learned

Living notes for the Developer + QA loop. One entry per sprint review (Friday) and per
defect that taught us something. No invented stats, no client stories, no prices
beyond what SUBSCRIPTION_PLAN.md states.

## Sprint 1 retrospective checkpoint — Friday 2026-11-20 (mid-sprint, sprint runs to Mon 2026-11-24)

### Done (all QA-passed by a separate QA agent, CI green)

- PS-1 Video compression (HEVC, on-device): 3 presets, size preview, progress UI, original to Recently Deleted. CI run 44384013048.
- PS-3 Live Photo to still: estimate model, on-device still extraction, convert sheet, one conversion costs one free delete. CI run 44397430404.
- Swipe mode (logic + UI): month-by-month deck, batch commit reusing confirmDelete with budget pre-check, undo pre-commit, Home entry card + Results toolbar button, test11/test12, 12-shot lane. QA-passed run 44461230906, head 17221c8.
- Sheet half-height polish: paywall / compress / convert sheets open at medium detent with scroll-to-result. QA-passed run 44473791029.
- Cleanup report export (CSV, Pro) shipped in v1.
- v1 code-complete: 12 screenshot tests, all 1320x2868 full-bleed, no black bars; support + privacy pages live at photosweep.singhsec.com.

### Not done / blocked

- PS-2 Free-tier generosity: DECISION NEEDED from Aman (first full cleanup free, or raise free deletes from 20 to 100). 20 deletes is the stingiest honest free tier in the category.
- PS-4 Vision feature prints: stretch, awaiting Aman's call.
- Storage widget + weekly nudge: BLOCKED on enrolment (needs App Group + Team ID).
- On This Day + streaks: Next item, PM call at Friday review. Pointless without swipe mode; swipe mode is now done, so it is the leading Next candidate.
- Real-device verification (10k-photo library, threshold tuning, keeper picker on real bursts): needs Aman's iPhone + enrolment.
- Submission: blocked on Apple Developer enrolment + signing secrets (shared with Clear Days and LabelCheck).
- Home header estimate excludes large videos (photo groups only, ~31 MB, while the Large videos row says ~2.7 GB): PM/copy call, not a bug fix. The listing already hedges with "Storage figures are estimates".

### Defects found this sprint (all fixed, QA-passed, none shipped broken)

- Home "How it works" text sat partly behind the floating tab bar (fixed: steps shortened to one line each, test01 asserts step 3 hittability at rest).
- Shot 01 header text ghosted under the nav bar (fixed: the scroll drag removed, test01 no longer scrolls).
- Paywall / compress / convert sheets left a large empty band below their content (fixed: medium detent + scroll-to-result; end state of the compress sheet expands to large during the run, most likely via the scrollTo-driven List scroll, which QA judged acceptable because the full result is visible with no clipping).
- Swipe deck next-card peek barely visible (fixed: 0.90 scale, 24pt offset, 0.8 opacity, systemGray5 fill + separator outline).
- Swipe month-done state left a large empty band below its content (fixed: deck and done state vertically centred; content centre within ~48px of screen centre).
- Video compression hardcoded 30 fps (fixed: uses the source track nominalFrameRate, falling back to 30; real-device verification with a 60 fps clip still pending enrolment).
- Stale counts after the lane grew 7 to 12 shots: screenshot lane guard checked 9 PNGs, project.yml comment said seven screens, ROADMAP shipped section said 8-shot lanes. A dropped shot would have passed CI silently.

### Lessons

- A lane growth must update every count in the same commit. Shot counts live in at least five places: the workflow guard and its comment, the project.yml UITests comment, README, app-store-listing.md, ROADMAP. The guard is the one that matters most: if it lags the lane, CI passes while a shot is silently missing.
- Verify sample-data dates against the design before building. The swipe-mode design's month map was wrong (base is 2025-10-09, so the September groups are September and only the screenshots are October); the fix was found during the build, not before it.
- Sheet detent end state needs an explicit decision. Medium detent plus scroll-to-result works, but the sheet can expand to large mid-run. Decide "stay at medium and scroll" vs "expand so the result is fully visible" deliberately; do not let the scroll behaviour decide it.
- Sharing a duplicated UI pattern (KeepBadgeLabel, thumbnailOverlayIcon, caption modifiers, phase-change scroll) is safe hygiene only when rendering is byte-identical. The screenshot lane is the proof: if the shots do not change, the refactor did not change the UI.
- Do not force a hygiene commit. Several 15-minute runs found no genuine item and correctly pushed nothing. A change for its own sake is churn, not hygiene.
- Never use `gh run watch`. It polls every 3 seconds and exhausts the GitHub API rate limit (403), blocking all gh calls for about an hour. Slow poll only: one `gh run view` per check, at least 180 seconds between checks, at most ~8 checks.
- Docs-only pushes skip CI by design (workflow paths-ignore on *.md). After a docs push, confirm the latest run id is unchanged rather than waiting for a new run.
- Every Info.plist key the app needs must live in project.yml; XcodeGen rewrites the plist from project.yml and drops keys that live only in the checked-in file. Verified 2026-11-20: NSPhotoLibraryUsageDescription, ITSAppUsesNonExemptEncryption, UISupportedInterfaceOrientations, CFBundleDisplayName and UILaunchStoryboardName are all in project.yml. The checked-in plist holds only Xcode-generated standard keys; UIApplicationSceneManifest is not needed (SwiftUI @main lifecycle) and the app demonstrably launches in CI.
- Repo-doc note (2026-11-20): the loop body lists LESSONS.md and GO_TO_MARKET.md as repo-root docs, but neither existed in the repo or its git history. This file was created at the Sprint 1 Friday review to hold the retrospective. GO_TO_MARKET.md is still absent; it is not created here because there is no approved content to put in it.
