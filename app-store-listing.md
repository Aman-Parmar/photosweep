# PhotoSweep: App Store Listing (draft)

## Name

PhotoSweep: Photo Cleaner

## Subtitle

Free up storage, honestly.

## Description

Your iPhone is full of photos you don't need: the same shot taken three times, the burst where only one frame is good, the blurry one, the screenshots you forgot, and the 4K video from two years ago.

PhotoSweep finds them on your phone, nothing uploaded, and lets you review every group before anything is deleted.

- Duplicates: same photo, saved twice (or three times)
- Similar and burst shots: pick the best frame, delete the rest
- Blurry or dark photos, for review
- Screenshots, grouped for bulk review
- Large videos, largest first

You pick the keeper. You confirm the delete. Deleted photos go to Recently Deleted, where you can recover them for 30 days.

No weekly plan. No auto-delete. No account, no ads, nothing uploaded. Free scans and reviews forever. Pro ($29.99/year or $39.99 once) adds unlimited deletes, large-video cleanup, and export.

Note: Apple Photos already finds exact duplicates free (Duplicates album). PhotoSweep finds what it doesn't: similar and burst shots, blurry photos, screenshots, and large videos. Storage figures are estimates. Photos may report slightly different sizes, and space is only freed once Recently Deleted is emptied.

## Keywords

photo cleaner, duplicate photos, similar photos, burst photos, screenshots, large videos

## Privacy

- No account, no analytics, no ads.
- All scanning happens on your device. No photo ever leaves your phone.
- Privacy policy: https://photosweep.singhsec.com/photosweep-privacy
- Support: https://photosweep.singhsec.com/photosweep-support

## Screenshots (7, iPhone 17 Pro Max)

1. Home scan: summary and category cards
2. Duplicates group review: keeper marked, delete proposed
3. Similar group review: burst frames, pick the best
4. Blurry group review
5. Screenshots: bulk review
6. Large videos: largest first
7. Paywall: yearly $29.99 (7-day trial) / lifetime $39.99, no weekly plan

## Review notes for Apple

- Differentiator (Guideline 4.3(b)): on-device photo cleaning with human review before every deletion, honest pricing (no weekly plan), no account, no ads, nothing uploaded. The category's incumbents charge $5.99–$11.99/week and auto-delete; PhotoSweep does neither.
- Deletion is user-initiated per group, confirmed in an alert, and goes through PHAssetChangeRequest to Recently Deleted (undoable for 30 days).
- Demo: the app runs in screenshot mode with synthetic sample data; a real library is needed to exercise PhotoKit scanning. Provide a test device with photos, or review the screenshot-mode flow.
