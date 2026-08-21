-- Phase 10C: mission-transition legality and command-sequence
-- rejection (spec section 24 "Mission transitions"/"Sequence").

begin;

do $$
declare
  user_a uuid := '99999999-9999-9999-9999-999999999991';
  def_id uuid;
  instance_a uuid;
  caught boolean;
  result jsonb;
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
    'user-i@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- (1) Invalid start: mission is 'assigned', not yet accepted.
  caught := false;
  begin
    perform public.forge_start_mission('cmd-badstart', 'key-badstart', instance_a, 1, 'hash-badstart');
  exception
    when others then
      if sqlerrm like 'invalid_transition|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: started an unaccepted mission'; end if;
  raise notice 'PASS: starting an unaccepted mission is rejected (invalid_transition)';

  -- (2) Invalid submit: mission hasn't been started yet either.
  caught := false;
  begin
    perform public.forge_submit_mission(
      'cmd-badsubmit', 'key-badsubmit', instance_a, 1, 'hash-badsubmit',
      'binary', '{"completed": true}'::jsonb
    );
  exception
    when others then
      if sqlerrm like 'invalid_transition|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: submitted a mission that was never started'; end if;
  raise notice 'PASS: submitting a not-yet-started mission is rejected (invalid_transition)';

  -- Now legally accept (sequence 1) and start (sequence 2).
  perform public.forge_accept_mission('cmd-1', 'key-1', instance_a, 1, 'hash-1');
  perform public.forge_start_mission('cmd-2', 'key-2', instance_a, 2, 'hash-2');

  -- (3) Invalid accept: already past 'assigned'.
  caught := false;
  begin
    perform public.forge_accept_mission('cmd-reaccept', 'key-reaccept', instance_a, 3, 'hash-reaccept');
  exception
    when others then
      if sqlerrm like 'invalid_transition|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: accepted an already-active mission a second time'; end if;
  raise notice 'PASS: re-accepting an already-active mission is rejected (invalid_transition)';

  -- (4) Stale sequence: current_sequence is now 2 (accept, start) —
  -- resubmitting sequence 2 again (a different command/key) is stale.
  caught := false;
  begin
    perform public.forge_start_mission('cmd-stale', 'key-stale', instance_a, 2, 'hash-stale');
  exception
    when others then
      if sqlerrm like 'stale_sequence|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: a stale sequence (2, already consumed) was accepted'; end if;
  raise notice 'PASS: a stale command sequence is rejected (stale_sequence)';

  -- (5) Out-of-order sequence: expected next is 3, but 5 skips ahead.
  caught := false;
  begin
    perform public.forge_record_mission_progress(
      'cmd-skip', 'key-skip', instance_a, 5, 'hash-skip',
      'binary', '{"completed": false}'::jsonb
    );
  exception
    when others then
      if sqlerrm like 'out_of_order|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: an out-of-order sequence (5, expected 3) was accepted'; end if;
  raise notice 'PASS: an out-of-order command sequence is rejected (out_of_order)';

  -- (6) Invalid cancel: complete the mission first, then cancelling a
  -- completed mission must be rejected.
  select public.forge_submit_mission(
    'cmd-3', 'key-3', instance_a, 3, 'hash-3', 'binary', '{"completed": true}'::jsonb
  ) into result;
  if result ->> 'confirmedMissionState' <> 'completed' then
    raise exception 'FAIL: setup for cancel-after-completion test did not actually complete the mission';
  end if;

  caught := false;
  begin
    perform public.forge_cancel_mission('cmd-badcancel', 'key-badcancel', instance_a, 4, 'hash-badcancel', null);
  exception
    when others then
      if sqlerrm like 'invalid_transition|%' then caught := true; else raise; end if;
  end;
  if not caught then raise exception 'FAIL: cancelled an already-completed mission'; end if;
  raise notice 'PASS: cancelling an already-completed mission is rejected (invalid_transition)';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 008_transitions_and_sequence.sql'; end $$;

rollback;
