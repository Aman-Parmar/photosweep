# PhotoSweep website pages

Static HTML only, no server code, no tracking, no external dependencies.

## Files

- `photosweep-support.html` - upload to photosweep.singhsec.com as `/photosweep-support`
- `photosweep-privacy.html` - upload to photosweep.singhsec.com as `/photosweep-privacy`

These are the exact URLs in App Store Connect (see `app-store-listing.md`):
- Support: https://photosweep.singhsec.com/photosweep-support
- Privacy: https://photosweep.singhsec.com/photosweep-privacy

The privacy page text matches `privacy-policy.md` in the repo root. The support
page contact is support@singhsec.com. That address must exist as a Hostinger
email forwarder to Aman's Gmail before submission, or support mail to it
will bounce.

Rule (Aman, 2026-11-09): each app gets its own subdomain on singhsec.com.
PhotoSweep is photosweep.singhsec.com. Never touch blogs.singhsec.com.

## Deploy on Hostinger hPanel

Same pattern as LabelCheck (`~/workspace/ios-apps/labelcheck/website/README.md`).

1. In Hostinger hPanel, create subdomain photosweep.singhsec.com on the same hosting plan as blogs.singhsec.com, with SSL on. Do not change blogs.singhsec.com in any way.
2. Use File Manager, go to the document root for photosweep.singhsec.com (not public_html for the apex, not the blogs subdomain folder).
3. Upload both HTML files there, with these exact filenames. If Hostinger serves `.html` files directly, you may need a redirect or rename to `photosweep-support/index.html` and `photosweep-privacy/index.html` instead, so the clean URLs open:
   - `photosweep-support.html` must open at https://photosweep.singhsec.com/photosweep-support
   - `photosweep-privacy.html` must open at https://photosweep.singhsec.com/photosweep-privacy
   Test both URLs in a browser before submitting to Apple.
4. Before launch, confirm the support email on the support page is the one Aman wants live; if the dedicated alias exists by then, swap it in and re-upload.

## Do not submit until

- Both URLs open in a browser, with the correct content, no error page.
