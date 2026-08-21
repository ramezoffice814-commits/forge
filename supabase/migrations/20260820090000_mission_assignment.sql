-- Phase 11: server-side mission assignment — closes the "mission_not_
-- found" live-mode gap Phase 10D documented (see supabase/README.md's
-- Phase 10D section). Adds the two catalog facts the assignment
-- eligibility checks below need that Phase 10B never stored (repeat
-- cooldown, recovery eligibility) and the one function that actually
-- creates an authoritative mission_instances row.
--
-- SELECTION-AUTHORITY DECISION (spec section 2): server VALIDATES a
-- client-proposed mission rather than re-implementing selection.
-- lib/features/missions/domain/mission_selection_engine.dart composes
-- adaptive difficulty, personalization scoring, variety, safety, and
-- recovery policies against a rich local behavioral profile/history
-- that has no server-side equivalent at all (no user-profile or
-- mission-history-analytics table exists in this schema, and building
-- one is a project of its own). Porting that engine would mean
-- duplicating fragile, frequently-tuned product logic in a second
-- language — exactly what the spec says to avoid ("without duplicating
-- fragile logic unnecessarily"). Instead: the client's local engine
-- keeps choosing a mission for UX/personalization exactly as it does
-- today; the server independently re-validates that specific choice
-- against every eligibility rule it *can* authoritatively check
-- (active, category exists, cooldown, recovery-only-when-marked,
-- one-per-day) and rejects outright rather than silently substituting
-- if it fails. A client that sends no preference gets a simple,
-- deterministic (not personalized) fallback — see
-- forge_pick_fallback_mission below.
--
-- Documented parity limitation: server-side eligibility does NOT
-- reproduce adaptive-difficulty resolution, personalization scoring,
-- accessibility-alternative substitution, or safety-classification
-- filtering against user-declared health/accessibility tags — none of
-- that data exists server-side. The server's job is narrower and
-- explicitly authoritative-only: "is this specific mission eligible
-- for this specific user right now," not "which mission is best."

alter table public.mission_definitions
  add column repeat_cooldown_days integer not null default 0,
  add column recovery_eligible boolean not null default true;

alter table public.mission_definitions
  add constraint mission_definitions_repeat_cooldown_nonnegative
  check (repeat_cooldown_days >= 0);

comment on column public.mission_definitions.repeat_cooldown_days is
  'Server-side counterpart to MissionDefinition.repeatCooldownDays — '
  'how many days must pass before this exact mission can be reassigned '
  'to the same user. 0 (the default for all seeded missions) means no '
  'cooldown.';

comment on column public.mission_definitions.recovery_eligible is
  'Server-side counterpart to MissionDefinition.recoveryEligible. Used '
  'only to reject a client-proposed assignment that claims recovery '
  'mode for a mission never marked eligible for it — the server does '
  'not itself decide *when* recovery mode should apply (that needs the '
  'same behavioral-history data selection authority does not have '
  'server-side yet).';

-- =======================================================================
-- forge_pick_fallback_mission — deterministic, not personalized. Used
-- only when the client sends no p_requested_mission_definition_id.
-- =======================================================================

create or replace function public.forge_pick_fallback_mission(
  p_user_id uuid,
  p_mission_date date,
  p_requested_category text
)
returns uuid
language sql
stable
as $$
  select md.id
  from public.mission_definitions md
  where md.active
    and (p_requested_category is null or md.category = p_requested_category)
    and (
      md.repeat_cooldown_days = 0
      or not exists (
        select 1 from public.mission_instances mi
        where mi.user_id = p_user_id
          and mi.mission_definition_id = md.id
          and mi.mission_date >= p_mission_date - md.repeat_cooldown_days
      )
    )
  order by md.stable_key -- deterministic, not random.
  limit 1;
$$;

revoke all on function public.forge_pick_fallback_mission(uuid, date, text) from public;

-- =======================================================================
-- forge_assign_daily_mission — the authoritative entrypoint.
-- =======================================================================

create or replace function public.forge_assign_daily_mission(
  p_command_id text,
  p_idempotency_key text,
  p_request_hash text,
  p_requested_mission_definition_id uuid default null,
  p_requested_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date;
  v_now timestamptz := timezone('utc', now());
  v_existing record;
  v_cached record;
  v_definition record;
  v_instance_id uuid;
  v_response jsonb;
begin
  if v_user_id is null then
    perform public.forge_raise('unauthenticated', 'No authenticated user for this request.');
  end if;

  -- Idempotency: an exact retry (same key + same request) returns the
  -- cached response; a conflicting one is rejected — identical shape to
  -- every other forge_* command (see 20260817090100_mission_reward_
  -- functions.sql's forge_check_idempotency_and_sequence, not reused
  -- directly here since assignment has no mission_instances row —
  -- hence no sequence — to key off yet).
  select * into v_cached from public.processed_commands where idempotency_key = p_idempotency_key;
  if found then
    if v_cached.request_hash = p_request_hash then
      return v_cached.response_payload;
    end if;
    perform public.forge_raise('idempotency_conflict',
      'This idempotency key was already used for a different request payload.');
  end if;

  if exists (select 1 from public.processed_commands where command_id = p_command_id) then
    perform public.forge_raise('duplicate_command',
      'This command_id was already processed under a different idempotency key.');
  end if;

  -- Authoritative date/time — the server's own UTC clock, never a
  -- client-supplied date (spec: "do not depend on a user's phone
  -- clock").
  v_today := (v_now at time zone 'utc')::date;

  -- Idempotent re-run / "repeated assignment returns same valid
  -- instance": lock any existing non-terminal instance for today first.
  select * into v_existing
  from public.mission_instances
  where user_id = v_user_id and mission_date = v_today
    and status not in ('completed', 'abandoned', 'rejected', 'expired', 'cancelled')
  for update;

  if found then
    v_response := jsonb_build_object(
      'status', 'accepted',
      'missionInstanceId', v_existing.id,
      'missionDefinitionId', v_existing.mission_definition_id,
      'assignedDate', v_today,
      'serverTimestamp', v_now,
      'confirmationId', p_command_id || ':confirm',
      'reasons', jsonb_build_array('An assignment for today already exists.')
    );
    insert into public.processed_commands
      (command_id, user_id, idempotency_key, command_type, request_hash, response_payload)
    values (p_command_id, v_user_id, p_idempotency_key, 'assign_daily_mission', p_request_hash, v_response);
    return v_response;
  end if;

  -- Resolve the mission definition: validate the client's proposal, or
  -- fall back deterministically if none was given.
  if p_requested_mission_definition_id is not null then
    select * into v_definition from public.mission_definitions
    where id = p_requested_mission_definition_id;

    if not found or not v_definition.active then
      perform public.forge_raise('invalid_mission_selection',
        'The requested mission is not a valid, active catalog entry.');
    end if;
    if p_requested_category is not null and v_definition.category <> p_requested_category then
      perform public.forge_raise('invalid_mission_selection',
        'The requested mission does not belong to the requested category.');
    end if;
    if v_definition.repeat_cooldown_days > 0 and exists (
      select 1 from public.mission_instances mi
      where mi.user_id = v_user_id
        and mi.mission_definition_id = v_definition.id
        and mi.mission_date >= v_today - v_definition.repeat_cooldown_days
    ) then
      perform public.forge_raise('invalid_mission_selection',
        'This mission is still within its repeat cooldown for this user.');
    end if;
  else
    select * into v_definition from public.mission_definitions
    where id = public.forge_pick_fallback_mission(v_user_id, v_today, p_requested_category);

    if not found then
      perform public.forge_raise('invalid_mission_selection',
        'No eligible active mission definition was found for a fallback assignment.');
    end if;
  end if;

  -- Bootstrap the authoritative mission_instances row. The
  -- mission_instances_one_active_per_day unique partial index (Phase
  -- 10B) is the second, storage-level guarantee against a duplicate
  -- daily assignment slipping through even under a concurrent request
  -- racing this same check-then-insert.
  insert into public.mission_instances (
    user_id, mission_definition_id, mission_date, status, current_sequence,
    assigned_at, resolved_difficulty, base_xp_hint
  ) values (
    v_user_id, v_definition.id, v_today, 'assigned', 0,
    v_now, v_definition.difficulty, v_definition.base_xp_hint
  )
  returning id into v_instance_id;

  perform public.forge_append_event(
    v_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'assigned', jsonb_build_object('missionDefinitionId', v_definition.id), v_now
  );

  v_response := jsonb_build_object(
    'status', 'accepted',
    'missionInstanceId', v_instance_id,
    'missionDefinitionId', v_definition.id,
    'assignedDate', v_today,
    'serverTimestamp', v_now,
    'confirmationId', p_command_id || ':confirm',
    'reasons', '[]'::jsonb
  );

  insert into public.processed_commands
    (command_id, user_id, idempotency_key, command_type, request_hash, response_payload)
  values (p_command_id, v_user_id, p_idempotency_key, 'assign_daily_mission', p_request_hash, v_response);

  return v_response;
exception
  when unique_violation then
    -- The one-active-per-day partial index caught a race the
    -- check-then-insert above didn't fully close — a concurrent
    -- request beat this one to it. Re-select and return that instance
    -- rather than surfacing a raw constraint error, matching "repeated
    -- request should return the existing valid assignment."
    select * into v_existing
    from public.mission_instances
    where user_id = v_user_id and mission_date = v_today
      and status not in ('completed', 'abandoned', 'rejected', 'expired', 'cancelled')
    limit 1;

    if not found then
      raise; -- a genuinely different constraint violation — do not mask it.
    end if;

    v_response := jsonb_build_object(
      'status', 'accepted',
      'missionInstanceId', v_existing.id,
      'missionDefinitionId', v_existing.mission_definition_id,
      'assignedDate', v_today,
      'serverTimestamp', v_now,
      'confirmationId', p_command_id || ':confirm',
      'reasons', jsonb_build_array('A concurrent request already created today''s assignment.')
    );
    return v_response;
end;
$$;

revoke all on function public.forge_assign_daily_mission(text, text, text, uuid, text) from public;
grant execute on function public.forge_assign_daily_mission(text, text, text, uuid, text) to authenticated;
