-- Phase 10C: authentication/authority boundary for the forge_* command
-- RPCs (spec section 24 "Authentication"/"Authority").
--
-- Note on scope: "client XP/rank/competition-score/achievement field
-- rejected" is enforced at the Edge Function layer
-- (supabase/functions/_shared/validation.ts, exercised by
-- validation_test.ts), not inside these PL/pgSQL functions themselves —
-- the RPC functions never read arbitrary payload keys for anything
-- reward-shaped in the first place (forge_validate_completion only ever
-- looks at the specific fields each progress type needs), so there is
-- no code path here for a smuggled "xp" field to influence. That
-- boundary is real, just enforced one layer up; see supabase/README.md.

begin;

do $$
declare
  user_a uuid := '77777777-7777-7777-7777-777777777777';
  user_b uuid := '88888888-8888-8888-8888-888888888888';
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
  ) values
    (user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'user-g@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now()),
    (user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
     'user-h@forge.test', crypt('test-password', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{}', false, now(), now());

  select id into def_id from public.mission_definitions where stable_key = 'fitness-10min-stretch';
  insert into public.mission_instances (user_id, mission_definition_id, mission_date)
  values (user_a, def_id, current_date)
  returning id into instance_a;

  -- (1) No authenticated user at all (auth.uid() null) -> unauthenticated.
  reset role;
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  set local role authenticated;

  caught := false;
  begin
    perform public.forge_accept_mission('cmd-noauth', 'key-noauth', instance_a, 1, 'hash-noauth');
  exception
    when others then
      if sqlerrm like 'unauthenticated|%' then
        caught := true;
      else
        raise;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: forge_accept_mission succeeded with no authenticated user';
  end if;
  raise notice 'PASS: forge_accept_mission rejects an unauthenticated caller';

  -- (2) User B tries to accept User A's mission -> forbidden.
  perform set_config('request.jwt.claims', json_build_object('sub', user_b::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_b::text, true);

  caught := false;
  begin
    perform public.forge_accept_mission('cmd-wronguser', 'key-wronguser', instance_a, 1, 'hash-wronguser');
  exception
    when others then
      if sqlerrm like 'forbidden|%' then
        caught := true;
      else
        raise;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: user B was able to accept user A''s mission';
  end if;
  raise notice 'PASS: forge_accept_mission rejects a non-owning caller';

  -- (3) A nonexistent mission instance -> mission_not_found, not a raw
  -- foreign-key/lookup error.
  caught := false;
  begin
    perform public.forge_accept_mission(
      'cmd-missing', 'key-missing', '99999999-9999-9999-9999-999999999999', 1, 'hash-missing'
    );
  exception
    when others then
      if sqlerrm like 'mission_not_found|%' then
        caught := true;
      else
        raise;
      end if;
  end;
  if not caught then
    raise exception 'FAIL: a nonexistent mission instance did not raise mission_not_found';
  end if;
  raise notice 'PASS: forge_accept_mission raises mission_not_found for a nonexistent mission, not a raw error';

  -- (4) The real owner CAN accept it — proves (1)/(2) failed for the
  -- right reason, not because the function is simply broken.
  perform set_config('request.jwt.claims', json_build_object('sub', user_a::text, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', user_a::text, true);

  select public.forge_accept_mission('cmd-real', 'key-real', instance_a, 1, 'hash-real') into result;
  if result ->> 'status' <> 'accepted' then
    raise exception 'FAIL: the real owner could not accept their own mission';
  end if;
  raise notice 'PASS: the real owner can accept their own mission';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 007_command_auth_boundary.sql'; end $$;

rollback;
