-- Duplicate/replay prevention — these are database CONSTRAINT
-- invariants, not RLS, and hold regardless of role (tested here mostly
-- as service_role, since processed_commands/xp_ledger have no
-- authenticated-role access at all — see 003).
--
-- Covers: "duplicate mission event sequence rejected", "duplicate
-- command rejected", "duplicate XP source rejected".

begin;

do $$
declare
  user_a uuid := '55555555-5555-5555-5555-555555555555';
  def_id uuid;
  instance_a uuid;
  duplicate_caught boolean;
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
    'user-e@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  select id into def_id from public.mission_definitions limit 1;
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  -- (1) duplicate mission_instance_id + sequence is rejected.
  insert into public.mission_events (
    mission_instance_id, user_id, command_id, idempotency_key, sequence,
    event_type, occurred_at
  ) values (
    instance_a, user_a, 'cmd-1', 'key-1', 1, 'accepted', now()
  );

  duplicate_caught := false;
  begin
    insert into public.mission_events (
      mission_instance_id, user_id, command_id, idempotency_key, sequence,
      event_type, occurred_at
    ) values (
      instance_a, user_a, 'cmd-2', 'key-2', 1, 'started', now()
    );
  exception
    when unique_violation then
      duplicate_caught := true;
  end;
  if not duplicate_caught then
    raise exception 'FAIL: a second event at the same (mission_instance_id, sequence) was accepted';
  end if;
  raise notice 'PASS: duplicate mission_instance_id+sequence is rejected';

  -- (2) duplicate command_id is rejected, even for a different sequence.
  duplicate_caught := false;
  begin
    insert into public.mission_events (
      mission_instance_id, user_id, command_id, idempotency_key, sequence,
      event_type, occurred_at
    ) values (
      instance_a, user_a, 'cmd-1', 'key-3', 2, 'started', now()
    );
  exception
    when unique_violation then
      duplicate_caught := true;
  end;
  if not duplicate_caught then
    raise exception 'FAIL: a second event reusing command_id ''cmd-1'' was accepted';
  end if;
  raise notice 'PASS: duplicate command_id is rejected';

  -- (3) processed_commands: duplicate idempotency_key is rejected.
  insert into public.processed_commands
    (command_id, user_id, idempotency_key, command_type, request_hash, response_payload)
  values ('server-cmd-1', user_a, 'server-key-1', 'submit_mission', 'hash-a', '{}'::jsonb);

  duplicate_caught := false;
  begin
    insert into public.processed_commands
      (command_id, user_id, idempotency_key, command_type, request_hash, response_payload)
    values ('server-cmd-2', user_a, 'server-key-1', 'submit_mission', 'hash-b', '{}'::jsonb);
  exception
    when unique_violation then
      duplicate_caught := true;
  end;
  if not duplicate_caught then
    raise exception 'FAIL: a second processed_commands row reusing an idempotency_key was accepted';
  end if;
  raise notice 'PASS: duplicate idempotency_key in processed_commands is rejected';

  -- (4) xp_ledger: duplicate (source_type, source_id) is rejected —
  -- the mechanism that makes duplicate XP for the same mission
  -- completion structurally impossible.
  insert into public.xp_ledger (user_id, source_type, source_id, amount, reason)
  values (user_a, 'mission_completion', instance_a::text, 20, 'first grant');

  duplicate_caught := false;
  begin
    insert into public.xp_ledger (user_id, source_type, source_id, amount, reason)
    values (user_a, 'mission_completion', instance_a::text, 20, 'duplicate grant attempt');
  exception
    when unique_violation then
      duplicate_caught := true;
  end;
  if not duplicate_caught then
    raise exception 'FAIL: a second xp_ledger row for the same source was accepted';
  end if;
  raise notice 'PASS: duplicate XP source is rejected';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 005_duplicate_prevention.sql'; end $$;

rollback;
