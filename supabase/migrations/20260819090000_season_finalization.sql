-- Phase 10D: weekly/season competition finalization — server-only
-- authority. Ports lib/features/competition/domain/policies/
-- league_movement_policy.dart, rookie_placement_policy.dart, and
-- season_scoring_policy.dart's exact rules into two SECURITY DEFINER
-- functions that are NEVER granted to `authenticated` at all (no grant
-- statement exists for either — the strongest possible "normal users
-- cannot call this" guarantee this schema has anywhere, matching
-- processed_commands/integrity_events/audit_log's own zero-policy
-- pattern). These are meant to run from a trusted, scheduled context
-- (a future admin/service-role-invoked Edge Function or a Supabase cron
-- job) — never from the Flutter app.
--
-- Documented scope decision (see supabase/README.md): ranking happens
-- across an entire league for the week/season, not subdivided into the
-- ~25-person weekly groups Item 9's product concept describes
-- (`mock_league_grouping_policy.dart`'s grouping was already flagged as
-- unmodeled server-side in Phase 10B, and remains so here) — a
-- league-wide ranking is the smallest correct superset of "rank
-- deterministically with the same tie-break rules," clearly reported
-- rather than silently assuming groups exist.

-- =======================================================================
-- Schema: one additive column, one new results table.
-- =======================================================================

alter table public.competition_seasons
  add column counted_week_count integer not null default 6;

alter table public.competition_seasons
  add constraint competition_seasons_counted_week_count_check
  check (counted_week_count > 0 and counted_week_count <= week_count);

comment on column public.competition_seasons.counted_week_count is
  'Best-N-of-M week count for season aggregation — the server-side '
  'counterpart to CompetitionScoringConstants.defaultSeasonCountedWeeks '
  '(6 of 8 by default), matching SeasonScoringPolicy.aggregate exactly.';

update public.competition_seasons set counted_week_count = 6 where stable_key = 'season-1';

create table public.competition_week_results (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  week_number integer not null,
  league_id uuid not null references public.league_definitions (id),
  rank integer not null,
  weekly_score numeric not null default 0,
  active_days integer not null default 0,
  average_difficulty numeric not null default 0,
  promotion_status text not null default 'safeZone',
  target_league_id uuid references public.league_definitions (id),
  computed_at timestamptz not null default timezone('utc', now()),

  constraint competition_week_results_unique unique (user_id, season_id, week_number),
  constraint competition_week_results_rank_positive check (rank > 0),
  constraint competition_week_results_promotion_status_check check (
    promotion_status in ('promotionZone', 'safeZone', 'demotionZone')
  )
);

comment on table public.competition_week_results is
  'Authoritative, idempotently-recomputed weekly ranking output of '
  'forge_finalize_season_week — one row per (user, season, week). '
  'Own-row SELECT only for clients; written exclusively by that '
  'SECURITY DEFINER function.';

create index competition_week_results_season_week_league_idx
  on public.competition_week_results (season_id, week_number, league_id);

alter table public.competition_week_results enable row level security;

create policy competition_week_results_select_own
  on public.competition_week_results
  for select
  to authenticated
  using (user_id = auth.uid());

-- =======================================================================
-- Helpers.
-- =======================================================================

-- Numeric weight mirroring MissionDifficultyLevel's declaration-order
-- `.index` (restorative=0 .. advanced=4) — the exact tie-break input
-- LeagueMovementPolicy.compareForRanking uses as "average difficulty".
create or replace function public.forge_difficulty_weight(p_difficulty text)
returns numeric
language sql
immutable
as $$
  select case p_difficulty
    when 'restorative' then 0
    when 'easy' then 1
    when 'moderate' then 2
    when 'challenging' then 3
    when 'advanced' then 4
    else 0
  end;
$$;

-- =======================================================================
-- forge_finalize_season_week — spec section 12.
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

  -- One league at a time, so promotion/demotion zone sizing (top-N/
  -- bottom-N of *this* league's ranked list) is computed against the
  -- right denominator — mirrors CompetitionRankingEngine.rank being
  -- called once per league in the Dart domain.
  for v_league in
    select * from public.league_definitions where active order by tier
  loop
    with participants as (
      select
        cm.user_id,
        coalesce(sum(csl.amount), 0) as weekly_score,
        count(distinct (csl.created_at at time zone 'utc')::date) as active_days,
        coalesce(avg(public.forge_difficulty_weight(
          coalesce(mi.resolved_difficulty, md.difficulty)
        )), 0) as average_difficulty,
        coalesce(max(csl.created_at), v_week.starts_at) as attained_at,
        cm.is_rookie,
        cm.rookie_protection_until
      from public.competition_memberships cm
      left join public.competition_score_ledger csl
        on csl.user_id = cm.user_id
        and csl.season_id = cm.season_id
        and csl.week_number = p_week_number
      left join public.mission_instances mi on mi.id = csl.mission_instance_id
      left join public.mission_definitions md on md.id = mi.mission_definition_id
      where cm.season_id = p_season_id and cm.league_id = v_league.id
      group by cm.user_id, cm.is_rookie, cm.rookie_protection_until
    ),
    ranked as (
      select
        p.*,
        row_number() over (
          order by
            p.weekly_score desc,
            p.active_days desc,
            p.average_difficulty desc,
            p.attained_at asc,
            p.user_id asc
        ) as rank,
        count(*) over () as total_count
      from participants p
    ),
    zoned as (
      select
        r.*,
        (r.rank <= v_league.promotion_count and v_league.promotion_count > 0
           and v_league.tier < (select max(tier) from public.league_definitions where active))
          as in_promotion_zone,
        (r.rank > r.total_count - v_league.demotion_count and v_league.demotion_count > 0
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
          select id from public.league_definitions
          where active and tier = v_league.tier + 1
        )
        when z.in_demotion_zone and not z.protected_this_week then (
          select id from public.league_definitions
          where active and tier = v_league.tier - 1
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
    jsonb_build_object('seasonId', p_season_id, 'weekNumber', p_week_number, 'rowsWritten', v_written));

  return v_written;
end;
$$;

revoke all on function public.forge_finalize_season_week(uuid, integer) from public;
-- Deliberately no grant to `authenticated` (or anyone else) at all —
-- see the migration header comment. Only service_role/a superuser-
-- equivalent migration/ops role can execute this.

-- =======================================================================
-- forge_finalize_season — spec section 13.
-- =======================================================================

create or replace function public.forge_finalize_season(p_season_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_season record;
  v_finalized_weeks integer;
  v_written integer := 0;
begin
  select * into v_season from public.competition_seasons where id = p_season_id;
  if not found then
    raise exception 'forge_finalize_season: no such season: %', p_season_id;
  end if;

  select count(distinct week_number) into v_finalized_weeks
  from public.competition_week_results where season_id = p_season_id;

  if v_finalized_weeks < v_season.week_count then
    raise exception
      'forge_finalize_season: incomplete season — % of % weeks finalized for season %. '
      'Run forge_finalize_season_week for every week first.',
      v_finalized_weeks, v_season.week_count, p_season_id;
  end if;

  with per_user_weeks as (
    select
      cwr.user_id,
      cwr.week_number,
      cwr.weekly_score,
      cwr.league_id,
      cwr.promotion_status,
      cwr.target_league_id,
      -- week_number as an explicit, deterministic tie-break (earlier
      -- week wins a tie) — required for "duplicate finalization safe"
      -- idempotent re-runs to always produce the identical result, not
      -- just a plausible one.
      row_number() over (
        partition by cwr.user_id order by cwr.weekly_score desc, cwr.week_number asc
      ) as score_rank,
      first_value(cwr.league_id) over (partition by cwr.user_id order by cwr.week_number asc) as start_league_id,
      first_value(cwr.league_id) over (partition by cwr.user_id order by cwr.week_number desc) as last_league_id,
      first_value(cwr.promotion_status) over (partition by cwr.user_id order by cwr.week_number desc) as last_status,
      first_value(cwr.target_league_id) over (partition by cwr.user_id order by cwr.week_number desc) as last_target_league_id
    from public.competition_week_results cwr
    where cwr.season_id = p_season_id
  ),
  aggregated as (
    select
      user_id,
      array_agg(week_number order by week_number) filter (where score_rank <= v_season.counted_week_count) as counted_weeks,
      array_agg(week_number order by week_number) filter (where score_rank > v_season.counted_week_count) as dropped_weeks,
      sum(weekly_score) filter (where score_rank <= v_season.counted_week_count) as total_season_score,
      -- max(uuid) has no built-in Postgres aggregate (uuid supports
      -- ordering comparisons but was never given min/max aggregates) —
      -- caught only by actually running this function for the first
      -- time. Every row within a user_id partition already carries an
      -- identical value here (each came from a first_value() window
      -- above), so this is purely "collapse N identical rows to one,"
      -- not a real ordering choice — max() over the text form achieves
      -- exactly that without needing a uuid max aggregate to exist.
      max(start_league_id::text)::uuid as start_league_id,
      max(last_league_id::text)::uuid as last_league_id,
      max(last_status) as last_status,
      max(last_target_league_id::text)::uuid as last_target_league_id
    from per_user_weeks
    group by user_id
  ),
  finalized as (
    select
      a.user_id,
      coalesce(a.total_season_score, 0) as total_season_score,
      coalesce(a.counted_weeks, '{}') as counted_weeks,
      coalesce(a.dropped_weeks, '{}') as dropped_weeks,
      case
        when a.last_status = 'promotionZone' and a.last_target_league_id is not null then a.last_target_league_id
        when a.last_status = 'demotionZone' and a.last_target_league_id is not null then a.last_target_league_id
        else a.last_league_id
      end as final_league_id,
      (a.start_league_id is distinct from (
        case
          when a.last_status = 'promotionZone' and a.last_target_league_id is not null then a.last_target_league_id
          when a.last_status = 'demotionZone' and a.last_target_league_id is not null then a.last_target_league_id
          else a.last_league_id
        end
      ) and a.last_status = 'promotionZone') as promoted,
      (a.start_league_id is distinct from (
        case
          when a.last_status = 'promotionZone' and a.last_target_league_id is not null then a.last_target_league_id
          when a.last_status = 'demotionZone' and a.last_target_league_id is not null then a.last_target_league_id
          else a.last_league_id
        end
      ) and a.last_status = 'demotionZone') as demoted
    from aggregated a
  ),
  ranked_final as (
    select
      f.*,
      row_number() over (
        partition by f.final_league_id
        order by f.total_season_score desc, f.user_id asc
      ) as rank_in_league
    from finalized f
  )
  insert into public.season_results (
    user_id, season_id, final_league_id, total_season_score,
    counted_weeks, dropped_weeks, rank_in_league, promoted, demoted
  )
  select
    rf.user_id, p_season_id, rf.final_league_id, rf.total_season_score,
    rf.counted_weeks, rf.dropped_weeks, rf.rank_in_league, rf.promoted, rf.demoted
  from ranked_final rf
  on conflict (user_id, season_id) do update set
    final_league_id = excluded.final_league_id,
    total_season_score = excluded.total_season_score,
    counted_weeks = excluded.counted_weeks,
    dropped_weeks = excluded.dropped_weeks,
    rank_in_league = excluded.rank_in_league,
    promoted = excluded.promoted,
    demoted = excluded.demoted,
    finalized_at = timezone('utc', now());

  get diagnostics v_written = row_count;

  -- Carry the final league placement forward onto this season's
  -- membership row (competition_memberships is season-scoped — see its
  -- own table comment) and audit every actual league change.
  update public.competition_memberships cm
  set league_id = sr.final_league_id
  from public.season_results sr
  where sr.season_id = p_season_id
    and cm.season_id = p_season_id
    and cm.user_id = sr.user_id
    and cm.league_id <> sr.final_league_id;

  insert into public.audit_log (actor_type, actor_id, action, target_type, target_id, metadata)
  select 'service', sr.user_id, 'league_assignment', 'user', sr.user_id::text,
    jsonb_build_object('seasonId', p_season_id, 'finalLeagueId', sr.final_league_id,
      'promoted', sr.promoted, 'demoted', sr.demoted)
  from public.season_results sr
  where sr.season_id = p_season_id and (sr.promoted or sr.demoted);

  update public.competition_seasons
  set status = 'completed'
  where id = p_season_id and status <> 'completed';

  insert into public.audit_log (actor_type, action, target_type, target_id, metadata)
  values ('service', 'season_finalization', 'competition_season', p_season_id::text,
    jsonb_build_object('participantsFinalized', v_written));

  return v_written;
end;
$$;

revoke all on function public.forge_finalize_season(uuid) from public;
-- Deliberately no grant to `authenticated` — see migration header.

revoke all on function public.forge_difficulty_weight(text) from public;

-- =======================================================================
-- Public-safe leaderboard read model — spec section 15. Only fields
-- suitable for leaderboard UI; never integrity signals, recovery data,
-- mission history, reflections, or any other private behavioral data.
-- Views run with their creating role's privileges by default in
-- Postgres (not the querying role's), which is exactly what lets a
-- narrow, explicitly-column-limited view safely read across users from
-- otherwise own-row-only tables (profiles, season_results,
-- competition_week_results) — the safety comes from which columns this
-- view selects, not from bypassing RLS by accident.
-- =======================================================================

create view public.competition_public_season_leaderboard as
select
  sr.season_id,
  sr.final_league_id,
  ld.name as league_name,
  sr.rank_in_league,
  sr.total_season_score as confirmed_score,
  sr.promoted,
  sr.demoted,
  p.display_name,
  p.avatar_path
from public.season_results sr
join public.league_definitions ld on ld.id = sr.final_league_id
join public.profiles p on p.user_id = sr.user_id;

comment on view public.competition_public_season_leaderboard is
  'Public-safe: display_name, avatar_path, league, confirmed season '
  'score, rank. Never integrity signals, recovery data, mission '
  'history, reflections, or email. Source tables stay own-row-only for '
  'direct client access — only this narrow, explicit column list is '
  'ever exposed cross-user.';

create view public.competition_public_weekly_leaderboard as
select
  cwr.season_id,
  cwr.week_number,
  cwr.league_id,
  ld.name as league_name,
  cwr.rank,
  cwr.weekly_score as confirmed_score,
  cwr.promotion_status,
  p.display_name,
  p.avatar_path
from public.competition_week_results cwr
join public.league_definitions ld on ld.id = cwr.league_id
join public.profiles p on p.user_id = cwr.user_id;

comment on view public.competition_public_weekly_leaderboard is
  'Public-safe weekly counterpart to competition_public_season_'
  'leaderboard — same column-exposure discipline. Never active_days-'
  'derived personal-habit inferences beyond what already appears in the '
  'existing local Dart LeaderboardEntry shape.';

grant select on public.competition_public_season_leaderboard to authenticated;
grant select on public.competition_public_weekly_leaderboard to authenticated;
