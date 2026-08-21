-- RLS: integrity_events and audit_log are fully invisible/unwritable to
-- normal clients. Covers: "client cannot read integrity_events",
-- "client cannot write audit_log".

begin;

do $$
declare
  user_a uuid := '44444444-4444-4444-4444-444444444444';
  event_id uuid;
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
    'user-d@forge.test', crypt('test-password', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
  );

  -- Seed one integrity_events row about this very user, as service_role.
  insert into public.integrity_events (user_id, signal_type, severity)
  values (user_a, 'excessive_volume', 'warning')
  returning id into event_id;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  -- Even a row about themselves must be invisible to the user it's
  -- about — spec section 12: "Normal users must NOT be able to inspect
  -- internal anti-abuse metadata." No grant exists at all here, so this
  -- is rejected at the permission-check stage rather than by RLS
  -- silently returning zero rows — a stricter, equally valid "cannot
  -- read."
  begin
    if exists (select 1 from public.integrity_events where id = event_id) then
      raise exception 'FAIL: client can read an integrity_events row about themselves';
    end if;
    raise notice 'PASS: client cannot read integrity_events, even their own (0 rows visible)';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot read integrity_events, even their own (%)', sqlstate;
  end;

  begin
    insert into public.audit_log (actor_type, actor_id, action, target_type, target_id)
    values ('user', user_a, 'xp_grant', 'user', user_a::text);
    raise exception 'FAIL: client inserted into audit_log';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot write audit_log (%)', sqlstate;
  end;

  begin
    if exists (select 1 from public.audit_log) then
      raise exception 'FAIL: client can read audit_log';
    end if;
    raise notice 'PASS: client cannot read audit_log (0 rows visible)';
  exception
    when others then
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'PASS: client cannot read audit_log (%)', sqlstate;
  end;
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 004_integrity_and_audit_locked.sql'; end $$;

rollback;
