-- RLS: cross-user ownership isolation.
-- Covers: "User A cannot read User B private mission data",
-- "User A cannot update User B profile".
--
-- Self-contained: creates two throwaway auth users, asserts, rolls back.

begin;

do $$
declare
  user_a uuid := '11111111-1111-1111-1111-111111111111';
  user_b uuid := '22222222-2222-2222-2222-222222222222';
  def_id uuid;
  instance_a uuid;
  affected_rows integer;
begin
  -- --- setup, as postgres (this local image's Bypass-RLS role with
  -- direct auth.users grants; service_role itself has no such grant
  -- here, only postgres does, and only postgres inherits service_role
  -- — not the reverse — so `set local role service_role` would lose
  -- auth.users access entirely) ------------------------------------
  set local role postgres;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values
    (user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'user-a@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now()),
    (user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'user-b@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now());
  -- The on_auth_user_created / on_auth_user_created_progression triggers
  -- fire automatically here, creating profiles + user_progression rows
  -- for both users — this is itself an implicit proof the bootstrap
  -- triggers work.

  select id into def_id from public.mission_definitions limit 1;
  if def_id is null then
    raise exception 'setup failed: no mission_definitions row to reference '
      '(did you run supabase/seed.sql?)';
  end if;

  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  -- --- act as user_a ----------------------------------------------------
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  if (select display_name from public.profiles where user_id = user_a) is null then
    raise exception 'FAIL: user_a cannot read their own profile';
  end if;
  raise notice 'PASS: user_a can read their own profile';

  if exists (select 1 from public.profiles where user_id = user_b) then
    raise exception 'FAIL: user_a can read user_b''s profile';
  end if;
  raise notice 'PASS: user_a cannot read user_b''s profile';

  update public.profiles set display_name = 'hacked' where user_id = user_b;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FAIL: user_a updated user_b''s profile (% rows)', affected_rows;
  end if;
  raise notice 'PASS: user_a cannot update user_b''s profile';

  -- mission_instances/mission_events are fully server-only as of
  -- 20260826010000_system_wide_least_privilege_hardening.sql — no
  -- direct client access at all, not even to the owner's own row. The
  -- real Flutter client never reads/writes either table directly
  -- (every command goes through the Edge Functions -> SECURITY
  -- DEFINER forge_* functions instead — see that migration's own
  -- header for the full finding), so this is a *stronger* invariant
  -- than the previous "owner-only" isolation this test used to check.
  -- See supabase/tests/016_least_privilege_hardening.sql for the full
  -- exploit-style regression coverage of that finding; this assertion
  -- just confirms the plain owner-read case specifically, in the same
  -- place the old assertion used to live.
  begin
    perform 1 from public.mission_instances where id = instance_a;
    raise exception 'FAIL: user_a could read their own mission_instances row directly '
      '(should be fully server-only now)';
  exception
    when insufficient_privilege then null;
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not ilike '%permission denied%' then raise; end if;
  end;
  raise notice 'PASS: even the owning user cannot read mission_instances directly (fully server-only)';

  -- --- act as user_b ----------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', user_b::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_b::text, true);

  begin
    perform 1 from public.mission_instances where id = instance_a;
    raise exception 'FAIL: user_b can read user_a''s mission_instances row';
  exception
    when insufficient_privilege then null;
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not ilike '%permission denied%' then raise; end if;
  end;
  raise notice 'PASS: user_b cannot read user_a''s private mission data';

  -- Nested block: exception handling scoped to *only* this one risky
  -- statement, so a genuine failure in any earlier assertion above still
  -- propagates as a real error instead of being swallowed here.
  begin
    insert into public.mission_events (
      mission_instance_id, user_id, command_id, idempotency_key, sequence,
      event_type, occurred_at
    ) values (
      instance_a, user_b, 'forged-command', 'forged-key', 1, 'accepted', now()
    );
    raise exception 'FAIL: user_b inserted a mission_events row for user_a''s '
      'mission (should have been rejected)';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then
        raise;
      end if;
      raise notice 'PASS: user_b cannot insert an event against user_a''s mission (%: %)', sqlstate, sqlerrm;
  end;
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 002_rls_ownership.sql'; end $$;

rollback;
