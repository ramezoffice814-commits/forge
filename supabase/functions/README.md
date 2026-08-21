# Forge Edge Functions (Phase 10C + Phase 11)

```
supabase/functions/
  _shared/                shared infrastructure — no business logic
    cors.ts                preflight + CORS headers
    auth.ts                 JWT extraction/verification, per-request client
    request.ts               JSON body parsing, field requirement helpers, request hashing
    validation.ts             reward-authority field rejection (spec section 3)
    progress.ts                progress payload shape/bounds validation (spec section 10)
    errors.ts                   stable machine-readable error codes (spec section 21)
    *_test.ts                    Deno unit tests for the modules above
  accept-mission/index.ts        user-facing — caller's own JWT
  start-mission/index.ts         user-facing — caller's own JWT
  record-progress/index.ts       user-facing — caller's own JWT
  submit-mission/index.ts        user-facing — caller's own JWT
  cancel-mission/index.ts        user-facing — caller's own JWT
  assign-daily-mission/index.ts  user-facing — caller's own JWT (Phase 11)
  finalize-week/index.ts         SERVER-ONLY — service-role + shared-secret gate (Phase 11)
  finalize-season/index.ts       SERVER-ONLY — service-role + shared-secret gate (Phase 11)
```

## What each function does (and doesn't)

Every **user-facing** function is a thin wrapper: authenticate the caller
with their own JWT, validate the request shape, call exactly one `forge_*`
RPC, map the result or error, return. None of them contain reward
calculation, ownership checks, sequence/idempotency logic, completion
validation, or (as of Phase 11) mission-eligibility logic — that all lives
in the database, in one atomic PL/pgSQL function call per command, so the
transaction boundary is real rather than something this TypeScript layer
has to fake across several separate queries.

The two **server-only** functions (`finalize-week`, `finalize-season`) are
a different shape entirely: they use the **service-role key**, read only
from the function's own runtime environment (`SUPABASE_SERVICE_ROLE_KEY`
— never sent to, or readable by, the Flutter app), plus a second,
independent gate — a shared secret (`FORGE_CRON_SECRET`) compared against
an `X-Cron-Secret` request header. Until that secret is actually configured
as a real environment variable, both functions reject every request
unconditionally; no production cron credential is configured in this
repo (spec section 14: "do not configure production cron credentials
yet"). This is in addition to, not instead of, the underlying
`forge_finalize_season_week`/`forge_finalize_season` SQL functions having
**zero grants to `authenticated` at all** — a normal user's own JWT could
never call the RPC directly regardless of this wrapper existing.

## Authentication

`_shared/auth.ts` builds a Supabase client using the **anon key** plus the
caller's own `Authorization` header, forwarded as-is. Every RPC call made
with that client runs with `auth.uid()` resolving to the same authenticated
user — there is no service-role key anywhere in `_shared/`, and no
user-facing function ever reads one. The acting user for every command
comes from `auth.uid()` *inside* the database function, never from a
request field.

## Cron readiness (spec section 15) — documented, not configured

Intended future Supabase Cron schedule, once `FORGE_CRON_SECRET` and
`SUPABASE_SERVICE_ROLE_KEY` are actually set for these two functions in a
real project:

- **Weekly finalization**: shortly after each `competition_weeks.ends_at`
  boundary — e.g. a Cron job running hourly that queries for any week
  whose `ends_at` has just passed and hasn't been finalized yet, then
  calls `finalize-week` with that `(seasonId, weekNumber)`. All boundary
  comparisons use the database's own UTC clock (`competition_weeks.
  ends_at` is `timestamptz`) — never a client/phone clock.
- **Season finalization**: after the *final* week of a season has been
  finalized — e.g. triggered by the same job noticing `week_number =
  competition_seasons.week_count` was just finalized, then calling
  `finalize-season` for that season. `forge_finalize_season` itself
  already rejects an incomplete season, so an early/duplicate trigger is
  safe by construction, not just by scheduling care.

No actual Supabase Cron configuration, secret, or credential is added by
this repo — only the two Edge Functions the schedule would eventually
call.

## Deploying

```bash
npx supabase functions deploy accept-mission
npx supabase functions deploy start-mission
npx supabase functions deploy record-progress
npx supabase functions deploy submit-mission
npx supabase functions deploy cancel-mission
npx supabase functions deploy assign-daily-mission
npx supabase functions deploy finalize-week
npx supabase functions deploy finalize-season
```

Not deployed in this session — see the Phase 10C/10D/11 final reports
for why (Docker/Supabase CLI environment blockers).

## Testing

```bash
deno test supabase/functions/_shared/
```

Not run in this session — the Deno CLI is not installed in this
environment. Genuinely written, never executed; see the final reports.
