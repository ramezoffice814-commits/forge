-- Phase 10B: achievement_definitions (system-managed catalog) and
-- user_achievements (server-authoritative unlock record). Mirrors the
-- xp_ledger trust shape: clients read, never self-award.

create table public.achievement_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  stable_key text not null unique,
  title text not null,
  description text not null,
  criteria jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.achievement_definitions is
  'System-managed achievement catalog. Read-only for clients, same '
  'shape as mission_definitions.';

create index achievement_definitions_active_idx
  on public.achievement_definitions (active)
  where active;

create trigger achievement_definitions_set_updated_at
  before update on public.achievement_definitions
  for each row
  execute function public.forge_set_updated_at();

alter table public.achievement_definitions enable row level security;

create policy achievement_definitions_select_active
  on public.achievement_definitions
  for select
  to authenticated
  using (active);

create table public.user_achievements (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id uuid not null references public.achievement_definitions (id),
  source_type text not null,
  source_id text,
  unlocked_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),

  -- A user can unlock a given achievement at most once, ever — the
  -- concrete mechanism behind "prevent duplicate unlocks".
  constraint user_achievements_unique_per_user unique (user_id, achievement_id)
);

comment on table public.user_achievements is
  'Server-authoritative unlock record. unique(user_id, achievement_id) '
  'prevents duplicate unlocks. Clients may SELECT their own rows only — '
  'no INSERT/UPDATE/DELETE policy exists, so self-awarding is '
  'structurally impossible, not just discouraged.';

create index user_achievements_user_id_idx on public.user_achievements (user_id);

alter table public.user_achievements enable row level security;

create policy user_achievements_select_own
  on public.user_achievements
  for select
  to authenticated
  using (user_id = auth.uid());
