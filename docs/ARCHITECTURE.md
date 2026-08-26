# Architecture

This document summarizes how Forge is put together. It describes what
exists in the codebase today — it is not an aspirational design document.

## Clean Architecture, feature-first

Each feature under `lib/features/<feature>/` owns three layers:

```
<feature>/
  domain/          # entities, policies, engines, use cases, repository interfaces
  data/            # repository implementations (mock and/or real), catalogs, mock contexts
  presentation/    # Riverpod providers/controllers, pages, widgets
```

The dependency direction is `presentation → domain ← data`: presentation
and data both depend on domain interfaces/entities; domain never imports
from presentation, and — where the code's own comments call this out
explicitly (the mission engine's policies, the progression engine's
policies, the mission-lifecycle aggregate) — domain code has no Flutter
import at all, so it's testable as plain Dart with no widget tree.

`lib/features/settings/` is a deliberate exception: presentation-only, no
`domain/`/`data/` of its own. It's a pure aggregator screen that reuses
other features' existing providers/widgets/storage (AI privacy, notification
preferences, auth) rather than introducing a second, competing preference
model for anything it displays.

Cross-cutting infrastructure lives outside any single feature:

- `lib/core/` — routing (`go_router` config, auth-redirect policy, app
  shell), theming (the "Forge" design tokens/ramps), secure storage,
  app configuration. `lib/core/di/`, `lib/core/network/`, and
  `lib/core/connectivity/` are reserved, currently-empty folders for
  infrastructure that later roadmap items will need.
- `lib/shared/` — stateless UI primitives (`ForgeButton`, `ForgeCard`,
  loading/error/empty states, etc.) and small utilities used by more than
  one feature. Nothing feature-specific belongs here.

## State management: Riverpod

Forge uses `flutter_riverpod` throughout, with a few load-bearing patterns
that recur across features:

- **`Notifier` + a `ready` `Future`.** Several controllers (mission
  selection, mission lifecycle, progression) need to run an async
  computation as their very first action, but Riverpod forbids writing
  `state` before `build()` returns. The fix used consistently across the
  codebase is: `build()` returns an initial "loading" state and schedules
  the real work via `Future.microtask(...)`, while a `Completer`-backed
  `ready` future lets callers (like `DashboardNotifier`) await the first
  real resolution instead of reactively `ref.watch`-ing the async chain —
  the latter was tried first and caused a real double-load race between a
  reactive rebuild and a manual `retry()` call (see the mission-selection
  controller's own doc comments for the full story).
- **`NotifierProvider.family`** for per-entity controllers (e.g. one
  `MissionLifecycleController` per mission instance ID), so multiple
  screens reading the same entity ID always share one controller instance.
- **Deferred side effects inside `build()`** (e.g. auto-assigning a
  mission or auto-seeding progression history) follow the same
  microtask-deferral pattern, guarded so they only run once.

## Routing: go_router

A single `StatefulShellRoute.indexedStack` hosts the five bottom-nav tabs
(Home, Rank, Progress, Awards, Profile), keeping each tab's state alive
across switches. Full-screen experiences that shouldn't show the bottom
nav (Daily Transmission, Active Mission) are pushed as top-level sibling
routes rather than nested inside the shell. `AuthStateAwareRedirectPolicy`
is the single place that decides where an unauthenticated or
still-restoring session should land — no screen calls `context.go`
imperatively to enforce auth.

## Discipline Intelligence Engine (mission selection)

A deterministic pipeline, not a black box and not an AI call:

```
catalog → eligibility filters → safety policy → difficulty engine
        → recovery policy → time/variety policies → personalization scoring
        → deterministic selection (+ fallback strategy) → MissionInstance
```

Every policy is a pure function over explicit inputs (a
`UserDisciplineProfile`, `BehavioralHistory`, the catalog). Given the same
inputs, the engine always produces the same `MissionSelectionResult`,
including its human-readable `selectionReasons` — there is no hidden
randomness and no live AI generation anywhere in this pipeline.

## Character system / Daily Transmission

The character presentation layer (`ForgeCharacterView`, character-state
machine, subtitle sequencing) is deliberately decoupled from *what* the
character says: dialogue comes from hand-authored `TransmissionScript`
mock data keyed by scenario, read through the same `MissionPreview` the
Dashboard uses, so the two screens can never disagree about today's
mission. Local TTS (`flutter_tts`) speaks the script; there is no live AI
text or voice generation.

## Event-sourced mission lifecycle

Mission progress is modeled as an append-only log of immutable
`MissionEvent`s (19 types — assigned, viewed, accepted, started,
progress-updated, paused, resumed, submitted, validation passed/failed,
completed, completion-undone, rejected, abandoned, expired, plus sync/
informational events), never as a single mutable status field.

- `MissionAggregate.rehydrate(instance, events)` is a pure reducer:
  replaying the same ordered events always produces the same aggregate.
  An event that isn't legal from the aggregate's current state is skipped
  defensively during replay rather than corrupting the derived state — the
  *use case* layer is what actually prevents an illegal event from being
  appended in the first place.
- `MissionLifecycleTransitions` is an explicit table (`(fromState,
  eventType) → nextState | null`), not an if/else chain, so every legal
  and illegal transition is enumerable and testable as data.
- `InMemoryMissionEventRepository` is the only implementation so far — no
  database. It's the sole place a sequence number is ever assigned, and it
  enforces idempotency-key uniqueness per mission stream so, e.g., a
  double-tapped "accept" resolves to one event, not two.
- Ten progress types (binary, counter, timer, checklist, percentage,
  quantity, reflection, reading, coding-session, hydration) each have a
  `Definition` (the target) and a `State` (current progress), validated by
  `MissionProgressPolicy` before ever becoming an event — bounds-checked,
  monotonic unless explicitly flagged as a correction.
- `MissionCompletionValidator` is local and always provisional
  (`provisionalOnly: true`) — it can tell the user they're not done yet,
  but it never grants anything.

## Progression engine

Built on the same philosophy as the mission lifecycle, one level up:

```
CompletedMissionSummary (bridged from a real completed MissionAggregate)
  → XpCalculationPolicy → XpRewardEvaluation (always provisionalOnly)
  → ProgressionAggregate (event-derived)
  → level / title / achievements
```

- `XpCalculationPolicy` is a pure, deterministic, fully explainable
  formula (every factor lands in a `reasons` list) with hard caps:
  100 XP per mission, 300 XP per day, capped streak/category/recovery
  bonuses, and diminishing returns on repeating the same mission —
  never zero, never punitive, just smaller each time.
- `LevelPolicy` looks up the current level from a generated, ordered
  catalog rather than a hardcoded if/else chain, so extending the level
  ladder is a catalog change, not a code change.
- `TitlePolicy` and the achievement engine (`AchievementEvaluator`) both
  read a shared, deterministically-built `MissionHistorySnapshot` rather
  than re-deriving their own stats from raw history.
- `ProgressionAggregate` folds a `ProgressionEvent` audit trail
  (`XpPreviewCalculated`, `LevelReached`, `AchievementUnlocked`,
  `TitleUnlocked`) for *when* something was first detected, while the
  actual locked/progressing/unlocked status shown in the UI is always
  freshly computed from the completion history — so a newly-qualifying
  achievement shows as unlocked immediately, without waiting for a
  separate event-appending step.

## Client/server trust boundary

This is the single most important architectural rule in the codebase, and
it did not change when the backend was built — the backend exists
specifically to enforce it:

- The client is authoritative for **local presentation state only**: UI
  state, provisional progress, the local event log, and the local
  progression preview.
- The client is **never** authoritative for: confirmed/competitive XP,
  leaderboard score, seasons, or any reward with real-world value. Those
  live only in Postgres, written only by SECURITY DEFINER `forge_*`
  functions the client cannot call directly, behind RLS that denies the
  client `INSERT`/`UPDATE` on every reward-bearing table.
- Every provisional value is explicitly typed and named to make this
  obvious at the call site (`XpRewardEvaluation.provisionalOnly`,
  `MissionRewardState`, `UserProgressionProfile.provisionalXp` vs.
  `totalConfirmedXp`). `lib/core/security/` (`AuthoritativeValue`,
  `DataAuthority`) generalizes this pattern across the backend layer.
- The backend independently re-validates and re-scores every mission
  completion, progression event, and competitive score server-side —
  `ProgressionReconciliation` and `CompetitionReconciliation`
  (`lib/features/progression/domain/services/`,
  `lib/features/competition/domain/services/`) fold a confirmed server
  result into local state by subtracting the confirmed delta out of the
  provisional bucket, never by letting the client overwrite a confirmed
  value with a local guess.
- **Current status: STAGING VERIFIED** (Roadmap Items 13/13B/13C), not
  production-verified — no production Supabase project has been
  configured or deployed to. See
  [../supabase/tests/README.md](../supabase/tests/README.md) and
  [../docs/ROADMAP.md](../docs/ROADMAP.md) for exactly what that means
  and its one documented caveat (no pixel-level UI automation of the
  live app).

## Mock/live environment model

`lib/core/config/app_config.dart` reads `APP_ENV` via `--dart-define`
(`String.fromEnvironment`), defaulting to `mock`. Mock mode never touches
a network or a real credential. `live` mode requires `SUPABASE_URL` and
`SUPABASE_ANON_KEY`; `main.dart` fails loudly at startup if `live` is
requested without them, rather than silently falling back to mock. Auth,
mission commands, mission assignment, and the leaderboard now have real
Supabase-backed implementations behind this switch (`lib/core/backend/`,
`lib/features/competition/data/supabase/`); character presentation and
Daily Transmission dialogue remain mock-only by design (see
[Character system](#character-system--daily-transmission)). `live` mode
has only been exercised against a local Supabase instance so far — see
[Client/server trust boundary](#clientserver-trust-boundary).

## Golden tests and font determinism

Golden (pixel-comparison) tests are isolated from the rest of the suite
via the `golden` tag in `dart_test.yaml`, run with
`flutter test --tags=golden` separately from
`flutter test --exclude-tags=golden`. All 4 golden test files set
`GoogleFonts.config.allowRuntimeFetching = false` so a run never depends
on network access.

Production renders text via `google_fonts`' Inter family
(`lib/core/theme/forge_theme.dart`), which only ever requests two real
weights — Regular (400) and Medium (500); every other weight seen
elsewhere in the app is a `copyWith`/plain `TextStyle` override applied
on top of one of those two already-resolved styles, rendered via Skia's
weight synthesis rather than a separate `google_fonts` asset lookup.
Those two weights are bundled as real `.ttf` assets under
`assets/fonts/` (declared in `pubspec.yaml`; see
`assets/fonts/README.md` for their source/license/integrity — SIL Open
Font License, downloaded from Google Fonts' own CDN at the exact URL
and hash the installed `google_fonts` package would fetch at runtime),
so `google_fonts` resolves them from the app's own asset bundle with
`allowRuntimeFetching` still `false`.

Before this was fixed (Roadmap Item 13/13B/13C), no font asset was
bundled, so with runtime fetching disabled `google_fonts` couldn't
render any Inter glyphs at all in the test sandbox — not a "substitute
system font" as this note previously (incorrectly) assumed, but literal
missing-glyph "tofu" boxes for every piece of text. The committed
baseline images had themselves been captured under that same broken
state, so they showed tofu boxes too, which is why the diff against a
correctly-fonted render had stayed small enough to not always fail —
until it did. All 18 baselines have been regenerated against the fixed,
deterministic font setup and now show the actual intended Forge
typography; every changed image was reviewed individually before being
accepted (see the Item 13B/13C PR description for the review notes).

## Notifications (Roadmap Item 15)

`lib/features/notifications/` splits by the same CLIENT OWNED /
SERVER AUTHORITATIVE line as [Client/server trust
boundary](#clientserver-trust-boundary): Daily Mission, Daily
Transmission, and Mission Follow-up reminders are computed live from
providers the client already treats as authoritative
(`resolvedMissionInstanceProvider`, `MissionLifecycleController`) and
never persisted server-side; Achievement Unlock, Level-up, Week
Result, Season Result, and Weekly Recap are rows in the `notifications`
table, written exclusively by `forge_create_notification()` inside the
same transaction as the fact they describe (`forge_submit_mission`,
`forge_finalize_season_week`, `forge_finalize_season`) — never
client-inserted, never inferred client-side ahead of server
confirmation. `NotificationInboxController` merges both sources into
one list, filtered through `NotificationPreferences.allows()` before
it ever reaches the UI.

Delivery was in-app inbox only through Item 15 — Item 17 (below) added
real OS-level local notifications for the three client-owned reminder
types on top of this same domain layer, without changing anything
described above: `NotificationPreferences.allows()`/quiet hours/
`LocalReminderEngine` remain the only source of "should this be shown,"
regardless of which channel eventually presents it. Remote push
(FCM/APNs/web push) and OS delivery for server-authoritative types
(achievement/level-up/competition/weekly recap) remain out of scope —
see Item 17's own section for exactly why.

**Platform behavior** — the three platforms this repo actually
targets (`android/`, `web/`, `windows/`; no `ios/`/`macos`/`linux`
directory exists):

- **Android**: full behavior. `flutter_secure_storage` (backing
  `LocalReminderStore`, `NotificationPreferencesController`'s
  bootstrap-before-load, and every other client-owned key/value need
  in this app) uses the Android Keystore.
- **Windows**: full behavior. `flutter_secure_storage` uses Windows
  Credential Manager (DPAPI-backed). No further Windows-specific
  handling was needed for this feature.
- **Web**: full behavior for everything actually implemented (inbox,
  preferences, deep links, quiet hours). `flutter_secure_storage`'s
  web backend persists into the browser's own storage rather than a
  real OS keystore — a pre-existing characteristic of every other
  secure-storage use in this app (auth session, onboarding flag),
  not something Item 15 introduces or changes.

## OS-Level Local Notifications (Roadmap Item 17)

`LocalNotificationService` (`lib/features/notifications/domain/
repositories/local_notification_service.dart`) is the single seam
between the notification domain above and an actual device notification
tray — a real `flutter_local_notifications`-backed
`PluginLocalNotificationService` on Android/Windows, an honest
`UnsupportedLocalNotificationService` no-op everywhere else (Web
today). `LocalNotificationScheduler` (`data/local_notification/`) is the
only thing that calls it, and makes no eligibility decisions of its own
— it translates a `ForgeNotification` Item 15's own domain already
approved into a `showNow`/`schedule`/`cancel` call, nothing more.

**Platform support is not uniform, by design, not oversight**:

- **Android**: full support (`NotificationCompat`). Scheduling uses
  `AndroidScheduleMode.inexactAllowWhileIdle` — no `SCHEDULE_EXACT_ALARM`
  permission, since these are reminders, not alarms. `POST_NOTIFICATIONS`
  (Android 13+) is requested only from an explicit Settings tap, never
  automatically, and never repeated once denied.
- **Windows**: full support via the plugin's C++/WinRT toast
  notifications, with two real, documented limitations: no repeating
  notifications (unused here — every schedule is a one-shot instant)
  and `cancel()`/`getActiveNotifications()` silently no-op without MSIX
  packaging, which this app doesn't use.
- **Web**: deliberately unsupported. The plugin's own Web
  implementation leans on a service worker for consistent tap-handling
  — close enough to the "web push infrastructure" this item was told
  not to add that treating it as in scope would be a stretch, not a
  good-faith reading. The existing in-app inbox remains Web's only
  notification surface.

Every plugin call in `PluginLocalNotificationService` is wrapped so a
platform/plugin failure degrades to reporting itself unsupported rather
than throwing — this is also what keeps `ForgeApp`'s unconditional
`ref.watch(osNotificationBootstrapProvider)` safe to run under `flutter
test`, where no real platform channel handler exists.

Mission Follow-up is the one reminder with a genuine future fire
instant (`acceptedAt + LocalReminderEngine.followupMinimumAge`) and gets
real advance `schedule()`, deferred out of quiet hours by
`QuietHours.nextEligibleTime`. Daily Mission/Transmission are mirrored
via an immediate `showNow()` exactly when `LocalReminderEngine` already
decides they're due — deliberately not given an invented fixed
clock-time policy Item 15 never specified. Every OS notification id is
derived deterministically from the existing Item 15 dedup key
(`LocalNotificationScheduler.stableId`), never random, so rescheduling
replaces rather than duplicates and cancellation is exact. Tapping a
notification decodes its payload through the exact same
`ForgeNotificationType.tryParse`/`NotificationDeepLink.forType`
functions the in-app inbox already uses — a payload is never a raw
route string, and an unrecognized one safely no-ops.

**Known limitations, stated rather than hidden**: server-authoritative
notification types are not mirrored to the OS this pass (in-app-inbox
only, as Item 15 shipped them); a scheduled reminder does not survive a
full device reboot (only an app restart) — `flutter_local_notifications`
has no built-in boot-rescheduling for `zonedSchedule`, and adding a
hand-rolled Android boot receiver was out of scope; no real Android
emulator/device or Windows Developer Mode was available in the
environment this item was built in, so real-device smoke testing is
unverified rather than assumed passing.
