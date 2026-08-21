-- Phase 10B: mission_instances — one mission assigned to one user for one
-- day. Holds lifecycle/status only — never a reward field (XP lives
-- exclusively in xp_ledger, see 20260816120600). This phase enforces
-- ownership and structural invariants (valid status, non-decreasing
-- sequence, at most one active mission per day); full transition-legality
-- validation (e.g. "assigned can't jump straight to completed") is
-- deliberately deferred to a future authoritative Edge Function per
-- spec section 15 — this migration proves the schema, not the engine.

create table public.mission_instances (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  mission_definition_id uuid not null references public.mission_definitions (id),
  mission_date date not null,
  status text not null default 'assigned',
  current_sequence integer not null default 0,
  assigned_at timestamptz not null default timezone('utc', now()),
  started_at timestamptz,
  submitted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint mission_instances_status_check check (
    status in (
      'assigned', 'accepted', 'active', 'paused', 'submitted',
      'completed', 'abandoned', 'rejected', 'expired', 'cancelled'
    )
  ),
  constraint mission_instances_sequence_check check (current_sequence >= 0)
);

comment on table public.mission_instances is
  'One mission assigned to one user for one day. No reward field lives '
  'here — see xp_ledger. Ownership + shape enforced here; full '
  'transition-legality validation is a future Edge Function.';

-- At most one non-terminal ("still in play") mission instance per user
-- per calendar day — spec: "prevent impossible duplicate active daily
-- mission situations".
create unique index mission_instances_one_active_per_day
  on public.mission_instances (user_id, mission_date)
  where status not in ('completed', 'abandoned', 'rejected', 'expired', 'cancelled');

create index mission_instances_user_id_idx on public.mission_instances (user_id);
create index mission_instances_status_idx on public.mission_instances (status);
create index mission_instances_mission_date_idx on public.mission_instances (mission_date);

create trigger mission_instances_set_updated_at
  before update on public.mission_instances
  for each row
  execute function public.forge_set_updated_at();

-- Sequence must never silently move backwards (spec section 5). A stale
-- or replayed update attempting to lower it is rejected outright rather
-- than silently clamped, so a bug surfaces immediately instead of
-- quietly corrupting ordering.
create or replace function public.forge_guard_mission_sequence()
returns trigger
language plpgsql
as $$
begin
  if new.current_sequence < old.current_sequence then
    raise exception
      'mission_instances.current_sequence cannot move backwards (% -> %) for mission %',
      old.current_sequence, new.current_sequence, old.id;
  end if;
  return new;
end;
$$;

create trigger mission_instances_guard_sequence
  before update on public.mission_instances
  for each row
  execute function public.forge_guard_mission_sequence();

alter table public.mission_instances enable row level security;

-- Ownership-scoped read/insert/update. No delete policy at all —
-- mission history is never deleted by a client (spec section 16:
-- "reward/audit history should not disappear casually").
create policy mission_instances_select_own
  on public.mission_instances
  for select
  to authenticated
  using (user_id = auth.uid());

create policy mission_instances_insert_own
  on public.mission_instances
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy mission_instances_update_own
  on public.mission_instances
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
