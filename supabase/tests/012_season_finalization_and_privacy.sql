-- Phase 10D: forge_finalize_season — best-N-of-M aggregation, incomplete
-- season rejection, deterministic final result, duplicate finalization
-- safety — plus the public-safe leaderboard views and the authorization
-- check that a normal user cannot call season finalization either
-- (spec section 24 "Season" + "Privacy" + "Authorization").

begin;

do $$
declare
  league_iron uuid;
  league_steel uuid;
  v_season_id uuid;
  incomplete_season_id uuid;
  user_full uuid := 'b0000000-0000-0000-0000-000000000001';
  wk integer;
  scores numeric[] := array[10, 20, 30, 40, 50, 60, 5, 1];
  written integer;
  total numeric;
  counted integer[];
  dropped integer[];
  final_league uuid;
  is_promoted boolean;
  caught boolean;
  leak_check integer;
begin
  -- postgres, not service_role: only postgres has direct auth.users
  -- grants + Bypass RLS on this local image (see 002's comment).
  set local role postgres;

  select id into league_iron from public.league_definitions where stable_key = 'league-iron';
  select id into league_steel from public.league_definitions where stable_key = 'league-steel';
  select id into v_season_id from public.competition_seasons where stable_key = 'season-1';

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values (
    user_full, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    'user-full@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  insert into public.competition_memberships (user_id, season_id, league_id, is_rookie)
  values (user_full, v_season_id, league_iron, false);

  -- Directly seed competition_week_results for all 8 weeks — this test
  -- targets forge_finalize_season's aggregation logic in isolation, not
  -- forge_finalize_season_week's ranking (already covered in
  -- 011_week_finalization.sql). service_role bypasses RLS to do this.
  for wk in 1..8 loop
    insert into public.competition_week_results (
      user_id, season_id, week_number, league_id, rank, weekly_score,
      active_days, average_difficulty, promotion_status, target_league_id
    ) values (
      user_full, v_season_id, wk, league_iron, 1, scores[wk], 3, 1.5,
      case when wk = 8 then 'promotionZone' else 'safeZone' end,
      case when wk = 8 then league_steel else null end
    );
  end loop;

  set local role postgres;

  -- (1) A season with fewer than week_count weeks finalized is rejected.
  insert into public.competition_seasons (stable_key, name, starts_at, ends_at, status, week_count, counted_week_count)
  values ('season-incomplete-test', 'Incomplete Test Season', now() - interval '30 days', now() + interval '30 days', 'active', 8, 6)
  returning id into incomplete_season_id;
  insert into public.competition_week_results (
    user_id, season_id, week_number, league_id, rank, weekly_score, active_days, average_difficulty, promotion_status
  ) values (user_full, incomplete_season_id, 1, league_iron, 1, 10, 1, 1, 'safeZone');
  -- only week 1 of 8 present.

  caught := false;
  begin
    perform public.forge_finalize_season(incomplete_season_id);
  exception
    when others then
      if sqlerrm like '%incomplete%' then caught := true; else raise; end if;
  end;
  if not caught then
    raise exception 'FAIL: an incomplete season (1 of 8 weeks) was finalized instead of rejected';
  end if;
  raise notice 'PASS: an incomplete season is rejected, not finalized';

  -- (2) A fully-finalized season aggregates best-6-of-8 correctly.
  select public.forge_finalize_season(v_season_id) into written;
  if written < 1 then
    raise exception 'FAIL: forge_finalize_season wrote no rows for a complete season';
  end if;

  select total_season_score, counted_weeks, dropped_weeks, final_league_id, promoted
  into total, counted, dropped, final_league, is_promoted
  from public.season_results where user_id = user_full and season_id = v_season_id;

  if total <> 210 then
    raise exception 'FAIL: expected best-6-of-8 total 210 (dropping the two lowest weeks), got %', total;
  end if;
  if not (counted @> array[1,2,3,4,5,6] and array_length(counted, 1) = 6) then
    raise exception 'FAIL: expected counted_weeks {1..6}, got %', counted;
  end if;
  if not (dropped @> array[7,8] and array_length(dropped, 1) = 2) then
    raise exception 'FAIL: expected dropped_weeks {7,8} (the two lowest scores), got %', dropped;
  end if;
  raise notice 'PASS: best-6-of-8 season aggregation matches SeasonScoringPolicy exactly (total=210, dropped the two lowest weeks)';

  if final_league <> league_steel or not is_promoted then
    raise exception 'FAIL: expected final promotion to league-steel, got league=% promoted=%', final_league, is_promoted;
  end if;
  raise notice 'PASS: final league outcome reflects the last week''s promotion zone';

  -- (3) Duplicate finalization is safe (idempotent re-run, same result).
  perform public.forge_finalize_season(v_season_id);
  select count(*) into written from public.season_results where user_id = user_full and season_id = v_season_id;
  if written <> 1 then
    raise exception 'FAIL: repeated season finalization produced % rows for one user, expected exactly 1', written;
  end if;
  raise notice 'PASS: repeated season finalization is idempotent (no duplicate season_results row)';

  -- Roadmap Item 15: the same idempotent re-run must not have
  -- duplicated the season_result notification either.
  select count(*) into written from public.notifications
  where user_id = user_full and type = 'season_result'
    and dedup_key = 'season_result:' || user_full::text || ':' || v_season_id::text;
  if written <> 1 then
    raise exception 'FAIL: expected exactly 1 season_result notification after 2 finalize runs, got %', written;
  end if;
  raise notice 'PASS: repeated season finalization does not duplicate the season_result notification';

  -- (4) Authorization: a normal authenticated user cannot call this.
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_full::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_full::text, true);

  caught := false;
  begin
    perform public.forge_finalize_season(v_season_id);
  exception
    when others then caught := true;
  end;
  if not caught then
    raise exception 'FAIL: a normal authenticated user was able to call forge_finalize_season';
  end if;
  raise notice 'PASS: forge_finalize_season is not callable by a normal authenticated user';

  -- (5) Privacy: the public leaderboard views expose only safe fields
  -- and never leak integrity/private data. A different authenticated
  -- user (not user_full) should still be able to read user_full's
  -- leaderboard row (that's the point of a public leaderboard) but only
  -- ever see the safe columns.
  if not exists (
    select 1 from public.competition_public_season_leaderboard
    where season_id = v_season_id and display_name is not null
  ) then
    raise exception 'FAIL: competition_public_season_leaderboard has no readable row for the finalized season';
  end if;
  raise notice 'PASS: the public season leaderboard exposes the finalized result';

  select count(*) into leak_check
  from information_schema.columns
  where table_schema = 'public'
    and table_name in ('competition_public_season_leaderboard', 'competition_public_weekly_leaderboard')
    and column_name in ('email', 'health_limitations', 'recovery_mission', 'signal_type', 'metadata', 'reflection');
  if leak_check <> 0 then
    raise exception 'FAIL: a leaderboard view exposes a column that looks like private/integrity data';
  end if;
  raise notice 'PASS: leaderboard views expose no private/integrity-shaped columns';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 012_season_finalization_and_privacy.sql'; end $$;

rollback;
