-- Roadmap Item 13C: infrastructure for staging week/season finalization
-- schedules. Enables pg_cron (job scheduling) and pg_net (async HTTP, so
-- a scheduled job can call the finalize-week/finalize-season Edge
-- Functions the same way any other HTTP caller would) — both ship with
-- every Supabase project but are not installed by default.
--
-- The actual cron.schedule(...) calls that reference these are
-- deliberately NOT in this migration, or in any committed file: they
-- embed FORGE_CRON_SECRET in the scheduled job's own command text (this
-- is the standard, Supabase-documented pattern for authenticating a
-- pg_cron-triggered HTTP call — cron.job is only readable by database
-- admins, the same trust level as the Postgres role that can already
-- read table data directly). Scheduling itself is done via execute_sql,
-- once, outside version control — see docs/ROADMAP.md's Item 13C entry
-- for the exact schedule/command/rollback method.
create extension if not exists pg_cron;
create extension if not exists pg_net;
