# CAN Rebrand & Cinematic Opening — Audit

Roadmap Item 21 ("CAN Rebrand & Cinematic App Experience"). Forge's
user-facing brand is now **CAN** ("I can" — capability, discipline,
progress, self-belief, action). This document is the full record of
what changed, what was deliberately left as "Forge" internally and why,
and the exact state of the cinematic opening experience. **This is not
a production deployment, a Google Play submission, or a package-ID
migration** — see Section 0 of this item's own brief.

## Brand inventory methodology

No blind global search-and-replace was performed. Every occurrence of
`Forge`/`FORGE`/`forge` in `lib/`, `android/`, `web/`, `windows/`,
`pubspec.yaml`, and `test/` was found via targeted regex search (quoted
string literals containing the word, plus a broader case-insensitive
pass), then individually read in context and classified:

| Category | Meaning | Action |
|---|---|---|
| A — User-facing brand | Text an end user actually sees/hears | Changed to CAN, or a CAN-voiced replacement |
| B — Internal code symbol | Class/type names (`ForgeTokens`, `ForgeCard`, `ForgeTheme`, `ForgeButton`, etc.), import paths, log tags | **Not renamed** — a mechanical rename here is pure internal refactor risk with zero user-visible benefit |
| C — Package/application identity | `applicationId`/`namespace` (`com.forge.app.forge`), the Dart package name (`forge`), Windows `BINARY_NAME`/`OriginalFilename`/`InternalName`, Android `appUserModelId`, notification channel ID, every persisted secure-storage key prefix (`forge.auth.*`, `forge.ai_coach.*`, `forge.notifications.*`, `forge.onboarding.*`, `forge.sync_queue.*`) | **Frozen, not touched** — renaming any of these risks breaking upgrades for any real install, exactly what this item's own Section 6 prohibits |
| D — Database/schema/migration | Table/column/function names, migration file names/content | **Not touched** — no migration exists in this diff at all |
| E — Backend function/security identifier | Edge Function names, RPC names, RLS policy names | **Not touched** |
| F — Documentation | `docs/*.md` referring to the product | Only new documents use "CAN"; historical roadmap entries (Items 1-20) keep saying "Forge" — they're an accurate record of what the product was called *at the time*, not rewritten |
| G — Test/fixture | Mock data, demo credentials (`demo@forge.app`, `forgepass1`), test assertion strings | Assertion strings updated to match real source changes; the mock demo email/password (internal-only, never transmitted, never real) left as-is — pure engineering fixture, not brand copy |
| H — File/folder name | File paths | **Not renamed** — e.g. `forge_theme.dart`, `forge_tokens.dart` stay as-is (Category B/C reasoning applies equally to file names) |
| I — Historical/migration content | SQL comments referencing "Forge" in old migrations | **Not touched** |

## User-facing references changed (Category A)

| File | Before | After |
|---|---|---|
| `lib/app.dart` | `title: 'Forge'` (OS task-switcher/window title) | `'CAN'` |
| `lib/features/auth/presentation/widgets/auth_header.dart` | `Text('FORGE', ...)` — shared kicker on every auth screen | `'CAN'` |
| `lib/features/auth/presentation/splash_page.dart` | `Text('FORGE', ...)` | `'CAN'` |
| `lib/features/auth/presentation/sign_up_page.dart` | `title: 'Forge yourself'` | `'Prove you can.'` |
| `lib/features/auth/data/supabase/supabase_auth_repository.dart` | fallback display name `'Forge user'` | `'CAN user'` |
| `lib/features/onboarding/presentation/onboarding_page.dart` | `kicker: 'FORGE YOURSELF'` | `'PROVE YOU CAN'` |
| `lib/features/settings/presentation/widgets/settings_about_section.dart` | `Text('Forge', ...)` | `'CAN'` |
| `lib/features/legal/presentation/pages/privacy_policy_page.dart` | 5 occurrences of "Forge" in headings/body | All "CAN" |
| `lib/features/legal/presentation/pages/terms_of_service_page.dart` | `'Forge does not yet have...'` | `'CAN does not yet have...'` |
| `lib/features/legal/presentation/widgets/legal_page_scaffold.dart` | `"Forge's actual current technical behavior..."` | `"CAN's actual current technical behavior..."` |
| `lib/features/notifications/data/local_notification/plugin_local_notification_service.dart` | `appName: 'Forge'` (Android notification-settings display name) | `'CAN'` |
| `lib/features/notifications/presentation/widgets/os_notification_settings_tile.dart` | `"...Forge won't..."` | `"...CAN won't..."` |
| `pubspec.yaml` | `description: "Forge — daily discipline challenge app"` | `"CAN — daily discipline challenge app"` |
| `android/app/src/main/AndroidManifest.xml` | `android:label="forge"` (home-screen/app-drawer label) | `"CAN"` |
| `web/manifest.json` | `name`/`short_name`: `"forge"` | `"CAN"` |
| `web/index.html` | `<title>forge</title>`, `apple-mobile-web-app-title` | `"CAN"` |
| `windows/runner/Runner.rc` | `ProductName`/`FileDescription`: `"forge"` | `"CAN"` |

### Narrative/lore substitution: "the Forge" → "the Current"

The Character/Daily Transmission/AI Coach system used "the Forge" as an
in-universe noun (a mystical place/practice of transformation through
effort — "the forge is ready", "Welcome to the Forge", persona
vocabulary). Since the product itself is dropping the Forge identity,
continuing to use it as in-world lore would read as an inconsistency,
not a deliberate reference. Replaced with **"the Current"** — chosen
because it fits the existing sci-fi/transmission/signal aesthetic (The
Watcher, Daily *Transmission*) and the cinematic opening's own energy/
ignition/arc visual motifs, without inventing unrelated new lore. This
is a creative call, not a mechanical rename — flagged here explicitly
for review, not slipped in silently:

- `character_persona.dart`: vocabulary list `'the forge'` → `'the current'`.
- `character_profile.dart`: The Watcher's title `'Keeper of the Forge'` → `'Keeper of the Current'`.
- `mock_transmission_scripts.dart`: `'the forge is ready'` → `'the current is ready'`; `'Welcome to the Forge'` → `'Welcome to the Current'` (both the dialogue line and its accessibility summary).
- `mock_transmission_repository.dart`: error message `'Could not reach the Forge.'` → `'Could not reach the Current.'`.
- `mock_ai_coach_client.dart`: `'The forge is warm again today...'` → `'The current runs strong again today...'`.

### Progression/social catalog renames

- `level_catalog.dart`: milestone titles `'Forge Initiate'`/`'Forge Master'` → `'Initiate'`/`'Master'` (matching the un-prefixed style already used by the ladder's own `'Builder'`/`'Architect'` milestones); description `'Just getting the forge lit.'` → `'Just getting the current flowing.'`.
- `title_catalog.dart`: `'The Explorer'`'s description `'...anything the Forge offers.'` → `'...anything CAN offers.'`.
- `achievement_catalog.dart`: `'Forged in Repetition'` → `'Proven Through Repetition'`.
- `mock_social_catalog.dart`: sample friend title `'Forge Veteran'` → `'Proven Veteran'`.

## Legacy identifiers retained (Category C) — full list

| Identifier | Where | Why it stays |
|---|---|---|
| `com.forge.app.forge` | `android/app/build.gradle.kts` `applicationId`/`namespace`; `appUserModelId` in `plugin_local_notification_service.dart` | Section 6/31's explicit instruction — renaming breaks Play Store upgrade continuity for any real install. |
| `forge` (Dart package name) | `pubspec.yaml` `name:` | Every `package:forge/...` import in `lib/`/`test/` depends on this; a rename is a mechanical, high-blast-radius refactor with zero user-visible benefit. |
| `forge` (Windows binary) | `windows/CMakeLists.txt` `BINARY_NAME`; `Runner.rc`'s `InternalName`/`OriginalFilename`; `CompanyName`/`LegalCopyright` (`com.forge.app`) | The actual built executable stays `forge.exe` — changing only the RC's internal-name strings while the real filename doesn't match would be a cosmetic inconsistency, not a fix. `ProductName`/`FileDescription` (the two strings Explorer's Properties dialog and Task Manager actually surface prominently) were changed; the filename-coupled ones were not. |
| `forge_reminders` | Android notification channel ID (`plugin_local_notification_service.dart`) | Renaming a notification channel ID on an existing install orphans the old channel and can reset a real user's per-channel OS notification settings — exactly the "identifier whose rename could break upgrades" this item's Section 6 warns against. |
| `forge.auth.mock_session`, `forge.ai_coach.privacy_level.*`, `forge.notifications.local_reminder.*`, `forge.onboarding.completed`, `forge.sync_queue.*`, `forge.ai_coach_cache.*` | Secure-storage/local-storage key prefixes across auth/AI Coach/notifications/onboarding/sync | Persisted keys — renaming silently loses every existing local user's saved state (session, AI privacy choice, reminder dedup history, onboarding-completed flag) on next launch. |
| `demo@forge.app` / `forgepass1` | `MockAuthRepository`'s seeded demo account, used directly in `auth_onboarding_flow_test.dart` | Internal mock/demo fixture, never transmitted anywhere real, not brand marketing copy — left as an engineering convenience, not a user-facing identity. |
| `[forge:crash]` | `crash_handler.dart`'s `debugPrint` log-tag prefix | Developer-console-only diagnostic tag, never shown to a user. |
| `forge_*.dart` file names (`forge_theme.dart`, `forge_tokens.dart`, `forge_card.dart`, etc.) | Throughout `lib/` | File names mirror their Category-B class names — same reasoning, not renamed. |

### Future migration consideration

If the package/application identity is ever intentionally migrated away
from `com.forge.app.forge` (e.g. for a real production launch under the
CAN name), that is its own dedicated, carefully-planned item — it
touches Play Store app identity (a *new* listing, not an update, unless
Play's package-rename path is used), Windows distribution identity, and
every persisted storage key prefix above. Not attempted here.

## Android/Windows/Web platform state

- **Android**: `android:label="CAN"` (home-screen/app-drawer name) —
  `applicationId`/`namespace` unchanged (`com.forge.app.forge`), per
  Section 31.
- **Windows**: `ProductName`/`FileDescription` = "CAN"; binary/internal
  identity unchanged (see table above).
- **Web**: `manifest.json` name/short_name/description = "CAN";
  `theme_color`/`background_color` changed from the default Flutter
  blue (`#0175C2`) to `ForgeColors.background` (`#161826`, the app's
  own established deep navy) — resolves a P3 cosmetic gap flagged since
  Item 18/20's own audits, using an already-existing token rather than
  inventing a new color. `web/index.html` gained a matching
  `theme-color` meta tag and an inline `background-color` style to
  prevent a white flash before the Flutter engine paints its first
  frame (this item's own Section 12 requirement).

## CAN icon — status

**INTEGRATED.** The approved source was found placed directly in the
project as `assets/Codex Image 28 Aug 2026, 15_03_26.png` (1254×1254,
24bpp RGB, no alpha, ~1.79MB) — visually confirmed to match the
approved CAN concept (wordmark, deep-navy/indigo rounded-square canvas,
violet/lavender palette, orbital arcs, upward-right energy arrow) before
any use. The original file was left untouched on disk, per this item's
own instruction; the canonical, tracked project copy is
`assets/branding/can_icon_source.png` (byte-identical, not staged
alongside the original to avoid committing the same ~1.8MB image
twice — `assets/Codex Image...png` itself is intentionally left
untracked). No image-editing library was available in this environment
(no ImageMagick, no working Python/PIL); every derivative below was
generated via .NET's `System.Drawing` through PowerShell, verified by
reading each result back before use.

- **Android legacy launcher icon**: direct high-quality resize of the
  source to 48/72/96/144/192px at mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi
  (`res/mipmap-*/ic_launcher.png`) — no stretching, aspect ratio
  preserved (the source is already 1:1).
- **Android adaptive icon** (API 26+): a proper foreground/background
  pair, not a reuse of the legacy square asset. `res/mipmap-*/
  ic_launcher_foreground.png` at 108/162/216/324/432px (108dp-canvas
  densities) — the source scaled to 58% and centered on a *transparent*
  canvas, comfortably inside the OS-guaranteed 66dp safe-zone circle
  (~61% of 108dp) under every mask shape (circle/rounded-square/
  squircle) with margin to spare — visually confirmed by reading the
  generated PNG back. The background is a solid color
  (`@color/ic_launcher_background`, `#161826` — `ForgeColors.background`,
  defined in the new `res/values/colors.xml`), not a second image.
  `res/mipmap-anydpi-v26/ic_launcher.xml` wires both together. Devices
  below API 26 fall back to the legacy square icon above.
  `applicationId`/`namespace` (`com.forge.app.forge`) — **unchanged**.
- **Web**: `web/icons/Icon-{192,512}.png` are direct resizes;
  `Icon-maskable-{192,512}.png` use the same 72%-safe-zone-padding
  technique as the Android adaptive foreground, but composited onto a
  *solid* `#161826` background (maskable icons should fill the full
  canvas, not go transparent, so an aggressive OS crop never exposes an
  empty edge) — `web/favicon.png` resized to 64px. `manifest.json`'s
  icon list still references the same filenames, now updated in place.
- **Windows**: `windows/runner/resources/app_icon.ico` rebuilt as a
  genuine multi-resolution icon (16/32/48/64/128/256px, each a real
  resize, embedded as PNG-compressed frames per size — supported since
  Windows Vista) — 163,391 bytes, round-tripped through `System.Drawing.
  Icon` to confirm the file is well-formed before finalizing.

No `flutter_launcher_icons`-style automation was added — every
derivative was generated once, directly, and verified; adding a new
dev-dependency for a one-time job already done would be unused tooling
going forward, not a net improvement.

### Native Android launch-screen continuity

The prior report correctly flagged that `launch_background.xml` was
still the stock Flutter white default — **fixed this pass**.
`res/values/colors.xml` now also defines `launch_background_color`
(`#161826`, same value as the adaptive-icon background). Both
`res/drawable/launch_background.xml` and the API-21+ `res/drawable-v21/
launch_background.xml` (which takes precedence on every device this app
targets) now paint that fixed navy plus a centered, static CAN mark
(`@mipmap/ic_launcher_foreground`) instead of `@android:color/white` /
the OS's dynamic `?android:colorBackground`. Both `NormalTheme` variants
(`values/styles.xml` light, `values-night/styles.xml` dark) now use the
same fixed color for `android:windowBackground` too, so the brief window
between the native launch screen being removed and Flutter's own first
frame painting can't flash a different color either. CAN is
dark-theme-only regardless of the OS's light/dark setting (`ForgeTheme.
dark()` is used unconditionally — see `app.dart`), so both style
variants deliberately converge on the identical navy rather than
following the system default.

Net effect: native launch (navy + static CAN mark) → `NormalTheme`
window background (same navy, while the Flutter engine initializes) →
`CanOpeningOverlay`'s own first frame (`tokens.background` = the same
`#161826`, now with the *animated* ignition/orbit/arrow sequence) →
routed content. No white flash, no stock Flutter branding, no
background-color jump at any handoff point — verified structurally
(`test/branding/can_icon_assets_test.dart`) rather than by native
screenshot, since `flutter test` cannot observe actual OS splash
rendering.

### Dashboard entrance (added this pass)

The prior report also correctly flagged that no dedicated Dashboard
entrance existed. `DashboardPage`'s `_DashboardBody` now wraps
`DashboardPopulated`'s real content in a new `_DashboardEntrance`
widget: a one-shot fade (opacity 0→1) plus a ~12px upward translation,
~360ms, `Curves.easeOutCubic` — within the requested 250-450ms / 8-16px
ranges. It does **not** coordinate directly with `CanOpeningOverlay`
(which stays deliberately router-and-destination agnostic — see its own
doc comment) — instead it relies on ordinary Flutter `State` lifecycle:
because `StatefulShellRoute.indexedStack` preserves each tab's widget
subtree, `_DashboardEntrance`'s `State` is created once, the first time
`DashboardPopulated` content actually renders (which in practice is
immediately after the CAN overlay dissolves into the authenticated
shell, or immediately after sign-in for a previously-unauthenticated
session) — and is *not* recreated on a subsequent data-only refresh
(e.g. completing a mission), only on a full loading/error round-trip,
which is an acceptably low-cost, infrequent replay for a sub-half-second
fade. Onboarding/auth/every other router-controlled destination keeps
the CAN overlay's own plain dissolve — no Dashboard-specific motion was
added anywhere else, and no Dashboard business logic changed.

Reduced motion (`MediaQuery.disableAnimations`) skips the wrapper
entirely — content renders immediately, no fade, no translation.

## Cinematic opening — architecture

**Files**: `lib/core/opening/can_opening_overlay.dart` (orchestration
+ state machine), `lib/core/opening/can_ignition_painter.dart`
(`CustomPainter` for the ignition/orbit/arrow beats),
`lib/core/opening/can_wordmark.dart` (the "C A N" reveal + halo-lock
beat). Wired into `lib/app.dart` via `MaterialApp.router`'s `builder`.

**Why an overlay, not a route**: `AppRoutePaths.splash` already exists
and `AuthStateAwareRedirectPolicy` already redirects off it the instant
auth/onboarding resolve — often near-instantly in mock mode, via
`RouterRefreshListenable`. Coupling the redirect itself to a ~2.5s
animation would have meant changing router behavior (real risk,
explicitly the kind of thing Section 19 says not to do) or racing it.
Instead, `CanOpeningOverlay` wraps whatever the router has *already*
resolved and covers it for a short, fixed sequence, then dissolves —
"animation is presentation only." The router, `SplashPage`, and
`AuthStateAwareRedirectPolicy` are all **completely unmodified** except
`SplashPage`'s own leftover "FORGE" text label (kept as an honest
fallback for the rare case auth restore outlasts the overlay's own 4s
safety cap).

**Sequence selection**: reads `onboardingStatusProvider` (the same
provider the router already watches) to distinguish first-time
(`!completed` → full ~2.5s sequence) from returning (`completed` →
fast ~1.1s sequence) users — no new persisted state was added.
`MediaQuery.of(context).disableAnimations` selects the reduced-motion
variant (~0.6s, plain fade only) regardless of onboarding status.

**Phases** (full sequence, via `CanIgnitionPainter` + `CanWordmark`):
ignition (a small radial glow flaring at center) → orbiting arcs (two,
one trailing the other for depth) → a diagonal arrow stroke with a glow
trail, traced progressively via `PathMetric` rather than redrawn as a
growing line → the "C A N" wordmark fading/scaling in per-letter (not
typed-in-order — "A" resolves last as the focal point) → one controlled
halo pulse (never repeating) → the whole overlay cross-fades away,
revealing the destination screen the router already navigated to
underneath.

**Failure safety**: a 4-second hard safety `Timer` force-dismisses the
overlay regardless of animation/controller state; `AnimationController`
construction is wrapped in `try/catch` that also force-dismisses on any
exception. The app can never get stuck behind this overlay.

**Lifecycle**: `CanOpeningOverlayState` is created once when
`MaterialApp.router`'s `builder` first mounts it and is never recreated
on a background→foreground resume (only on a genuine cold process
start) — verified by a dedicated test (see Testing below).

## Colors

No new color system — every color in the cinematic sequence
(`accent`/`accent2`/`accentRamp`/the app's existing `background`/`text`)
comes from `ForgeTokens`/`ForgeColors`, the same deep-navy/violet/
lavender palette every other screen already uses. No orange, teal,
green, or gold appears anywhere in the new code.

## Micro-interactions & haptics

Audited per this item's own "high-value interactions" list. Rather than
adding motion broadly across many screens (real risk of "animation
overload" this item explicitly cautions against), one clean, low-risk,
high-confidence addition was made: `LevelUpCelebration` now fires
`HapticFeedback.mediumImpact()` once, alongside its existing one-shot
scale-in animation and screen-reader announcement — no new platform
permission (`HapticFeedback` is a core Flutter API), silently a no-op
where haptics aren't supported, verified not to break its existing test
suite.

Mission-progress completion haptics were considered and **deliberately
not added this pass**: `MissionProgressControl` dispatches to 10
different progress-type-specific control widgets (binary/counter/
timer/checklist/percentage/quantity/reflection/reading/coding-session/
hydration), each with its own completion-detection shape — correctly
threading a "confirmed completion only, not every intermediate tick"
haptic through all ten safely is materially more scope than this pass's
remaining budget supports without risking a rushed bug in
mission-completion UX. Left as a candidate for a future, dedicated pass
rather than attempted hastily here.

## Loading / error experience

**No change needed.** `ForgeLoadingState` already renders its spinner
in `tokens.accent` (the theme's own violet, not a hardcoded default
color); `ForgeErrorState`/`ForgeEmptyState`/`ForgeOfflineState` are
already token-driven and carry no old-brand text. These were already
CAN-consistent by construction — this item's own "generic/default
loading experience" concern doesn't apply here.

## Accessibility

`CanOpeningOverlay` wraps its own content in a single `Semantics(label:
'CAN', excludeSemantics: true)` node (the same double-announcement-safe
pattern established across Items 19-20's own accessibility work) —
individual arc/wordmark-letter widgets never leak their own separate
semantics. The destination content underneath is wrapped in
`ExcludeSemantics` while the overlay is showing (a screen reader
shouldn't be able to navigate into visually-covered content), reachable
normally the instant the overlay is removed. The reduced-motion variant
uses no orbit/scale/arrow/repeated-pulse, matching this item's Section
16 exactly. All of Item 20's accessibility fixes (13 duplicate-
announcement corrections) are untouched by this pass.

## Testing

`test/core/opening/can_opening_overlay_test.dart` — 6 dedicated tests
covering sequence selection (full/fast/reduced), timing/dismissal,
"settles exactly once and never replays," and the safety-cap fallback
when onboarding status never resolves — verified via deterministic
small-step `tester.pump()` calls rather than golden screenshots, per
this item's own "do not rely solely on golden screenshots for temporal
behavior" instruction. "Correct destination after animation"/
"authenticated destination"/"unauthenticated destination"/"no duplicate
navigation" are already covered by the existing full-`ForgeApp`
integration suite (`auth_onboarding_flow_test.dart`,
`dashboard_navigation_test.dart`, etc.) — all 9 of those files pump
`ForgeApp` and settle via `tester.pumpAndSettle()`, which correctly
fast-forwards through the overlay's controller/timer chain exactly like
any other animation; **all continue to pass unmodified** with the
overlay wired in system-wide (verified empirically, not assumed).

7 existing golden baselines were regenerated to reflect the intentional
text changes above (dashboard/progression show level titles and the
renamed achievement; daily-transmission shows the new dialogue line) —
each diff was confirmed small (0.04%-0.41% pixel difference) and
localized to the changed text before regenerating, not blindly
accepted. No new golden was added for the opening sequence itself or
for Settings — the sequence is fundamentally temporal (a "settled
mid-animation frame" golden would be fragile and low-value, covered
far better by the dedicated timing tests above), and Settings has never
had a golden test in this codebase; adding one is a bigger, separate
scope decision than this pass's own text-consistency check warrants.

### Final visual patch (icon integration + Dashboard entrance)

`test/branding/can_icon_assets_test.dart` — 26 deterministic
file-existence and content-reference checks (canonical source present;
every Android legacy + adaptive-foreground density exists; the adaptive
XML/color resources wire up correctly; `AndroidManifest.xml` declares
`CAN`, not `forge`; both `launch_background.xml` variants and both
`NormalTheme`s use the fixed navy, not the stock white/dynamic system
default; every Web icon file exists and `manifest.json`/`index.html`
reference real files with the right title/color; the Windows `.ico`
exists and is a plausible multi-resolution size). Deliberately file/
content checks, not pixel comparisons — native OS icon and splash-screen
rendering isn't observable from `flutter test` at all, and asserting on
it would be exactly the fragile screenshot test this item warns against.

`test/features/dashboard/presentation/dashboard_page_test.dart` gained
3 tests for `_DashboardEntrance`: normal motion shows an in-flight
opacity below 1.0 then settles to fully visible; reduced motion never
renders the fade wrapper at all (immediate, full opacity); a data-only
refresh of the same populated state does not reintroduce a mid-fade
frame. All three target the entrance's `Key('dashboard-entrance-
opacity')` specifically rather than a blanket `find.byType(Opacity)` —
Dashboard already has an unrelated, pre-existing "mission-frame reveal"
animation that also uses `Opacity`, which a broad type-based search
would have conflated with this one (caught during development: the
first version of these tests used the broad search and failed non-
deterministically against the wrong widget).

Golden tests: unchanged, 0 regenerated. The Dashboard entrance wrapper
renders as a no-op once settled (opacity 1.0, translate 0), confirmed
by re-running `dashboard_golden_test.dart` before and after — pixel-
identical. Icon/launch-screen changes are native-platform resources
entirely outside Flutter's own widget tree and cannot affect a Flutter
golden test.

## What this document does not do

It does not migrate `com.forge.app.forge`. It does not rename any
database table, RPC, Edge Function, or migration. It does not create,
fabricate, or substitute a CAN icon image. It does not deploy anything
or submit to any store.
