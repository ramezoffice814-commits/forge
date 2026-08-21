-- Phase 10B: mission_definitions — the mission catalog. System-managed
-- content: normal clients may read active definitions, never write them.
-- (Content authoring is out of scope for this phase — a future
-- service-role/admin tool or migration/seed is the only writer.)

create table public.mission_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  stable_key text not null unique,
  title text not null,
  description text not null,
  category text not null,
  difficulty text not null,
  expected_duration_minutes integer not null,
  active boolean not null default true,
  rules jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint mission_definitions_category_check check (
    category in (
      'fitness', 'coding', 'reading', 'learning', 'mindfulness',
      'hydration', 'planning', 'focus', 'sleep_routine', 'recovery',
      'creative', 'social_wellbeing'
    )
  ),
  constraint mission_definitions_difficulty_check check (
    difficulty in (
      'restorative', 'easy', 'moderate', 'challenging', 'advanced'
    )
  ),
  constraint mission_definitions_duration_check check (
    expected_duration_minutes > 0 and expected_duration_minutes <= 240
  )
);

comment on table public.mission_definitions is
  'System-managed mission catalog. Clients may SELECT active rows only; '
  'no client INSERT/UPDATE/DELETE policy exists at all.';

create index mission_definitions_active_idx
  on public.mission_definitions (active)
  where active;

create trigger mission_definitions_set_updated_at
  before update on public.mission_definitions
  for each row
  execute function public.forge_set_updated_at();

alter table public.mission_definitions enable row level security;

-- Read-only, active rows only. No insert/update/delete policy for any
-- client role — content changes go through migrations/seed data or a
-- future service-role authoring tool, never the `authenticated` role.
create policy mission_definitions_select_active
  on public.mission_definitions
  for select
  to authenticated
  using (active);
