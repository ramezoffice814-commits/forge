# Store Asset Requirements

Roadmap Item 20 ("Production Release & Store Submission Prep"). What
Forge would need visually before a real Play Store listing could go
live, and the current state of each asset. **No new brand asset is
created by this document** — per this item's own instruction, no icon,
splash screen, screenshot, or graphic is invented here; this is an
audit and a spec, not artwork.

**Policy-verification note**: the size/format specs below reflect
Google Play's asset requirements as understood at the time of this
writing. Store asset specs are Google's own policy and can change —
**verify the exact current specs in Play Console's own "Store
listing" → "Main store listing" asset uploader before finalizing any
asset**, rather than trusting this table blindly. This is flagged for
explicit current-policy verification, not asserted as guaranteed
current fact (same treatment as the Android target-API question in
[docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md)).

## Current state (confirmed by reading the repo)

| Asset | Current state | Location |
|---|---|---|
| Android launcher icon | Stock Flutter template default, all densities | `android/app/src/main/res/mipmap-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` |
| Android adaptive icon | Not configured — no adaptive-icon XML found | n/a |
| Android splash/launch background | Stock Flutter default (plain white background); customization instructions exist in the file only as comments, unused | `android/app/src/main/res/drawable/launch_background.xml` |
| Web favicon/PWA icons | Not independently re-audited this pass — carried over from Item 18/19's finding that `manifest.json`'s `theme_color`/`background_color` are still the default Flutter blue (`#0175C2`) | `web/manifest.json`, `web/icons/` |
| Windows app icon | **Already Forge-specific** — the one asset that is not a template default | `windows/runner/resources/app_icon.ico` |
| Play Store feature graphic | Does not exist | n/a |
| Play Store screenshots | Do not exist | n/a |
| Play Store hi-res icon (512×512) | Does not exist as a separate store-upload asset (the launcher icon itself is still the stock default anyway) | n/a |

## What Play Store submission requires (spec, not yet produced)

| Asset | Typical requirement | Status |
|---|---|---|
| App icon (hi-res, store listing) | 512×512 PNG, 32-bit with alpha | Missing — and the underlying launcher icon it would be based on is still the stock default, so this blocks on real branding first. |
| Feature graphic | 1024×500 PNG or JPG, no alpha | Missing. |
| Phone screenshots | Typically 2–8 images, JPEG or 24-bit PNG, each dimension between roughly 320px and 3840px, with a max aspect ratio around 2:1 | Missing — see the screenshot plan in [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| 7" / 10" tablet screenshots | Optional but recommended if the app supports tablet layouts | Not evaluated — Forge's existing golden-test coverage already includes "wide/tablet reference size" variants for several screens (dashboard, progression, competition), so tablet layouts do render; no tablet screenshots have been captured. |
| Short description | Up to 80 characters | Draft exists — see [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| Full description | Up to 4000 characters | Draft exists — see [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| Privacy Policy URL | Required, must be a live, publicly reachable URL | **Blocked** — `/legal/privacy` exists as an in-app route (Item 19) but is not hosted anywhere reachable outside the app itself; Play Console needs a URL, not an in-app route. A real production Web deployment (out of scope for this item) or a separately hosted copy of the same content would be needed. |

## What blocks producing the missing assets

- **App icon / adaptive icon / splash / feature graphic**: all need
  real brand art (a logo, a color identity) that doesn't currently
  exist anywhere in this repository — inventing one is a design
  decision, not an engineering one, and explicitly out of this item's
  scope ("do not invent final legal terms" extends in spirit to "do not
  invent final brand assets" — neither is this codebase's call to make
  unilaterally).
- **Screenshots**: blocked on the same real-device/real-run
  verification gaps already tracked in
  [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) (no Android
  device/emulator available in this environment) — see the screenshot
  plan in [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md) for exactly
  which screens/states are proposed once a device is available.
- **Hosted Privacy Policy URL**: blocked on a real Web hosting decision,
  which is itself blocked on the legal-content approval gate (no point
  hosting draft text as if it were final).

## What this document does not do

It does not create any icon, splash screen, screenshot, or graphic. It
does not choose a brand color or logo. It exists so the exact list of
what's missing — and exactly why — is written down once, rather than
discovered piecemeal during an actual submission attempt.
