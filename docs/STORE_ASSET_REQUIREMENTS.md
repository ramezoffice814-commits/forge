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
| Android launcher icon | **CAN-branded** (updated in Roadmap Item 21) — real legacy icon at all densities plus a proper adaptive icon (foreground/background pair, safe-zone-checked) | `android/app/src/main/res/mipmap-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher{,_foreground}.png`, `mipmap-anydpi-v26/ic_launcher.xml` |
| Android adaptive icon | **Configured** (Item 21) — `ic_launcher_foreground.png` at 5 densities + a solid `#161826` background color, wired via `mipmap-anydpi-v26/ic_launcher.xml` | see above |
| Android splash/launch background | **CAN-branded** (Item 21) — fixed navy (`#161826`) plus a static centered CAN mark, replacing the stock white default | `android/app/src/main/res/drawable{,-v21}/launch_background.xml` |
| Web favicon/PWA icons | **CAN-branded** (Item 21) — `manifest.json`'s `theme_color`/`background_color` now `#161826` (was the default Flutter blue `#0175C2`); all icon/favicon files regenerated from the approved CAN source | `web/manifest.json`, `web/icons/`, `web/favicon.png` |
| Windows app icon | **CAN-branded** (Item 21) — regenerated as a genuine multi-resolution `.ico` from the approved CAN source (previously a Forge-specific but pre-CAN-rebrand icon) | `windows/runner/resources/app_icon.ico` |
| Play Store feature graphic | Does not exist | n/a |
| Play Store screenshots | Do not exist | n/a |
| Play Store hi-res icon (512×512) | Does not exist yet as a *separate store-upload file* — the underlying app icon is now real CAN branding (see above), so this is a trivial export from the same canonical source (`assets/branding/can_icon_source.png`) whenever actual submission prep happens, not a real branding blocker anymore | n/a |

## What Play Store submission requires (spec, not yet produced)

| Asset | Typical requirement | Status |
|---|---|---|
| App icon (hi-res, store listing) | 512×512 PNG, 32-bit with alpha | Not yet exported as a dedicated file, but no longer blocked on real branding (Item 21) — a straightforward resize of `assets/branding/can_icon_source.png` whenever actual submission prep happens. |
| Feature graphic | 1024×500 PNG or JPG, no alpha | Missing. |
| Phone screenshots | Typically 2–8 images, JPEG or 24-bit PNG, each dimension between roughly 320px and 3840px, with a max aspect ratio around 2:1 | Missing — see the screenshot plan in [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| 7" / 10" tablet screenshots | Optional but recommended if the app supports tablet layouts | Not evaluated — Forge's existing golden-test coverage already includes "wide/tablet reference size" variants for several screens (dashboard, progression, competition), so tablet layouts do render; no tablet screenshots have been captured. |
| Short description | Up to 80 characters | Draft exists — see [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| Full description | Up to 4000 characters | Draft exists — see [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md). |
| Privacy Policy URL | Required, must be a live, publicly reachable URL | **Blocked** — `/legal/privacy` exists as an in-app route (Item 19) but is not hosted anywhere reachable outside the app itself; Play Console needs a URL, not an in-app route. A real production Web deployment (out of scope for this item) or a separately hosted copy of the same content would be needed. |

## What blocks producing the missing assets

- **App icon / adaptive icon / splash**: **resolved** (Roadmap Item 21)
  — the approved CAN icon source was provided and integrated across
  Android/Web/Windows, see the audit in
  [docs/CAN_REBRAND_AUDIT.md](CAN_REBRAND_AUDIT.md).
- **Feature graphic**: still needs real brand art beyond the app icon
  itself (a 1024×500 promotional graphic is a distinct design asset,
  not a derivative of the icon) — inventing one is a design decision,
  not an engineering one, and out of scope here.
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
