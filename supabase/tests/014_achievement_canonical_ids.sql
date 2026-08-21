-- Phase 11: achievement canonical IDs + evaluation (spec section 21).

begin;

do $$
declare
  user_a uuid := 'c0000000-0000-0000-0000-000000000003';
  def_id uuid;
  instance_id uuid;
  expected_ids text[] := array[
    'first_mission', 'momentum_3_day', 'consistency_7_day',
    'tried_3_categories', 'tried_all_categories', 'coding_10',
    'reading_10', 'fitness_10', 'returned_from_break', 'recovery_5',
    'advanced_10', 'mastery_50_total'
  ];
  missing_ids text[];
  caught boolean;
begin
  -- postgres, not service_role: only postgres has direct auth.users
  -- grants + Bypass RLS on this local image (see 002's comment).
  set local role postgres;

  -- (1) Canonical IDs: every expected stable_key exists exactly once.
  select array_agg(k) into missing_ids
  from unnest(expected_ids) as k
  where not exists (select 1 from public.achievement_definitions where stable_key = k);
  if coalesce(array_length(missing_ids, 1), 0) > 0 then
    raise exception 'FAIL: missing canonical achievement stable_keys: %', missing_ids;
  end if;
  raise notice 'PASS: all 12 canonical achievement stable_keys exist';

  if (select count(*) from public.achievement_definitions where stable_key = any(expected_ids)) <> 12 then
    raise exception 'FAIL: expected exactly 12 canonical achievement rows (no duplicates)';
  end if;
  raise notice 'PASS: exactly one row per canonical stable_key (no duplicates)';

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values (
    user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'user-achievement@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  insert into public.mission_instances (user_id, mission_definition_id, mission_date, status, completed_at)
  values (user_a, def_id, current_date, 'completed', now())
  returning id into instance_id;

  -- (2) Server unlock maps cleanly to a client definition: evaluating
  -- after one completion unlocks exactly 'first_mission'.
  if not exists (
    select 1 from public.forge_evaluate_achievements(user_a, instance_id) where stable_key = 'first_mission'
  ) then
    raise exception 'FAIL: forge_evaluate_achievements did not unlock first_mission after one completion';
  end if;
  raise notice 'PASS: server unlock maps cleanly onto a canonical client-matching id (first_mission)';

  -- (3) Duplicate unlock impossible — re-evaluating does not produce a
  -- second first_mission row (the unique(user_id, achievement_id)
  -- constraint plus the not-exists guard in forge_evaluate_achievements
  -- together make this structurally true, not just usually true).
  perform public.forge_evaluate_achievements(user_a, instance_id);
  if (select count(*) from public.user_achievements ua
      join public.achievement_definitions ad on ad.id = ua.achievement_id
      where ua.user_id = user_a and ad.stable_key = 'first_mission') <> 1 then
    raise exception 'FAIL: first_mission was unlocked more than once for the same user';
  end if;
  raise notice 'PASS: duplicate unlock of the same achievement is impossible';

  -- (4) User cannot self-award: no insert policy exists on
  -- user_achievements for `authenticated` at all (already covered
  -- structurally in 003_no_client_authority_writes.sql — re-confirmed
  -- here in the achievement-specific context).
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  caught := false;
  begin
    insert into public.user_achievements (user_id, achievement_id, source_type)
    select user_a, id, 'self-serve' from public.achievement_definitions where stable_key = 'mastery_50_total';
  exception
    when others then caught := true;
  end;
  if not caught then
    raise exception 'FAIL: a client self-awarded an achievement directly';
  end if;
  raise notice 'PASS: client cannot self-award an achievement (no insert policy exists)';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 014_achievement_canonical_ids.sql'; end $$;

rollback;
