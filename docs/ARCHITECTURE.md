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
- **Current status: locally runtime verified, not staging- or
  production-verified.** See
  [../supabase/tests/README.md](../supabase/tests/README.md) and
  [../docs/ROADMAP.md](../docs/ROADMAP.md) Item 12 for exactly what that
  means and Item 13 for what's still required before anything is
  staging-verified.

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
`flutter test --exclude-tags=golden`. This exists because golden output is
sensitive to the host's font-fallback chain: the app renders text with
`google_fonts`' Inter family, but the test sandbox doesn't bundle real
Inter `.ttf` assets and `GoogleFonts.config.allowRuntimeFetching` is
deliberately `false` in tests (no network fetch during a test run), so a
substitute system font renders instead — producing a small
(observed: 0.04%–0.54%) pixel diff against the committed baseline images
without any actual UI regression. The reference baselines were generated
on Windows; running `--tags=golden` on a different OS/font-availability
combination is expected to show this same class of diff. This is a known
visual-test infrastructure gap (fixing it means bundling real Inter
`.ttf` files as test assets, or configuring `google_fonts` to skip
loading entirely in tests), not an application defect — every non-golden
test exercises the same widgets' actual behavior and logic.
