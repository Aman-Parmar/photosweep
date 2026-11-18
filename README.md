# PhotoSweep — Free up iPhone storage, honestly.

A native iOS photo cleaner. It finds duplicates, similar/burst shots, blurry photos, screenshots and large videos — on the device, nothing uploaded — and you review every group before anything is deleted. Deleted photos go to Recently Deleted, where Photos keeps them for 30 days.

- Platform: iOS 17 and later, iPhone
- Language and UI: Swift 5.9 (per `project.yml`), SwiftUI
- Data: PhotoKit on-device only, SwiftData for scan history (metadata only — no image data is ever stored)
- Local ML: average-hash similarity + gradient-energy sharpness (CoreGraphics, on-device)
- Payments: StoreKit 2, serverless (no backend, no receipt server)
- Project generation: XcodeGen (`project.yml` at the repo root)
- CI: GitHub Actions (`.github/workflows/ios.yml`)

## What it does

- Scan your library on-device: exact duplicates (same file contents), similar/burst photos (feature similarity within a time-sorted neighbour window — never pairwise over the whole library), blurry or dark photos, screenshots for bulk review, and large videos ranked by size
- Review before delete: every group shows its photos, the keeper is pre-picked (sharpest, then highest resolution), and you can tap any photo to keep it instead
- Delete only when you confirm: deletion goes through `PHAssetChangeRequest` to Recently Deleted — undoable for 30 days
- Storage estimates, always labelled "estimate": Photos reports slightly different sizes, and space is only freed once Recently Deleted is emptied
- Free scan and review forever; Pro is depth only (unlimited deletes, large-video cleanup, export)

## What it deliberately does not do

- No auto-delete. Ever. Nothing is deleted without you reviewing the group and confirming.
- No cloud upload, no account, no analytics, no ads, no third-party SDKs.
- No weekly plan and no monthly tier. The category's 1-star complaint is pricing ($5.99–$11.99/week traps, charges after cancelled trials) — PhotoSweep's whole wedge is honest pricing.
- No "save X GB guaranteed". Every figure is an estimate.
- Apple Photos already finds exact duplicates free (Duplicates album, iOS 16+). PhotoSweep finds what it doesn't: similar/burst shots, blurry photos, screenshots, and large videos. It does not pretend otherwise.

## StoreKit products

Configure these exact product IDs in App Store Connect under the PhotoSweep app. Prices in USD.

| Product ID | Type | Price |
| --- | --- | --- |
| `photosweep_pro_yearly` | Auto-renewable subscription, 1 year | $29.99 |
| `photosweep_pro_lifetime` | Non-consumable, one-time purchase | $39.99 |

Notes on pricing (see `SUBSCRIPTION_PLAN.md` and `VALIDATION.md`):

- No weekly plan, no monthly tier: the wedge is honest pricing against the category's weekly traps. Yearly at $29.99 with a 7-day free trial, lifetime at $39.99 (about 16 months of yearly). One Pro entitlement, not two feature sets.
- The 7-day trial on yearly is configured in App Store Connect per product (like Clear Days) — the `.storekit` file carries prices only, not the trial.
- Free tier: scan + review unlimited, 20 deletes total. Pro: unlimited deletes, large-video cleanup, export.
- Test in Xcode with the StoreKit Configuration file `Resources/PhotoSweep.storekit` (already wired into the Run scheme in `project.yml`). Test with the sandbox, never with a real Apple ID in a debug build.

## Data and honesty

- All scanning is on-device (PhotoKit + CoreGraphics). No photo, thumbnail, hash, or scan result ever leaves the phone. There is no network call anywhere in the app.
- Limited photo access is supported: the scan only sees what the user granted, and the Home screen says so plainly ("Scanned 214 of 12,400 photos").
- The similarity threshold (~0.35 feature distance) and the neighbour window (20) are named constants in `Logic/` with tests pinning the boundary behaviour. Similar grouping is a proposal, never a fact — the user reviews every group.
- Screenshots are grouped for bulk review with a warning: some screenshots are receipts, tickets, or confirmations worth keeping.

## Prerequisites

You need a Mac to build for iOS. There is no supported way to build an iOS app on Linux or Windows alone. Linux is used here only for cheap logic tests in CI.

- macOS 26 (Tahoe) or later
- Xcode 26 with the iOS 26 SDK
- Command Line Tools: `xcode-select --install`
- Homebrew: https://brew.sh
- XcodeGen: `brew install xcodegen`
- A GitHub account, for the repo and CI
- An Apple Developer Program membership, for device testing and TestFlight (see "What needs Aman" below). Simulator testing works without it — but a real 10,000-photo library can only be verified on a real device.

## Build from scratch

```bash
git clone https://github.com/Aman-Parmar/photosweep.git
cd photosweep
xcodegen generate
open PhotoSweep.xcodeproj
```

Then run on the iPhone 17 simulator (or a real device). The simulator has a tiny, synthetic photo library — the screenshot lane uses `--screenshot-mode`, which loads fixed synthetic sample data instead of PhotoKit.

## Run the tests

```bash
# Linux: pure-logic tests only (no Mac needed)
swift test

# macOS: full Xcode build + unit tests
xcodegen generate
xcodebuild test -scheme PhotoSweep \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:PhotoSweepTests

# Screenshots (7 shots, iPhone 17 Pro Max simulator)
xcodebuild test -scheme PhotoSweep \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:PhotoSweepUITests/ScreenshotTests
```

## What needs Aman

- Apple Developer enrolment ($99) + App Store Connect setup, Paid Apps Agreement + bank/tax, Small Business Program — before TestFlight or submission.
- Signing: App Store Connect API key (.p8), Team ID, and (later) Fastlane Match secrets, stored as GitHub Actions secrets — never in this repo.
- Real 1024x1024 App Icon (the repo only has the `Contents.json` sizes file).
- Support + privacy pages live before submission: `https://photosweep.singhsec.com/photosweep-support` and `https://photosweep.singhsec.com/photosweep-privacy` (same pattern as Clear Days).
- Real-device verification of a large library: scan wall-clock and grouping quality on a 10,000-photo library cannot be verified in the simulator.

## Repo visibility

This repo is PUBLIC on purpose. Public repos get free, unlimited GitHub Actions minutes; LabelCheck was flipped private on 2026-11-17 and its CI immediately blocked on GitHub billing ("recent account payments have failed or spending limit needs to be increased"). Keep PhotoSweep public. Do not flip it private without fixing billing first.
