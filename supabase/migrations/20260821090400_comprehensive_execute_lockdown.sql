-- Roadmap Item 13: comprehensive follow-up to 20260821090200/090300.
--
-- The direct information_schema.routine_privileges sweep after those
-- two migrations showed the platform default-privilege gap was not
-- limited to the three server-only finalize/group functions — it
-- affects every function in this schema. Every internal helper this
-- project's own migration comments describe as "not directly callable
-- by `authenticated`... leaving helpers open would let a client bypass
-- the ownership/idempotency/validation wrapper entirely" was, in fact,
-- callable by both `anon` and `authenticated` on this real hosted
-- project the whole time.
--
-- Actual exploitability was limited for most of these: they are
-- SECURITY INVOKER (not SECURITY DEFINER), so a direct call still runs
-- under the caller's own RLS/table-grant restrictions rather than any
-- elevated privilege — e.g. forge_lock_owned_mission's `select ... for
-- update` on mission_instances still only sees the caller's own rows
-- under RLS even when called directly, and forge_evaluate_achievements'
-- insert into user_achievements would itself be denied since
-- `authenticated` has no insert grant on that table. But "the exploit
-- doesn't work today because of a second, independent control" is not
-- the same as "correctly locked down," and every one of these was
-- always meant to be unreachable directly per this project's own
-- documented intent. Fixed for real, not just in comments.
--
-- Also narrows the six legitimate command entrypoints to
-- `authenticated` only — `anon` never needed EXECUTE on these (each
-- function's own `auth.uid() is null` check already rejected an
-- unauthenticated caller, so this was not exploitable, but there is no
-- reason for anon to hold the grant at all).

-- Internal helpers: never callable directly by anyone but the
-- SECURITY DEFINER command functions that invoke them internally.
revoke execute on function public.forge_append_event(uuid, uuid, text, text, text, jsonb, timestamptz) from anon, authenticated;
revoke execute on function public.forge_calculate_competition_score(text, boolean, text, numeric, integer, text) from anon, authenticated;
revoke execute on function public.forge_calculate_xp_reward(text, boolean, integer, integer, integer, integer, integer) from anon, authenticated;
revoke execute on function public.forge_category_tier_multiplier(integer) from anon, authenticated;
revoke execute on function public.forge_check_idempotency_and_sequence(public.mission_instances, text, text, integer, text) from anon, authenticated;
revoke execute on function public.forge_current_competition_week(timestamptz) from anon, authenticated;
revoke execute on function public.forge_current_streak_days(uuid, timestamptz, uuid) from anon, authenticated;
revoke execute on function public.forge_difficulty_weight(text) from anon, authenticated;
revoke execute on function public.forge_diversity_factor(integer) from anon, authenticated;
revoke execute on function public.forge_evaluate_achievements(uuid, uuid) from anon, authenticated;
revoke execute on function public.forge_evaluate_integrity(uuid, timestamptz, timestamptz, integer, integer, uuid) from anon, authenticated;
revoke execute on function public.forge_level_for_xp(bigint) from anon, authenticated;
revoke execute on function public.forge_lock_owned_mission(uuid, uuid) from anon, authenticated;
revoke execute on function public.forge_pick_fallback_mission(uuid, date, text) from anon, authenticated;
revoke execute on function public.forge_raise(text, text) from anon, authenticated;
revoke execute on function public.forge_record_processed_command(uuid, text, uuid, text, text, text, jsonb, integer) from anon, authenticated;
revoke execute on function public.forge_validate_completion(text, jsonb) from anon, authenticated;
revoke execute on function public.forge_xp_required_for_level(integer) from anon, authenticated;

-- Trigger functions: also still had a residual PUBLIC grant (same
-- pattern as handle_new_user*/handle_new_user_progression in 090300 —
-- these are among the earliest, Phase 10B migrations, predating the
-- revoke-then-grant discipline every later migration follows).
revoke execute on function public.forge_set_updated_at() from public;
revoke execute on function public.forge_guard_mission_sequence() from public;
revoke execute on function public.forge_guard_mission_event_ownership() from public;

-- The six legitimate command entrypoints: authenticated keeps EXECUTE
-- (unchanged — this is the real, intended API surface); anon does not
-- need it at all.
revoke execute on function public.forge_accept_mission(text, text, uuid, integer, text) from anon;
revoke execute on function public.forge_start_mission(text, text, uuid, integer, text) from anon;
revoke execute on function public.forge_record_mission_progress(text, text, uuid, integer, text, text, jsonb) from anon;
revoke execute on function public.forge_cancel_mission(text, text, uuid, integer, text, text) from anon;
revoke execute on function public.forge_submit_mission(text, text, uuid, integer, text, text, jsonb) from anon;
revoke execute on function public.forge_assign_daily_mission(text, text, text, uuid, text) from anon;
