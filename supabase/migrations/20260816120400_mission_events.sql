-- Phase 10B: mission_events — the append-only event ledger a mission
-- instance's full history is reconstructed from, mirroring the Dart
-- domain's own event-sourced `MissionAggregate` (see
-- lib/features/missions/domain/events/). `command_id`/`idempotency_key`/
-- `sequence` map directly onto Phase 10A's `BackendCommand` fields —
-- see supabase/README.md for the exact mapping.
--
-- This table is append-only by design: no update policy, no delete
-- policy, and the unique constraints below make replay/duplicate
-- insertion fail loudly rather than silently corrupt history.

create table public.mission_events (
  id uuid primary key default extensions.gen_random_uuid(),
  mission_instance_id uuid not null references public.mission_instances (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  command_id text not null,
  idempotency_key text not null,
  sequence integer not null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  received_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),

  constraint mission_events_sequence_positive check (sequence > 0),
  constraint mission_events_command_id_unique unique (command_id),
  constraint mission_events_idempotency_key_unique unique (idempotency_key),
  constraint mission_events_instance_sequence_unique
    unique (mission_instance_id, sequence),
  constraint mission_events_event_type_check check (
    event_type in (
      'assigned', 'viewed', 'accepted', 'started', 'progress_updated',
      'paused', 'resumed', 'submitted', 'validation_passed',
      'validation_failed', 'completed', 'completion_undone', 'rejected',
      'easier_requested', 'category_change_requested', 'abandoned',
      'expired', 'sync_queued', 'sync_confirmed', 'sync_failed'
    )
  )
);

comment on table public.mission_events is
  'Append-only event ledger. command_id and idempotency_key are '
  'globally unique; (mission_instance_id, sequence) is unique — a '
  'replayed or duplicate command fails the insert rather than being '
  'silently accepted twice. No client UPDATE/DELETE policy exists.';

create index mission_events_mission_instance_id_idx
  on public.mission_events (mission_instance_id);
create index mission_events_user_id_idx on public.mission_events (user_id);
create index mission_events_idempotency_key_idx
  on public.mission_events (idempotency_key);

-- Ownership consistency: a mission_events row's user_id must match the
-- owning mission_instances row's user_id — spec section 6. Enforced as
-- a trigger rather than a CHECK constraint because Postgres CHECK
-- constraints cannot reference another table.
create or replace function public.forge_guard_mission_event_ownership()
returns trigger
language plpgsql
as $$
declare
  instance_owner uuid;
begin
  select user_id into instance_owner
  from public.mission_instances
  where id = new.mission_instance_id;

  if instance_owner is null then
    raise exception 'mission_instances % does not exist', new.mission_instance_id;
  end if;

  if instance_owner <> new.user_id then
    raise exception
      'mission_events.user_id (%) does not match mission_instances owner (%) for mission %',
      new.user_id, instance_owner, new.mission_instance_id;
  end if;

  return new;
end;
$$;

create trigger mission_events_guard_ownership
  before insert on public.mission_events
  for each row
  execute function public.forge_guard_mission_event_ownership();

alter table public.mission_events enable row level security;

-- Read/insert own rows only. Deliberately no update or delete policy —
-- under RLS, the absence of a policy for an operation denies it by
-- default, which is exactly the "append-only" behavior this table needs.
create policy mission_events_select_own
  on public.mission_events
  for select
  to authenticated
  using (user_id = auth.uid());

create policy mission_events_insert_own
  on public.mission_events
  for insert
  to authenticated
  with check (user_id = auth.uid());
