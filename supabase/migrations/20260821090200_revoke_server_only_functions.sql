-- Roadmap Item 13: CRITICAL security fix — found by Supabase's security
-- advisor (`get_advisors`) after the first real staging deployment, then
-- confirmed directly against information_schema.routine_privileges.
--
-- ROOT CAUSE: a real hosted Supabase project runs `ALTER DEFAULT
-- PRIVILEGES ... GRANT EXECUTE ON FUNCTIONS TO anon, authenticated,
-- service_role;` as part of its own platform bootstrap (outside this
-- repo's migrations), so every newly CREATEd function automatically
-- receives EXECUTE for anon/authenticated/service_role at creation
-- time. `revoke all on function X from public;` — used throughout this
-- project's migrations — only revokes the separate PUBLIC pseudo-role
-- grant; it does NOT touch these already-established, role-specific
-- default-privilege grants. This was invisible during purely local
-- development because the local CLI's Postgres image does not
-- reproduce that platform bootstrap (see Roadmap Item 12's own baseline
-- grants migration for the mirror-image version of this same lesson).
--
-- IMPACT: forge_finalize_season_week, forge_finalize_season, and
-- forge_build_weekly_groups — every migration's own comment already
-- states these are meant to be server-only, callable by nobody but a
-- trusted service-role context — were actually callable by ANY signed-
-- in user, and even by the unauthenticated `anon` role, via
-- /rest/v1/rpc/<function_name>. A malicious or merely curious client
-- could force week/season finalization, rewrite rankings, or trigger
-- promotion/demotion at will. Confirmed via
-- information_schema.routine_privileges before this fix, and confirmed
-- gone after it (see the Roadmap Item 13 final report for the exact
-- verification).
--
-- FIX: revoke EXECUTE from the specific roles, not just PUBLIC — this
-- is the only way to remove a grant that came from ALTER DEFAULT
-- PRIVILEGES rather than an explicit `grant ... to public`.
--
-- handle_new_user / handle_new_user_progression are also tightened for
-- the same reason, even though calling either directly via RPC (outside
-- an actual trigger-firing context) would fail with a Postgres runtime
-- error regardless — trigger functions were never meant to be part of
-- the public RPC surface at all, and leaving them technically callable
-- is unnecessary exposure with zero upside.

revoke execute on function public.forge_finalize_season_week(uuid, integer) from anon, authenticated;
revoke execute on function public.forge_finalize_season(uuid) from anon, authenticated;
revoke execute on function public.forge_build_weekly_groups(uuid, integer) from anon, authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated;
revoke execute on function public.handle_new_user_progression() from anon, authenticated;
