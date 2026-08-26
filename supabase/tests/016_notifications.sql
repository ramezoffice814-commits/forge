-- Roadmap Item 15: notifications RLS, forbidden-insert, and
-- server-authoritative creation (achievement unlock + level-up),
-- atomically with forge_submit_mission — the same deterministic
-- first-mission scenario 010 already pins, extended with a pre-set
-- confirmed_xp so this same completion also crosses a level threshold,
-- so one test covers both notification types without duplicating setup.

begin;

do $$
declare
  user_a uuid := '99999999-9999-9999-9999-999999999994';
  user_b uuid := '99999999-9999-9999-9999-999999999995';
  def_id uuid;
  instance_a uuid;
  result jsonb;
  notif_count integer;
  notif_row record;
  affected_rows integer;
  caught boolean;
begin
  set local role postgres;

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values
    (user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'user-notif-a@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now()),
    (user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'user-notif-b@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now());
  -- on_auth_user_created_notification_preferences fires here too — an
  -- implicit proof the bootstrap trigger works, checked explicitly below.

  if not exists (select 1 from public.notification_preferences where user_id = user_a) then
    raise exception 'FAIL: notification_preferences was not bootstrapped for a new user';
  end if;
  raise notice 'PASS: notification_preferences bootstrapped automatically on signup';

  -- Pre-set user_a one level-up away (level 1 needs 50 confirmed_xp to
  -- reach level 2; the deterministic first-mission completion below
  -- grants exactly 12 more) so this single completion also exercises
  -- the level_up notification, not just achievement_unlock.
  update public.user_progression set confirmed_xp = 49 where user_id = user_a;

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  -- --- act as user_a: complete the mission (achievement + level-up) ------
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  perform public.forge_accept_mission('n-cmd-a', 'n-key-a', instance_a, 1, 'n-hash-a');
  perform public.forge_start_mission('n-cmd-b', 'n-key-b', instance_a, 2, 'n-hash-b');
  select public.forge_submit_mission(
    'n-cmd-c', 'n-key-c', instance_a, 3, 'n-hash-c', 'binary', '{"completed": true}'::jsonb
  ) into result;

  if (result -> 'progressionUpdate' ->> 'newLevel')::integer <> 2 then
    raise exception 'FAIL: expected this completion to reach level 2, got %',
      result -> 'progressionUpdate' ->> 'newLevel';
  end if;

  -- (1) Achievement-unlock notification exists, exactly once, with safe
  -- denormalized metadata — never a raw internal id leak beyond what
  -- the client already needs.
  select count(*) into notif_count
  from public.notifications
  where user_id = user_a and type = 'achievement_unlock';
  if notif_count <> 1 then
    raise exception 'FAIL: expected exactly 1 achievement_unlock notification, got %', notif_count;
  end if;
  select * into notif_row from public.notifications
  where user_id = user_a and type = 'achievement_unlock';
  if notif_row.metadata ->> 'stableKey' <> 'first_mission' then
    raise exception 'FAIL: achievement_unlock metadata.stableKey mismatch: %', notif_row.metadata;
  end if;
  raise notice 'PASS: exactly one achievement_unlock notification, correct metadata';

  -- (2) Level-up notification exists, exactly once, with the correct
  -- before/after levels — never fabricated by the client.
  select count(*) into notif_count
  from public.notifications where user_id = user_a and type = 'level_up';
  if notif_count <> 1 then
    raise exception 'FAIL: expected exactly 1 level_up notification, got %', notif_count;
  end if;
  select * into notif_row from public.notifications where user_id = user_a and type = 'level_up';
  if (notif_row.metadata ->> 'previousLevel')::integer <> 1
     or (notif_row.metadata ->> 'newLevel')::integer <> 2 then
    raise exception 'FAIL: level_up metadata mismatch: %', notif_row.metadata;
  end if;
  raise notice 'PASS: exactly one level_up notification, correct previous/new level';

  -- (3) Dedup: directly re-invoking forge_create_notification with the
  -- same dedup_key (simulating a retried/duplicate finalization path,
  -- not just relying on the idempotency-cache short-circuit) must not
  -- create a second row.
  set local role postgres;
  perform public.forge_create_notification(
    user_a, 'level_up', notif_row.dedup_key, jsonb_build_object('previousLevel', 1, 'newLevel', 2)
  );
  select count(*) into notif_count
  from public.notifications where user_id = user_a and type = 'level_up';
  if notif_count <> 1 then
    raise exception 'FAIL: forge_create_notification duplicate call created a second row (count=%)', notif_count;
  end if;
  raise notice 'PASS: forge_create_notification is idempotent on (user_id, dedup_key)';

  -- --- RLS: cross-user isolation -----------------------------------------
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  select count(*) into notif_count from public.notifications where user_id = user_a;
  if notif_count <> 2 then
    raise exception 'FAIL: user_a should see exactly 2 of their own notifications, saw %', notif_count;
  end if;
  raise notice 'PASS: user_a can read their own notifications';

  perform set_config('request.jwt.claims', json_build_object('sub', user_b::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_b::text, true);

  select count(*) into notif_count from public.notifications where user_id = user_a;
  if notif_count <> 0 then
    raise exception 'FAIL: user_b could read user_a''s notifications (RLS bypass), saw %', notif_count;
  end if;
  raise notice 'PASS: user_b cannot read user_a''s notifications (cross-user isolation)';

  select count(*) into notif_count from public.notification_preferences where user_id = user_a;
  if notif_count <> 0 then
    raise exception 'FAIL: user_b could read user_a''s notification_preferences (RLS bypass)';
  end if;
  raise notice 'PASS: user_b cannot read user_a''s notification_preferences (account-switch isolation)';

  -- (4) Forbidden client insert: a client must never be able to mint an
  -- achievement/level_up/competition-shaped notification for themselves.
  caught := false;
  begin
    insert into public.notifications (user_id, type, dedup_key, metadata)
    values (user_b, 'achievement_unlock', 'forged:' || user_b::text, '{"title":"forged"}'::jsonb);
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%row-level security%' or sqlerrm ilike '%permission denied%' then
        caught := true;
      else
        raise exception 'FAIL: unexpected error on forged insert attempt: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: a client was able to INSERT a notification row directly — self-awarding is possible';
  end if;
  raise notice 'PASS: direct client INSERT into notifications is rejected (no INSERT policy/grant exists)';

  -- (4b) Forbidden RPC call: even calling forge_create_notification()
  -- itself (not just the bare table) must be rejected for an
  -- authenticated client — it is never granted EXECUTE, only invoked
  -- internally from other SECURITY DEFINER functions.
  caught := false;
  begin
    perform public.forge_create_notification(
      user_b, 'achievement_unlock', 'forged-rpc:' || user_b::text, '{"title":"forged"}'::jsonb
    );
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then
        caught := true;
      else
        raise exception 'FAIL: unexpected error calling forge_create_notification directly: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: an authenticated client was able to call forge_create_notification() directly';
  end if;
  raise notice 'PASS: direct client call to forge_create_notification() is rejected (no EXECUTE grant)';

  -- (5) Read-state permission: user_a may mark their own notification
  -- read (read_at only)...
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  update public.notifications set read_at = now()
  where user_id = user_a and type = 'achievement_unlock';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'FAIL: user_a could not mark their own notification read';
  end if;
  raise notice 'PASS: user_a can mark their own notification read';

  -- ...but cannot rewrite type/metadata even on their own row (column-
  -- level GRANT restricts UPDATE to read_at only).
  caught := false;
  begin
    update public.notifications set type = 'level_up'
    where user_id = user_a and type = 'achievement_unlock';
  exception
    when insufficient_privilege then caught := true;
    when others then
      if sqlerrm ilike '%permission denied%' then
        caught := true;
      else
        raise exception 'FAIL: unexpected error rewriting notification type: %', sqlerrm;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: user_a was able to rewrite a notification''s type — content is not immutable';
  end if;
  raise notice 'PASS: notification type/metadata/dedup_key are immutable even for the owning user';

  -- ...and cannot mark user_b's notifications read.
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);
  update public.notifications set read_at = now() where user_id = user_b;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FAIL: user_a was able to update user_b''s notification read state';
  end if;
  raise notice 'PASS: user_a cannot update user_b''s notification read state';

  -- (6) Preferences: user_a can update their own preferences...
  update public.notification_preferences
  set quiet_hours_enabled = true, quiet_hours_start_minute = 1350,
      quiet_hours_end_minute = 420, timezone = 'Africa/Cairo'
  where user_id = user_a;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'FAIL: user_a could not update their own notification_preferences';
  end if;
  raise notice 'PASS: user_a can update their own notification_preferences';

  -- ...but not user_b's.
  update public.notification_preferences set master_enabled = false where user_id = user_b;
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'FAIL: user_a was able to update user_b''s notification_preferences';
  end if;
  raise notice 'PASS: user_a cannot update user_b''s notification_preferences';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 016_notifications.sql'; end $$;

rollback;
