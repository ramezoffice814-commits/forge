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

**AWAITING APPROVED CAN ICON FILE.** An icon concept was shared in this
session's chat as an inline image, but no actual file was found
anywhere in the project or session temp/scratchpad directories this
session could read or process — no icon asset was fabricated as a
substitute, per this item's own explicit instruction. Once a real
source file is provided (recommended: save it to
`assets/branding/can_icon_source.png` in the repo), the remaining work
is:

- **Android**: replace `android/app/src/main/res/mipmap-{hdpi,mdpi,
  xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` at each density, and add a
  proper adaptive-icon foreground/background pair
  (`res/drawable/ic_launcher_foreground.xml` or PNG + a matching
  `res/mipmap-anydpi-v26/ic_launcher.xml`) if an adaptive treatment is
  wanted — keep the CAN mark inside the adaptive safe zone (roughly the
  center 66% of the canvas) so it isn't clipped by circular/squircle
  masks.
- **Web**: replace `web/icons/Icon-{192,512}.png` and
  `Icon-maskable-{192,512}.png`, plus `web/favicon.png`.
- **Windows**: replace `windows/runner/resources/app_icon.ico` (a
  multi-resolution `.ico`, not a plain PNG).

No `flutter_launcher_icons`-style automation was wired in this pass —
adding a new dev-dependency and generator config for an asset that
doesn't exist yet would be untested, unused tooling; the manual steps
above are the concrete, actionable path once the source file exists.

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

## What this document does not do

It does not migrate `com.forge.app.forge`. It does not rename any
database table, RPC, Edge Function, or migration. It does not create,
fabricate, or substitute a CAN icon image. It does not deploy anything
or submit to any store.
