-- Phase 10C: idempotency/replay/duplicate-prevention for the forge_*
-- command RPCs (spec section 24 "Idempotency"), and a documented note
-- on the "Concurrency" scenarios this single-session script cannot
-- exercise directly.

begin;

do $$
declare
  user_a uuid := '99999999-9999-9999-9999-999999999992';
  def_id uuid;
  instance_a uuid;
  caught boolean;
  result_1 jsonb;
  result_2 jsonb;
  ledger_count integer;
  event_count integer;
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
    'user-j@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- (1) A legitimate retry — same idempotency_key, same request_hash —
  -- must return the exact cached result and apply no effects twice.
  select public.forge_accept_mission('cmd-acc', 'key-acc', instance_a, 1, 'hash-acc') into result_1;
  select public.forge_accept_mission('cmd-acc', 'key-acc', instance_a, 1, 'hash-acc') into result_2;
  if result_1 <> result_2 then
    raise exception 'FAIL: an exact retry returned a different result than the original';
  end if;

  select count(*) into event_count from public.mission_events
  where mission_instance_id = instance_a and event_type = 'accepted';
  if event_count <> 1 then
    raise exception 'FAIL: a retried accept produced % accepted events, expected exactly 1', event_count;
  end if;
  raise notice 'PASS: an exact retry (same idempotency key + request hash) returns the cached result and applies no effects twice';

  -- (2) A conflicting replay — same idempotency_key, different
  -- request_hash — must be rejected outright.
  caught := false;
  begin
    perform public.forge_accept_mission('cmd-acc2', 'key-acc', instance_a, 1, 'hash-DIFFERENT');
  exception
    when others then
      if sqlerrm like 'idempotency_conflict|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: a conflicting replay (same key, different payload hash) was accepted'; end if;
  raise notice 'PASS: a conflicting replay is rejected (idempotency_conflict)';

  -- (3) A reused command_id under a different idempotency_key is
  -- rejected as a duplicate command.
  caught := false;
  begin
    perform public.forge_accept_mission('cmd-acc', 'key-DIFFERENT', instance_a, 1, 'hash-acc');
  exception
    when others then
      if sqlerrm like 'duplicate_command|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: a reused command_id under a different idempotency key was accepted'; end if;
  raise notice 'PASS: a reused command_id under a different idempotency key is rejected (duplicate_command)';

  -- (4) Duplicate XP / achievement / competition score is structurally
  -- impossible: complete the mission once, then attempt to submit it
  -- again (a genuinely new command/key this time — not a retry) and
  -- confirm no second xp_ledger row is created and the second attempt
  -- is cleanly rejected by the status guard.
  perform public.forge_start_mission('cmd-start', 'key-start', instance_a, 2, 'hash-start');
  perform public.forge_submit_mission(
    'cmd-sub1', 'key-sub1', instance_a, 3, 'hash-sub1', 'binary', '{"completed": true}'::jsonb
  );

  select count(*) into ledger_count from public.xp_ledger where mission_instance_id = instance_a;
  if ledger_count <> 1 then
    raise exception 'FAIL: expected exactly 1 xp_ledger row after one legitimate completion, found %', ledger_count;
  end if;

  caught := false;
  begin
    perform public.forge_submit_mission(
      'cmd-sub2', 'key-sub2', instance_a, 4, 'hash-sub2', 'binary', '{"completed": true}'::jsonb
    );
  exception
    when others then
      if sqlerrm like 'invalid_transition|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: a second, genuinely-new submit command on an already-completed mission was accepted'; end if;

  select count(*) into ledger_count from public.xp_ledger where mission_instance_id = instance_a;
  if ledger_count <> 1 then
    raise exception 'FAIL: a second submit attempt created an additional xp_ledger row (now %)', ledger_count;
  end if;
  raise notice 'PASS: duplicate XP for the same mission completion is structurally impossible (xp_ledger stays at exactly 1 row)';

  -- Note on true concurrency (spec section 24 "double submission
  -- produces one reward only"): this script runs single-threaded
  -- inside one psql session, so it cannot issue two genuinely
  -- simultaneous requests the way two racing Edge Function invocations
  -- would. What actually provides that guarantee is demonstrated
  -- structurally above and in forge_lock_owned_mission's `for update`
  -- row lock (supabase/migrations/20260817090100_mission_reward_
  -- functions.sql): a second concurrent call blocks on that lock until
  -- the first transaction commits, then re-reads the now-advanced
  -- current_sequence and is rejected by the same stale_sequence/
  -- invalid_transition paths exercised above. A true multi-connection
  -- concurrency test would need two separate psql/pgbench sessions
  -- issuing overlapping transactions and is out of reach for this
  -- single-script test harness — documented here rather than faked.
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 009_command_idempotency.sql'; end $$;

rollback;
