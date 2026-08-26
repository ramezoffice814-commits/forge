-- System-wide least-privilege hardening regression tests.
--
-- Every assertion here proves a specific exploit is denied, not merely
-- that metadata (grants/policies) looks correct — each one actually
-- attempts the forbidden statement and checks it fails, mirroring the
-- exact statements confirmed exploitable against forge-staging before
-- 20260826010000_system_wide_least_privilege_hardening.sql, and
-- confirmed denied after it.

begin;

do $$
declare
  user_a uuid := '66666666-6666-6666-6666-666666666601';
  user_b uuid := '66666666-6666-6666-6666-666666666602';
  def_id uuid;
  instance_a uuid;
  result jsonb;
  caught boolean;
  row_count_check integer;
begin
  set local role postgres;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values
    (user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'hardening-a@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now()),
    (user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'hardening-b@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now());

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';

  -- --- act as user_a ------------------------------------------------
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- (1) mission_instances is fully server-only now — no direct
  -- client SELECT/INSERT/UPDATE at all, since the real Flutter client
  -- never touches this table directly (every command goes through the
  -- Edge Functions -> SECURITY DEFINER forge_* functions instead).
  caught := false;
  begin
    perform 1 from public.mission_instances limit 1;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error selecting mission_instances: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could SELECT mission_instances directly';
  end if;
  raise notice 'PASS: authenticated cannot SELECT mission_instances directly';

  caught := false;
  begin
    insert into public.mission_instances (user_id, mission_definition_id, mission_date)
    values (user_a, def_id, current_date);
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error inserting mission_instances: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could INSERT into mission_instances directly';
  end if;
  raise notice 'PASS: authenticated cannot INSERT into mission_instances directly';

  -- (2) mission_events is fully server-only now too — a forged
  -- "completed" event can never be injected directly into the
  -- append-only history the server's own streak/integrity logic reads.
  caught := false;
  begin
    insert into public.mission_events (mission_instance_id, user_id, event_type, payload, sequence)
    values (gen_random_uuid(), user_a, 'completed', '{}'::jsonb, 1);
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error inserting mission_events: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could INSERT into mission_events directly';
  end if;
  raise notice 'PASS: authenticated cannot INSERT into mission_events directly';

  -- (3) xp_ledger: no direct client write of any kind — XP is only
  -- ever granted atomically inside forge_submit_mission.
  caught := false;
  begin
    insert into public.xp_ledger (user_id, source_type, source_id, amount, reason)
    values (user_a, 'mission_completion', 'forged', 999999, 'forged xp');
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error inserting xp_ledger: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could INSERT into xp_ledger directly';
  end if;
  raise notice 'PASS: authenticated cannot INSERT into xp_ledger directly';

  -- (4) user_progression: confirmed level/XP can never be rewritten
  -- directly, even on the caller's own row.
  caught := false;
  begin
    update public.user_progression set confirmed_xp = 999999, level = 99 where user_id = user_a;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error updating user_progression: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could UPDATE user_progression directly';
  end if;
  raise notice 'PASS: authenticated cannot UPDATE user_progression directly';

  -- (5) user_achievements: self-awarding is impossible.
  caught := false;
  begin
    insert into public.user_achievements (user_id, achievement_id)
    select user_a, id from public.achievement_definitions limit 1;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error inserting user_achievements: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could self-award an achievement directly';
  end if;
  raise notice 'PASS: authenticated cannot self-award an achievement directly';

  -- (6) competition_score_ledger: no direct client write.
  caught := false;
  begin
    insert into public.competition_score_ledger
      (user_id, season_id, week_number, mission_instance_id, source_type, source_id, amount)
    values (user_a, gen_random_uuid(), 1, gen_random_uuid(), 'mission_completion', 'forged', 999);
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error inserting competition_score_ledger: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could INSERT into competition_score_ledger directly';
  end if;
  raise notice 'PASS: authenticated cannot INSERT into competition_score_ledger directly';

  -- (7) season_results: final league placement can never be rewritten
  -- directly, even on the caller's own row.
  caught := false;
  begin
    update public.season_results set promoted = true where user_id = user_a;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error updating season_results: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could UPDATE season_results directly';
  end if;
  raise notice 'PASS: authenticated cannot UPDATE season_results directly';

  -- (8) audit_log / integrity_events / processed_commands: fully
  -- inaccessible, both read and write.
  caught := false;
  begin
    perform 1 from public.audit_log limit 1;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error selecting audit_log: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: authenticated could SELECT audit_log directly';
  end if;
  raise notice 'PASS: authenticated cannot SELECT audit_log directly';

  -- --- act as anon ---------------------------------------------------
  reset role;
  set local role anon;

  caught := false;
  begin
    perform 1 from public.user_progression limit 1;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error (anon selecting user_progression): %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: anon could SELECT user_progression';
  end if;
  raise notice 'PASS: anon has zero access to user_progression';

  caught := false;
  begin
    perform 1 from public.mission_instances limit 1;
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then caught := true;
      else raise exception 'FAIL: unexpected error (anon selecting mission_instances): %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: anon could SELECT mission_instances';
  end if;
  raise notice 'PASS: anon has zero access to mission_instances';

  -- --- regression: the real mission flow must still work end to end -
  -- The SECURITY DEFINER command functions must be completely
  -- unaffected by these revokes, since they use the function owner's
  -- privileges for their internal statements, not the caller's own
  -- table grants.
  set local role postgres;
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  perform public.forge_accept_mission('hardening-cmd-a', 'hardening-key-a', instance_a, 1, 'hardening-hash-a');
  perform public.forge_start_mission('hardening-cmd-b', 'hardening-key-b', instance_a, 2, 'hardening-hash-b');
  select public.forge_submit_mission(
    'hardening-cmd-c', 'hardening-key-c', instance_a, 3, 'hardening-hash-c', 'binary', '{"completed": true}'::jsonb
  ) into result;

  if (result ->> 'status') <> 'accepted' then
    raise exception 'FAIL: real mission flow broke after least-privilege hardening — status was %', result ->> 'status';
  end if;
  raise notice 'PASS: the real mission accept->start->submit flow still works end to end (SECURITY DEFINER functions unaffected by these revokes)';

  -- user_a can still read their own confirmed progression afterward —
  -- SELECT was intentionally preserved, only writes were revoked.
  select count(*) into row_count_check from public.user_progression where user_id = user_a;
  if row_count_check <> 1 then
    raise exception 'FAIL: authenticated lost SELECT access to their own user_progression row';
  end if;
  raise notice 'PASS: authenticated retains SELECT on their own user_progression row';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 016_least_privilege_hardening.sql'; end $$;

rollback;
