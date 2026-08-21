-- Phase 10B: competition/league persistence — the durable backing for
-- the existing Item 9 Dart domain model (lib/features/competition/).
-- Lifetime XP (xp_ledger/user_progression) stays completely separate
-- from competitive score here, matching the Dart domain's own core rule
-- that competitive rank is never derived from lifetime XP.
--
-- Real leaderboard computation and real promotion/demotion logic are
-- explicitly out of scope for this phase (see task scope). What exists
-- here is storage + ownership + duplicate-prevention only: every
-- server-authoritative field (score, league, promotion/demotion,
-- season result) has no client write policy at all.
--
-- Scope note: a public, cross-user "who's in my league group this week"
-- read path is deliberately NOT built in this migration — building it
-- correctly requires a weekly grouping concept this phase doesn't model
-- yet, and a half-correct public read (e.g. leaking a full league's
-- membership instead of just one ~25-person weekly group) would be a
-- worse privacy outcome than deferring it. See supabase/README.md.

create table public.competition_seasons (
  id uuid primary key default extensions.gen_random_uuid(),
  stable_key text not null unique,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'upcoming',
  week_count integer not null,
  scoring_version integer not null default 1,
  league_rules_version integer not null default 1,
  promotion_rules_version integer not null default 1,
  active boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint competition_seasons_status_check check (
    status in ('upcoming', 'active', 'completed', 'archived')
  ),
  constraint competition_seasons_week_count_positive check (week_count > 0),
  constraint competition_seasons_dates_check check (ends_at > starts_at)
);

comment on table public.competition_seasons is
  'System-managed season catalog. Explicit UTC boundaries — never '
  'derived from a device timezone. Read-only for clients.';

create trigger competition_seasons_set_updated_at
  before update on public.competition_seasons
  for each row
  execute function public.forge_set_updated_at();

alter table public.competition_seasons enable row level security;

create policy competition_seasons_select_all
  on public.competition_seasons
  for select
  to authenticated
  using (true);

create table public.competition_weeks (
  id uuid primary key default extensions.gen_random_uuid(),
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  week_number integer not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'upcoming',
  created_at timestamptz not null default timezone('utc', now()),

  constraint competition_weeks_status_check check (
    status in ('upcoming', 'active', 'completed')
  ),
  constraint competition_weeks_number_positive check (week_number > 0),
  constraint competition_weeks_dates_check check (ends_at > starts_at),
  constraint competition_weeks_unique_number unique (season_id, week_number)
);

comment on table public.competition_weeks is
  'One row per (season, week_number). Explicit UTC boundaries, '
  'read-only for clients.';

create index competition_weeks_season_id_idx on public.competition_weeks (season_id);

alter table public.competition_weeks enable row level security;

create policy competition_weeks_select_all
  on public.competition_weeks
  for select
  to authenticated
  using (true);

create table public.league_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  stable_key text not null unique,
  name text not null,
  tier integer not null,
  min_placement_rating integer not null default 0,
  max_group_size integer not null default 25,
  promotion_count integer not null default 0,
  demotion_count integer not null default 0,
  protected_placement_days integer not null default 7,
  visual_tier integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint league_definitions_unique_tier unique (tier)
);

comment on table public.league_definitions is
  'System-managed league catalog (Ember..Mythic). Read-only for '
  'clients — promotion/demotion counts and thresholds are catalog data, '
  'never client-writable.';

create trigger league_definitions_set_updated_at
  before update on public.league_definitions
  for each row
  execute function public.forge_set_updated_at();

alter table public.league_definitions enable row level security;

create policy league_definitions_select_active
  on public.league_definitions
  for select
  to authenticated
  using (active);

create table public.competition_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  league_id uuid not null references public.league_definitions (id),
  is_rookie boolean not null default true,
  rookie_protection_until timestamptz,
  joined_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint competition_memberships_unique_per_season unique (user_id, season_id)
);

comment on table public.competition_memberships is
  'A user''s current league standing for a season — server-authoritative. '
  'Own-row SELECT only; no client INSERT/UPDATE/DELETE policy exists. '
  'League placement/movement is decided by a future server process only.';

create index competition_memberships_user_id_idx
  on public.competition_memberships (user_id);
create index competition_memberships_season_league_idx
  on public.competition_memberships (season_id, league_id);

create trigger competition_memberships_set_updated_at
  before update on public.competition_memberships
  for each row
  execute function public.forge_set_updated_at();

alter table public.competition_memberships enable row level security;

create policy competition_memberships_select_own
  on public.competition_memberships
  for select
  to authenticated
  using (user_id = auth.uid());

create table public.competition_score_ledger (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  week_number integer not null,
  mission_instance_id uuid references public.mission_instances (id) on delete set null,
  source_type text not null,
  source_id text not null,
  amount numeric not null,
  created_at timestamptz not null default timezone('utc', now()),

  constraint competition_score_ledger_week_positive check (week_number > 0),
  constraint competition_score_ledger_source_type_check check (
    source_type in ('mission_completion', 'consistency_bonus', 'adjustment')
  ),
  -- Same duplicate-prevention shape as xp_ledger: one score grant per
  -- source, ever.
  constraint competition_score_ledger_source_unique unique (source_type, source_id)
);

comment on table public.competition_score_ledger is
  'Authoritative, append-only competitive-score ledger — completely '
  'separate from xp_ledger (lifetime XP never determines competitive '
  'rank). unique(source_type, source_id) prevents duplicate scoring. '
  'Own-row SELECT only; no client write policy exists.';

create index competition_score_ledger_user_season_week_idx
  on public.competition_score_ledger (user_id, season_id, week_number);

alter table public.competition_score_ledger enable row level security;

create policy competition_score_ledger_select_own
  on public.competition_score_ledger
  for select
  to authenticated
  using (user_id = auth.uid());

create table public.season_results (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  season_id uuid not null references public.competition_seasons (id) on delete cascade,
  final_league_id uuid not null references public.league_definitions (id),
  total_season_score numeric not null default 0,
  counted_weeks integer[] not null default '{}',
  dropped_weeks integer[] not null default '{}',
  rank_in_league integer,
  promoted boolean not null default false,
  demoted boolean not null default false,
  finalized_at timestamptz not null default timezone('utc', now()),

  constraint season_results_unique_per_season unique (user_id, season_id)
);

comment on table public.season_results is
  'Finalized, server-authoritative season outcome — written once by a '
  'future season-finalization process. Own-row SELECT only; no client '
  'write policy exists.';

create index season_results_user_id_idx on public.season_results (user_id);
create index season_results_season_id_idx on public.season_results (season_id);

alter table public.season_results enable row level security;

create policy season_results_select_own
  on public.season_results
  for select
  to authenticated
  using (user_id = auth.uid());
