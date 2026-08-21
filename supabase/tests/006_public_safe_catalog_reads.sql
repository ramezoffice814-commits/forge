-- Catalog tables (mission_definitions, achievement_definitions,
-- league_definitions, competition_seasons, competition_weeks) remain
-- readable to any authenticated client — this is intentional, public-safe
-- reference data, and a lockdown regression here would break the app.
-- Covers: "public-safe competition/profile data remains readable where
-- intended."

begin;

do $$
declare
  user_a uuid := '66666666-6666-6666-6666-666666666666';
  readable_count integer;
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
    'user-f@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  select count(*) into readable_count from public.mission_definitions where active;
  if readable_count = 0 then
    raise exception 'FAIL: client cannot read any active mission_definitions '
      '(did you run supabase/seed.sql?)';
  end if;
  raise notice 'PASS: client can read active mission_definitions (% rows)', readable_count;

  select count(*) into readable_count from public.achievement_definitions where active;
  if readable_count = 0 then
    raise exception 'FAIL: client cannot read any active achievement_definitions';
  end if;
  raise notice 'PASS: client can read active achievement_definitions (% rows)', readable_count;

  select count(*) into readable_count from public.league_definitions where active;
  if readable_count = 0 then
    raise exception 'FAIL: client cannot read any active league_definitions';
  end if;
  raise notice 'PASS: client can read active league_definitions (% rows)', readable_count;

  select count(*) into readable_count from public.competition_seasons;
  if readable_count = 0 then
    raise exception 'FAIL: client cannot read competition_seasons';
  end if;
  raise notice 'PASS: client can read competition_seasons (% rows)', readable_count;

  select count(*) into readable_count from public.competition_weeks;
  if readable_count = 0 then
    raise exception 'FAIL: client cannot read competition_weeks';
  end if;
  raise notice 'PASS: client can read competition_weeks (% rows)', readable_count;

  -- Their own profile and progression rows must also be readable (this
  -- overlaps 002/003 slightly but is worth asserting here too, since
  -- this file is specifically "what should still work").
  if (select display_name from public.profiles where user_id = user_a) is null then
    raise exception 'FAIL: client cannot read their own bootstrapped profile';
  end if;
  raise notice 'PASS: client can read their own profile';

  if not exists (select 1 from public.user_progression where user_id = user_a) then
    raise exception 'FAIL: client cannot read their own bootstrapped progression row';
  end if;
  raise notice 'PASS: client can read their own progression row';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 006_public_safe_catalog_reads.sql'; end $$;

rollback;
