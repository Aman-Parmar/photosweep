# PhotoSweep — Roadmap

## v1 (this scaffold — shipped)

- XcodeGen project (com.singhsec.photosweep, iOS 17+, SwiftUI, iPhone-only)
- Pure-logic layer, Linux-tested: SimilarityEngine (feature distance, exact-hash, blurry/dark, burst), GroupingEngine (neighbour-window grouping, large-video ranking), KeeperPicker (sharpest → most pixels → largest file → earliest), StorageEstimator (estimates, always labelled as such)
- PhotoKit scanner: on-device only, limited-access aware, average-hash similarity + gradient-energy sharpness, deletion via PHAssetChangeRequest to Recently Deleted
- Views: Home scan, Results grouped by category, Group review with keeper pick, Screenshots bulk review, Large videos, Paywall, Settings
- StoreKit 2: Pro $29.99/yr (7-day trial, App Store Connect) / $39.99 lifetime, no weekly plan, no monthly tier
- Cleanup report export (CSV, Pro): one row per group plus large videos, with scan totals — the benefit the paywall, README and listing already promised
- CI: Linux first, then macOS test + 7-shot screenshot lanes in parallel; docs-only skips CI; cancel in-flight
- Docs: README, VALIDATION, ROADMAP, SUBSCRIPTION_PLAN, app-store-listing, privacy-policy

## v1.1 — Real-device verification (needs Aman's iPhone + enrolment)

- Scan a real 10,000-photo library: wall-clock, memory, grouping quality. Tune the ~0.35 threshold and the neighbour window from real results.
- Verify the keeper picker on real bursts (sharpest frame vs. best moment are not always the same photo).
- Real 1024x1024 App Icon. Done 2026-11-18: blue gradient, three photo cards with a broom sweeping duplicates away; all sizes in `AppIcon.appiconset`, verified at 120px.
- photosweep.singhsec.com support + privacy pages live. Done 2026-11-18: subdomain created on Hostinger with Lifetime SSL; static HTML in `website/` uploaded as `photosweep-support/index.html` and `photosweep-privacy/index.html` (clean URLs needed the folder form); verified live at https://photosweep.singhsec.com/photosweep-support and https://photosweep.singhsec.com/photosweep-privacy, exact text matches the repo files.

## v1.2 — Polish

- Video thumbnails and duration in group review: NOT APPLICABLE — videos are never grouped (GroupingEngine pulls them out first, by design); they already show thumbnails and duration in the Large Videos tab, which is the only place videos appear.
- "Similar" explanation: show the two photos side by side when the user taps a group member. Done 2026-11-18: every non-keeper tile has a compare button (bottom-right) opening a sheet with the keeper and the tapped photo side by side, file size and dimensions, and a "Keep this photo instead" button. Covered by screenshot test 08-compare (extra capture, not one of the 7 listing shots).
- Widgets: "storage freed this month" glance (only if it earns its place — no widget for its own sake). Data layer done 2026-11-18: every confirmed deletion records a `CleanupEvent` (date, photos, bytes) in SwiftData, and Settings shows the freed-this-month total. The widget extension itself still needs an App Group to share the store, which needs enrolment (Team ID) — build it after enrolment.

## v2 — Only if v1 earns it

- `VNFeaturePrintObservation.computeDistance` in-memory (replaces the average hash when observations can be kept alive for a scan).
- A dedicated blur detector (Laplacian variance) instead of the gradient-energy proxy.
- Live Photos: treat a Live Photo and its still as one item.
- iCloud-only assets: download-on-demand progress instead of skipping silently.

## Deliberately not on the roadmap

- Auto-delete, scheduled cleaning, or cleaning without review.
- Cloud backup, sync, or any server.
- Weekly subscription, ads, or selling a "storage booster" that is just the iOS Settings page.
- Social sharing of "I freed X GB" (a cleaner is a utility, not a streak).
