# Backup & Recovery

No backup/disaster-recovery documentation existed anywhere in this
repository before Roadmap Item 18. This is the honest current state —
what's actually backed up today, what isn't, and what a real incident
response would require — not a claim that a tested recovery procedure
exists.

## What backs up the database today

**Nothing app-level.** Forge has never had a production Supabase
project — `forge-staging` is the only deployed environment (see
[docs/ROADMAP.md](ROADMAP.md) Item 13), and no automated backup job,
export script, or scheduled dump exists in this repository for it.

Supabase itself provides automated backups on paid-tier projects
(daily backups on Pro, point-in-time recovery on higher tiers) — this
is a platform capability the *account/project settings* control, not
something this codebase configures or can verify from here. Whether
`forge-staging` (or a future production project) has this enabled is a
Supabase dashboard setting, orthogonal to anything in this repo.
**Confirm and document the actual tier/backup setting for whichever
project is live before treating this as covered** — this file
deliberately does not assume it.

## What actually reconstructs a database

**The migrations themselves.** `supabase/migrations/` (28 files as of
this writing — Roadmap Item 19 re-verified the count and the clean-reset
result, no new migration added this pass) is the full, ordered,
deterministic schema history — verified via `npx supabase db reset`
against a clean local Postgres: every migration applies from zero
without error, followed by `supabase/seed.sql`. This means:

- A fresh Postgres instance can always be brought to the current
  *schema* via `supabase db reset` (or `supabase db push` against a
  real project) — structure recovery is solid.
- **This does NOT recover data.** Migrations create empty tables;
  actual rows (user accounts, mission history, XP ledgers, competition
  results) exist only in whatever Supabase-managed backup (or lack of
  one) the live project has. Losing the database without a working
  platform-level backup means losing all real data — the migrations
  are a schema recovery mechanism, not a data one.

## Rollback

**Migrations are forward-only.** No migration in this repository
contains a down/rollback script, and none of them are designed to be
reversible in place — the one destructive-looking statement in the
whole set (`alter table public.audit_log drop constraint
audit_log_action_check` in `20260817090000_mission_reward_columns.sql`)
is immediately followed by a `add constraint` recreating it with the
new definition, not a rollback path.

If a migration needs to be undone against a live project, the only
correct approach today is:
1. Write a **new, forward migration** that reverses the specific change
   (e.g. `alter table ... drop column x` if a bad migration added
   column `x`) — never edit or delete an already-applied migration
   file.
2. Verify the new migration against a fresh `supabase db reset` locally
   first, exactly like any other change (see
   [supabase/tests/README.md](../supabase/tests/README.md)).
3. Run the full SQL test suite (`bash supabase/tests/run_all.sh` or
   `supabase/tests/verify_backend.sh`) before applying it anywhere real.

There is no tooling in this repo to auto-generate a reverse migration —
this is a manual, reviewed process every time.

## Verification tooling that already exists

- `supabase/tests/verify_backend.sh` — one command that resets the
  local database from zero, applies every migration + seed, runs all
  17 SQL security/behavior test scripts, and runs the Deno
  shared-module tests. This is the closest thing to a "does the schema
  still reconstruct correctly" check that exists today, and it's
  exactly what Item 18 ran to verify the two new performance indexes
  didn't break anything (see
  [docs/RELEASE_READINESS.md](RELEASE_READINESS.md)).
- `supabase/tests/run_all.sh` — just the SQL scripts, if Deno isn't
  available.

Neither of these tests actual data recovery (restoring a real backup
file) — only schema/migration correctness and RLS/authority behavior.

## Local (on-device) data — a different, much smaller concern

Everything Forge stores locally (`flutter_secure_storage`-backed:
session tokens, onboarding-completion flag, per-user AI privacy
choice, per-user/per-day local reminder dedup state, the AI Coach
response cache) is disposable by design — every one of these is either
a cache, a session artifact, or reconstructible from a fresh sign-in.
Losing local storage (app uninstall, device reset) never loses data
that doesn't also exist authoritatively server-side (for anything
server-backed) or is meant to be genuinely ephemeral (for anything
client-owned, like a local reminder's "already shown today" flag).
**No local-data backup story is needed** — this is a deliberate
architectural property (see the client/server trust boundary in
[docs/ARCHITECTURE.md](ARCHITECTURE.md)), not a gap.

## Known gaps (stated, not fixed by this document)

- No real backup verification has ever been performed against
  `forge-staging` or any Supabase project this codebase talks to —
  this document describes the *mechanism* available (Supabase's own
  tiered backups), not a confirmed, tested restore.
- No data-export/anonymized-dump tooling exists for offline analysis
  or a manual backup outside Supabase's own platform mechanism.
- No documented RTO/RPO (recovery time/point objective) exists — Forge
  has never been in production, so none has been needed yet. This
  should be defined before any real production launch, not invented
  speculatively here.
- Destructive restore testing against real (even staging) data was
  explicitly out of scope for this pass — Item 18's own instructions
  required using only isolated, disposable data for any such test, and
  none was performed.
