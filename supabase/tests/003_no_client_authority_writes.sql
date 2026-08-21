-- RLS: server-authoritative fields cannot be written by a normal client.
-- Covers: "client cannot insert confirmed XP", "client cannot change
-- level", "client cannot self-award achievement", "client cannot
-- change competition score", "client cannot assign themselves
-- league/rank".

begin;

do $$
declare
  user_a uuid := '33333333-3333-3333-3333-333333333333';
  league_id uuid;
  season_id uuid;
  affected_rows integer;
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
    'user-c@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  select id into league_id from public.league_definitions limit 1;
  select id into season_id from public.competition_seasons limit 1;
  if league_id is null or season_id is null then
    raise exception 'setup failed: seed.sql must be applied first';
  end if;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- xp_ledger: no insert policy at all.
  begin
    insert into public.xp_ledger (user_id, source_type, source_id, amount, reason)
    values (user_a, 'admin_adjustment', 'self-serve', 999999, 'because I said so');
    raise exception 'FAIL: client inserted into xp_ledger';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot insert confirmed XP (%)', sqlstate;
  end;

  -- user_progression: no update policy — and no UPDATE grant at all, so
  -- this is rejected at the permission-check stage, before RLS is even
  -- consulted (a stricter, equally valid form of "cannot write").
  begin
    update public.user_progression set level = 99, confirmed_xp = 999999 where user_id = user_a;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FAIL: client updated their own user_progression row';
    end if;
    raise notice 'PASS: client cannot change their own level/confirmed_xp (0 rows affected)';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot change their own level/confirmed_xp (%)', sqlstate;
  end;

  -- user_achievements: no insert policy at all (self-award).
  begin
    insert into public.user_achievements (user_id, achievement_id, source_type)
    select user_a, id, 'self-serve' from public.achievement_definitions limit 1;
    raise exception 'FAIL: client self-awarded an achievement';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot self-award an achievement (%)', sqlstate;
  end;

  -- competition_score_ledger: no insert policy at all.
  begin
    insert into public.competition_score_ledger
      (user_id, season_id, week_number, source_type, source_id, amount)
    values (user_a, season_id, 1, 'adjustment', 'self-serve', 999999);
    raise exception 'FAIL: client inserted into competition_score_ledger';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot change competition score (%)', sqlstate;
  end;

  -- competition_memberships: no insert policy at all (self-assign league).
  begin
    insert into public.competition_memberships (user_id, season_id, league_id, is_rookie)
    values (user_a, season_id, league_id, false);
    raise exception 'FAIL: client self-assigned a league membership';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot assign themselves a league (%)', sqlstate;
  end;

  -- season_results: no insert policy at all.
  begin
    insert into public.season_results (user_id, season_id, final_league_id, promoted)
    values (user_a, season_id, league_id, true);
    raise exception 'FAIL: client inserted a season_results row';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot write a season result (%)', sqlstate;
  end;

  -- Catalog tables: system-managed, no client write policy at all.
  begin
    update public.league_definitions set promotion_count = 999 where id = league_id;
    get diagnostics affected_rows = row_count;
    if affected_rows <> 0 then
      raise exception 'FAIL: client updated league_definitions';
    end if;
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  raise notice 'PASS: client cannot modify league_definitions';

  begin
    insert into public.mission_definitions
      (stable_key, title, description, category, difficulty, expected_duration_minutes)
    values ('fake-mission', 'Fake', 'Fake', 'fitness', 'easy', 5);
    raise exception 'FAIL: client inserted a mission_definitions row';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot author mission_definitions (%)', sqlstate;
  end;
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 003_no_client_authority_writes.sql'; end $$;

rollback;
