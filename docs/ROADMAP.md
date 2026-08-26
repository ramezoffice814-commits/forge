# Roadmap

This tracks Forge's build order. Each item was built, tested, and verified
(`dart format`, `flutter analyze`, `flutter test`, and — from Item 10
onward — a real local Supabase/Postgres backend verification pass) before
the next one started. Descriptions below reflect what's actually in the
repository — see [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit
together, and the [README's Trust Boundaries](../README.md#trust-boundaries)
for exactly what "verified" means at each stage.

## Completed

### 1 — Foundation
Project scaffolding: Flutter project setup, the "Forge" design system
(theme tokens, color ramps, spacing/radius scales), and the shared widget
library (`ForgeButton`, `ForgeCard`, loading/error/empty/offline states)
that every later feature builds on.

### 2 — Navigation
The app shell: a `StatefulShellRoute.indexedStack` hosting the five
bottom-nav tabs (Home, Rank, Progress, Awards, Profile) with state
preserved across tab switches, plus the routing conventions later features
follow (named routes, top-level routes for full-screen experiences that
shouldn't show the bottom nav).

### 3 — Auth
Sign-up, sign-in, forgot-password, and session restore, with a mock
repository as the default and a real Supabase-backed repository behind
`APP_ENV=live`. `AuthStateAwareRedirectPolicy` centralizes every
auth-based redirect decision so no individual screen enforces auth itself.

### 4 — Dashboard
The Home tab's real content: header, discipline/streak overview, weekly
snapshot, league preview card, and the mission card slot that later items
wire up to real mission data.

### 5 — Character System and Daily Transmission Experience
The Watcher character and the full Daily Transmission presentation flow —
reveal, dialogue, mission reveal, accept — built on reusable animation
states, local TTS, synchronized subtitles, and deterministic mock scripts.
Explicitly out of scope at this stage: real AI generation, a real backend,
XP, proof upload, ranking.

### 6 — Discipline Intelligence Engine and Mission Selection Foundation
A deterministic, backend-style rules engine so no mission is ever invented
ad hoc: catalog → eligibility filters → safety policy → difficulty engine
→ recovery policy → personalization scoring → deterministic selection (with
a fallback strategy) → a shared `MissionInstance` that Dashboard and
Transmission both read from, so they can never disagree about today's
mission.

### 7 — Mission Lifecycle, Progress Tracking, and Event Engine
Missions moved from a mutable status flag to a fully event-sourced
lifecycle: 19 typed `MissionEvent`s, a pure `MissionAggregate.rehydrate()`
reducer, an explicit lifecycle transition table, ten reusable progress
controls, a local completion validator, an in-memory event repository, and
`ActiveMissionPage` with a per-mission event timeline. Explicitly out of
scope: a real backend, persistence, XP, proof verification.

### 8 — Progression System, XP Evaluation, Levels, Titles, and Achievement Engine
Mission completions now feed a deterministic, explainable progression
pipeline: XP evaluation with documented caps and diminishing returns, a
generated level ladder, behavior-earned cosmetic titles kept separate from
XP, and an achievement engine with locked/progressing/unlocked states.
Everything at this stage was explicitly local-preview-only.

### 9 — Fair Competition and Season Engine
Seasons, weeks, leagues, and a competitive rating foundation, kept
completely separate from XP: weekly/season score is computed by
`ForgeCompetitiveScorePolicy` from difficulty/quality/diversity/
consistency factors plus repetition, recovery, and integrity adjustments
— never from XP. Adds rookie placement (14 days or 10 completions,
whichever first), a 6-tier league catalog, deterministic ranking with a
documented tie-break order, best-N-of-M season aggregation, an anti-abuse
integrity evaluator, and a Hall of Fame that never feeds back into current
ranking. Local/mock-first: an `InMemoryCompetitionRepository` backs a
deterministic 42-user mock population, and every competitive value is
explicitly marked `provisionalOnly`.

### 10 — Backend Foundation (Authority, Schema, Authoritative Commands, Reconciliation)
The single largest roadmap item so far, in four parts:

- **10A — Backend contracts and trust boundary.** `BackendClient`
  interface (mock, authenticated, and Supabase-backed implementations),
  typed commands for every mission action, idempotency-key generation and
  replay guarding, a persisted sync queue, and the `AuthoritativeValue`/
  `DataAuthority` types that make provisional-vs-confirmed state explicit
  at the type level rather than by convention.
- **10B — Supabase schema and RLS.** Postgres tables for profiles, mission
  definitions/instances/events, processed commands (idempotency), the XP
  ledger, user progression, achievements, the full competition schema
  (seasons/weeks/leagues), integrity events, and an audit log — Row Level
  Security on every one of them.
- **10C — Authoritative mission backend.** `forge_*` SECURITY DEFINER
  command functions (accept/start/record-progress/submit/cancel mission)
  that independently recompute XP, progression, achievements, and
  competitive score server-side, plus the matching Deno Edge Functions and
  a `SupabaseBackendClient` wiring the Flutter client to them.
- **10D — Live authority integration foundation.** Mock/live backend mode
  switching, a sync executor, competition and progression reconciliation
  (subtracting the confirmed delta out of the provisional bucket once a
  server result lands — never overwriting confirmed with local), account-
  switch queue isolation, week/season finalization SQL, and the public
  leaderboard read models.

### 11 — Live Backend Completion
Authoritative daily mission assignment (server-derived date, idempotent
repeat, no duplicate even via the offline fallback path), canonical
achievement IDs (12 stable keys the server and client agree on), weekly
groups (≤25 members, rookie-first ordering), a real leaderboard repository
reading the confirmed public views, scheduler-ready `finalize-week`/
`finalize-season` Edge Functions, and `AuthorityStatusBadge`/
`SyncConflictBanner` UI so the client can honestly show what's still
provisional versus confirmed.

### 12 — Backend Runtime Verification
The backend was actually executed against a real local Supabase/Postgres
instance rather than only reasoned about. Verified, and independently
**re-verified during the Items-10–12 recovery pass** (see
[../supabase/tests/README.md](../supabase/tests/README.md)):

- All 24 migrations apply cleanly from zero, then seed.
- All 14 SQL test files (`002`–`015`) pass every assertion: RLS ownership,
  no-client-authority-writes, integrity/audit lockdown, duplicate
  prevention, public-safe catalog reads, command auth boundary,
  transition/sequence rejection, command idempotency (including
  exact-retry-returns-cached-result and conflicting-replay-rejected),
  reward calculation matching the client formula exactly, week/season
  finalization (ranking, tie-break, rookie protection, idempotent re-run),
  mission assignment, achievement canonical IDs, and weekly grouping.
- True two-connection concurrency (duplicate assignment/completion/reward
  prevented, idempotent retry, conflicting replay rejected) was verified
  by hand during the original pass; not yet scripted into the harness.
- Deno shared-module tests (19, historically) and real HTTP Edge Function
  smoke tests were verified during the original pass. **Deno-dependent
  checks remain unverified on the recovery-pass machine specifically until
  Deno is installed there** — the harness reports this explicitly rather
  than faking a pass.

**Classification: locally runtime verified.** Explicitly **not** staging-
verified and **not** production-ready — no Supabase project has been
created outside a local machine, and no Edge Function has been deployed
anywhere.

### 13 / 13B / 13C — Staging Deployment, Verification-Gap Closure, Live Mission Identity Reconciliation
Moved Forge from *locally runtime verified* to *staging verified* against
the real `forge-staging` Supabase project: staging/production target
config, all 24 migrations and 14 SQL test files re-verified directly
against staging Postgres, all 8 Edge Functions deployed, real
adapter-level integration tests against staging (auth, mission lifecycle,
retry, conflict, offline reconnect, account switch), Dart/SQL reward
parity fixtures, a root-caused-and-fixed mission-identity bug (live mode
now always adopts the server-confirmed `resolvedMissionInstanceProvider`
id, never a locally-generated one), `FORGE_CRON_SECRET` provisioned and
staging cron schedules activated, and structured observability
(`logOutcome`) extended to all 8 functions.

**Classification: STAGING VERIFIED**, with one documented caveat: no
pixel-level UI automation of the live app (adapter/SQL/HTTP-level
verification only). Not production-ready — no production Supabase
project has been configured or deployed to.

### 14 / 14B — AI Personalization & Coach Layer, Live Integration
Advisory/personalization-only AI Coach module
(`lib/features/ai_coach/`): mission explanation, Daily Transmission
dialogue line, post-mission coaching, weekly recap, and a coach chat
surface, all built on a provider-agnostic client abstraction, a
privacy-minimized context (full/limited/disabled, defaulting to
limited), deterministic fallback templates, client- and server-side rate
limiting, and a server-side `ai-coach` Edge Function that never lets the
Flutter app hold a provider credential. Wired live into the Dashboard
mission card, the Daily Transmission screen (additive only — the
existing dialogue/TTS/subtitle state machine is untouched), and Profile
(a persisted privacy preference, restored on restart). One AI-suggested
action (`requestEasierMission`) is wired end-to-end through a
confirmation step to the existing deterministic
`MissionSelectionController` — the AI never mutates mission state
directly, and every other suggested action is recognized but not yet
wired to anything.

The `ai-coach` Edge Function is deployed to `forge-staging` and was
smoke-tested there with real HTTP calls (all 5 tasks, plus missing-auth,
unknown-task, and nested-authority-field-injection failure paths) — see
the Item 14B PR for the full transcript. **No real AI provider is
configured; the only provider wired anywhere is a deterministic, free
mock** (provider cost: $0).

**Classification: COMPLETE, mock-provider only, staging verified.** A
real provider has not yet been selected, and the server-side rate
limiter — confirmed correct in isolation but, per a real staging test,
in-memory per warm isolate and **not** coordinated across concurrently
warm instances — must become a persistent, cross-instance counter before
any real, paid provider is connected. Not a blocker while the only
provider is the free mock.

### 15 — Notifications, Retention & Daily Operating Loop
A Forge-native notification domain and in-app inbox, built on the
existing client/server trust boundary (`lib/core/security/
trust_boundary.dart`): Achievement Unlock, Level-up, Week Result,
Season Result, and Weekly Recap are server-authoritative rows, written
exclusively by `forge_create_notification()` inside the same
transaction as the fact each one describes (`forge_submit_mission`,
`forge_finalize_season_week`, `forge_finalize_season`) — never
client-inserted, never inferred ahead of server confirmation. Daily
Mission, Daily Transmission, and Mission Follow-up reminders are
computed live client-side from state the client already treats as
authoritative, deliberately not persisted server-side (this avoids
duplicating Item 13C's own client-request-driven mission-assignment
architecture with a new server-side batch pipeline). Per-category
preferences (including quiet hours, correctly handling the overnight
wraparound) actually gate what reaches the inbox; deep links route
through a closed, exhaustively-matched enum so no notification payload
can navigate to an arbitrary destination.

While deploying to `forge-staging`, a live smoke test found and fixed
two critical, live-exploitable bugs: `forge_create_notification` was
directly callable by `anon`/`authenticated` via RPC, and the two new
tables had full CRUD open to both roles despite the migration's own
narrower `grant` statements — the root cause (a real hosted Supabase
project's platform bootstrap grants broad privileges outside this
repo's migrations, which additive `grant` statements alone never
override) turned out to affect **every table created before this
item**. A follow-up system-wide audit found the same root cause had
left `mission_instances`/`mission_events` directly rewritable by any
authenticated client, bypassing `forge_submit_mission`'s entire
validation/XP/achievement pipeline — confirmed the real Flutter client
never touches either table directly (every mission command goes
through Edge Functions calling the SECURITY DEFINER `forge_*`
functions instead), so both are now fully server-only, and every other
pre-existing table is narrowed to its already-documented intended
grant. See PR #8 for the full audit.

**Classification: COMPLETE within current scoped architecture.**
Deliberately deferred, not defects: Optional Re-engagement (type H —
the preference field exists, opt-in, but no notification is ever
generated); OS-level local push (`flutter_local_notifications`) and
remote push (FCM/APNs/web push) — delivery is in-app inbox only this
pass, matching the spec's own priority ordering and the explicit
stop-condition around new paid providers/infrastructure. Verified:
offline/reconnect (fetch failure → retryable error state, recovery,
no duplication, read-state persistence across a reconnect), account-
switch isolation, AI-disabled compatibility (zero dependency on any AI
Coach provider), and — via the system-wide audit above — that the
client cannot forge, mutate, or read across users for any
notification or reward-authority row anywhere in the schema.

### 16 — Settings, Account Controls & Preferences Center
A real `/settings` screen (`lib/features/settings/`) aggregating existing
preference surfaces rather than duplicating them: account identity summary
with sign-out (the app's first sign-out UI — none existed before this
item) and a delete-account control wired to the pre-existing
`DeleteAccountRequestUseCase` placeholder (which honestly surfaces "not
available yet" rather than faking success, since no deletion backend
exists), the existing AI privacy tile and notification preferences tile
(quiet hours included) moved unchanged from Profile, and a read-only
accessibility status row reflecting `MediaQuery.disableAnimations` (no new
override toggle — the OS setting is the only source of truth). Profile is
now progress-focused only, with a settings icon routing to the new
authenticated-only `/settings` route.

Auditing account-switch isolation for this item surfaced the same class of
bug already found and fixed for `LocalReminderStore` in Item 15:
`AiPrivacyPreferenceStore` used one non-user-scoped local storage key, so a
second account signing in on the same device would silently inherit (or
overwrite) the first account's AI privacy choice. Fixed by keying the
store per user ID and making `aiPrivacyBootstrapProvider` reactive to auth
status (resets to the safe default on sign-out, reloads fresh per user on
sign-in) — which in turn surfaced a genuine Riverpod bug in that same fix
(writing to another provider synchronously during the unauthenticated
branch's own initial build threw "Providers are not allowed to modify
other providers during their initialization"), caught by the new
account-switch regression test before it could reach production, and
fixed with an explicit yield.

**Classification: COMPLETE.** No theme, locale, or in-app text-size
support exists in the app, so Settings deliberately doesn't offer toggles
for them (would have no real effect). No server-backed preference or
schema changed in this item — only a local storage key scheme — so Deno,
SQL, and staging verification are not applicable here.

## Next

Item 17 has not yet been scoped.

## Further Out

Named as future direction, not committed scope or timelines:

- Real AI-generated character dialogue, replacing the current mock
  scripts.
- OS-level local push and remote push notifications (FCM/APNs/web
  push) — Item 15 shipped in-app inbox only.
- Optional re-engagement notifications (Item 15's type H).
- Real account deletion, once a backend deletion flow exists (Item 16
  intentionally left the existing honest placeholder in place rather than
  implementing destructive deletion without a security review).
- Theme (light/dark) and locale/i18n support, if ever prioritized —
  neither exists today, so Item 16's Settings screen has nothing to
  surface for them yet.
- Monetization.
- Production deployment (only after Item 13 is complete and reviewed).
- iOS/macOS/Linux platform targets (only Android, Web, and Windows exist
  today).

This list will be revised as priorities change — nothing here is a
promise of order or delivery date.
