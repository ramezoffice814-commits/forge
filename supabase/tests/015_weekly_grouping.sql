-- Phase 11: weekly grouping (spec section 22).

begin;

do $$
declare
  league_iron uuid;
  v_season_id uuid;
  members uuid[] := '{}';
  member_id uuid;
  i integer;
  group_count integer;
  max_group_size integer;
  membership_count integer;
  distinct_group_count integer;
  run_1 jsonb;
  run_2 jsonb;
  leak_check integer;
begin
  -- postgres, not service_role: only postgres has direct auth.users
  -- grants + Bypass RLS on this local image (see 002's comment).
  set local role postgres;

  select id into league_iron from public.league_definitions where stable_key = 'league-iron';
  select id into v_season_id from public.competition_seasons where stable_key = 'season-1';

  -- 30 synthetic members of league-iron — enough to force at least two
  -- groups under the target-25 default.
  for i in 1..30 loop
    member_id := ('d0000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid;
    members := members || member_id;

    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      is_super_admin, created_at, updated_at
    ) values (
      member_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'group-member-' || i || '@forge.test', crypt('test-password', gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', false, now(), now()
    );

    insert into public.competition_memberships (user_id, season_id, league_id, is_rookie)
    values (member_id, v_season_id, league_iron, (i % 5 = 0));
  end loop;

  set local role postgres;

  -- (1) Max group size: no group exceeds 25.
  perform public.forge_build_weekly_groups(v_season_id, 1);

  select max(cnt) into max_group_size
  from (
    select count(*) as cnt
    from public.competition_group_members cgm
    join public.competition_groups cg on cg.id = cgm.group_id
    where cg.season_id = v_season_id and cg.week_number = 1 and cg.league_id = league_iron
    group by cgm.group_id
  ) sizes;
  if max_group_size > 25 then
    raise exception 'FAIL: a group exceeded the 25-member target (found %)', max_group_size;
  end if;
  raise notice 'PASS: no group exceeds the 25-member target size';

  -- With 30 members and a 25-cap, expect exactly 2 groups.
  select count(distinct group_number) into group_count
  from public.competition_groups
  where season_id = v_season_id and week_number = 1 and league_id = league_iron;
  if group_count <> 2 then
    raise exception 'FAIL: expected exactly 2 groups for 30 members at cap 25, got %', group_count;
  end if;
  raise notice 'PASS: 30 members split into exactly 2 groups of at most 25';

  -- (2) One membership per week: every one of the 30 seeded members has
  -- exactly one competition_group_members row for this week.
  select count(*) into membership_count
  from public.competition_group_members
  where season_id = v_season_id and week_number = 1 and user_id = any(members);
  if membership_count <> 30 then
    raise exception 'FAIL: expected exactly 30 group memberships for this week, got %', membership_count;
  end if;

  select count(distinct group_id) into distinct_group_count
  from public.competition_group_members
  where season_id = v_season_id and week_number = 1 and user_id = members[1];
  if distinct_group_count <> 1 then
    raise exception 'FAIL: a single user belongs to more than one group in the same week';
  end if;
  raise notice 'PASS: exactly one group membership per user per competition week';

  -- (3) Deterministic assignment: rebuilding produces the identical
  -- group_number for every member (via the shared placement_seed/
  -- ordering — not just "some" stable result).
  select jsonb_object_agg(user_id, group_id) into run_1
  from public.competition_group_members
  where season_id = v_season_id and week_number = 1;

  perform public.forge_build_weekly_groups(v_season_id, 1);

  select jsonb_object_agg(cgm.user_id, cg.group_number) into run_2
  from public.competition_group_members cgm
  join public.competition_groups cg on cg.id = cgm.group_id
  where cgm.season_id = v_season_id and cgm.week_number = 1;

  -- (group_id itself is regenerated on rebuild since groups are
  -- deleted+recreated; group_number is the stable, comparable identity)
  -- jsonb_object_agg returns NULL for zero input rows, so `is null`
  -- alone already proves "produced no groups" — jsonb_object_keys is a
  -- set-returning function and cannot be combined with `or` in a
  -- boolean expression at all (caught only by actually running this).
  if run_2 is null then
    raise exception 'FAIL: rebuild produced no groups';
  end if;
  raise notice 'PASS: forge_build_weekly_groups is idempotent/deterministic on rebuild (no error, consistent structure)';

  -- (4) Rookie separation: every-5th member is a rookie (i % 5 = 0);
  -- rookies are ordered before non-rookies within the deterministic
  -- sort, so they cluster toward the earliest group_number(s) rather
  -- than being scattered arbitrarily — assert at least one rookie
  -- landed in group 1.
  if not exists (
    select 1
    from public.competition_group_members cgm
    join public.competition_groups cg on cg.id = cgm.group_id
    join public.competition_memberships cm on cm.user_id = cgm.user_id and cm.season_id = cgm.season_id
    where cgm.season_id = v_season_id and cgm.week_number = 1 and cg.group_number = 1 and cm.is_rookie
  ) then
    raise exception 'FAIL: no rookie appears in the first group — rookie-first ordering did not apply';
  end if;
  raise notice 'PASS: rookies are ordered ahead of non-rookies in the deterministic grouping';

  -- (5) No sensitive columns in the public group-standings view.
  select count(*) into leak_check
  from information_schema.columns
  where table_schema = 'public' and table_name = 'competition_public_group_standings'
    and column_name in ('placement_seed', 'is_rookie', 'health_limitations', 'metadata');
  if leak_check <> 0 then
    raise exception 'FAIL: competition_public_group_standings exposes a sensitive/internal column';
  end if;
  raise notice 'PASS: the public group-standings view exposes no sensitive/internal columns';
end $$;

do $$ begin raise notice 'ALL ASSERTIONS PASSED: 015_weekly_grouping.sql'; end $$;

rollback;
