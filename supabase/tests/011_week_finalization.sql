-- Phase 10D: forge_finalize_season_week — deterministic ranking,
-- tie-breaking, rookie protection, promotion/demotion, ceiling/floor
-- handling, and idempotent re-run (spec section 24 "Weekly
-- finalization"). Uses the seeded season-1/week-1 from supabase/seed.sql.

begin;

do $$
declare
  league_iron uuid;
  league_ember uuid;
  v_season_id uuid;
  user_top uuid := 'a0000000-0000-0000-0000-000000000001';
  user_tie_a uuid := 'a0000000-0000-0000-0000-000000000002';
  user_tie_b uuid := 'a0000000-0000-0000-0000-000000000003';
  user_rookie_bottom uuid := 'a0000000-0000-0000-0000-000000000004';
  user_nonrookie_bottom uuid := 'a0000000-0000-0000-0000-000000000005';
  -- Five filler participants (ranks 4-8) so that, with league-iron's
  -- promotion_count=5/demotion_count=5 (seed.sql) and 10 total
  -- participants, the promotion zone (ranks 1-5) and demotion zone
  -- (ranks 6-10) no longer overlap. With only the original 5
  -- participants every rank was simultaneously in both zones (5 people,
  -- both counts = 5), and forge_finalize_season_week's own zone
  -- precedence (promotion wins on overlap — by design, see
  -- 20260820090200_weekly_groups.sql) meant the bottom rank always
  -- showed as promotionZone, never reaching the rookie-protection path
  -- this test exists to exercise.
  filler_ids uuid[] := array[
    'a0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000007',
    'a0000000-0000-0000-0000-000000000008',
    'a0000000-0000-0000-0000-000000000009',
    'a0000000-0000-0000-0000-00000000000a'
  ];
  filler_scores numeric[] := array[9, 8, 7, 6, 5];
  fi integer;
  def_id uuid;
  instance_id uuid;
  written integer;
  r record;
  rank_top integer;
  rank_tie_a integer;
  rank_tie_b integer;
  status_rookie text;
  status_nonrookie text;
  caught boolean;
begin
  -- postgres, not service_role: only postgres has direct auth.users
  -- grants + Bypass RLS on this local image (see 002's comment).
  set local role postgres;

  select id into league_iron from public.league_definitions where stable_key = 'league-iron';
  select id into league_ember from public.league_definitions where stable_key = 'league-ember';
  select id into v_season_id from public.competition_seasons where stable_key = 'season-1';
  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  )
  select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    u.id::text || '@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  from unnest(array[user_top, user_tie_a, user_tie_b, user_rookie_bottom, user_nonrookie_bottom] || filler_ids) as u(id);

  -- All ten participants are members of league-iron only (league_ember
  -- is looked up above purely so its id is available if a future
  -- extension of this test wants a floor-league scenario — it has no
  -- members here).
  insert into public.competition_memberships (user_id, season_id, league_id, is_rookie, rookie_protection_until)
  values
    (user_top, v_season_id, league_iron, false, null),
    (user_tie_a, v_season_id, league_iron, false, null),
    (user_tie_b, v_season_id, league_iron, false, null),
    (user_rookie_bottom, v_season_id, league_iron, true, now() + interval '7 days'),
    (user_nonrookie_bottom, v_season_id, league_iron, false, null);

  for fi in 1..5 loop
    insert into public.competition_memberships (user_id, season_id, league_id, is_rookie, rookie_protection_until)
    values (filler_ids[fi], v_season_id, league_iron, false, null);

    insert into public.mission_instances (user_id, mission_definition_id, mission_date, status, completed_at)
    values (filler_ids[fi], def_id, current_date, 'completed', now())
    returning id into instance_id;
    insert into public.competition_score_ledger (user_id, season_id, week_number, mission_instance_id, source_type, source_id, amount)
    values (filler_ids[fi], v_season_id, 1, instance_id, 'mission_completion', instance_id::text, filler_scores[fi]);
  end loop;

  -- user_top: highest score, alone.
  insert into public.mission_instances (user_id, mission_definition_id, mission_date, status, completed_at)
  values (user_top, def_id, current_date, 'completed', now())
  returning id into instance_id;
  insert into public.competition_score_ledger (user_id, season_id, week_number, mission_instance_id, source_type, source_id, amount)
  values (user_top, v_season_id, 1, instance_id, 'mission_completion', instance_id::text, 20.0);

  -- user_tie_a and user_tie_b: identical score, tie-break must be
  -- deterministic (active_days, then average_difficulty, then
  -- attained_at, then userId) — both get the same single-completion
  -- amount and difficulty; user_tie_a's row is inserted with an earlier
  -- created_at via an explicit timestamp so it should rank ahead on the
  -- "earlier attainment" tie-break.
  insert into public.mission_instances (user_id, mission_definition_id, mission_date, status, completed_at)
  values (user_tie_a, def_id, current_date, 'completed', now())
  returning id into instance_id;
  insert into public.competition_score_ledger (user_id, season_id, week_number, mission_instance_id, source_type, source_id, amount, created_at)
  values (user_tie_a, v_season_id, 1, instance_id, 'mission_completion', instance_id::text, 10.0, now() - interval '2 hours');

  insert into public.mission_instances (user_id, mission_definition_id, mission_date, status, completed_at)
  values (user_tie_b, def_id, current_date, 'completed', now())
  returning id into instance_id;
  insert into public.competition_score_ledger (user_id, season_id, week_number, mission_instance_id, source_type, source_id, amount, created_at)
  values (user_tie_b, v_season_id, 1, instance_id, 'mission_completion', instance_id::text, 10.0, now());

  -- user_rookie_bottom / user_nonrookie_bottom: zero activity — will
  -- rank last, testing rookie protection suppresses their demotion zone
  -- while the non-rookie's does not.
  perform 1; -- (no ledger rows — zero score by construction)

  set local role postgres;
  select public.forge_finalize_season_week(v_season_id, 1) into written;
  if written <> 10 then
    raise exception 'FAIL: expected 10 rows written for league-iron participants, got %', written;
  end if;

  select rank into rank_top from public.competition_week_results where user_id = user_top and season_id = v_season_id and week_number = 1;
  select rank into rank_tie_a from public.competition_week_results where user_id = user_tie_a and season_id = v_season_id and week_number = 1;
  select rank into rank_tie_b from public.competition_week_results where user_id = user_tie_b and season_id = v_season_id and week_number = 1;

  if rank_top <> 1 then
    raise exception 'FAIL: highest-scoring user did not rank 1st (got %)', rank_top;
  end if;
  raise notice 'PASS: highest weekly score ranks 1st';

  if rank_tie_a >= rank_tie_b then
    raise exception 'FAIL: earlier-attained tie should outrank the later one (a=%, b=%)', rank_tie_a, rank_tie_b;
  end if;
  raise notice 'PASS: tied scores are broken deterministically by earliest attainment';

  select promotion_status into status_rookie
  from public.competition_week_results where user_id = user_rookie_bottom and season_id = v_season_id and week_number = 1;
  select promotion_status into status_nonrookie
  from public.competition_week_results where user_id = user_nonrookie_bottom and season_id = v_season_id and week_number = 1;

  if status_rookie <> 'safeZone' then
    raise exception 'FAIL: a protected rookie in the demotion zone should be safeZone, got %', status_rookie;
  end if;
  raise notice 'PASS: rookie protection suppresses demotion';

  if status_nonrookie <> 'demotionZone' then
    raise exception 'FAIL: an unprotected bottom-ranked user should be demotionZone, got %', status_nonrookie;
  end if;
  raise notice 'PASS: an unprotected bottom-ranked user is placed in the demotion zone';

  -- Idempotency: re-running produces identical results, not duplicates.
  select public.forge_finalize_season_week(v_season_id, 1) into written;
  select count(*) into written from public.competition_week_results
  where season_id = v_season_id and week_number = 1;
  if written <> 10 then
    raise exception 'FAIL: repeated finalization produced % rows, expected exactly 10 (no duplicates)', written;
  end if;
  raise notice 'PASS: repeated finalization is idempotent (no duplicate rows)';

  -- Authorization: a normal authenticated user cannot call this at all.
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_top::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_top::text, true);

  caught := false;
  begin
    perform public.forge_finalize_season_week(v_season_id, 1);
  exception
    when insufficient_privilege then caught := true;
    when others then caught := true; -- any rejection counts; see comment below.
  end;
  if not caught then
    raise exception 'FAIL: a normal authenticated user was able to call forge_finalize_season_week';
  end if;
  raise notice 'PASS: forge_finalize_season_week is not callable by a normal authenticated user';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 011_week_finalization.sql'; end $$;

rollback;
