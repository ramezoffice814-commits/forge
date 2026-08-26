-- System-wide privilege hardening audit, prompted by two critical bugs
-- found and fixed for the Item 15 notifications tables (feature/
-- notifications-retention-loop, PR #7): forge_create_notification was
-- callable directly by anon/authenticated via RPC, and notifications/
-- notification_preferences had full CRUD open to both roles despite
-- the migration's own narrower `grant` statements.
--
-- FINDING: every table created before Item 15 has the exact same root
-- cause. A real hosted Supabase project's platform bootstrap grants
-- full CRUD (SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER)
-- to anon AND authenticated on every table via ALTER DEFAULT
-- PRIVILEGES, outside this repo's migrations.
-- 20260821090000_baseline_authenticated_grants.sql already documented
-- the *intended* grant for every one of these tables, but — because it
-- only ever ran additive `grant X` statements, never `revoke all`
-- first — none of those intentions were ever actually enforced on a
-- real hosted project. Confirmed directly against forge-staging via
-- information_schema.role_table_grants: every single pre-Item-15 table
-- had full CRUD open to both anon and authenticated.
--
-- Confirmed empirically exploitable: as an authenticated user,
-- `update public.mission_instances set status = 'completed'` on an
-- owned row succeeded, bypassing forge_submit_mission's validation/
-- XP/achievement pipeline entirely. Confirmed NOT exploitable for
-- processed_commands/integrity_events/audit_log specifically (RLS
-- default-denies with no matching policy at all for those three), and
-- for xp_ledger/user_progression/user_achievements/season_results/
-- competition_score_ledger specifically for non-SELECT commands (only
-- a SELECT policy exists on each, so INSERT/UPDATE/DELETE were already
-- RLS-blocked despite the broad grant) — but all of these still had
-- the unnecessary broad grant sitting underneath RLS as pure
-- unnecessary attack surface, which this migration removes regardless
-- of whether RLS happened to be the last line of defense.
--
-- ADDITIONAL FINDING: mission_instances/mission_events specifically.
-- A repo-wide search (`grep ".from('...')"` across lib/) proves the
-- Flutter client NEVER reads or writes either table directly — every
-- mission command goes through Edge Functions (accept-mission/start-
-- mission/record-progress/submit-mission/cancel-mission — see
-- lib/core/backend/supabase_backend_client.dart), which call the
-- SECURITY DEFINER forge_* SQL functions server-side; those functions
-- derive auth.uid() and re-validate ownership/sequence/business rules
-- entirely independently of the caller's own table grants (confirmed
-- empirically: the full accept -> start -> submit flow still works
-- perfectly as authenticated with zero table grant on either table,
-- since SECURITY DEFINER functions use the function owner's
-- privileges for their internal statements, not the caller's). The
-- mission_instances_insert_own/_update_own and
-- mission_events_insert_own RLS policies (from
-- 20260816120300_mission_instances.sql / 20260816120400_mission_
-- events.sql) are dead code from an earlier, superseded direct-write
-- architecture. These two tables are hardened to fully server-only —
-- zero grant to anon/authenticated — matching processed_commands/
-- integrity_events/audit_log's existing tier, rather than merely
-- narrowed to the originally-intended select/insert/update.
--
-- NOT touched: the forge_* command functions' own EXECUTE grants to
-- authenticated (forge_accept_mission, forge_submit_mission, etc.) —
-- these are intentional, pre-existing, already-flagged-and-accepted
-- advisor warnings. Each function re-derives auth.uid() and performs
-- its own full ownership/business validation regardless of caller, so
-- direct RPC access (bypassing the Edge Function layer) reaches the
-- exact same validated, safe outcome — this is not the same class of
-- issue as forge_create_notification, which has zero validation of
-- its own and must never be reachable by a client under any
-- circumstance.
--
-- FIX: revoke all from anon, authenticated on every table below, then
-- re-grant exactly the documented intent from
-- 20260821090000_baseline_authenticated_grants.sql — except
-- mission_instances/mission_events, which get no grant at all per the
-- finding above. notifications/notification_preferences (already
-- hardened in the Item 15 migration) and the two leaderboard views
-- genuinely read directly by SupabaseLeaderboardRepository are the
-- only tables newly SELECT-granted here for a real, verified reason.
--
-- Applied and verified directly against forge-staging before this
-- migration was written: every confirmed exploit re-attempted and
-- denied after the fix; the real mission accept -> start -> submit
-- flow re-verified working end to end; get_advisors back to the exact
-- pre-existing baseline (one previously-flagged security_definer_view
-- finding for the now-fully-locked-down competition_public_group_
-- standings view even disappeared as a side effect).

revoke all on public.profiles from anon, authenticated;
grant select, update on public.profiles to authenticated;

revoke all on public.mission_definitions from anon, authenticated;
grant select on public.mission_definitions to authenticated;

-- Confirmed server-only: no direct client read/write anywhere in
-- lib/ — see this migration's header finding.
revoke all on public.mission_instances from anon, authenticated;
revoke all on public.mission_events from anon, authenticated;

revoke all on public.user_progression from anon, authenticated;
grant select on public.user_progression to authenticated;

revoke all on public.xp_ledger from anon, authenticated;
grant select on public.xp_ledger to authenticated;

revoke all on public.competition_seasons from anon, authenticated;
grant select on public.competition_seasons to authenticated;

revoke all on public.competition_weeks from anon, authenticated;
grant select on public.competition_weeks to authenticated;

revoke all on public.league_definitions from anon, authenticated;
grant select on public.league_definitions to authenticated;

revoke all on public.competition_memberships from anon, authenticated;
grant select on public.competition_memberships to authenticated;

revoke all on public.competition_score_ledger from anon, authenticated;
grant select on public.competition_score_ledger to authenticated;

revoke all on public.season_results from anon, authenticated;
grant select on public.season_results to authenticated;

revoke all on public.achievement_definitions from anon, authenticated;
grant select on public.achievement_definitions to authenticated;

revoke all on public.user_achievements from anon, authenticated;
grant select on public.user_achievements to authenticated;

revoke all on public.competition_week_results from anon, authenticated;
grant select on public.competition_week_results to authenticated;

revoke all on public.competition_groups from anon, authenticated;
grant select on public.competition_groups to authenticated;

revoke all on public.competition_group_members from anon, authenticated;
grant select on public.competition_group_members to authenticated;

-- Deliberately no grant at all — matches 20260821090000's own
-- intentional exclusion (server/SECURITY-DEFINER-only tables). RLS
-- already default-denies these with no matching policy; this removes
-- the unnecessary grant sitting underneath that defense regardless.
revoke all on public.processed_commands from anon, authenticated;
revoke all on public.integrity_events from anon, authenticated;
revoke all on public.audit_log from anon, authenticated;

-- The two public leaderboard views are genuinely read directly by the
-- client (SupabaseLeaderboardRepository) — SELECT only, matching their
-- read-only purpose.
revoke all on public.competition_public_weekly_leaderboard from anon, authenticated;
grant select on public.competition_public_weekly_leaderboard to authenticated;

revoke all on public.competition_public_season_leaderboard from anon, authenticated;
grant select on public.competition_public_season_leaderboard to authenticated;

-- Confirmed unused by the client (no reference anywhere in lib/) —
-- server-only for now, matching processed_commands/integrity_events/
-- audit_log's tier rather than guessing at a future SELECT need.
revoke all on public.competition_public_group_standings from anon, authenticated;
