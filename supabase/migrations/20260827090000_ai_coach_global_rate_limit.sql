-- Roadmap Item 14C: prerequisite for wiring a real, free-tier AI provider
-- into the ai-coach Edge Function. rate_limiter.ts's own header comment
-- already documents why this is needed: its existing per-user/per-minute
-- limiter is an in-memory, per-warm-isolate counter — it does not
-- coordinate across concurrently warm instances and cannot enforce a
-- global daily cap. A free-tier provider account has an account-wide
-- daily/monthly request quota shared across every user of this app; once
-- a real provider is wired, only a persistent, cross-instance counter can
-- prevent that shared quota from being silently exceeded (which would
-- degrade or block the feature for everyone, not just one user).
--
-- This table/function is deliberately separate from the existing
-- per-user rate_limiter.ts logic, not a replacement for it — both layers
-- apply. The per-user limiter still catches a single abusive client
-- cheaply and fast; this one is the backstop that protects the shared
-- account-wide quota regardless of how many distinct users are involved.

create table public.ai_coach_daily_usage (
  usage_date date primary key,
  request_count integer not null default 0
);

comment on table public.ai_coach_daily_usage is
  'One row per calendar day: a single global counter of real (non-mock) '
  'AI Coach provider calls, used to enforce a shared free-tier daily '
  'quota across every user. Never client-readable or client-writable — '
  'only forge_check_and_increment_ai_coach_global_usage() touches it.';

-- CRITICAL: `revoke all` explicitly from anon/authenticated, not just
-- public — confirmed elsewhere in this project (see
-- 20260825120000_notifications.sql's own comment) that a real hosted
-- Supabase project grants baseline table privileges to anon/authenticated
-- outside this repo's migrations via ALTER DEFAULT PRIVILEGES, so a
-- revoke from public alone would not actually close this off.
revoke all on public.ai_coach_daily_usage from public, anon, authenticated;

-- =======================================================================
-- forge_check_and_increment_ai_coach_global_usage — atomically increments
-- today's counter and reports whether the request that triggered the
-- increment is still within the caller-supplied daily cap. A rejected
-- request's own increment is immediately rolled back, so refused calls
-- never consume quota.
--
-- SECURITY DEFINER, and — same reasoning as forge_create_notification in
-- 20260825120000_notifications.sql — never granted to authenticated at
-- all. Only the ai-coach Edge Function's own service-role client calls
-- this; a client-callable version of this RPC would let any authenticated
-- user burn through the shared daily quota on demand.
-- =======================================================================

create or replace function public.forge_check_and_increment_ai_coach_global_usage(
  p_daily_cap integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  insert into public.ai_coach_daily_usage (usage_date, request_count)
  values (current_date, 1)
  on conflict (usage_date) do update
    set request_count = public.ai_coach_daily_usage.request_count + 1
  returning request_count into v_count;

  if v_count > p_daily_cap then
    update public.ai_coach_daily_usage
      set request_count = request_count - 1
      where usage_date = current_date;
    return false;
  end if;

  return true;
end;
$$;

comment on function public.forge_check_and_increment_ai_coach_global_usage(integer) is
  'SECURITY DEFINER, server-only (see revoke below). Atomically '
  'increments today''s global AI Coach usage counter and returns whether '
  'the caller may proceed — false means the daily cap is already '
  'reached, and this call''s own increment has been rolled back so it '
  'costs no quota.';

-- Same ALTER DEFAULT PRIVILEGES caveat as every other server-only
-- function in this project (see 20260821090200_revoke_server_only_
-- functions.sql, 20260825120000_notifications.sql) — `from public` alone
-- is not sufficient on a real hosted project.
revoke all on function public.forge_check_and_increment_ai_coach_global_usage(integer)
  from public, anon, authenticated;
