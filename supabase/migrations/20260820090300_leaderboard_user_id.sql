-- Phase 11: expose user_id on the public leaderboard views (spec
-- section 9: "current user visibly identified"). A bare uuid is not
-- itself private — RLS already lets any row's existence, display_name,
-- and score be read by any authenticated user via these views; adding
-- user_id only lets the Flutter client compare a row against its own
-- session id to highlight "you," nothing more. Uses CREATE OR REPLACE
-- VIEW (legal in Postgres only for *appending trailing* columns — an
-- existing column cannot be reordered, renamed, or dropped this way, so
-- user_id is added as the LAST column of each SELECT list below, after
-- every column the original view already had, in its original order.
-- PostgREST/the Dart row mapper both read columns by name, not
-- position, so trailing placement has no client-side effect. The
-- original migration files themselves are untouched.

create or replace view public.competition_public_season_leaderboard as
select
  sr.season_id,
  sr.final_league_id,
  ld.name as league_name,
  sr.rank_in_league,
  sr.total_season_score as confirmed_score,
  sr.promoted,
  sr.demoted,
  p.display_name,
  p.avatar_path,
  sr.user_id
from public.season_results sr
join public.league_definitions ld on ld.id = sr.final_league_id
join public.profiles p on p.user_id = sr.user_id;

create or replace view public.competition_public_weekly_leaderboard as
select
  cwr.season_id,
  cwr.week_number,
  cwr.league_id,
  ld.name as league_name,
  cwr.rank,
  cwr.weekly_score as confirmed_score,
  cwr.promotion_status,
  p.display_name,
  p.avatar_path,
  cwr.user_id
from public.competition_week_results cwr
join public.league_definitions ld on ld.id = cwr.league_id
join public.profiles p on p.user_id = cwr.user_id;

create or replace view public.competition_public_group_standings as
select
  cg.season_id,
  cg.week_number,
  cg.league_id,
  cg.group_number,
  cwr.rank,
  cwr.weekly_score as confirmed_score,
  cwr.promotion_status,
  p.display_name,
  p.avatar_path,
  cgm.user_id
from public.competition_groups cg
join public.competition_group_members cgm on cgm.group_id = cg.id
join public.competition_week_results cwr
  on cwr.user_id = cgm.user_id and cwr.season_id = cg.season_id and cwr.week_number = cg.week_number
join public.profiles p on p.user_id = cgm.user_id;
