-- Roadmap Item 13: search_path hardening (spec section 27 "Security
-- Pass") — found by Supabase's own security advisor after the first
-- real staging deployment (`get_advisors(type: security)`), a tool this
-- project never had access to during purely-local development.
--
-- None of the 21 functions below are directly callable by `authenticated`
-- or `anon` (all revoked-from-public in their own migrations; only
-- called internally by the properly-search_path-pinned command
-- entrypoints), so this is defense-in-depth rather than a fix for an
-- exploitable path today — but pinning search_path on every function
-- uniformly, not just the ones with an external attack surface, removes
-- the entire risk class rather than relying on "this one happens to be
-- unreachable directly."
--
-- ALTER FUNCTION ... SET search_path is additive metadata — it does not
-- redefine any function body, so this migration touches no logic at
-- all, only closes this one hardening gap.

alter function public.forge_lock_owned_mission(uuid, uuid) set search_path = public;
alter function public.forge_check_idempotency_and_sequence(public.mission_instances, text, text, integer, text) set search_path = public;
alter function public.forge_record_processed_command(uuid, text, uuid, text, text, text, jsonb, integer) set search_path = public;
alter function public.forge_append_event(uuid, uuid, text, text, text, jsonb, timestamptz) set search_path = public;
alter function public.forge_set_updated_at() set search_path = public;
alter function public.forge_guard_mission_sequence() set search_path = public;
alter function public.forge_guard_mission_event_ownership() set search_path = public;
alter function public.forge_xp_required_for_level(integer) set search_path = public;
alter function public.forge_level_for_xp(bigint) set search_path = public;
alter function public.forge_category_tier_multiplier(integer) set search_path = public;
alter function public.forge_evaluate_achievements(uuid, uuid) set search_path = public;
alter function public.forge_calculate_xp_reward(text, boolean, integer, integer, integer, integer, integer) set search_path = public;
alter function public.forge_current_streak_days(uuid, timestamptz, uuid) set search_path = public;
alter function public.forge_validate_completion(text, jsonb) set search_path = public;
alter function public.forge_current_competition_week(timestamptz) set search_path = public;
alter function public.forge_diversity_factor(integer) set search_path = public;
alter function public.forge_evaluate_integrity(uuid, timestamptz, timestamptz, integer, integer, uuid) set search_path = public;
alter function public.forge_calculate_competition_score(text, boolean, text, numeric, integer, text) set search_path = public;
alter function public.forge_raise(text, text) set search_path = public;
alter function public.forge_difficulty_weight(text) set search_path = public;
alter function public.forge_pick_fallback_mission(uuid, date, text) set search_path = public;

-- =======================================================================
-- Reviewed, NOT changed: "Security Definer View" (ERROR-level advisory)
-- on competition_public_season_leaderboard / _weekly_leaderboard /
-- _group_standings.
--
-- These views deliberately run with their CREATING role's privileges
-- (Postgres's pre-security_invoker default for views), not the
-- querying user's — see 20260819090000_season_finalization.sql's own
-- comment: "Views run with their creating role's privileges by default
-- in Postgres ... which is exactly what lets a narrow,
-- explicitly-column-limited view safely read across users from
-- otherwise own-row-only tables." Switching these to
-- `security_invoker = true` (the fix the advisor suggests) would make
-- each view run as the querying `authenticated` user, who only has
-- row-level access to their OWN season_results/competition_week_
-- results/profiles rows under RLS — the view would then return zero
-- rows for anyone else, breaking the entire public-leaderboard feature
-- these views exist for. The safety here comes from the narrow,
-- explicit, audited column list each view selects (no email, no
-- integrity/recovery data, no private mission history — see each
-- view's own comment), not from view-level RLS enforcement. Consciously
-- accepted, not an oversight.
--
-- Also reviewed, NOT changed: "RLS Enabled No Policy" (INFO-level) on
-- processed_commands / integrity_events / audit_log. This is the
-- deliberate design from Phase 10B/10C — see each table's own migration
-- comment ("No policies created for `authenticated` — every operation
-- denies by default... adding a permissive policy here would be the
-- mistake, not omitting one"). Working as intended.
