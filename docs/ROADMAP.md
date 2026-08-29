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

### 17 — OS-Level Local Notifications
Real device notifications for Forge's three client-owned reminder types
(Daily Mission, Daily Transmission, Mission Follow-up), built entirely on
top of Item 15's existing notification domain rather than beside it:
`LocalNotificationService` (`lib/features/notifications/domain/
repositories/`) is the one seam between Forge and an actual device
notification tray — a real `flutter_local_notifications`-backed
implementation on Android and Windows, and an honest no-op on Web (see
below). `LocalNotificationScheduler` translates already-decided
`ForgeNotification`s into OS calls: it makes no eligibility decisions of
its own — `NotificationPreferences.allows`/`QuietHours.isQuietAt`/
`LocalReminderEngine` (all Item 15) remain the only source of "should
this be shown."

Daily Mission and Daily Transmission are mirrored to the OS via an
immediate `showNow()` exactly when `LocalReminderEngine` already decides
they're due for the in-app inbox — no invented fixed clock-time policy
(e.g. "always remind at 9am") that Item 15 never specified. Mission
Follow-up is the one reminder with a genuinely well-defined future
instant (`acceptedAt + followupMinimumAge`, both pre-existing Item 15
constants) and gets real advance scheduling instead, deferred out of
quiet hours via a new `QuietHours.nextEligibleTime` and automatically
cancelled once the mission completes or preferences change — all keyed
by a stable, deterministic OS notification id derived from the existing
dedup key (never random), so rescheduling replaces rather than
duplicates. Tapping a notification reuses Item 15's own closed
`NotificationDeepLink` mapping unchanged — a payload is only ever a
`ForgeNotificationType`'s wire name, parsed through the same
`tryParse`/`forType` functions the in-app inbox already uses, so a
forged or unrecognized payload safely no-ops rather than navigating
anywhere.

Client-owned local reminders and their OS mirroring work fully offline
by design (no network dependency in `LocalReminderEngine` itself) —
verified by restructuring `NotificationInboxController._load()` so a
failed server fetch still surfaces the existing retryable error state
for the in-app inbox, but no longer blocks the local-reminder/OS-sync
path that used to be sequenced after it. Account-switch isolation is
enforced by cancelling every locally-scheduled OS reminder on sign-out.

**Platform support** (spec section 3 — no assumed parity):
- **Android**: full support via the plugin's `NotificationCompat` APIs.
  Uses `AndroidScheduleMode.inexactAllowWhileIdle` deliberately — no
  `SCHEDULE_EXACT_ALARM` permission requested, since these are
  reminders, not time-critical alarms. `POST_NOTIFICATIONS` is declared
  and requested only from an explicit Settings action, never
  automatically.
- **Windows**: genuinely supported by the plugin (C++/WinRT toast
  notifications), with two real, documented limitations rather than
  hidden ones: no repeating notifications (not used here — every
  schedule is an explicit one-shot instant) and `cancel()`/
  `getActiveNotifications()` are no-ops without MSIX packaging, which
  this app doesn't use — cancellation there is best-effort.
- **Web**: a deliberate no-op. `flutter_local_notifications` technically
  ships a Web implementation, but it leans on a service worker for
  consistent tap-handling — close enough to the "web push
  infrastructure" this item was explicitly told not to add that treating
  it as in scope would stretch that instruction rather than honor it.
  Web keeps the existing in-app inbox only, with an honest "not
  available on this platform" in Settings.

**Explicitly out of scope this pass**: server-authoritative notification
types (achievement/level-up/competition/weekly recap) are not mirrored
to the OS — they remain in-app-inbox-only, pull-based, exactly as Item
15 shipped them; extending OS delivery to them would need a dedup story
spanning server-originated ids, which this item deliberately didn't take
on. Scheduled reminders do not survive a full device reboot (only a
normal app restart/backgrounding) — `flutter_local_notifications` has no
built-in boot-rescheduling for `zonedSchedule`, and the spec's own
conditional language ("implement only if supported cleanly by the
plugin") permits skipping a hand-rolled boot receiver for it. No
Android emulator/device or unlocked Windows Developer Mode was available
in the environment this item was built in, so real-device/emulator
smoke testing is honestly unverified — reported as such rather than
assumed.

**Classification: COMPLETE within the scope above.** Regression suite
green (see the PR); no Deno/SQL/staging verification needed — no server
schema or RPC changed, only client-side scheduling logic.

### 18 — Production Hardening & Release Readiness
A whole-codebase production-readiness audit (see
[docs/RELEASE_READINESS.md](RELEASE_READINESS.md) for the full,
area-by-area matrix and blocker list) covering security, configuration,
error handling, crash handling, observability, performance, migrations,
backup/recovery, data retention, account-deletion readiness, legal/
privacy surfaces, accessibility, and all three platform build pipelines
— **not** a production deployment.

Re-verified the existing security/RLS/grant/Edge-Function hardening from
Items 15/PR#8 still holds after Items 16/17 with no drift, and found no
new P0 (cannot-release) issue anywhere. Real gaps found and fixed where
safe and well-scoped:

- **No crash/uncaught-error handling existed at all** — added
  `lib/core/error/crash_handler.dart` (`FlutterError.onError`,
  `PlatformDispatcher.instance.onError`, `runZonedGuarded` in
  `main.dart`), console-only, no paid crash-reporting SaaS wired in.
- **The Android release build was broken** by Item 17's own
  `flutter_local_notifications` dependency (missing core library
  desugaring) — a real, previously-undiscovered regression this item's
  own release-build attempt surfaced and fixed
  (`android/app/build.gradle.kts`).
- **`notifications.fetchInbox()` had no `.limit()`** on a table with no
  retention policy, re-run on every sign-in/preference change — bounded
  to 200 rows.
- **`xp_ledger`/`competition_score_ledger`'s daily/weekly cap queries**
  (inside `forge_submit_mission`) had no supporting composite index —
  two purely-additive indexes added
  (`20260826020000_performance_indexes.sql`), verified via a clean
  `supabase db reset` + the full 17-script SQL suite + 25 Deno tests, all
  passing.
- `supabase_flutter` upgraded 2.16.0 → 2.17.2 (same major version, the
  only dependency judged clearly low-risk) with full regression
  verification; `flutter_riverpod`/`go_router`/`flutter_secure_storage`
  major-version upgrades were deliberately deferred as out of scope for
  a hardening pass.

Confirmed-absent, documented rather than fabricated: **no Terms of
Service or Privacy Policy exists anywhere in the app** (a real
app-store-submission blocker), the Android release build remains
debug-signed (real signing keys were explicitly not generated this
pass), and a genuine staging smoke test with real credentials could not
be run (none available in this environment) — a fabricated-but-non-empty
live-mode Web build was smoke-tested instead, confirming the release/
live path boots cleanly with no mock fallback and no debug banner, which
is the part actually verifiable without real secrets. Windows release
build is blocked by this machine's disabled Developer Mode (a
system-setting change requiring explicit permission, not toggled
automatically). `ActiveMissionPage`/`ProgressPage` accessibility gaps
and several cosmetic/branding items (default Android launcher
icon/splash, default Web `theme_color`) were found and documented, not
fixed — kept out of scope to avoid turning a hardening pass into a
redesign.

**Classification: PARTIALLY VERIFIED** — no P0 blocker, full regression
green (Flutter 970 passed/2 skipped/0 failed, Golden 18/18, SQL 17/17,
Deno 25/25), but real release-signing, legal content, and a live
staging smoke test remain genuinely outstanding pending assets/
credentials only a human can provide. See
[docs/RELEASE_READINESS.md](RELEASE_READINESS.md) for the complete
blocker list (P0–P3) and exact reasoning behind every fixed-vs-deferred
decision.

### 19 — Release Candidate & Real Platform Verification
Turned the hardened `develop` build into a genuine release candidate —
not a production deployment — by closing the real-environment, signing,
legal-surface, and release-pipeline gaps Item 18 left open. Full
area-by-area record in [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md).

Real work landed: an RC versioning strategy (`1.0.0-rc.1+2`, no prior
policy existed); safe Android signing plumbing (`android/key.properties`
drives real signing if present, fails clearly if incomplete, falls back
to the existing debug-signing dev/CI convenience if absent — no
production keystore generated, per the item's own explicit
instruction); real `/legal/privacy`/`/legal/terms` routes with honest,
factual draft content and a prominent "pending legal review" banner
(not fabricated legal text); targeted accessibility fixes to the two
screens Item 18 flagged as having zero coverage
(`ActiveMissionPage`/`ProgressionPage`); and three new CI jobs
(`android-build`/`web-build`/`windows-build`) that build — never sign,
never publish — each platform's release configuration on every PR, so
a regression like Item 18's desugaring break fails a PR automatically
instead of surfacing during a manual release pass.

Those new CI jobs then did exactly that: all three passed independently
on GitHub-hosted runners against the exact code in this item, including
**Windows** — proving a local machine's disabled-Developer-Mode block
was specific to that one machine, not this project's Windows build
config, even though a real launched-and-interacted-with Windows run
remains unverified.

**Classification: PARTIALLY VERIFIED** — no P0 blocker, full regression
green (Flutter 978 passed/2 skipped/0 failed, Golden 18/18, SQL 17/17,
Deno 25/25), all 5 CI checks green including the 3 new release-build
jobs. Not "COMPLETE": Android real-device/emulator verification, a real
(not just built) Windows run, and every staging-dependent check
(auth/mission/progression/competition/notifications/AI Coach) remain
genuinely blocked by missing hardware/credentials in this environment —
unchanged from Item 18, reported honestly rather than assumed resolved.
Final legal-content approval and an Android AAB build remain open too.
Not "BLOCKED" either — nothing here is stuck pending a decision within
this item's own control.

### 20 — Production Release & Store Submission Prep
Prepared Forge for a genuine production/store release while preserving
strict human approval gates around signing keys, legal content,
production infrastructure, store accounts, and final submission — this
item does not deploy production or submit to any store. Full
area-by-area record in
[docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md); final gate
breakdown in [docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md).

Real work landed: an Android AAB CI job (`android-aab-build` — Play
Store submission needs an `.aab`, which a passing APK build doesn't by
itself prove); a genuine, previously-undiscovered fix — `android/app/
src/main/AndroidManifest.xml` never declared `android.permission.
INTERNET`, only the `debug`/`profile` overlay manifests did (Flutter's
own dev-connection boilerplate, which doesn't carry into `release`),
and no plugin's own manifest supplied it as a merger fallback either;
a real release build would have been unable to make any Supabase
network call the moment live mode was ever used, invisible until now
because the app has only ever run in mock mode; a fuller accessibility
pass (13 concrete double-announcement fixes — `Semantics(label: ...)`
without `excludeSemantics: true`, causing a screen reader to announce
the same information twice — found by auditing all 33 files using
`Semantics(` in `lib/`, not by guessing from zero-occurrence counts);
the RC version bump (`1.0.0-rc.1+2` → `1.0.0-rc.2+3`); and six new
documents ([docs/PRODUCTION_CONFIG.md](PRODUCTION_CONFIG.md),
[docs/DATA_RETENTION_DECISIONS.md](DATA_RETENTION_DECISIONS.md),
[docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md),
[docs/STORE_ASSET_REQUIREMENTS.md](STORE_ASSET_REQUIREMENTS.md),
[docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md) — including draft store
copy marked DRAFT/REQUIRES HUMAN APPROVAL, a screenshot plan, and a
factual Data Safety engineering inventory — and
[docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md)).

Confirmed-absent, documented rather than invented: a production
Android signing key (none generated, per this item's own explicit
instruction), approved legal content, real brand assets (icon/splash/
feature graphic/screenshots — still stock Flutter defaults), a hosted
Privacy Policy URL, a Play Store developer account and its associated
declarations, and a real account-deletion implementation (design-only
document produced, `requestAccountDeletion()` unchanged). Android
real-device and Windows launched-and-interacted-with verification
remain unavailable in this environment, unchanged since Items 17–19.

**Classification: PARTIALLY VERIFIED.** No P0 blocker, full regression
green (Flutter 978 passed/2 skipped/0 failed, Golden 18/18, SQL 16/16,
Deno 25/25), one genuine networking-permission gap found and fixed,
secret scan clean. Not "COMPLETE" (in the release-*preparation* sense
this item defines, not a claim Forge has been published): production
signing ownership, legal approval, store assets, a hosted Privacy
Policy URL, and several store declarations are all AWAITING HUMAN
ACTION or BLOCKED — see
[docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md)'s explicit
**NO-GO** determination for the full gate-by-gate reasoning. Not
"BLOCKED" either — nothing here is stuck pending a decision within
this item's own control; every gap needs a credential, a device, a real
keystore, a store account, or a human legal/business decision this
item correctly declined to invent.

### 21 — CAN Rebrand & Cinematic App Experience
Forge's user-facing brand is now **CAN** ("I can" — capability,
discipline, progress, self-belief, action). Full record in
[docs/CAN_REBRAND_AUDIT.md](CAN_REBRAND_AUDIT.md). Not a production
deployment, a Play Store submission, or a package-ID migration.

Every occurrence of "Forge"/"FORGE"/"forge" across `lib/`, `android/`,
`web/`, `windows/`, `pubspec.yaml`, and `test/` was inventoried and
classified before touching anything — user-facing brand text changed
to CAN (app title, the shared auth-screen kicker, sign-up/onboarding
headings, Settings/About, legal-page copy, the Android notification
app name, level/achievement/title-catalog strings); internal code
symbols (`ForgeTokens`, `ForgeTheme`, etc.), the frozen package/
application identity (`com.forge.app.forge`, unchanged per this item's
own explicit instruction), every persisted secure-storage key prefix,
the Android notification channel ID, and historical roadmap entries
were all deliberately left alone — each with its own documented reason
in the audit, not a blind global replace. The Character/Daily
Transmission system's in-universe "the Forge" lore noun was replaced
with "the Current" (a creative call, flagged explicitly, not slipped in
silently) to keep the narrative internally consistent now that the
product itself isn't named Forge.

A cinematic CAN opening sequence was built as a presentation-only
overlay (`lib/core/opening/`) wrapping `MaterialApp.router`'s routed
content — it never touches routing or auth state; `AuthStateAwareRedirectPolicy`
resolves the real destination exactly as it always has, immediately,
and the overlay simply covers the screen for a short fixed sequence
(~2.5s first-run / ~1.1s returning-user fast path / ~0.6s reduced-
motion, selected via the same `onboardingStatusProvider` the router
already watches) before dissolving to reveal it. A hard 4-second safety
cap and defensive error handling guarantee the app can never get stuck
behind it. Verified with 6 dedicated deterministic timing tests (not
goldens, per this item's own "temporal behavior" instruction) plus
empirical confirmation that all 9 existing full-`ForgeApp` integration
test files continue to pass unmodified with the overlay wired in
system-wide. 7 existing golden baselines were regenerated to reflect
the intentional rebrand text changes, each diff reviewed as small and
localized before accepting.

The CAN icon was initially **AWAITING APPROVED CAN ICON FILE** — a
concept was shared in chat but no actual file could be found in the
project/session at that point; no icon was fabricated as a substitute.
A follow-up patch later found the approved source placed directly in
the project, preserved it as a canonical tracked copy
(`assets/branding/can_icon_source.png`), and integrated real derivatives
across Android (legacy launcher + a proper adaptive icon foreground/
background pair, safe-zone-checked), Web (including maskable variants),
and Windows (a genuine multi-resolution `.ico`) — see
[docs/CAN_REBRAND_AUDIT.md](CAN_REBRAND_AUDIT.md) for the full record.
That same patch also fixed the Android native launch screen (previously
still the stock Flutter white default; now the same CAN navy plus a
static mark, eliminating the pre-Flutter white flash) and added a
restrained Dashboard entrance animation. One restrained haptic
touchpoint was added (level-up); broader mission-completion haptics
were deliberately deferred rather than threaded hastily through all ten
progress-control types. Version bumped `1.0.0-rc.2+3` →
`1.0.0-rc.3+4`, following the same RC pattern Items 19-20 established.

**Classification: PARTIALLY VERIFIED.** No P0 blocker, no security or
backend-compatibility change (no migration, no RPC/Edge Function
rename), full regression green, CAN icon now fully integrated across
all three platforms. Not "COMPLETE": real Android real-device and
Windows launched-and-interacted-with verification remain unavailable in
this environment, unchanged since Items 17-20 — the icon-source
blocker is closed, but real-platform interaction still is not. Not
"BLOCKED" either — nothing here is stuck pending a decision within this
item's own control.

### 22 (Phase A) — Free Public Beta Launch
Prepared CAN for a genuinely usable free public beta — signed Android
APK via GitHub Releases, a free-hosted Web/PWA candidate, and a
zero-cost backend, with zero Google Play requirement and zero mandatory
paid infrastructure. **This item stopped at its own Human Launch
Approval Gate — nothing was published.** No GitHub Release was
created, no APK was uploaded, no Web build was deployed, and no
Supabase configuration was changed. Full record in
[docs/PUBLIC_BETA_SECURITY_GATE.md](PUBLIC_BETA_SECURITY_GATE.md),
[docs/ANDROID_BETA_SIGNING_SETUP.md](ANDROID_BETA_SIGNING_SETUP.md),
[docs/ANDROID_BETA_DEVICE_TEST.md](ANDROID_BETA_DEVICE_TEST.md), and
[docs/FREE_BETA_RELEASE.md](FREE_BETA_RELEASE.md).

Real work landed: a full public-beta security gate audit (treating the
beta as genuinely adversarial, not "trusted because small") found no
BLOCKED item — auth/RLS/XP/mission/ranking authority all re-confirmed
PASS via the existing SQL regression suite; AI Coach confirmed
genuinely zero-cost end-to-end (no real provider wired client- or
server-side); two areas carry an honestly-stated PASS WITH LIMITATION
(the `ai-coach` rate limiter's in-memory/per-isolate nature, already
self-documented as acceptable while only the free mock provider is
wired; and account deletion remaining a placeholder, assessed as not a
launch blocker for this specific APK-via-GitHub-Releases distribution
path since Play Store's policy trigger doesn't apply here — a human
product decision, not decided unilaterally). A restrained "CAN Beta"
label was added to Settings/About only (per this item's own "do not
plaster beta across every screen" instruction). Version switched from
`-rc.` to `-beta.` (`1.0.0-rc.3+4` → `1.0.0-beta.1+5`) — a deliberate
identifier change, not just a number bump, since this is the first
build real external users would actually install. PWA installability
was confirmed already satisfied by Item 21's own icon/manifest work,
with Cloudflare Pages recommended (not deployed) as the free-hosting
candidate over GitHub Pages specifically because it natively supports
the SPA-rewrite `go_router` needs.

**Update**: the human-owned Android beta signing key now exists
(`can-beta-release.jks`, alias `can-beta`, self-generated by the human
outside git as instructed — none was generated by this item). Verified
without ever printing a password: keystore/alias confirmed via
`keytool -list` (password extracted from the gitignored, untracked
`android/key.properties` into a local shell variable, never echoed),
certificate SHA-256 fingerprint captured, `android/key.properties`
confirmed gitignored and untracked. Local release builds remain
blocked by this machine's Application Control policy (unrelated to
signing, not bypassed), so a manual-dispatch-only GitHub Actions
workflow (`.github/workflows/android_beta_signed_build.yml`) was added
to build and sign on a GitHub-hosted runner instead — it never runs
automatically, produces only a private workflow artifact (this repo is
private), and has **not been run** (it needs 4 repository secrets the
human hasn't created yet; exact steps in
[docs/ANDROID_BETA_SIGNING_SETUP.md](ANDROID_BETA_SIGNING_SETUP.md)).
No signed APK exists yet.

**Update**: the repository default branch was changed from `main` to
`develop` (a pure GitHub-settings pointer change, zero commits/history
touched) — required because `workflow_dispatch` workflows are only
registered once their YAML exists on the default branch. PR #15 merged
into `develop`; the signed-build workflow became dispatchable and was
run exactly once (`33246791735`). Signing itself succeeded — a real
release APK was built and signed with the human key — but the
workflow's own verification step failed, from an unquoted build-tools
wildcard glob (multiple installed Android build-tools versions on the
runner broke `apksigner`/`aapt` invocation) and a certificate-
fingerprint extraction bug (`awk` field selection assumed the wrong
number of `": "` delimiters in `apksigner`'s real output). Both root
causes were confirmed by re-reading the failure log and independently
reproducing each locally against the real Android SDK and real tool
output; both are now fixed in the workflow file and re-tested locally
without touching any signing secret. Full root-cause writeup in
[docs/FREE_BETA_RELEASE.md](FREE_BETA_RELEASE.md). The workflow has
**not** been redispatched — that remains a separate, explicit human-
authorized step. No signed APK exists yet.

The beta environment decision (reuse `forge-staging` vs. a separate
project) is a **conditional recommendation to reuse `forge-staging`**,
gated on a human confirming its live Edge Function deployment/secrets/
cron state, since this pass has no live Supabase credentials to verify
that directly — the same standing credential gap reported since Items
18-21, not newly introduced here.

**Classification: PARTIALLY VERIFIED (Phase A).** No P0 blocker, no
security regression, full regression green, secret scan clean, no
public deployment occurred. Explicitly **not** "COMPLETE" — this is
Phase A (audit, prepare, document) by the item's own design; actual
distribution requires the human signing key, the beta-environment
confirmation, and explicit Human Launch Approval, none of which this
item is authorized to supply or grant itself.

**Update — first real Android device test found a critical startup
crash, now fixed:** the second signed build (run `33261115870`) passed
every static verification the CI workflow performs, was downloaded,
checksum-verified, and installed on a real Android device — the first
time any build from this project ran on real hardware. It launched,
then immediately crashed to a "No route for '/splash'." screen. Full
trace confirmed via the installed `go_router` package's own source
(not speculation): `/splash` was correctly registered all along: the
real cause was `assertAuthRepositoryConfigIsSafe`/
`assertBackendModeConfigIsSafe` (Items 18-19 production-safety guards)
correctly refusing to let a *release* build run against the *mock*
backend — a rule written before this item's own intentional,
zero-cost, mock-only public beta existed as a legitimate exception to
it. The router's own `errorBuilder` compounded the misdiagnosis risk by
always claiming "No route for '<uri>'" regardless of the real thrown
error, hiding the true cause behind what looked exactly like a missing
route. Fixed on both counts (see
[docs/FREE_BETA_RELEASE.md](FREE_BETA_RELEASE.md) and
[docs/ANDROID_BETA_DEVICE_TEST.md](ANDROID_BETA_DEVICE_TEST.md) for the
full writeup): both guards now accept an explicit
`AppConfig.isPublicBetaBuild` flag
(`--dart-define=CAN_PUBLIC_BETA=true`, wired into the signed-build
workflow, not a secret), and the router's `errorBuilder` now surfaces
the real error instead of a generic message. Version bumped to
`1.0.0-beta.2+6` since build 5 never ran successfully on a real device.
Delivered via PR into `develop`, not merged by this pass. **A new
signed APK has not been built or dispatched yet — real-device retest is
required once one is.**

## Next

Item 22 Phase B (the actual signed build, GitHub Release, and any
deployment) requires, in order: the human signing key ([docs/ANDROID_BETA_SIGNING_SETUP.md](ANDROID_BETA_SIGNING_SETUP.md)),
human confirmation of `forge-staging`'s live readiness (or a decision
to provision a separate beta project) per
[docs/FREE_BETA_RELEASE.md](FREE_BETA_RELEASE.md)'s "Beta environment
decision," and explicit Human Launch Approval for the specific set of
public actions listed in this item's own final report. None of these
are started. Also still open from Item 20's own gate document: closing
each NO-GO condition in
[docs/PRODUCTION_GO_NO_GO.md](PRODUCTION_GO_NO_GO.md) once the
corresponding human/business input exists (real store screenshots — the
CAN icon itself is now integrated, see Item 21 — a hosted Privacy
Policy, a Play Store developer account, if a Play Store listing is ever
pursued alongside the free-beta path); implementing real account
deletion per the design in
[docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md) once the
anonymize-vs-cascade decision is made; a chosen retention policy per
[docs/DATA_RETENTION_DECISIONS.md](DATA_RETENTION_DECISIONS.md); and
genuine Android real-device (or cloud device farm) and Windows
launched-and-interacted-with verification, now with a ready checklist
in [docs/ANDROID_BETA_DEVICE_TEST.md](ANDROID_BETA_DEVICE_TEST.md).

## Further Out

Named as future direction, not committed scope or timelines:

- Real AI-generated character dialogue, replacing the current mock
  scripts.
- Remote push notifications (FCM/APNs/web push) and OS delivery for
  server-authoritative notification types — Item 17 shipped OS-level
  local notifications for the three client-owned reminder types only.
- Optional re-engagement notifications (Item 15's type H).
- Real account deletion, once a backend deletion flow exists (Item 16
  intentionally left the existing honest placeholder in place rather than
  implementing destructive deletion without a security review; Item 18
  enumerated the affected tables and the cascade-vs-anonymize design
  question that still needs deciding).
- Theme (light/dark) and locale/i18n support, if ever prioritized —
  neither exists today, so Item 16's Settings screen has nothing to
  surface for them yet.
- A device-reboot-surviving reschedule path for Mission Follow-up
  (requires a native Android boot receiver the current plugin doesn't
  provide out of the box).
- A real crash-reporting SaaS (Crashlytics/Sentry) — Item 18 added only
  a console-logging crash boundary, deliberately not a paid service.
- Monetization.
- Production deployment (only after Item 13 is complete and reviewed).
- iOS/macOS/Linux platform targets (only Android, Web, and Windows exist
  today).

This list will be revised as priorities change — nothing here is a
promise of order or delivery date.
