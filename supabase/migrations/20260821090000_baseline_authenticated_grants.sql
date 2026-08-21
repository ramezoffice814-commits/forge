-- Roadmap Item 12: baseline table-level grants for `authenticated` (spec
-- section 6/8 — found only by actually running the SQL test suite
-- against a real local Postgres instance for the first time).
--
-- ROOT CAUSE: Postgres requires a baseline GRANT on a table before RLS
-- policies are even evaluated — a `create policy ... to authenticated`
-- restricts which ROWS are visible, it does not by itself grant any
-- access to the table at all. On a real hosted Supabase project this is
-- invisible because the platform's own bootstrap SQL (run once when a
-- project is created, outside this repo's migrations) already grants
-- broad table access to `anon`/`authenticated`/`service_role` and sets
-- matching `ALTER DEFAULT PRIVILEGES` for future tables. This local CLI
-- stack does not reproduce that bootstrap, so every one of this
-- project's own RLS-protected tables was actually unreadable/unwritable
-- by `authenticated` here — confirmed by running supabase/tests/002
-- through 015 against a real local database for the first time, all of
-- which failed with "permission denied for table X" before this
-- migration existed.
--
-- Every grant below matches — table for table, command for command —
-- an existing `create policy ... to authenticated` in an earlier
-- migration; nothing here grants more than what a policy already
-- expects to gate at the row level. Three RLS-enabled tables are
-- deliberately given NO grant at all, because they have zero policies
-- for `authenticated` by design (server/SECURITY-DEFINER-only):
-- processed_commands, integrity_events, audit_log. Granting them here
-- would silently reopen exactly what spec section 8 requires stay shut
-- ("Normal authenticated users cannot: ... inspect integrity_events...
-- write audit_log").
--
-- No policy in this schema targets `anon` (the app requires sign-in for
-- everything), so nothing is granted to `anon` here either.

grant select, update on public.profiles to authenticated;
grant select on public.mission_definitions to authenticated;
grant select, insert, update on public.mission_instances to authenticated;
grant select, insert on public.mission_events to authenticated;
grant select on public.user_progression to authenticated;
grant select on public.xp_ledger to authenticated;
grant select on public.competition_seasons to authenticated;
grant select on public.competition_weeks to authenticated;
grant select on public.league_definitions to authenticated;
grant select on public.competition_memberships to authenticated;
grant select on public.competition_score_ledger to authenticated;
grant select on public.season_results to authenticated;
grant select on public.achievement_definitions to authenticated;
grant select on public.user_achievements to authenticated;
grant select on public.competition_week_results to authenticated;
grant select on public.competition_groups to authenticated;
grant select on public.competition_group_members to authenticated;
