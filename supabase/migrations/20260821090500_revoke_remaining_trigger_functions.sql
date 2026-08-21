-- Roadmap Item 13: closes the last gap from 20260821090400 — that
-- migration revoked forge_set_updated_at / forge_guard_mission_sequence
-- / forge_guard_mission_event_ownership from PUBLIC only, the same
-- single-step mistake later caught and fixed for handle_new_user in
-- 20260821090300. Confirmed via information_schema.routine_privileges
-- that anon/authenticated still held separate, PUBLIC-independent
-- EXECUTE grants on these three exactly as with every other function in
-- this project — revoking from the specific roles is required in
-- addition to revoking from PUBLIC, not instead of it.

revoke execute on function public.forge_set_updated_at() from anon, authenticated;
revoke execute on function public.forge_guard_mission_sequence() from anon, authenticated;
revoke execute on function public.forge_guard_mission_event_ownership() from anon, authenticated;
