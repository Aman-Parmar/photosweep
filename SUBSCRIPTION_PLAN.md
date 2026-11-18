# PhotoSweep — Subscription Plan

## Principle

The category's 1-star complaint is pricing: $5.99–$11.99/week plans, charges after cancelled trials, "free" apps that paywall at launch. PhotoSweep's wedge is honest pricing. There is no weekly plan and no monthly tier — not as a launch omission, as a permanent position. If the price is wrong, it is wrong in one place and can be changed in one place.

## Products

Configure these exact product IDs in App Store Connect under the PhotoSweep app. Prices in USD.

| Product ID | Type | Price | Trial |
| --- | --- | --- | --- |
| `photosweep_pro_yearly` | Auto-renewable subscription, 1 year | $29.99 | 7-day free trial |
| `photosweep_pro_lifetime` | Non-consumable, one-time purchase | $39.99 | None |

- Subscription group: `photosweep_pro` (one group, so a yearly subscriber who buys lifetime is not double-charged for the same entitlement).
- One Pro entitlement, not two feature sets. Buying either product unlocks the same Pro.
- The 7-day trial on yearly is configured in App Store Connect per product (same as Clear Days) — the `.storekit` file carries prices only. Apple charges on trial end unless cancelled; Pro is active during the trial; lapsing never deletes scan history.

## Free vs Pro

| Feature | Free | Pro |
| --- | --- | --- |
| Scan (unlimited) | Yes | Yes |
| Review groups, pick keeper | Yes | Yes |
| Deletes | 20 total | Unlimited |
| Live Photo to still | 1 free delete each | Unlimited |
| Large-video cleanup | List only | Yes |
| Export cleanup report | No | Yes |

Free keeps the scan and the review forever — the job itself is never paywalled. Pro is depth only: more deletes, video cleanup, export.

## Why these prices

- Anchor: Clever Cleaner (generous free tier, no ads) and MemeScanr ($59.99 lifetime) are the honest-pricing references in the category. $29.99/yr sits below them; $39.99 lifetime is about 16 months of yearly.
- The ad-driven top (Cleanup, ~$11M/mo est.) charges weekly. PhotoSweep does not compete on ad spend — it competes on trust, and the price is part of the trust.
- At $29.99/yr, one paying user covers the (zero) server cost many times over: there is no backend, no per-user cost, no Plaid-style per-item billing. Margin is not the constraint here; discovery is.

## Test

- Test in Xcode with the StoreKit Configuration file `Resources/PhotoSweep.storekit` (wired into the Run scheme in `project.yml`). Test with the sandbox, never with a real Apple ID in a debug build.
- The real 7-day trial is configured in App Store Connect per product — blocked on Apple Developer enrolment.
