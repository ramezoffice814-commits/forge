-- Phase 11: forge_assign_daily_mission (spec section 20).

begin;

do $$
declare
  user_a uuid := 'c0000000-0000-0000-0000-000000000001';
  user_b uuid := 'c0000000-0000-0000-0000-000000000002';
  user_c uuid := 'c0000000-0000-0000-0000-000000000003';
  def_fitness uuid;
  def_reading uuid;
  result_1 jsonb;
  result_2 jsonb;
  instance_count integer;
  caught boolean;
begin
  -- postgres, not service_role: only postgres has direct auth.users
  -- grants + Bypass RLS on this local image (see 002's comment).
  set local role postgres;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  )
  select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    u.id::text || '@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  from unnest(array[user_a, user_b, user_c]) as u(id);

  select id into def_fitness from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  select id into def_reading from public.mission_definitions where stable_key = 'reading-15min-book';

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- (1) One authoritative daily assignment, with a client-proposed mission.
  select public.forge_assign_daily_mission('cmd-1', 'key-1', 'hash-1', def_fitness, null) into result_1;
  if (result_1 ->> 'status') <> 'accepted' or (result_1 ->> 'missionDefinitionId') <> def_fitness::text then
    raise exception 'FAIL: initial assignment did not accept the requested mission';
  end if;
  raise notice 'PASS: a valid, active, client-proposed mission is assigned';

  -- (2) Repeated assignment returns the same valid instance (not a new
  -- command_id/idempotency_key this time — a genuinely new request for
  -- "assign me today's mission again").
  select public.forge_assign_daily_mission('cmd-2', 'key-2', 'hash-2', def_reading, null) into result_2;
  if (result_2 ->> 'missionInstanceId') <> (result_1 ->> 'missionInstanceId') then
    raise exception 'FAIL: a second assignment request for the same day created a different instance';
  end if;
  select count(*) into instance_count from public.mission_instances where user_id = user_a and mission_date = current_date;
  if instance_count <> 1 then
    raise exception 'FAIL: expected exactly 1 mission_instances row for today, found %', instance_count;
  end if;
  raise notice 'PASS: repeated assignment returns the existing valid instance, no duplicate daily mission';

  -- (3) An invalid (nonexistent) mission definition is rejected. Must
  -- run as a user with NO existing assignment for today: the "already
  -- assigned" fast path above (found existing instance -> return it)
  -- runs before any validation of a *new* request's mission id, by
  -- design — the server never swaps a day's mission based on a later
  -- request, valid or not. Testing this against user_a (who already
  -- has today's assignment from steps 1-2) would never reach the
  -- validation at all, so user_c — untouched so far — is used instead.
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_c::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_c::text, true);

  caught := false;
  begin
    perform public.forge_assign_daily_mission('cmd-3', 'key-3', 'hash-3', '00000000-0000-0000-0000-000000000000', null);
  exception
    when others then
      if sqlerrm like 'invalid_mission_selection|%' then caught := true; else raise; end if;
  end;
  if not caught then
    raise exception 'FAIL: a nonexistent mission definition was accepted';
  end if;
  raise notice 'PASS: an invalid mission selection is rejected (invalid_mission_selection)';

  -- Switch back to user_a for the remaining assertions below.
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- (4) Server time determines the assignment date — assigned_date in
  -- the response always matches the server's own current_date, never a
  -- client-suppliable value (there is no such parameter at all).
  if (result_1 ->> 'assignedDate')::date <> current_date then
    raise exception 'FAIL: assignedDate did not match the server''s own current_date';
  end if;
  raise notice 'PASS: assignment date is server-derived (no client-suppliable date parameter exists)';

  -- (5) A different user cannot read User A's private assignment.
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_b::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_b::text, true);

  if exists (
    select 1 from public.mission_instances where id = (result_1 ->> 'missionInstanceId')::uuid
  ) then
    raise exception 'FAIL: User B can read User A''s private mission_instances row';
  end if;
  raise notice 'PASS: a different user cannot read another user''s assignment (RLS)';

  -- (6) auth.uid() alone determines ownership — there is no user-id
  -- parameter on forge_assign_daily_mission at all for a client to
  -- misuse, so "assign a mission to another user" is not just rejected,
  -- it is not expressible. Confirm User B's own assignment is owned by
  -- User B, not User A, when called as User B.
  select public.forge_assign_daily_mission('cmd-4', 'key-4', 'hash-4', null, null) into result_2;
  if not exists (
    select 1 from public.mission_instances
    where id = (result_2 ->> 'missionInstanceId')::uuid and user_id = user_b
  ) then
    raise exception 'FAIL: User B''s assignment was not owned by User B';
  end if;
  raise notice 'PASS: assignment is always owned by auth.uid() — no client-suppliable user id exists to misuse';

  -- (7) The deterministic fallback (no requested mission) still
  -- prevents a duplicate active daily mission for User B on retry.
  select public.forge_assign_daily_mission('cmd-5', 'key-5', 'hash-5', null, null) into result_2;
  select count(*) into instance_count from public.mission_instances where user_id = user_b and mission_date = current_date;
  if instance_count <> 1 then
    raise exception 'FAIL: duplicate active daily mission was created for User B (found %)', instance_count;
  end if;
  raise notice 'PASS: duplicate active daily mission prevented even via the deterministic fallback path';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 013_mission_assignment.sql'; end $$;

rollback;
