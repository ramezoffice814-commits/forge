-- Phase 11: authoritative weekly grouping (spec sections 10-12) — the
-- ~25-person weekly group concept Phase 10B/10C/10D all explicitly
-- deferred ("a weekly grouping concept this phase doesn't model yet").
--
-- Only non-sensitive inputs drive grouping: league, rookie status, and
-- the prior week's confirmed rank (a coarse "performance band," not raw
-- behavioral data) — never health data, recovery reasons, or private
-- mission category/history, matching the spec's explicit exclusion
-- list.

create table public.competition_groups (
  id uuid primary key default extensions.gen_random_uuid(),
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  week_number integer not null,
  league_id uuid not null references public.league_definitions (id),
  group_number integer not null,
  created_at timestamptz not null default timezone('utc', now()),

  constraint competition_groups_number_positive check (group_number > 0),
  constraint competition_groups_unique unique (season_id, week_number, league_id, group_number)
);

comment on table public.competition_groups is
  'One weekly ranking group (target size 25) within one league. '
  'Written only by forge_build_weekly_groups. Read-only for clients.';

alter table public.competition_groups enable row level security;

create policy competition_groups_select_all
  on public.competition_groups
  for select
  to authenticated
  using (true);

create table public.competition_group_members (
  id uuid primary key default extensions.gen_random_uuid(),
  group_id uuid not null references public.competition_groups (id) on delete cascade,
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  week_number integer not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  placement_seed numeric not null default 0,
  created_at timestamptz not null default timezone('utc', now()),

  -- A user belongs to at most one group per competition week — the
  -- concrete mechanism behind "prevent joining multiple groups for the
  -- same competition week" (spec section 11).
  constraint competition_group_members_one_per_week unique (season_id, week_number, user_id)
);

comment on table public.competition_group_members is
  'unique(season_id, week_number, user_id) makes a user belonging to '
  'two groups in the same week structurally impossible. Own-row '
  'SELECT only for clients — which group everyone else is in is not '
  'itself public (only the ranked results are, via the leaderboard '
  'views).';

create index competition_group_members_group_idx
  on public.competition_group_members (group_id);

alter table public.competition_group_members enable row level security;

create policy competition_group_members_select_own
  on public.competition_group_members
  for select
  to authenticated
  using (user_id = auth.uid());

-- =======================================================================
-- forge_build_weekly_groups — deterministic, idempotent (re-running for
-- an already-grouped week recomputes identically via delete+rebuild
-- inside the same transaction, never accumulating duplicates).
-- =======================================================================

create or replace function public.forge_build_weekly_groups(
  p_season_id uuid,
  p_week_number integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_league record;
  v_written integer := 0;
  v_rows_this_league integer;
begin
  -- Idempotent re-run: clear this week's groups first (cascades to
  -- members), then rebuild from scratch — never a partial merge that
  -- could leave a stale membership behind.
  delete from public.competition_groups
  where season_id = p_season_id and week_number = p_week_number;

  for v_league in
    select * from public.league_definitions where active order by tier
  loop
    with seeded as (
      select
        cm.user_id,
        -- Prior week's confirmed rank as a coarse, non-sensitive
        -- "performance band" — 999999 (effectively "unranked/last")
        -- for a rookie or anyone with no prior-week result, so new
        -- participants land in the higher-numbered (later) groups
        -- rather than skewing an early one.
        coalesce(prev.rank, 999999) as performance_band,
        cm.is_rookie
      from public.competition_memberships cm
      left join public.competition_week_results prev
        on prev.user_id = cm.user_id
        and prev.season_id = cm.season_id
        and prev.week_number = p_week_number - 1
      where cm.season_id = p_season_id and cm.league_id = v_league.id
    ),
    ordered as (
      select
        s.*,
        row_number() over (
          order by s.is_rookie asc, s.performance_band asc, s.user_id asc
        ) as ord
      from seeded s
    ),
    grouped as (
      select
        o.*,
        ((o.ord - 1) / 25) + 1 as group_number
      from ordered o
    ),
    inserted_groups as (
      insert into public.competition_groups (season_id, week_number, league_id, group_number)
      select distinct p_season_id, p_week_number, v_league.id, g.group_number
      from grouped g
      returning id, group_number
    )
    insert into public.competition_group_members (group_id, season_id, week_number, user_id, placement_seed)
    select ig.id, p_season_id, p_week_number, g.user_id, g.performance_band
    from grouped g
    join inserted_groups ig on ig.group_number = g.group_number;

    get diagnostics v_rows_this_league = row_count;
    v_written := v_written + v_rows_this_league;
  end loop;

  return v_written;
end;
$$;

revoke all on function public.forge_build_weekly_groups(uuid, integer) from public;
-- Deliberately no grant — server-only, same as the finalization
-- functions this feeds into.

-- =======================================================================
-- Redefine forge_finalize_season_week to rank within each weekly group
-- rather than across the whole league (spec section 12), calling
-- forge_build_weekly_groups first so groups always exist for the week
-- being finalized. Structurally identical to the Phase 10D version
-- (20260819090000_season_finalization.sql) otherwise — same tie-break
-- order, same promotion/demotion/rookie-protection logic — just scoped
-- per group_number instead of per whole league.
-- =======================================================================

create or replace function public.forge_finalize_season_week(
  p_season_id uuid,
  p_week_number integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week record;
  v_league record;
  v_written integer := 0;
  v_rows_this_league integer;
begin
  select * into v_week from public.competition_weeks
  where season_id = p_season_id and week_number = p_week_number;
  if not found then
    raise exception 'forge_finalize_season_week: no such (season, week): (%, %)', p_season_id, p_week_number;
  end if;

  perform public.forge_build_weekly_groups(p_season_id, p_week_number);

  for v_league in
    select * from public.league_definitions where active order by tier
  loop
    with participants as (
      select
        cgm.user_id,
        cg.group_number,
        coalesce(sum(csl.amount), 0) as weekly_score,
        count(distinct (csl.created_at at time zone 'utc')::date) as active_days,
        coalesce(avg(public.forge_difficulty_weight(
          coalesce(mi.resolved_difficulty, md.difficulty)
        )), 0) as average_difficulty,
        coalesce(max(csl.created_at), v_week.starts_at) as attained_at,
        cm.is_rookie,
        cm.rookie_protection_until
      from public.competition_group_members cgm
      join public.competition_groups cg on cg.id = cgm.group_id
      join public.competition_memberships cm
        on cm.user_id = cgm.user_id and cm.season_id = cgm.season_id
      left join public.competition_score_ledger csl
        on csl.user_id = cgm.user_id
        and csl.season_id = cgm.season_id
        and csl.week_number = p_week_number
      left join public.mission_instances mi on mi.id = csl.mission_instance_id
      left join public.mission_definitions md on md.id = mi.mission_definition_id
      where cg.season_id = p_season_id and cg.week_number = p_week_number and cg.league_id = v_league.id
      group by cgm.user_id, cg.group_number, cm.is_rookie, cm.rookie_protection_until
    ),
    ranked as (
      select
        p.*,
        row_number() over (
          partition by p.group_number
          order by
            p.weekly_score desc,
            p.active_days desc,
            p.average_difficulty desc,
            p.attained_at asc,
            p.user_id asc
        ) as rank,
        count(*) over (partition by p.group_number) as group_total
      from participants p
    ),
    zoned as (
      select
        r.*,
        (r.rank <= v_league.promotion_count and v_league.promotion_count > 0
           and v_league.tier < (select max(tier) from public.league_definitions where active))
          as in_promotion_zone,
        (r.rank > r.group_total - v_league.demotion_count and v_league.demotion_count > 0
           and v_league.tier > (select min(tier) from public.league_definitions where active))
          as in_demotion_zone,
        (r.is_rookie and (r.rookie_protection_until is null or r.rookie_protection_until > v_week.ends_at))
          as protected_this_week
      from ranked r
    )
    insert into public.competition_week_results (
      user_id, season_id, week_number, league_id, rank, weekly_score,
      active_days, average_difficulty, promotion_status, target_league_id
    )
    select
      z.user_id, p_season_id, p_week_number, v_league.id, z.rank, z.weekly_score,
      z.active_days, z.average_difficulty,
      case
        when z.in_promotion_zone then 'promotionZone'
        when z.in_demotion_zone and not z.protected_this_week then 'demotionZone'
        else 'safeZone'
      end,
      case
        when z.in_promotion_zone then (
          select id from public.league_definitions where active and tier = v_league.tier + 1
        )
        when z.in_demotion_zone and not z.protected_this_week then (
          select id from public.league_definitions where active and tier = v_league.tier - 1
        )
        else null
      end
    from zoned z
    on conflict (user_id, season_id, week_number) do update set
      league_id = excluded.league_id,
      rank = excluded.rank,
      weekly_score = excluded.weekly_score,
      active_days = excluded.active_days,
      average_difficulty = excluded.average_difficulty,
      promotion_status = excluded.promotion_status,
      target_league_id = excluded.target_league_id,
      computed_at = timezone('utc', now());

    get diagnostics v_rows_this_league = row_count;
    v_written := v_written + v_rows_this_league;
  end loop;

  insert into public.audit_log (actor_type, action, target_type, target_id, metadata)
  values ('service', 'league_assignment', 'competition_week',
    p_season_id::text || ':' || p_week_number::text,
    jsonb_build_object('seasonId', p_season_id, 'weekNumber', p_week_number, 'rowsWritten', v_written, 'grouped', true));

  return v_written;
end;
$$;

revoke all on function public.forge_finalize_season_week(uuid, integer) from public;

-- Group-scoped counterpart to the season/weekly leaderboard views —
-- same column-exposure discipline. group_number is public-safe (it's
-- just "which cohort," not sensitive), placement_seed (a raw
-- performance-band number) is NOT exposed here — only rank/score are.
create view public.competition_public_group_standings as
select
  cg.season_id,
  cg.week_number,
  cg.league_id,
  cg.group_number,
  cwr.rank,
  cwr.weekly_score as confirmed_score,
  cwr.promotion_status,
  p.display_name,
  p.avatar_path
from public.competition_groups cg
join public.competition_group_members cgm on cgm.group_id = cg.id
join public.competition_week_results cwr
  on cwr.user_id = cgm.user_id and cwr.season_id = cg.season_id and cwr.week_number = cg.week_number
join public.profiles p on p.user_id = cgm.user_id;

comment on view public.competition_public_group_standings is
  'Public-safe within-group standings. Never exposes placement_seed '
  '(the internal performance-band ordering input) or any other group '
  'member''s data beyond display_name/avatar_path/rank/score/status.';

grant select on public.competition_public_group_standings to authenticated;
