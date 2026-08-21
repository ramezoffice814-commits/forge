# Forge RLS/security test scripts

Plain SQL, not pgTAP — no extra extension or `supabase test db` project
setup required, only a running local Postgres (`supabase start`). Each
script is self-contained: it creates its own two throwaway auth users,
runs its assertions, and **rolls back** at the end, so running any (or
all) of them leaves the database exactly as it found it.

## How to run

```bash
supabase start
supabase db reset   # applies every migration + seed.sql fresh

# then, for each script:
psql "$(supabase status -o json | node -pe 'JSON.parse(require("fs").readFileSync(0)).DB_URL')" \
  -v ON_ERROR_STOP=1 -f supabase/tests/002_rls_ownership.sql
```

Or, simpler, using the connection string `supabase start` prints
directly (defaults to `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
for the local stack):

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -v ON_ERROR_STOP=1 -f supabase/tests/002_rls_ownership.sql
```

Run them **in order** — later scripts assume nothing from earlier ones
(each is independent), but the numbering reflects the order they were
designed/reviewed in. Or run `bash supabase/tests/run_all.sh` to run
every script in sequence.

Scripts 002-006 are Phase 10B (schema/RLS-level: ownership, no-client-
authority-writes, integrity/audit lockdown, duplicate prevention via
unique constraints, public-safe reads). Scripts 007-010 are Phase 10C
(the `forge_*` command RPCs in `20260817090100_mission_reward_
functions.sql`: auth/authority boundary, transition/sequence
rejection, idempotency/duplicate-command handling, and reward-
calculation correctness + privacy). Scripts 011-012 are Phase 10D (the
`forge_finalize_season_week`/`forge_finalize_season` functions in
`20260819090000_season_finalization.sql`: deterministic ranking, tie-
breaking, rookie protection, promotion/demotion, best-N-of-M season
aggregation, idempotent re-run, the public leaderboard views' column
safety, and that neither finalization function is callable by a normal
authenticated user). Scripts 013-015 are Phase 11: `forge_assign_daily_
mission` (013 — one authoritative daily assignment, idempotent repeat,
invalid-mission rejection, server-derived date, RLS isolation, no
duplicate daily mission even via the fallback path), achievement
canonical IDs (014 — all 12 canonical stable_keys present exactly once,
server unlock maps cleanly to a client-matching id, duplicate unlock
impossible, no client self-award path), and weekly grouping (015 — max
25-member groups, exactly one group membership per user per week,
deterministic rebuild, rookie-first ordering, no sensitive columns on
the public group-standings view).

Run `bash supabase/tests/verify_backend.sh` to execute every script
002-015 (plus migrations/seed/Deno tests) in one pass, once Docker/Deno
are available in this environment — see that script's own header for
exactly what it does and does not attempt.

## How the simulation works

Supabase's `auth.uid()` reads the `request.jwt.claims` Postgres GUC
(normally set per-request by PostgREST from a real JWT). To simulate
"acting as user X" from plain SQL without a real login, every script
does:

```sql
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"<user-uuid>","role":"authenticated"}';
```

This is the same technique Supabase's own documentation recommends for
local RLS testing. `set local role service_role` (no JWT claim needed —
`service_role` bypasses RLS entirely by Supabase design) is used to set
up throwaway rows a test needs to already exist before probing another
role's access.

## Pass/fail convention

Each assertion either:
- succeeds silently (a `raise notice` marks it), or
- raises an exception with a clear message identifying exactly which
  invariant failed.

A script that runs to completion and prints `ALL ASSERTIONS PASSED` for
every block passed. Any `ERROR:` output means a real regression.
