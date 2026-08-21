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

## Next

### 13 — Staging Deployment & Flutter Live Integration
Move Forge from *locally runtime verified* to *staging verified*, using a
real non-production Supabase project: deploy all migrations and Edge
Functions, configure staging-only environment variables and cron secret,
exercise the real authoritative path end-to-end from the actual Flutter
app (Daily Transmission → accept/start/progress/submit → confirmed XP →
confirmed progression → confirmed achievement → confirmed competition
score → leaderboard refresh), verify the offline queue/reconciliation
path against a real network (idempotent retry on an unknown outcome,
stale-sequence conflict reconciliation, account-switch isolation), staging
week/season schedules, a Dart/SQL parity harness, and a staging-specific
security pass.

## Further Out

Named as future direction, not committed scope or timelines:

- Real AI-generated character dialogue, replacing the current mock
  scripts.
- Notifications.
- Monetization.
- Production deployment (only after Item 13 is complete and reviewed).
- iOS/macOS/Linux platform targets (only Android, Web, and Windows exist
  today).

This list will be revised as priorities change — nothing here is a
promise of order or delivery date.
