# Public Beta Security Gate

Roadmap Item 22 ("Free Public Beta Launch"). A public beta is
**internet-accessible** — this document treats it as genuinely
adversarial from day one: unknown users, hostile users, scripted abuse,
tampered clients, replay attempts, invalid tokens, excessive requests,
malformed input. "Beta" is a distribution/maturity label, not a trust
level. Nothing here weakens a control to make launch easier.

## Beta vs. production vs. staging — what actually differs

| | Development/staging (today) | Public beta (this item prepares) | Production (not this item) |
|---|---|---|---|
| Audience | Developers only, local/CI | Unknown internet users who opt in | General public via app stores |
| Backend | Local Docker Postgres (CI/tests) or `forge-staging` (manual, credential-gated) | `forge-staging` reused, see "Beta environment decision" below | A dedicated production Supabase project (does not exist — see [docs/RELEASE_CANDIDATE_2.md](RELEASE_CANDIDATE_2.md) "Production Supabase readiness") |
| Signing | Debug-signed | **Release-signed by a human-owned key** (see [docs/ANDROID_BETA_SIGNING_SETUP.md](ANDROID_BETA_SIGNING_SETUP.md)) | Same key, ideally enrolled in Play App Signing |
| Distribution | Not distributed | Signed APK via GitHub Releases; Web/PWA candidate (not yet deployed) | Play Store / App Store |
| Legal content | N/A | Draft, clearly labeled, beta disclaimer required | Must be final, reviewed |
| Abuse assumption | None (trusted operators) | **Full adversarial assumption** | Full adversarial assumption |

## Gate table

| Area | Status | Detail |
|---|---|---|
| Auth | PASS | `SupabaseAuthRepository` always replaces the session wholesale via the SDK (no manual token merge, no session-fixation risk — re-confirmed unchanged across Items 15-21); sign-out cancels every user-scoped local store. |
| RLS | PASS | Re-verified via the SQL regression suite this pass (16/16, including `002_rls_ownership.sql`, `016_least_privilege_hardening.sql`) against a fresh local Postgres reset — every table a client can reach is scoped by `auth.uid()`-based ownership; `mission_instances`/`mission_events` are fully server-only (not even readable by the owning user directly, only via command functions). |
| XP authority | PASS | `003_no_client_authority_writes.sql` — client cannot insert/modify XP, level, or confirmed values under any client role; every reward is computed server-side inside `forge_submit_mission` and friends. |
| Mission authority | PASS | Command functions (`accept-mission`, `start-mission`, `submit-mission`, `cancel-mission`, `record-progress`, `assign-daily-mission`) are the only write path; each validates the caller's JWT and validates input shape before touching anything. |
| Ranking authority | PASS | Competition score/league-movement writes are server-only (`003_no_client_authority_writes.sql` covers this too); `finalize-week`/`finalize-season` are cron-secret-gated, not client-callable. |
| Upload policy | NOT APPLICABLE | No file/image upload feature exists anywhere in the app — no Storage bucket, no upload UI, no upload endpoint. Section 23's checklist has nothing to audit. |
| AI privacy | PASS | AI Coach calls only ever reach `SupabaseAiCoachClient` → the `ai-coach` Edge Function → `mock_provider.ts` (server-side, deterministic, zero-cost) — confirmed no direct client-to-third-party-provider call exists anywhere in `lib/`, and the Edge Function's own code comment states no real provider is configured. `AiPrivacyLevel.disabled` is a real, fully-supported mode. |
| Secret handling | PASS | No service-role key, DB password, or provider secret exists anywhere in `lib/` — confirmed via repeated `gitleaks` scans across Items 18-21, all clean. |
| Web secret exposure | PASS | Everything compiled into a Flutter Web build is public by construction (see "Web security" below) — confirmed nothing beyond the public `SUPABASE_URL`/`SUPABASE_ANON_KEY` (both designed to be public) would ever be baked in, since no other `--dart-define` value is read anywhere in `lib/`. |
| Notification security | PASS | Every notification read/write is scoped by `.eq('user_id', _userId)` client-side, backed by RLS server-side (re-confirmed since Item 18's own audit, unchanged). |
| Rate limits | **PASS WITH LIMITATION** | Only `ai-coach` has an explicit rate limiter (`rate_limiter.ts`, 10 requests/user/task/minute) — and it's honestly documented in its own code as an in-memory, per-warm-isolate counter, not a persistent cross-instance store (acceptable today specifically because the wired provider is the free mock, per its own comment). The 6 command functions have idempotency protection (`processed_commands`) but no explicit requests-per-minute throttle beyond requiring a valid JWT per call — see "Rate/abuse controls" below for the full reasoning. |
| Audit logging | PASS | `integrity_events`/`audit_log` tables exist with a review-status lifecycle (Item 16-era); `logOutcome` on every Edge Function call logs exactly 5 safe fields, no secrets, no request bodies. |
| Error logging | PASS | `installCrashHandlers()` (Item 18) logs only `error.toString()` and a stack trace via `debugPrint`, both developer-console-only — no password/token/PII code path exists into it, re-confirmed this pass by re-reading `crash_handler.dart` and `logCrash()`. |
| Account lifecycle | **PASS WITH LIMITATION** | Sign-up/sign-in/session-restore/sign-out all real and tested; account **deletion** is a deliberate, honest placeholder (`NotSupportedYetFailure`) — see "Account deletion" below for whether this blocks beta launch. |
| Data retention | PASS WITH LIMITATION | No retention policy is enforced (see [docs/DATA_RETENTION_DECISIONS.md](DATA_RETENTION_DECISIONS.md)) — acceptable for a beta of unknown, likely small duration, but real users' data will accumulate with no automatic cleanup; tracked, not fixed here. |
| Legal status | **PASS WITH LIMITATION** | Draft Privacy Policy/Terms exist with a prominent "pending legal review" banner (Item 19) — see "Privacy/legal beta presentation" below for what a public beta specifically requires beyond what already exists. |

**No item is classified BLOCKED.** Two areas (rate limits, account
lifecycle/deletion) carry an explicit, honestly-stated limitation —
neither is silently accepted; both are addressed below with a concrete
beta-scoped decision.

## Public beta data safety (detail)

Every user-controlled table was re-checked against the existing SQL
regression suite rather than re-derived from scratch:

- `profiles`, `notification_preferences`: owner-only read/write, RLS-enforced.
- `mission_instances`, `mission_events`, `processed_commands`: **fully
  server-only** — not even the owning user can read these directly;
  every interaction goes through a command function.
- `xp_ledger`, `user_progression`, `achievements`, `competition_score_ledger`,
  `season_results`, `competition_week_results`: server-write-only,
  client-read scoped to the owner (or, for leaderboard-shaped data,
  scoped to public-safe fields only — see `006_public_safe_catalog_reads.sql`).
- `integrity_events`, `audit_log`: fully server/reviewer-only, no
  client read or write path exists.
- `notifications`: owner-scoped read/write, `.limit(200)` bounded
  (Item 18).

## Auth / new-user flow (Section 7)

Traced the real, non-demo path a new user takes:
first launch → `CanOpeningOverlay` (full sequence, first-time) →
onboarding carousel → sign-up → `MockAuthRepository`/
`SupabaseAuthRepository.signUp()` → session established → Dashboard.
This is the **same path** `auth_onboarding_flow_test.dart` exercises
end-to-end (re-run this pass, still passing). No developer/demo
shortcut exists in this path: `MockAuthRepository`'s seeded
`demo@forge.app`/`forgepass1` account is a **local-mock-mode-only**
convenience (see [docs/CAN_REBRAND_AUDIT.md](CAN_REBRAND_AUDIT.md) —
Category G, never real, never transmitted) — a beta build talking to
real Supabase (`APP_ENV=live`) uses `SupabaseAuthRepository` exclusively,
which has no seeded account and no bypass of any kind. A public beta
user cannot reach the mock demo account unless someone deliberately
ships a mock-mode build, which section "Mock vs. real backend" below
addresses directly.

## Mock vs. real backend — feature readiness matrix (Section 8)

| Feature | Backend today | Beta classification |
|---|---|---|
| Auth (sign up/in/out, session restore) | Real (Supabase Auth) | READY FOR PUBLIC BETA |
| Missions (assign/accept/start/submit/cancel/progress) | Real (Postgres + Edge Functions) | READY FOR PUBLIC BETA |
| XP/progression/levels/titles | Real (server-computed, RLS-enforced) | READY FOR PUBLIC BETA |
| Achievements | Real (server-awarded) | READY FOR PUBLIC BETA |
| Competition/leagues/ranking | Real (server-computed, cron-finalized) | READY FOR PUBLIC BETA |
| Notifications (in-app inbox) | Real (Supabase-backed) | READY FOR PUBLIC BETA |
| OS local notifications (Android/Windows) | Real (device-local scheduling, no server) | READY FOR PUBLIC BETA |
| Settings / accessibility controls | Real (local + Supabase-backed preferences) | READY FOR PUBLIC BETA |
| Daily Transmission (character dialogue) | **Mock** (deterministic scripted content) | DEGRADED BUT SAFE — clearly narrative/character content, not a claim of real AI; no misrepresentation risk |
| AI Coach | **Mock** (deterministic `mock_provider.ts`, zero-cost) | DEGRADED BUT SAFE — already honestly disclosed in the Privacy Policy; not claimed as real AI anywhere in product copy (see [docs/PLAY_STORE_PREP.md](PLAY_STORE_PREP.md)'s draft copy, which deliberately omits AI marketing language for this exact reason) |
| Account deletion | **Placeholder** (`NotSupportedYetFailure`) | See "Account deletion" below |
| File/image upload | Does not exist | NOT APPLICABLE |

No mock-only capability is presented to a user as real — this was the
explicit design discipline established in Item 19's Privacy Policy
draft and re-confirmed unchanged this pass.

## AI Coach beta policy (Section 9)

**Zero-cost, confirmed end-to-end.** No real AI provider is wired
anywhere — client-side or server-side. `AI_PROVIDER`/`OLLAMA_BASE_URL`
dart-defines exist only as unused documentation placeholders in
`.env.example` (grepped: zero references anywhere in `lib/`). The
`ai-coach` Edge Function's own code comment states plainly: "none is
configured yet (mock_provider.ts is the only provider actually wired
this pass)." **No paid provider is inserted by this item.** The mock
AI Coach remains enabled, exactly as it already honestly presents
itself in the Privacy Policy — this is the safe "mock/demo AI clearly
labeled" option Section 9 asks for, already in place, not something
this pass needed to build.

## Rate / abuse controls (detail)

Audited every Edge Function:

- **`ai-coach`**: real per-user-per-task-per-minute limiter (10/min),
  already in place, already honestly documented as in-memory/
  per-isolate. Acceptable for a beta's expected traffic volume; the
  function's own comment already specifies the exact trigger for
  hardening it (before any real, paid provider is ever wired) — not
  reached by this item.
- **`accept-mission`/`start-mission`/`submit-mission`/`cancel-mission`/
  `record-progress`/`assign-daily-mission`**: every call requires a
  valid Supabase Auth JWT (unauthenticated calls are rejected outright)
  and is idempotent (`processed_commands` — a replayed/duplicated
  command is a safe no-op, not a double-effect). There is no explicit
  requests-per-minute cap beyond that. **This is assessed as an
  acceptable beta-scoped posture, not fixed with a new client-invisible
  throttle this pass**: Supabase's own platform provides baseline
  connection/request-volume protections, every call is attributable to
  a real authenticated account (not anonymous), and the actual
  exploitable value of spamming an idempotent, reward-bounded command
  is low (there is no per-call reward to farm — rewards are
  bounded by the mission's own definition, not by call count). Flagged
  here explicitly as a known, accepted limitation rather than silently
  ignored — a persistent, cross-instance rate limiter for these
  functions is real future-item scope if beta traffic ever shows signs
  of abuse.
- **`finalize-week`/`finalize-season`**: not client-callable at all
  (require `FORGE_CRON_SECRET`), so client-side abuse is not a surface
  here.

No fake/client-only rate limit was added — every real limit that
exists lives server-side.

## File / storage safety (Section 23)

**Not applicable.** No file, image, or document upload feature exists
anywhere in this codebase — no Supabase Storage bucket is referenced,
no `image_picker`/`file_picker`-style dependency exists in
`pubspec.yaml`, no upload UI exists in any feature. This section's
checklist (MIME policy, size limits, signed URLs, bucket RLS) has
nothing to audit against; re-confirmed by grep, not assumed.

## Logging / crash safety (detail)

Re-read `lib/core/error/crash_handler.dart` this pass: `logCrash()`
logs `error.toString()` and the stack trace only, via `debugPrint`
(local device console, never transmitted). No paid crash-reporting SaaS
is integrated (unchanged since Item 18's own deliberate choice). Server
side, every Edge Function's `logOutcome` call is hard-coded to exactly
5 fields (`function`/`commandId`/`resultCode`/`durationMs`/`success`) —
no code path exists to log a request body, header, JWT, or the
`x-cron-secret` value those functions read.

## Privacy / legal beta presentation (Section 25)

**No final legal approval exists, and none is claimed here.** For
public beta specifically, three things must be true before real
traffic reaches it, tracked explicitly:

1. The existing "pending legal review" banner (`LegalPageScaffold`,
   Item 19) must remain visible and unmodified — it already is.
2. A beta-specific disclaimer should exist somewhere a user will
   actually see it before creating an account (Section 28) — added
   this pass, see "Beta disclaimer" below.
3. **Human decision required**: whether the current draft Privacy
   Policy/Terms are legally sufficient to let real strangers create
   real accounts against them, even labeled "beta." This document does
   not make that call — it is explicitly a human legal/business
   decision, not an engineering one. Until that decision is made, this
   item's own Beta GO/NO-GO (below) reflects it as a **conditional**
   gate, not a silent pass.

## Account deletion (Section 26)

**Current state unchanged**: `requestAccountDeletion()` throws
`NotSupportedYetFailure` in both repository implementations — no
destructive deletion logic was added or attempted this pass, per this
item's own explicit instruction.

**Assessment**: this is a real, honestly-tracked launch consideration,
not dismissed. Google Play policy would require it before a Play Store
listing goes live — but this item's own distribution path is a signed
APK via GitHub Releases, **not** Play Store, so that specific policy
trigger does not apply to this beta. What *does* still matter
regardless of distribution channel: a real user who wants their data
gone currently has no self-service way to get it. Recommended
resolution for beta specifically (a decision, not an implementation,
per this item's own "design first and report" instruction): either (a)
treat beta as sufficiently small/short that manual deletion-on-request
(a human operator running a one-off, reviewed SQL statement against
`forge-staging` when asked) is an acceptable stopgap, clearly stated in
the beta disclaimer, or (b) block broader beta growth until real
self-service deletion is built per
[docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md). This
document recommends (a) for a small, invite/announcement-scale beta —
**a human product decision, not made unilaterally here.**

## Web security (Section 20)

Everything compiled into a Flutter Web build is public by construction
— treated as such, not defended by obscurity. Confirmed via the same
method already used in Items 20-21's own audits: grepped every
`String.fromEnvironment`/`bool.fromEnvironment` call site in `lib/`
(`AppConfig` is the only reader) — the full set is `APP_ENV`,
`SUPABASE_TARGET`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `AI_PROVIDER`
(unused), `OLLAMA_BASE_URL` (unused). No service-role key, private API
key, signing secret, DB password, or "hidden server secret" is read
anywhere in `lib/` — there is no code path for one to ever be compiled
into a Web bundle. `SUPABASE_URL`/`SUPABASE_ANON_KEY` are the two
values a live/beta Web build would carry, and both are public-by-design
per Supabase's own architecture (access control is RLS, not secrecy of
the anon key) — see [docs/PRODUCTION_CONFIG.md](PRODUCTION_CONFIG.md).

## Supabase public config (Section 21)

Re-confirmed: this codebase's own security model already depends
entirely on RLS + auth + server-side policy, never on hiding the anon
key (`AppConfig`'s own doc comment states this explicitly, unchanged
since it was written). `SUPABASE_SERVICE_ROLE_KEY` and
`FORGE_CRON_SECRET` are read only server-side
(`supabase/functions/finalize-week/index.ts`,
`finalize-season/index.ts`) — confirmed via grep, no client code path
reads either.

## What this document does not do

It does not create a production or beta Supabase project. It does not
implement account deletion. It does not add a persistent cross-instance
rate limiter. It does not grant legal approval. It does not publish,
deploy, or distribute anything.
