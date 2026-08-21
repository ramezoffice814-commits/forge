# Forge — Supabase Database Foundation (Phase 10B + 10C + 10D)

This directory is the source of truth for Forge's real Postgres schema
**and** the authoritative mission-command pipeline built on top of it.
Phase 10B established schema/RLS/ledger storage only, with every reward
field deliberately unwritable. Phase 10C ([jump to section](#phase-10c-the-authoritative-command-pipeline))
made those tables actually writable: real Edge Functions, real SQL
transaction functions, and the real `SupabaseBackendClient`. Phase 10D
([jump to section](#phase-10d-live-integration--season-finalization))
wires the Flutter app to that pipeline (reconciliation, offline
queueing, account-switch-safe sync) and adds server-only weekly/season
competition finalization plus a public-safe leaderboard read model. No
service-role secret exists anywhere in this repo at any phase.

## Directory layout

```
supabase/
  config.toml            local Supabase CLI project config
  migrations/             ordered, rerunnable SQL migrations (source of truth)
  seed.sql                idempotent reference-data seed (leagues, season, missions, achievements)
  functions/               Edge Functions — thin wrappers around the SQL functions below (Phase 10C)
  tests/                   plain-SQL RLS/security test scripts (not pgTAP)
```

Migrations are applied in filename (timestamp) order by
`supabase db reset` / `supabase migration up`. **Never hand-edit an
already-applied migration** — add a new one instead, the same way you
would never rewrite a shipped mission event.

## Authority model

Forge treats the database, not the Flutter client, as the source of
truth for anything that affects competition fairness or trust:

| Category | Examples | Who can write it |
|---|---|---|
| **Client-owned** | `profiles.display_name`, `profiles.avatar_path`, mission event *commands* (accept/start/progress/submit) | The authenticated user, for their own rows only |
| **Provisional / append-only ledger** | `mission_events` | Client inserts append-only rows; nothing about a mission's *reward* is derived by the client |
| **Server-authoritative** | `xp_ledger`, `user_progression`, `user_achievements`, `competition_score_ledger`, `competition_memberships`, `season_results` | Nobody, from the client. No `insert`/`update`/`delete` RLS policy exists for `authenticated` on any of these tables. Writes will only ever come from a service-role context (a future Edge Function). |
| **System-managed catalogs** | `mission_definitions`, `achievement_definitions`, `league_definitions`, `competition_seasons`, `competition_weeks` | Nobody, from the client. Read-only. |
| **Internal / never client-visible** | `integrity_events`, `audit_log`, `processed_commands` | Nobody, from the client — not even read access to their own rows. Service-role only. |

This mirrors the `DataAuthority` enum and `AuthoritativeValue<T>`
hierarchy from Phase 10A: `localOnly`/`provisional` values in the
Flutter app should only ever be upgraded to `serverConfirmed` by data
that actually came from a table in the "Server-authoritative" row
above, through a real backend response — never fabricated client-side.

## RLS philosophy

Every table that a normal `authenticated` client can touch at all has
RLS **enabled**, with **explicit, narrow policies** — never a blanket
`using (true)` for a private table, and never reliance on the Flutter
app to "just filter by user_id" client-side. Concretely:

- Ownership checks always use `auth.uid() = user_id` (or, for
  `mission_events`, ownership of the *parent* `mission_instances` row,
  enforced by a `BEFORE INSERT` trigger since Postgres `CHECK`
  constraints cannot reference another table).
- Tables with **no legitimate client write path at all**
  (`processed_commands`, `xp_ledger` writes, `user_progression`
  writes, `user_achievements` writes, `competition_score_ledger`,
  `competition_memberships`, `season_results`, `integrity_events`,
  `audit_log`) simply have **no insert/update/delete policy** for
  `authenticated`. In Postgres, enabling RLS with zero policies for a
  role is a default-deny — this is treated as a *feature*, not an
  oversight, and is called out with a comment in each migration so a
  future contributor doesn't "fix" it by adding a permissive policy
  without a design review.
- `integrity_events` and `audit_log` additionally have **no select
  policy for `authenticated` at all** — a user cannot read even a row
  that is *about themselves*. This is deliberate: these are internal
  anti-abuse/audit surfaces, not user-facing data.
- Read-only reference catalogs (`mission_definitions`,
  `achievement_definitions`, `league_definitions`,
  `competition_seasons`, `competition_weeks`) are readable by any
  authenticated user (`select` where `active`, or unconditionally for
  season/week catalogs) but have no write policy at all.

## Public vs. private data

Phase 10B deliberately **does not** build any cross-user public read
surface (no "public profile" view, no leaderboard view). Two things
that might look like omissions are intentional scope decisions:

1. **No public profile view.** `profiles` RLS is strictly
   own-row-only. The Social feature (`lib/features/social/`) currently
   runs entirely on local mock data and was explicitly out of scope
   for this phase ("Do NOT implement social features"). Building a
   public-profile read path now, before the feature that would consume
   it exists, would just be opening a surface prematurely.
2. **No cross-user leaderboard/weekly-group view.** Doing this
   correctly requires a "who is grouped with whom this week"
   concept (~25-person weekly groups) that isn't modeled anywhere yet.
   A half-correct version — e.g. exposing an entire league's full
   membership instead of a scoped weekly group — would be a *worse*
   privacy outcome than deferring it, so it was deferred. This is
   consistent with this phase's explicit "Do NOT implement real
   leaderboard computation yet."

Both are documented inline in `migrations/20260816120100_profiles.sql`
and `migrations/20260816120900_competition.sql`.

## Migration workflow

```bash
# from the repo root, using the Supabase CLI via npx (no global install required)
npx supabase start        # boots local Postgres + Studio + Auth via Docker
npx supabase db reset     # (re)applies every migration in migrations/, then seed.sql
```

Adding a new migration:

```bash
npx supabase migration new some_description
# edit the generated supabase/migrations/<timestamp>_some_description.sql
npx supabase db reset      # verify it applies cleanly from scratch
```

Guidelines:

- Prefer several small, logically-grouped migrations over one giant
  file (this phase used 11: extensions/helpers, profiles, mission
  definitions, mission instances, mission events, processed commands,
  xp ledger, user progression, achievements, competition/league,
  integrity/audit).
- Every migration must be safe to run against a fresh empty database
  in order — nothing here assumes manual out-of-band setup.
- Never manually edit remote/production schema outside of a migration
  file.

## Edge Functions (implemented in Phase 10C)

`accept-mission` / `start-mission` / `record-progress` / `submit-mission`
/ `cancel-mission` now exist under `supabase/functions/` — see
`supabase/functions/README.md` for their structure. Each is a thin
TypeScript wrapper: authenticate, validate the request shape, call the
matching `forge_*` PL/pgSQL function in
`migrations/20260817090100_mission_reward_functions.sql`, map the
result. All real logic — ownership, sequence/idempotency, completion
validation, XP/progression/achievement/competition-score calculation,
integrity evaluation, audit logging — lives in that one SQL file, not
in TypeScript, so the whole authoritative operation is one atomic
Postgres transaction per command.

Still not built (Phase 10D+): `finalize-season-week` / `finalize-season`
(weekly/season aggregation, promotion/demotion, Hall of Fame) and a
standalone integrity/anti-abuse job — see the Phase 10C final report's
"what remains" section.

## Secrets policy

- **NEVER put the `service_role` key in Flutter/mobile/web client
  code, in `--dart-define`, in `AppConfig`, in a committed file, or in
  any bundle that ships to a device.** The service-role key bypasses
  RLS entirely by Supabase's design — it is equivalent to full
  database admin access and must only ever live in a trusted server
  context (an Edge Function's runtime environment, a CI secret store).
- The Flutter app, once wired in a later phase, should only ever hold
  the `anon` public key plus a signed-in user's own JWT — both of
  which are safe to ship, because RLS is what actually enforces
  boundaries, not secrecy of the anon key.
- No real Supabase URL, anon key, or service-role key was added to
  this repo, `.env`, or `AppConfig` in this phase. `AppConfig`'s
  existing `isSupabaseConfigured` / `supabaseUrl` / `supabaseAnonKey`
  fail-safe defaults (from Phase 10A) are unchanged.

## Phase 10A mapping

Documentation only — no Dart code or application wiring was added
this phase. This is the intended future correspondence between
`lib/core/backend/` contracts and this schema:

| Phase 10A (Dart) | Phase 10B (Postgres) |
|---|---|
| `BackendCommand.commandId` | `mission_events.command_id` / `processed_commands.command_id` (both `unique`) |
| `BackendCommand.idempotencyKey` (via `DeterministicIdempotencyKeyGenerator`) | `mission_events.idempotency_key` / `processed_commands.idempotency_key` (both `unique`) |
| `IdempotencyReplayGuard` (in-memory, per-process) | `processed_commands` (durable, cross-process) + `mission_events_instance_sequence_unique` / sequence-guard trigger — the durable version of the same non-decreasing-sequence rule |
| `AcceptMissionCommand` / `StartMissionCommand` / `RecordMissionProgressCommand` / `SubmitMissionCommand` / `CancelMissionCommand` | Each becomes one `mission_events` row (`event_type` matching), inserted by a future Edge Function after validation |
| `RawBackendResponse<T>` / `ServerConfirmedResult<T>` | The row(s) an Edge Function writes to `xp_ledger` / `user_progression` / `competition_score_ledger` after a command is accepted — never fabricated client-side |
| `ServerClock` / `MockServerClock` | Postgres `now()` / `timezone('utc', now())` — every timestamp column here is `timestamptz`, stamped server-side |
| `DataAuthority.serverConfirmed` | Any value read from `xp_ledger`, `user_progression`, `competition_score_ledger`, `season_results`, `user_achievements` |
| `DataAuthority.provisional` | A `mission_events` row the client just inserted, before a future Edge Function has derived any reward from it |
| `lib/core/security/trust_boundary.dart` | This README's [Authority model](#authority-model) table — same three-way split, restated for the database side |

## Phase 10C: the authoritative command pipeline

### New schema (additive only — no Phase 10B migration was edited)

`migrations/20260817090000_mission_reward_columns.sql` adds:
`mission_definitions.base_xp_hint` (the server-side counterpart to
`MissionDefinition.baseXpHint`, which had no column at all in Phase
10B); `mission_instances.resolved_difficulty` / `.recovery_mission` /
`.base_xp_hint` / `.completion_quality` (per-instance facts the mission-
selection engine resolves dynamically, which Phase 10C's reward engine
needs but Phase 10B never stored); and two new `audit_log.action`
values (`progression_update`, `competition_score_award`) via a
drop+recreate of that CHECK constraint.

### The transaction flow

`migrations/20260817090100_mission_reward_functions.sql` defines five
`SECURITY DEFINER` PL/pgSQL functions — `forge_accept_mission`,
`forge_start_mission`, `forge_record_mission_progress`,
`forge_submit_mission`, `forge_cancel_mission` — each callable only by
`authenticated` (every helper function they use internally has
`EXECUTE` revoked from `PUBLIC`, so a client cannot bypass the wrapper
by calling a helper directly). Each derives the acting user exclusively
from `auth.uid()` inside the function body — never from a parameter —
and each is one Postgres transaction: an unhandled exception rolls back
every write the call made.

`forge_submit_mission` is the important one. Per command:
1. Lock the mission row (`for update`) — the same lock that makes
   concurrent double-submission resolve to one reward (see
   [Concurrency](#concurrency)).
2. Check `processed_commands` for idempotency (exact retry → return the
   cached response; conflicting replay → reject; reused command_id
   under a different key → reject).
3. Check the command-sequence counter (`mission_instances.current_
   sequence`) against the expected next value.
4. Append the `submitted` mission_events row.
5. Independently re-validate completion (`forge_validate_completion` —
   never trusts the client's own "I'm done" claim).
6. On failure: append `validation_failed`, leave the mission open,
   return a rejected result. On success: append `validation_passed` +
   `completed`, mark the mission `completed`.
7. Compute XP (`forge_calculate_xp_reward`), write `xp_ledger` (skipped
   if the computed amount is `0` — `xp_ledger.amount` has a nonzero
   CHECK), update `user_progression`, evaluate achievements
   (`forge_evaluate_achievements`), evaluate integrity
   (`forge_evaluate_integrity`, writing to `integrity_events` only),
   and — if a competition week is currently configured — compute and
   ledger a competitive score (`forge_calculate_competition_score`),
   applying per-mission/category-day/day/week caps eagerly at write
   time. Every one of these writes an `audit_log` row.
8. Persist the idempotency record and return the full response.

### XP policy parity — `xp_policy_v1`

`forge_calculate_xp_reward` is a direct line-by-line port of
`lib/features/progression/domain/policies/xp_calculation_policy.dart`'s
`XpCalculationPolicy.evaluate`: same difficulty multipliers, same
`CategoryMasteryThresholds` tier multipliers (0/5/15/30 completions →
1.0/1.05/1.1/1.15), same streak-bonus/recovery-bonus/diminishing-
returns/per-mission-cap/daily-cap formula, in the same order. No
shortcuts were taken here — this is full parity, not a subset.

### Progression policy parity

`forge_level_for_xp`/`forge_xp_required_for_level` port
`LevelPolicy`/`LevelCatalog` exactly (`25 * (level-1) * level`, levels
1-30) — a formula, not a lookup table, so no separate `level_
definitions` table was needed.

### Competition policy parity — `competition_policy_v1`

`forge_calculate_competition_score` ports
`ForgeCompetitiveScorePolicy.evaluate`'s per-mission formula in full:
difficulty/quality/diversity factors, repetition decay, recovery
normalization, and the integrity-driven zero/half adjustment, all with
the same constants as `CompetitionScoringConstants`. Two honest,
documented differences from the Dart architecture (not omissions of the
formula itself):
- **Caps applied eagerly at write time** (category/day/week, via a
  running `sum()` against `competition_score_ledger`) rather than at a
  later weekly-aggregation pass the way `CompetitionCapPolicy` is
  invoked in the Dart domain. This is strictly more protective — a
  weekly job that hasn't run yet can never let someone exceed a cap in
  the meantime.
- **`consistencyFactor` stays `1.0`** here, exactly like
  `ForgeCompetitiveScorePolicy.evaluate` itself does — true weekly
  consistency bonuses (`CompetitionConsistencyPolicy`) and season
  aggregation (`CalculateWeeklyScoreUseCase`, `SeasonScoringPolicy`) are
  a separate job in the Dart domain too, and stay out of scope for a
  single mission's submit transaction, consistent with Phase 10B's own
  "do not implement real leaderboard computation yet."
- **`completionQuality` defaults to `standard`** — no proof-quality
  evidence pipeline exists yet to set `mission_instances.
  completion_quality` to anything else; the column exists for a future
  phase to populate.

### Achievement evaluation — a documented partial subset

`forge_evaluate_achievements` supports exactly the
`achievement_definitions.criteria` keys this schema can already answer:
`missions_completed`, `distinct_categories`, `recovery_completions`.
Two of the five seeded achievements are **not evaluated**:
`active_days_in_week` (needs a true weekly-consistency concept not
built yet) and `early_completions` (needs a local-timezone-aware
time-of-day concept that doesn't exist anywhere in this schema *or* in
the Dart `AchievementCriteria` hierarchy — this isn't a port gap, the
Dart side never modeled it either). This is a deliberate, reported
subset, not a silent omission — see the Phase 10C final report.

### Completion validation

`forge_validate_completion` ports `MissionCompletionValidator` exactly,
one branch per progress type, reading a generic jsonb payload instead
of Dart's sealed classes. `supabase/functions/_shared/progress.ts`
additionally validates payload shape/sane bounds (mirroring
`MissionProgressPolicy`'s numeric ceilings) before the request ever
reaches the database — but does **not** replicate
`MissionProgressPolicy`'s *stateful* rules (decrease-requires-
correction, implausible-single-interval-jump), since those compare
against the mission's prior progress state and doing that here would
mean re-folding the full event history just to validate a shape. That
stateful check stays enforced client-side, before a progress update is
ever queued.

### Concurrency

Two `submit-mission` requests racing for the same mission resolve to
exactly one reward via the same two mechanisms the whole schema already
relies on: `forge_lock_owned_mission`'s `select ... for update` row
lock (the second transaction blocks until the first commits, then
re-reads the now-advanced `current_sequence` and is rejected as stale)
plus the pre-existing unique constraints (`xp_ledger(source_type,
source_id)`, `mission_events(mission_instance_id, sequence)`,
`processed_commands(idempotency_key)`). No new concurrency primitive
was invented — this phase only had to make sure every write path
actually goes through the row lock, which `forge_submit_mission` does
by construction (everything happens after `forge_lock_owned_mission`
returns, inside the same function call/transaction).

### Error model

Every `forge_*` function raises exceptions formatted as `'error_code|
human message'` (via `forge_raise`) rather than returning an ambiguous
status. `supabase/functions/_shared/errors.ts` parses that back into
one of the stable codes (`unauthenticated`, `forbidden`,
`invalid_payload`, `forbidden_authority_field`, `mission_not_found`,
`invalid_transition`, `stale_sequence`, `out_of_order`,
`duplicate_command`, `idempotency_conflict`,
`completion_requirements_not_met`, `integrity_rejected`,
`internal_error`) and maps it to an HTTP status — a raw Postgres error
message never reaches the client; anything unrecognized becomes
`internal_error` with the real detail only in the function's own logs.

### Flutter adapter

`lib/core/backend/supabase_backend_client.dart` is now a real
`BackendClient` implementation (the Phase 10A stub is gone). It depends
on a narrow `EdgeFunctionsClient` interface (`edge_functions_client.
dart`) rather than `supabase_flutter` directly, so its request/response-
mapping and trust-boundary logic (malformed-response rejection,
`missionInstanceId` cross-checking, business-rejection vs. internal-
error handling) is fully unit-tested with zero network access — see
`test/core/backend/supabase_backend_client_test.dart`.
`supabase_edge_functions_client.dart` is the thin real implementation of
that interface, built from a `SupabaseClient` that already carries the
signed-in user's session; it never constructs a client with a service-
role key. `sync_queueing_backend_client.dart` is the minimal offline
integration with the existing `SyncQueue` (spec section 23) — not a
background daemon, just a wrapper that queues a failed call as
provisional and only marks it confirmed once a later `flushPending()`
call gets a real server response.

## Phase 10D: live integration & season finalization

### App-side wiring (`lib/core/backend/`, `lib/features/*/presentation/`)

- **Backend mode** (`backend_mode.dart`): `BackendMode.mock` /
  `BackendMode.liveSupabase`, resolved from the existing `AppConfig`
  (`isMock`/`isSupabaseConfigured`) — never a separate flag. Mirrors
  `assertAuthRepositoryConfigIsSafe`'s exact guard shape: a release
  build against mock, or a live build missing Supabase credentials,
  throws rather than silently falling back.
- **DI** (`backend_providers.dart`): `backendModeProvider` →
  `rawBackendClientProvider` (Mock/Supabase) →
  `authenticatedBackendClientProvider` (identity-checked) →
  `syncQueueingBackendClientProvider`/`backendClientProvider` (offline-
  queueing). Screens depend only on `backendClientProvider`, which is
  typed as `SyncQueueingBackendClient` — no Supabase SDK type ever
  appears above the DI composition root.
- **Persistence** (`persisted_sync_queue_store.dart`): reuses the
  existing `SecureKeyValueStore` (already used for the auth session) —
  no new storage package. Partitioned per-user by storage key
  (`forge.sync_queue.<userId>`); `SyncQueueRestoreGuard` is a second,
  independent ownership check at restore time.
- **Reconciliation** (`core/backend/reconciliation/mission_command_
  reconciliation.dart`, `progression/domain/services/progression_
  reconciliation.dart`, `competition/domain/services/competition_
  reconciliation.dart`): pure, deterministic mapping from a server
  verdict/error code to one of exact-match/accepted/rejected/stale-
  sequence/server-ahead/idempotency-replay/conflict, plus the actual
  provisional→confirmed merge for XP/achievements/competition score.
- **Sync executor** (`sync_queue_executor.dart`): one method
  (`runOnce`), no internal timers — the spec's "not a heavy daemon."
  `SyncQueueingBackendClient.flushPending` (extended this phase)
  distinguishes a retryable transport failure (stays `pending`) from an
  unrecognized/malformed response (`markConflict` — never auto-retried
  again).
- **Mission → backend wiring** (`mission_backend_sync_bridge.dart`):
  the same "bridge" pattern the codebase already used for mission→
  progression/competition (`mission_completion_bridge.dart`) — reacts
  to local `MissionLifecycleController` transitions and dispatches the
  matching command, never mutating the local event-sourced domain
  itself.
- **Confirmed XP** (`progression_event.dart`'s new `XpConfirmedByServer`
  event + `ProgressionAggregate.rehydrate`'s updated fold): the durable
  mechanism — a transient in-memory overwrite would be discarded by the
  very next `_refresh()`, so confirmation had to become a real event
  type, exactly like every other progression fact.

### Known, documented limitation: no server-side mission assignment yet

A real end-to-end live round trip additionally requires a server-side
`mission_instances` row to already exist for the mission being acted
on — nothing in Phase 10A-D creates one (mission *assignment* was
explicitly out of scope for Phase 10C and remains so here; the client
technically *can* insert its own row via the existing
`mission_instances_insert_own` RLS policy, but nothing wires the local
mission-selection engine's instance id to a real inserted row yet). In
live mode, the commands this phase wires are dispatched correctly and
will receive a clean `mission_not_found` until that gap closes in a
later phase — this phase's deliverable is the wiring/reconciliation
logic itself, which is independently correct and tested regardless.

### Server-side: weekly/season finalization (`20260819090000_season_
finalization.sql`)

`forge_finalize_season_week`/`forge_finalize_season` are `SECURITY
DEFINER` functions with **no grant to `authenticated` at all** — the
strongest "normal users cannot call this" guarantee in this schema,
matching `processed_commands`/`integrity_events`/`audit_log`'s own
zero-policy pattern. Meant to run from a trusted, scheduled context (a
future admin/service-role Edge Function or Supabase cron job) — never
from the Flutter app.

They port `LeagueMovementPolicy`, `RookiePlacementPolicy`, and
`SeasonScoringPolicy` faithfully: the same tie-break order (score →
active days → average difficulty → earliest attainment → user id,
never account age), the same floor/ceiling handling, the same rookie
grace-period suppression, the same best-N-of-M season aggregation. One
documented scope decision: ranking happens across an entire league for
the week/season, not subdivided into Item 9's ~25-person weekly groups
(`mock_league_grouping_policy.dart`'s grouping was already flagged as
unmodeled server-side in Phase 10B and remains so) — a league-wide
ranking is the smallest correct superset of "rank deterministically
with the same tie-break rules."

### Public-safe leaderboard read model

`competition_public_season_leaderboard` / `competition_public_weekly_
leaderboard` are plain SQL views exposing exactly: display name,
avatar path, league name, rank, confirmed score, promotion/demotion
status. Never integrity signals, recovery data, mission history,
reflections, or email. Views run with their creating role's privileges
by default in Postgres (not the querying role's) — which is what lets
a narrow, explicitly-column-limited view safely read across users from
otherwise own-row-only tables; the safety comes from which columns are
selected, not from bypassing RLS by accident. Granted `SELECT` to
`authenticated`.

## Verification status

Legend: **implemented** (code exists) · **statically reviewed** (read
carefully, never executed) · **locally executed** (actually run against
a real local Postgres/Docker/Deno this repo controls) · **staging
verified** (run against a shared, non-production Supabase project) ·
**production verified** (run against the real deployed project). A row
is only marked done at a level once that exact level actually happened
— never inferred from a lower level succeeding.

| Subsystem | Implemented | Statically reviewed | Locally executed | Staging verified | Production verified |
|---|---|---|---|---|---|
| Migrations 0001–0020 (schema, RLS, triggers) | ✅ | ✅ | ✅ (Roadmap Item 12) | ❌ | ❌ |
| RLS cross-user isolation (002) | ✅ | ✅ | ✅ | ❌ | ❌ |
| No-client-authority-writes (003) | ✅ | ✅ | ✅ | ❌ | ❌ |
| integrity_events/audit_log fully locked (004) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Duplicate-prevention invariants (005) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Public-safe catalog reads (006) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Command auth boundary (007) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Lifecycle transitions/sequence (008) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Command idempotency, incl. retry-same-key and conflicting-payload rejection (009) | ✅ | ✅ | ✅ | ❌ | ❌ |
| XP/progression reward calculation + privacy (010) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Week finalization: ranking, tie-break, rookie protection, promotion/demotion (011) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Season finalization: best-N-of-M, idempotency, privacy (012) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Server-side mission assignment + idempotency (013) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Achievement canonical IDs (014) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Weekly grouping (015) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Deno `_shared` modules (errors/progress/validation) | ✅ | ✅ | ✅ (19/19) | ❌ | ❌ |
| Edge Function HTTP layer (auth gate, malformed body, cron secret) | ✅ | ✅ | ✅ (manual curl smoke tests, `assign-daily-mission` + `finalize-week`) | ❌ | ❌ |
| Two-connection concurrency: simultaneous daily assignment | ✅ | ✅ | ✅ (proven: one winner, one instance, deterministic loser response) | ❌ | ❌ |
| Two-connection concurrency: simultaneous mission completion | ✅ | ✅ | ✅ (proven: exactly one xp_ledger/achievement/score-ledger row) | ❌ | ❌ |
| Load sanity (100–grouping participants) | ✅ | ✅ | ✅ (grouping 16ms, finalization 58ms at 100 participants) | ❌ | ❌ |
| Cron activation (real Supabase Cron schedule) | ✅ (script/SQL ready) | ✅ | ❌ | ❌ | ❌ |
| Per-function granular Deno tests (assign/accept/start/record/submit/cancel/finalize-week/finalize-season) | ❌ (not written — only `_shared` covered) | — | ❌ | ❌ | ❌ |

**How Roadmap Item 12 actually got a real local Postgres running**, for
whoever runs this next: Docker Desktop needed a cold start (2-4 minutes
before `docker ps` responded — `docker info` specifically was
unreliably slow under load and is no longer used as the health probe,
see `verify_backend.sh`); the bundled Realtime service crashed with
SIGILL from an Erlang/BEAM JIT incompatibility in this specific
virtualized environment and was disabled (this project never uses
Realtime); Storage and Studio were also disabled since neither is used
here and each extra container narrowed the health-check margin on a
memory-constrained machine. None of that reflects a problem with this
project's own schema or code.

**Bugs this first real run caught that static review had missed** (see
Roadmap Item 12's final report for full detail): `CREATE OR REPLACE
VIEW` cannot reorder existing columns, only append trailing ones (a
leaderboard-view migration violated its own stated rule); the
achievement-canonicalization migration's `UPDATE` silently no-ops on a
from-zero reset because `seed.sql` always runs after every migration,
so the seed itself now inserts canonical IDs directly; `service_role`
has no direct grant on `auth.users` on this local image (only
`postgres` does) — every SQL test's setup block now runs as `postgres`
instead; no migration ever granted baseline `authenticated` table
privileges (RLS policies restrict rows, they don't grant table access
by themselves) — a new migration adds the precise minimal grant set;
`forge_evaluate_achievements`'s `on conflict` target was ambiguous
against its own OUT parameter of the same name; real Postgres has no
built-in `max(uuid)` aggregate; several test files had a bare top-level
`raise notice` outside any PL/pgSQL block (invalid syntax on its own);
one test exercised the "invalid mission" path against a user who
already had a same-day assignment, silently masking the check; one
finalization test's zone-overlap setup made the assertion unreachable;
one test still expected a stale pre-canonicalization achievement key.

To reproduce all of the above from scratch:
```bash
./supabase/tests/verify_backend.sh
```
This installs the Supabase CLI locally if needed, starts the local
stack, resets the database from zero, runs all 14 SQL test files, and
runs the Deno `_shared` tests — one command, genuinely executed, exits
non-zero on any real failure.
