-- Phase 10C: reward-calculation correctness for a fully deterministic,
-- brand-new-user scenario, plus the privacy assertions from spec
-- section 24 ("internal integrity details not returned", "raw SQL
-- errors not returned").
--
-- Deterministic scenario: a brand-new user's very first mission
-- completion, using the seeded 'fitness-10min-stretch' definition
-- (category=fitness, difficulty=easy, base_xp_hint=12). With zero
-- history, XpCalculationPolicy's formula collapses to:
--   difficultyMultiplier(easy)=1.0, categoryMultiplier(0 prior)=1.0
--   subtotal = round(12 * 1.0 * 1.0) = 12
--   consistencyBonus=0 (streak=0), recoveryBonus=0, diminishing=1.0
--   finalXp = 12 (well under both the 100/mission and 300/day caps)
-- See forge_calculate_xp_reward in supabase/migrations/
-- 20260817090100_mission_reward_functions.sql — this test pins that
-- exact formula's output, not just "some positive number".

begin;

do $$
declare
  user_a uuid := '99999999-9999-9999-9999-999999999993';
  def_id uuid;
  instance_a uuid;
  result jsonb;
  ledger_amount integer;
  progression_xp bigint;
  progression_level integer;
  caught boolean;
begin
  -- postgres, not service_role: only postgres has direct auth.users
  -- grants + Bypass RLS on this local image (see 002's comment).
  set local role postgres;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values (
    user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'user-k@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  perform public.forge_accept_mission('cmd-a', 'key-a', instance_a, 1, 'hash-a');
  perform public.forge_start_mission('cmd-b', 'key-b', instance_a, 2, 'hash-b');
  select public.forge_submit_mission(
    'cmd-c', 'key-c', instance_a, 3, 'hash-c', 'binary', '{"completed": true}'::jsonb
  ) into result;

  -- (1) Server calculates XP — pinned to the exact deterministic value.
  if (result ->> 'confirmedXpReward')::integer <> 12 then
    raise exception 'FAIL: expected confirmedXpReward=12 for this deterministic scenario, got %',
      result ->> 'confirmedXpReward';
  end if;

  select amount into ledger_amount from public.xp_ledger where mission_instance_id = instance_a;
  if ledger_amount <> 12 then
    raise exception 'FAIL: expected xp_ledger.amount=12, got %', ledger_amount;
  end if;
  raise notice 'PASS: server-calculated XP matches the deterministic formula exactly (12)';

  -- (2) Server calculates progression.
  select confirmed_xp, level into progression_xp, progression_level
  from public.user_progression where user_id = user_a;
  if progression_xp <> 12 or progression_level <> 1 then
    raise exception 'FAIL: expected user_progression (confirmed_xp=12, level=1), got (%, %)',
      progression_xp, progression_level;
  end if;
  if (result -> 'progressionUpdate' ->> 'confirmedTotalXp')::bigint <> 12 then
    raise exception 'FAIL: response progressionUpdate.confirmedTotalXp did not match the ledger';
  end if;
  raise notice 'PASS: server-calculated progression matches (confirmed_xp=12, level=1)';

  -- (3) Achievement unlock: 'first_mission' (missions_completed: 1) must
  -- unlock on this very first completion, recorded via the RPC response
  -- and via user_achievements — never self-awarded by the client. Uses
  -- the canonical stable_key (spec section 6 /
  -- 20260820090100_achievement_canonical_ids.sql) — 'first-steps' was
  -- the old Phase 10B placeholder key, since renamed.
  if not (result -> 'achievementUpdates' @> '"first_mission"') then
    raise exception 'FAIL: expected achievementUpdates to include "first_mission", got %',
      result -> 'achievementUpdates';
  end if;
  if not exists (
    select 1 from public.user_achievements ua
    join public.achievement_definitions ad on ad.id = ua.achievement_id
    where ua.user_id = user_a and ad.stable_key = 'first_mission'
  ) then
    raise exception 'FAIL: "first_mission" was reported unlocked but no user_achievements row exists';
  end if;
  raise notice 'PASS: server-evaluated achievement unlock recorded correctly';

  -- (4) Server calculates competitive score — a season/week is
  -- configured by seed.sql, so this deterministic scenario (first
  -- completion in its category this week) should produce a positive,
  -- capped competition_score_ledger entry.
  if not exists (
    select 1 from public.competition_score_ledger where mission_instance_id = instance_a and amount > 0
  ) then
    raise exception 'FAIL: expected a positive competition_score_ledger row for this completion';
  end if;
  if (result ->> 'competitionScoreUpdate')::numeric <= 0 then
    raise exception 'FAIL: expected a positive competitionScoreUpdate in the response';
  end if;
  raise notice 'PASS: server-calculated competitive score is positive and ledgered separately from XP';

  -- (5) Privacy: internal integrity signal details are never returned
  -- to the client — only the neutral clean/warning/excluded state.
  if result ? 'integritySignals' or result ? 'signals' then
    raise exception 'FAIL: response leaked raw integrity signal detail';
  end if;
  if (result ->> 'integrityStatus') not in ('clean', 'warning', 'excluded') then
    raise exception 'FAIL: unexpected integrityStatus value: %', result ->> 'integrityStatus';
  end if;
  raise notice 'PASS: only a neutral integrityStatus is exposed, never internal signal detail';

  -- (6) Privacy: raw SQL errors are never returned — a completion
  -- attempt against a nonexistent mission raises the stable
  -- mission_not_found code, not a raw constraint/lookup error string.
  caught := false;
  begin
    perform public.forge_submit_mission(
      'cmd-ghost', 'key-ghost', '00000000-0000-0000-0000-000000000000', 1, 'hash-ghost',
      'binary', '{"completed": true}'::jsonb
    );
  exception
    when others then
      if sqlerrm like 'mission_not_found|%' then
        caught := true;
      else
        raise exception 'FAIL: a raw/unexpected error surfaced instead of a stable error code: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: submitting against a nonexistent mission did not raise mission_not_found';
  end if;
  raise notice 'PASS: an invalid submission raises a stable error code, never a raw SQL error';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 010_reward_calculation_and_privacy.sql'; end $$;

rollback;
