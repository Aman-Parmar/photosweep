# PhotoSweep — Roadmap

## v1 (this scaffold — shipped)

- XcodeGen project (com.singhsec.photosweep, iOS 17+, SwiftUI, iPhone-only)
- Pure-logic layer, Linux-tested: SimilarityEngine (feature distance, exact-hash, blurry/dark, burst), GroupingEngine (neighbour-window grouping, large-video ranking), KeeperPicker (sharpest → most pixels → largest file → earliest), StorageEstimator (estimates, always labelled as such)
- PhotoKit scanner: on-device only, limited-access aware, average-hash similarity + gradient-energy sharpness, deletion via PHAssetChangeRequest to Recently Deleted
- Views: Home scan, Results grouped by category, Group review with keeper pick, Screenshots bulk review, Large videos, Paywall, Settings
- StoreKit 2: Pro $29.99/yr (7-day trial, App Store Connect) / $39.99 lifetime, no weekly plan, no monthly tier
- CI: Linux first, then macOS test + 7-shot screenshot lanes in parallel; docs-only skips CI; cancel in-flight
- Docs: README, VALIDATION, ROADMAP, SUBSCRIPTION_PLAN, app-store-listing, privacy-policy

## v1.1 — Real-device verification (needs Aman's iPhone + enrolment)

- Scan a real 10,000-photo library: wall-clock, memory, grouping quality. Tune the ~0.35 threshold and the neighbour window from real results.
- Verify the keeper picker on real bursts (sharpest frame vs. best moment are not always the same photo).
- Real 1024x1024 App Icon.
- photosweep.singhsec.com support + privacy pages live.

## v1.2 — Polish

- Video thumbnails and duration in group review (currently the Videos tab only).
- "Similar" explanation: show the two photos side by side when the user taps a group member.
- Export a cleanup report (PDF/CSV, Pro).
- Widgets: "storage freed this month" glance (only if it earns its place — no widget for its own sake).

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
