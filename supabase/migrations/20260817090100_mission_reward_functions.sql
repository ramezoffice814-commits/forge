-- Phase 10C: the authoritative mission-command transaction pipeline.
--
-- Every function below is SECURITY DEFINER and derives the acting user
-- exclusively from auth.uid() — never from a parameter, so there is no
-- argument a caller could pass to impersonate another user. This is the
-- one place mission commands actually take effect: accept/start/
-- record-progress/submit/cancel are all single PL/pgSQL function calls,
-- and a single function call is one implicit Postgres transaction — an
-- unhandled exception anywhere inside rolls back everything the call did
-- (spec section 6: "if any critical step fails: ROLLBACK. Do not leave
-- partially awarded XP."). Ownership locking (`... for update`) plus the
-- unique constraints Phase 10B already created are what make concurrent
-- double-submission produce at most one reward (spec section 7) — this
-- migration adds no new concurrency primitive beyond those two.
--
-- Naming convention for the jsonb envelope every command function
-- returns/raises: on success, a jsonb object shaped like the matching
-- Phase 10A response contract (see lib/core/backend/responses/). On
-- failure, an exception whose message is 'error_code|human message' —
-- the paired Edge Function catches it and maps error_code to the stable
-- codes in section 21 of the spec (see supabase/functions/_shared/
-- errors.ts). Postgres already gives every RAISE EXCEPTION an implicit
-- ROLLBACK of the current function call, so this doubles as the
-- transaction-failure mechanism, not just error reporting.
--
-- Two separate "sequence" concepts coexist deliberately:
--   - mission_instances.current_sequence is the COMMAND sequence — it
--     matches Phase 10A's BackendCommand.sequence exactly (one
--     increment per accepted command: accept=1, start=2, progress=3,
--     submit=4, ...). This is what stale/out-of-order rejection is
--     checked against.
--   - mission_events.sequence is the EVENT-LOG sequence Phase 10B
--     already defined (one increment per appended row). A single
--     submit-mission command can append 2-3 events (submitted, then
--     either validation_failed, or validation_passed+completed) —
--     exactly mirroring SubmitMissionUseCase's own Dart behavior — so
--     it advances by more than the command sequence does. See
--     supabase/README.md for the full mapping.

-- =======================================================================
-- Section 1: pure helper functions (XP/level/streak/validation/scoring).
-- None of these are directly callable by `authenticated` — only the
-- command functions in Section 3 call them internally.
-- =======================================================================

-- Mirrors LevelCatalog._requiredXpFor exactly (lib/features/progression/
-- data/catalog/level_catalog.dart): a smooth formula, not a lookup
-- table, capped at the same 30-level ladder.
create or replace function public.forge_xp_required_for_level(p_level integer)
returns bigint
language sql
immutable
as $$
  select case
    when p_level <= 1 then 0::bigint
    else (25 * (least(p_level, 30) - 1) * least(p_level, 30))::bigint
  end;
$$;

-- Mirrors LevelPolicy.levelFor: the highest level (1..30) whose
-- required XP is met by p_xp.
create or replace function public.forge_level_for_xp(p_xp bigint)
returns integer
language sql
immutable
as $$
  select coalesce(
    (select max(lvl) from generate_series(1, 30) as lvl
     where public.forge_xp_required_for_level(lvl) <= p_xp),
    1
  );
$$;

-- Mirrors CategoryMasteryThresholds.tierFor + XpCalculationPolicy's
-- _categoryTierMultipliers map (0/5/15/30 completions ->
-- 1.0/1.05/1.1/1.15).
create or replace function public.forge_category_tier_multiplier(p_prior_completions integer)
returns numeric
language sql
immutable
as $$
  select case
    when p_prior_completions >= 30 then 1.15
    when p_prior_completions >= 15 then 1.10
    when p_prior_completions >= 5  then 1.05
    else 1.00
  end;
$$;

-- Mirrors XpCalculationPolicy.evaluate end to end. Every intermediate
-- value is carried in the returned breakdown, same philosophy as the
-- Dart XpRewardEvaluation type (every factor explainable, never a black
-- box). xp_policy_v1 — bump the version string if this formula changes.
create or replace function public.forge_calculate_xp_reward(
  p_difficulty text,
  p_recovery boolean,
  p_base_xp_hint integer,
  p_prior_category_completions integer,
  p_streak_days integer,
  p_recent_same_definition_count integer,
  p_xp_already_earned_today integer
)
returns table(final_xp integer, breakdown jsonb)
language plpgsql
immutable
as $$
declare
  v_difficulty_mult numeric;
  v_category_mult numeric;
  v_subtotal numeric;
  v_consistency_bonus integer;
  v_recovery_bonus integer;
  v_pre_diminish integer;
  v_diminish_factor numeric;
  v_post_diminish integer;
  v_diminish_penalty integer;
  v_final integer;
  v_remaining_daily integer;
  v_capped_by_daily boolean := false;
  v_capped_by_mission boolean := false;
begin
  v_difficulty_mult := case p_difficulty
    when 'restorative' then 0.6
    when 'easy' then 1.0
    when 'moderate' then 1.3
    when 'challenging' then 1.6
    when 'advanced' then 2.0
    else 1.0
  end;

  v_category_mult := public.forge_category_tier_multiplier(p_prior_category_completions);

  v_subtotal := round(p_base_xp_hint * v_difficulty_mult * v_category_mult);
  v_consistency_bonus := least(greatest(p_streak_days * 2, 0), 20);
  v_recovery_bonus := case when p_recovery then 10 else 0 end;
  v_pre_diminish := (v_subtotal + v_consistency_bonus + v_recovery_bonus)::integer;

  v_diminish_factor := case
    when p_recent_same_definition_count <= 0 then 1.0
    else greatest(least(1.0 / (1 + 0.5 * p_recent_same_definition_count), 1.0), 0.2)
  end;
  v_post_diminish := round(v_pre_diminish * v_diminish_factor)::integer;
  v_diminish_penalty := v_post_diminish - v_pre_diminish;

  v_final := least(greatest(v_post_diminish, 0), 100);
  if v_post_diminish > 100 then v_capped_by_mission := true; end if;

  v_remaining_daily := least(greatest(300 - p_xp_already_earned_today, 0), 300);
  if v_final > v_remaining_daily then
    v_final := v_remaining_daily;
    v_capped_by_daily := true;
  end if;

  return query select
    v_final,
    jsonb_build_object(
      'policyVersion', 'xp_policy_v1',
      'baseXp', p_base_xp_hint,
      'difficultyMultiplier', v_difficulty_mult,
      'categoryMultiplier', v_category_mult,
      'consistencyBonus', v_consistency_bonus,
      'recoveryBonus', v_recovery_bonus,
      'diminishingReturnsFactor', v_diminish_factor,
      'diminishingPenalty', v_diminish_penalty,
      'cappedByPerMissionLimit', v_capped_by_mission,
      'cappedByDailyLimit', v_capped_by_daily,
      'finalXp', v_final
    );
end;
$$;

-- Mirrors MissionHistorySnapshotBuilder's `_streaks` (current streak
-- half only — that's all the XP formula needs): consecutive UTC
-- calendar days of completed missions, counting back from p_as_of's
-- day (or the day before, so a streak "in progress" isn't reset by
-- finishing today), broken by any gap.
create or replace function public.forge_current_streak_days(
  p_user_id uuid,
  p_as_of timestamptz,
  p_exclude_mission_instance_id uuid default null
)
returns integer
language plpgsql
stable
as $$
declare
  v_today date := (p_as_of at time zone 'utc')::date;
  v_dates date[];
  v_len integer;
  v_gap integer;
  v_current integer := 1;
  v_i integer;
begin
  select array_agg(d order by d) into v_dates
  from (
    select distinct (mi.completed_at at time zone 'utc')::date as d
    from public.mission_instances mi
    where mi.user_id = p_user_id
      and mi.status = 'completed'
      and mi.completed_at is not null
      and (p_exclude_mission_instance_id is null or mi.id <> p_exclude_mission_instance_id)
  ) s;

  v_len := coalesce(array_length(v_dates, 1), 0);
  if v_len = 0 then
    return 0;
  end if;

  v_gap := v_today - v_dates[v_len];
  if v_gap > 1 then
    return 0;
  end if;

  for v_i in reverse (v_len - 1)..1 loop
    if v_dates[v_i + 1] - v_dates[v_i] = 1 then
      v_current := v_current + 1;
    else
      exit;
    end if;
  end loop;

  return v_current;
end;
$$;

-- Mirrors MissionCompletionValidator exactly, one branch per progress
-- type, working off a generic jsonb payload instead of Dart's sealed
-- classes. This is the server independently re-validating completion —
-- never trusting a client-asserted "I'm done" (spec section 11).
--
-- Known, documented gap vs. the Dart policy: MissionProgressPolicy's
-- richer per-update rules (decrease-requires-correction,
-- implausible-duration-jump rejection) are enforced client-side and, at
-- a shape/bounds level, in supabase/functions/_shared/progress.ts — not
-- re-derived here from raw event history. What this function guarantees
-- is the one thing that actually gates a reward: the final submitted
-- progress snapshot genuinely meets its own mission's completion
-- criteria. See supabase/README.md.
create or replace function public.forge_validate_completion(p_progress_type text, p_progress jsonb)
returns table(passed boolean, reason_codes text[])
language plpgsql
immutable
as $$
declare
  v_passed boolean := false;
  v_reasons text[] := '{}';
  v_item_ids text[];
  v_completed_ids text[];
  v_time_ok boolean;
  v_checklist_ok boolean;
begin
  case p_progress_type
    when 'binary' then
      v_passed := coalesce((p_progress ->> 'completed')::boolean, false);
      if not v_passed then v_reasons := array['binaryNotCompleted']; end if;

    when 'counter' then
      v_passed := coalesce((p_progress ->> 'currentCount')::numeric, 0)
        >= coalesce((p_progress ->> 'targetCount')::numeric, 0);
      if not v_passed then v_reasons := array['counterBelowTarget']; end if;

    when 'quantity' then
      v_passed := coalesce((p_progress ->> 'currentValue')::numeric, 0)
        >= coalesce((p_progress ->> 'targetValue')::numeric, 0);
      if not v_passed then v_reasons := array['quantityBelowTarget']; end if;

    when 'hydration' then
      v_passed := coalesce((p_progress ->> 'currentServings')::numeric, 0)
        >= coalesce((p_progress ->> 'targetServings')::numeric, 0);
      if not v_passed then v_reasons := array['hydrationBelowTarget']; end if;

    when 'percentage' then
      v_passed := coalesce((p_progress ->> 'percentage')::numeric, 0)
        >= coalesce((p_progress ->> 'thresholdPercentage')::numeric, 0);
      if not v_passed then v_reasons := array['percentageBelowThreshold']; end if;

    when 'timer' then
      v_passed := coalesce((p_progress ->> 'accumulatedSeconds')::numeric, 0)
        >= coalesce((p_progress ->> 'targetSeconds')::numeric, 0);
      if not v_passed then v_reasons := array['timerBelowTarget']; end if;

    when 'reading' then
      v_passed := coalesce((p_progress ->> 'durationReadSeconds')::numeric, 0)
        >= coalesce((p_progress ->> 'targetSeconds')::numeric, 0);
      if not v_passed then v_reasons := array['readingBelowTarget']; end if;

    when 'checklist' then
      select array(select jsonb_array_elements_text(coalesce(p_progress -> 'itemIds', '[]'::jsonb)))
        into v_item_ids;
      select array(select jsonb_array_elements_text(coalesce(p_progress -> 'completedItemIds', '[]'::jsonb)))
        into v_completed_ids;
      v_passed := coalesce(array_length(v_item_ids, 1), 0) > 0 and v_item_ids <@ v_completed_ids;
      if not v_passed then v_reasons := array['checklistIncomplete']; end if;

    when 'codingSession' then
      v_time_ok := coalesce((p_progress ->> 'activeSeconds')::numeric, 0)
        >= coalesce((p_progress ->> 'targetSeconds')::numeric, 0);
      select array(select jsonb_array_elements_text(coalesce(p_progress -> 'itemIds', '[]'::jsonb)))
        into v_item_ids;
      select array(select jsonb_array_elements_text(coalesce(p_progress -> 'completedItemIds', '[]'::jsonb)))
        into v_completed_ids;
      v_checklist_ok := coalesce(array_length(v_item_ids, 1), 0) = 0 or v_item_ids <@ v_completed_ids;
      v_passed := v_time_ok and v_checklist_ok;
      if not v_passed then v_reasons := array['codingSessionIncomplete']; end if;

    when 'reflection' then
      v_passed := coalesce((p_progress ->> 'responsePresent')::boolean, false)
        and coalesce((p_progress ->> 'responseLength')::numeric, 0)
          >= coalesce((p_progress ->> 'minimumLength')::numeric, 0);
      if not v_passed then v_reasons := array['reflectionTooShort']; end if;

    else
      v_passed := false;
      v_reasons := array['unsupportedProgressType'];
  end case;

  return query select v_passed, v_reasons;
end;
$$;

-- Finds the (season, week) whose [starts_at, ends_at) window contains
-- p_now, preferring the season marked 'active'. Returns zero rows if
-- none is configured — callers must treat that as "no competition
-- context right now" and skip competitive scoring entirely, not error.
create or replace function public.forge_current_competition_week(p_now timestamptz)
returns table(season_id uuid, week_number integer)
language sql
stable
as $$
  select cw.season_id, cw.week_number
  from public.competition_weeks cw
  join public.competition_seasons cs on cs.id = cw.season_id
  where cs.status = 'active'
    and p_now >= cw.starts_at
    and p_now < cw.ends_at
  order by cw.starts_at desc
  limit 1;
$$;

-- Mirrors CompetitionDiversityPolicy.factorFor exactly.
create or replace function public.forge_diversity_factor(p_prior_completions_this_week_in_category integer)
returns numeric
language sql
immutable
as $$
  select case
    when p_prior_completions_this_week_in_category = 0 then 1.1
    when p_prior_completions_this_week_in_category < 4 then 1.0
    else greatest(1.0 - 0.03 * (p_prior_completions_this_week_in_category - 4), 0.85)
  end;
$$;

-- Mirrors CompetitionIntegrityPolicy.evaluateCompletion. Structural
-- duplicate prevention already exists via unique constraints (spec:
-- "no route to duplicate XP/competition score"), so is_duplicate is
-- always false here — there is no code path that reaches this function
-- with a genuine duplicate to flag. Every other signal is a real,
-- queried check. Writes nothing itself — the caller (forge_submit_
-- mission) is responsible for persisting integrity_events rows, since
-- only it knows the mission_instance_id/command context.
create or replace function public.forge_evaluate_integrity(
  p_user_id uuid,
  p_completed_at timestamptz,
  p_client_timestamp timestamptz,
  p_recent_same_definition_count integer,
  p_provisional_xp integer,
  p_exclude_mission_instance_id uuid default null
)
returns table(state text, signals text[])
language plpgsql
stable
as $$
declare
  v_signals text[] := '{}';
  v_previous_completed_at timestamptz;
  v_gap_seconds numeric;
  v_completions_today integer;
  v_historical_avg numeric;
  v_state text;
begin
  select max(completed_at) into v_previous_completed_at
  from public.mission_instances
  where user_id = p_user_id and status = 'completed' and completed_at is not null
    and (p_exclude_mission_instance_id is null or id <> p_exclude_mission_instance_id);

  if v_previous_completed_at is not null then
    v_gap_seconds := abs(extract(epoch from (p_completed_at - v_previous_completed_at)));
    if v_gap_seconds < 20 then
      v_signals := v_signals || 'impossible_sequence';
    end if;
  end if;

  select count(*) into v_completions_today
  from public.mission_instances
  where user_id = p_user_id
    and status = 'completed'
    and completed_at is not null
    and (completed_at at time zone 'utc')::date = (p_completed_at at time zone 'utc')::date
    and (p_exclude_mission_instance_id is null or id <> p_exclude_mission_instance_id);
  -- +1 for the completion currently being scored (already committed to
  -- mission_instances by the time this runs, but excluded above so it
  -- isn't counted twice).
  if (v_completions_today + 1) > 12 then
    v_signals := v_signals || 'excessive_volume';
  end if;

  if p_recent_same_definition_count >= 5 then
    v_signals := v_signals || 'repeated_farming';
  end if;

  select avg(amount) into v_historical_avg
  from public.xp_ledger
  where user_id = p_user_id and source_type = 'mission_completion'
    and (p_exclude_mission_instance_id is null or mission_instance_id <> p_exclude_mission_instance_id);
  if v_historical_avg is not null and v_historical_avg > 0
     and p_provisional_xp > v_historical_avg * 4 then
    v_signals := v_signals || 'abnormal_score_jump';
  end if;

  -- Client timestamp is informational only (spec section 4) — this
  -- signal exists for observability, never to override the server's
  -- own completed_at, which is always what actually gets stored.
  if p_client_timestamp is not null and p_client_timestamp > p_completed_at + interval '5 minutes' then
    v_signals := v_signals || 'timestamp_anomaly';
  end if;

  if 'impossible_sequence' = any(v_signals)
     or 'excessive_volume' = any(v_signals)
     or 'repeated_farming' = any(v_signals)
     or 'abnormal_score_jump' = any(v_signals) then
    v_state := 'warning';
  else
    v_state := 'clean';
  end if;
  -- Note: this function never returns 'excluded' — the excluding
  -- signals in the Dart policy (duplicateCompletion,
  -- invalidValidationState, timestampAnomaly-as-exclusion) correspond
  -- to states this server-side flow already prevents structurally
  -- (duplicate/invalid submissions never reach this point at all) or
  -- treats as a soft warning instead of a hard exclusion, since a
  -- >5-minute client/server clock skew alone is a weak signal to zero
  -- someone's score over. Documented simplification — see
  -- supabase/README.md.

  return query select v_state, v_signals;
end;
$$;

-- Mirrors ForgeCompetitiveScorePolicy.evaluate for the per-mission
-- portion only (consistency bonus and weekly/season aggregation are a
-- separate, later aggregation job in the Dart domain too — see
-- CalculateWeeklyScoreUseCase — and stay out of scope for a single
-- mission's submit transaction here, matching Dart's own architecture).
-- competition_policy_v1 — bump if this formula changes.
create or replace function public.forge_calculate_competition_score(
  p_difficulty text,
  p_recovery boolean,
  p_quality text,
  p_diversity_factor numeric,
  p_repeated_count integer,
  p_integrity_state text
)
returns table(final_score numeric, breakdown jsonb)
language plpgsql
immutable
as $$
declare
  v_base numeric := 10.0;
  v_difficulty_factor numeric;
  v_quality_factor numeric;
  v_consistency_factor numeric := 1.0;
  v_product numeric;
  v_retained_fraction numeric;
  v_repetition_adj numeric := 0;
  v_after_repetition numeric;
  v_recovery_cap numeric;
  v_recovery_adj numeric := 0;
  v_after_recovery numeric;
  v_integrity_adj numeric := 0;
  v_after_integrity numeric;
  v_final numeric;
begin
  if p_integrity_state = 'excluded' then
    return query select 0::numeric, jsonb_build_object(
      'policyVersion', 'competition_policy_v1',
      'zeroedReason', 'excluded'
    );
    return;
  end if;

  v_difficulty_factor := case p_difficulty
    when 'restorative' then 0.6
    when 'easy' then 0.8
    when 'moderate' then 1.0
    when 'challenging' then 1.3
    when 'advanced' then 1.6
    else 1.0
  end;
  v_quality_factor := case coalesce(p_quality, 'standard')
    when 'low' then 0.7
    when 'high' then 1.15
    else 1.0
  end;

  v_product := v_base * v_difficulty_factor * v_quality_factor * p_diversity_factor * v_consistency_factor;

  if p_repeated_count > 0 then
    v_retained_fraction := power(0.6, least(p_repeated_count, 1000));
    v_repetition_adj := -(v_product * (1 - v_retained_fraction));
  end if;
  v_after_repetition := v_product + v_repetition_adj;

  if p_recovery then
    v_recovery_cap := v_after_repetition * 0.5;
    if v_after_repetition - v_recovery_cap > 0 then
      v_recovery_adj := -(v_after_repetition - v_recovery_cap);
    end if;
  end if;
  v_after_recovery := v_after_repetition + v_recovery_adj;

  if p_integrity_state = 'warning' then
    v_integrity_adj := -(v_after_recovery * 0.5);
  end if;
  v_after_integrity := v_after_recovery + v_integrity_adj;

  v_final := least(greatest(v_after_integrity, 0.0), 25.0);

  return query select v_final, jsonb_build_object(
    'policyVersion', 'competition_policy_v1',
    'baseScore', v_base,
    'difficultyFactor', v_difficulty_factor,
    'qualityFactor', v_quality_factor,
    'diversityFactor', p_diversity_factor,
    'consistencyFactor', v_consistency_factor,
    'repetitionAdjustment', v_repetition_adj,
    'recoveryAdjustment', v_recovery_adj,
    'integrityAdjustment', v_integrity_adj,
    'cappedAtPerMissionMax', (v_after_integrity > 25.0)
  );
end;
$$;

-- Evaluates every active achievement for p_user_id and inserts a
-- user_achievements row for any newly-met one (unique(user_id,
-- achievement_id) makes a duplicate unlock structurally impossible —
-- this function relies on that constraint rather than re-checking
-- membership itself, so it's safe to call unconditionally).
--
-- Supports exactly the achievement_definitions.criteria keys that map
-- to data this schema can already answer: missions_completed,
-- distinct_categories, recovery_completions. The seed catalog's other
-- two keys — active_days_in_week (needs a true weekly-consistency
-- concept) and early_completions (needs a local-timezone-aware
-- time-of-day concept, which doesn't exist anywhere in this schema or
-- the Dart AchievementCriteria hierarchy either) — are deliberately not
-- evaluated. Documented gap, not a silent omission; see
-- supabase/README.md and the Phase 10C final report.
create or replace function public.forge_evaluate_achievements(p_user_id uuid, p_mission_instance_id uuid)
returns table(achievement_id uuid, stable_key text, title text)
language plpgsql
as $$
declare
  v_def record;
  v_current integer;
  v_target integer;
begin
  for v_def in
    select ad.id, ad.stable_key, ad.title, ad.criteria
    from public.achievement_definitions ad
    where ad.active
      and not exists (
        select 1 from public.user_achievements ua
        where ua.user_id = p_user_id and ua.achievement_id = ad.id
      )
  loop
    v_current := null;
    v_target := null;

    if v_def.criteria ? 'missions_completed' then
      v_target := (v_def.criteria ->> 'missions_completed')::integer;
      select count(*) into v_current
      from public.mission_instances
      where user_id = p_user_id and status = 'completed';
    elsif v_def.criteria ? 'distinct_categories' then
      v_target := (v_def.criteria ->> 'distinct_categories')::integer;
      select count(distinct md.category) into v_current
      from public.mission_instances mi
      join public.mission_definitions md on md.id = mi.mission_definition_id
      where mi.user_id = p_user_id and mi.status = 'completed';
    elsif v_def.criteria ? 'recovery_completions' then
      v_target := (v_def.criteria ->> 'recovery_completions')::integer;
      select count(*) into v_current
      from public.mission_instances
      where user_id = p_user_id and status = 'completed' and recovery_mission;
    else
      continue; -- unsupported criteria key — see function comment.
    end if;

    if v_target is not null and v_current is not null and v_current >= v_target then
      insert into public.user_achievements (user_id, achievement_id, source_type, source_id)
      values (p_user_id, v_def.id, 'mission_completion', p_mission_instance_id::text)
      on conflict (user_id, achievement_id) do nothing;

      if found then
        achievement_id := v_def.id;
        stable_key := v_def.stable_key;
        title := v_def.title;
        return next;
      end if;
    end if;
  end loop;
end;
$$;

-- =======================================================================
-- Section 2: shared idempotency/ownership/sequence plumbing, used by
-- every command function below.
-- =======================================================================

-- Raises a structured 'error_code|message' exception — the one place
-- every command function formats a rejection, so the Edge Function's
-- error mapping (supabase/functions/_shared/errors.ts) only has to
-- parse one shape.
create or replace function public.forge_raise(p_code text, p_message text)
returns void
language plpgsql
as $$
begin
  raise exception '%|%', p_code, p_message using errcode = 'P0001';
end;
$$;

-- Locks and returns the mission_instances row for p_mission_instance_id,
-- enforcing that it exists and belongs to the caller. `for update`
-- serializes any concurrent command against the same mission — the
-- core of spec section 7's "double submission produces one reward
-- only": a second concurrent transaction blocks here until the first
-- commits or rolls back, then re-reads the now-advanced
-- current_sequence and is naturally rejected as stale.
create or replace function public.forge_lock_owned_mission(p_user_id uuid, p_mission_instance_id uuid)
returns public.mission_instances
language plpgsql
as $$
declare
  v_mission public.mission_instances;
begin
  select * into v_mission
  from public.mission_instances
  where id = p_mission_instance_id
  for update;

  if not found then
    perform public.forge_raise('mission_not_found', 'No mission instance exists with that id.');
  end if;
  if v_mission.user_id <> p_user_id then
    perform public.forge_raise('forbidden', 'This mission instance does not belong to the authenticated user.');
  end if;

  return v_mission;
end;
$$;

-- Idempotency/sequence gate shared by every command. Returns the
-- cached jsonb response if this is a legitimate retry (same
-- idempotency_key, same request_hash); raises 'idempotency_conflict'
-- for a conflicting replay (same key, different hash); raises
-- 'duplicate_command' if p_command_id was already used under a
-- *different* idempotency key; raises 'stale_sequence'/'out_of_order'
-- against the mission's current command-sequence counter. Returns NULL
-- (not an exception) when the command is genuinely new and in-order —
-- the caller proceeds to execute it.
create or replace function public.forge_check_idempotency_and_sequence(
  p_mission public.mission_instances,
  p_command_id text,
  p_idempotency_key text,
  p_sequence integer,
  p_request_hash text
)
returns jsonb
language plpgsql
as $$
declare
  v_cached record;
  v_command_row record;
  v_expected_next integer;
begin
  select * into v_cached from public.processed_commands where idempotency_key = p_idempotency_key;
  if found then
    if v_cached.request_hash = p_request_hash then
      return v_cached.response_payload;
    else
      perform public.forge_raise('idempotency_conflict',
        'This idempotency key was already used for a different request payload.');
    end if;
  end if;

  select * into v_command_row from public.processed_commands where command_id = p_command_id;
  if found then
    perform public.forge_raise('duplicate_command',
      'This command_id was already processed under a different idempotency key.');
  end if;

  v_expected_next := p_mission.current_sequence + 1;
  if p_sequence < v_expected_next then
    perform public.forge_raise('stale_sequence',
      format('Expected sequence %s but received %s.', v_expected_next, p_sequence));
  elsif p_sequence > v_expected_next then
    perform public.forge_raise('out_of_order',
      format('Expected sequence %s but received %s — an earlier command is missing.', v_expected_next, p_sequence));
  end if;

  return null;
end;
$$;

-- Persists the durable idempotency record and advances the mission's
-- command sequence — always called exactly once, right before a
-- command function returns its success envelope, so the whole command
-- (including this bookkeeping) is part of the same atomic transaction.
create or replace function public.forge_record_processed_command(
  p_mission_instance_id uuid,
  p_command_id text,
  p_user_id uuid,
  p_idempotency_key text,
  p_command_type text,
  p_request_hash text,
  p_response jsonb,
  p_new_sequence integer
)
returns void
language plpgsql
as $$
begin
  insert into public.processed_commands
    (command_id, user_id, idempotency_key, command_type, request_hash, response_payload)
  values
    (p_command_id, p_user_id, p_idempotency_key, p_command_type, p_request_hash, p_response);

  update public.mission_instances
  set current_sequence = p_new_sequence
  where id = p_mission_instance_id;
end;
$$;

-- Appends one mission_events row with an auto-assigned event-log
-- sequence, deriving a unique command_id/idempotency_key per event by
-- suffixing the parent command's ids with the event type (see the
-- migration header comment on the two sequence concepts).
create or replace function public.forge_append_event(
  p_mission_instance_id uuid,
  p_user_id uuid,
  p_command_id text,
  p_idempotency_key text,
  p_event_type text,
  p_payload jsonb,
  p_occurred_at timestamptz
)
returns void
language plpgsql
as $$
declare
  v_next_seq integer;
begin
  select coalesce(max(sequence), 0) + 1 into v_next_seq
  from public.mission_events
  where mission_instance_id = p_mission_instance_id;

  insert into public.mission_events (
    mission_instance_id, user_id, command_id, idempotency_key, sequence,
    event_type, payload, occurred_at
  ) values (
    p_mission_instance_id, p_user_id,
    p_command_id || ':' || p_event_type,
    p_idempotency_key || ':' || p_event_type,
    v_next_seq, p_event_type, p_payload, p_occurred_at
  );
end;
$$;

-- =======================================================================
-- Section 3: the five authoritative command entrypoints. Each is the
-- only thing an Edge Function calls (via supabase-js .rpc(), using the
-- caller's own JWT — never a service-role key) after its own request
-- validation. auth.uid() — not any parameter — is the sole source of
-- the acting user's identity throughout.
-- =======================================================================

create or replace function public.forge_accept_mission(
  p_command_id text,
  p_idempotency_key text,
  p_mission_instance_id uuid,
  p_sequence integer,
  p_request_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_mission public.mission_instances;
  v_cached jsonb;
  v_now timestamptz := timezone('utc', now());
  v_response jsonb;
begin
  if v_user_id is null then
    perform public.forge_raise('unauthenticated', 'No authenticated user for this request.');
  end if;

  v_mission := public.forge_lock_owned_mission(v_user_id, p_mission_instance_id);
  v_cached := public.forge_check_idempotency_and_sequence(
    v_mission, p_command_id, p_idempotency_key, p_sequence, p_request_hash
  );
  if v_cached is not null then
    return v_cached;
  end if;

  if v_mission.status <> 'assigned' then
    perform public.forge_raise('invalid_transition',
      format('Mission cannot be accepted from status "%s".', v_mission.status));
  end if;

  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'accepted', '{}'::jsonb, v_now
  );

  update public.mission_instances
  set status = 'accepted'
  where id = p_mission_instance_id;

  v_response := jsonb_build_object(
    'status', 'accepted',
    'missionInstanceId', p_mission_instance_id,
    'serverTimestamp', v_now,
    'confirmationId', p_command_id || ':confirm',
    'reasons', '[]'::jsonb
  );

  perform public.forge_record_processed_command(
    p_mission_instance_id, p_command_id, v_user_id, p_idempotency_key,
    'accept_mission', p_request_hash, v_response, p_sequence
  );

  return v_response;
end;
$$;

create or replace function public.forge_start_mission(
  p_command_id text,
  p_idempotency_key text,
  p_mission_instance_id uuid,
  p_sequence integer,
  p_request_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_mission public.mission_instances;
  v_cached jsonb;
  v_now timestamptz := timezone('utc', now());
  v_response jsonb;
begin
  if v_user_id is null then
    perform public.forge_raise('unauthenticated', 'No authenticated user for this request.');
  end if;

  v_mission := public.forge_lock_owned_mission(v_user_id, p_mission_instance_id);
  v_cached := public.forge_check_idempotency_and_sequence(
    v_mission, p_command_id, p_idempotency_key, p_sequence, p_request_hash
  );
  if v_cached is not null then
    return v_cached;
  end if;

  if v_mission.status <> 'accepted' then
    perform public.forge_raise('invalid_transition',
      format('Mission cannot be started from status "%s".', v_mission.status));
  end if;

  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'started', '{}'::jsonb, v_now
  );

  update public.mission_instances
  set status = 'active', started_at = v_now
  where id = p_mission_instance_id;

  v_response := jsonb_build_object(
    'status', 'accepted',
    'missionInstanceId', p_mission_instance_id,
    'serverTimestamp', v_now,
    'confirmationId', p_command_id || ':confirm',
    'reasons', '[]'::jsonb
  );

  perform public.forge_record_processed_command(
    p_mission_instance_id, p_command_id, v_user_id, p_idempotency_key,
    'start_mission', p_request_hash, v_response, p_sequence
  );

  return v_response;
end;
$$;

create or replace function public.forge_record_mission_progress(
  p_command_id text,
  p_idempotency_key text,
  p_mission_instance_id uuid,
  p_sequence integer,
  p_request_hash text,
  p_progress_type text,
  p_progress jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_mission public.mission_instances;
  v_cached jsonb;
  v_now timestamptz := timezone('utc', now());
  v_response jsonb;
begin
  if v_user_id is null then
    perform public.forge_raise('unauthenticated', 'No authenticated user for this request.');
  end if;

  v_mission := public.forge_lock_owned_mission(v_user_id, p_mission_instance_id);
  v_cached := public.forge_check_idempotency_and_sequence(
    v_mission, p_command_id, p_idempotency_key, p_sequence, p_request_hash
  );
  if v_cached is not null then
    return v_cached;
  end if;

  if v_mission.status not in ('active', 'paused') then
    perform public.forge_raise('invalid_transition',
      format('Progress cannot be recorded from status "%s".', v_mission.status));
  end if;

  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'progress_updated',
    jsonb_build_object('progressType', p_progress_type, 'progress', p_progress),
    v_now
  );

  v_response := jsonb_build_object(
    'status', 'accepted',
    'missionInstanceId', p_mission_instance_id,
    'acceptedSequence', p_sequence,
    'serverTimestamp', v_now,
    'confirmationId', p_command_id || ':confirm',
    'reasons', '[]'::jsonb
  );

  perform public.forge_record_processed_command(
    p_mission_instance_id, p_command_id, v_user_id, p_idempotency_key,
    'record_progress', p_request_hash, v_response, p_sequence
  );

  return v_response;
end;
$$;

create or replace function public.forge_cancel_mission(
  p_command_id text,
  p_idempotency_key text,
  p_mission_instance_id uuid,
  p_sequence integer,
  p_request_hash text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_mission public.mission_instances;
  v_cached jsonb;
  v_now timestamptz := timezone('utc', now());
  v_response jsonb;
begin
  if v_user_id is null then
    perform public.forge_raise('unauthenticated', 'No authenticated user for this request.');
  end if;

  v_mission := public.forge_lock_owned_mission(v_user_id, p_mission_instance_id);
  v_cached := public.forge_check_idempotency_and_sequence(
    v_mission, p_command_id, p_idempotency_key, p_sequence, p_request_hash
  );
  if v_cached is not null then
    return v_cached;
  end if;

  if v_mission.status not in ('assigned', 'accepted', 'active', 'paused') then
    perform public.forge_raise('invalid_transition',
      format('Mission cannot be cancelled from status "%s".', v_mission.status));
  end if;

  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'abandoned',
    jsonb_build_object('reason', p_reason),
    v_now
  );

  update public.mission_instances
  set status = 'cancelled', cancelled_at = v_now
  where id = p_mission_instance_id;

  v_response := jsonb_build_object(
    'status', 'accepted',
    'missionInstanceId', p_mission_instance_id,
    'serverTimestamp', v_now,
    'confirmationId', p_command_id || ':confirm',
    'reasons', '[]'::jsonb
  );

  perform public.forge_record_processed_command(
    p_mission_instance_id, p_command_id, v_user_id, p_idempotency_key,
    'cancel_mission', p_request_hash, v_response, p_sequence
  );

  return v_response;
end;
$$;

-- The core of Phase 10C. Mirrors SubmitMissionUseCase's event sequence
-- (submitted -> validation_failed, OR submitted -> validation_passed ->
-- completed) and then — only on the completed path — runs the full
-- reward pipeline described in spec section 6, steps 10-18, as part of
-- the same transaction: XP ledger, progression update, achievement
-- evaluation, competition score ledger, integrity evaluation, audit
-- log, all before this function returns. Nothing here trusts
-- p_progress/p_progress_type for anything beyond "what did the client
-- observe" — forge_validate_completion independently re-derives
-- pass/fail, and every reward number comes from forge_calculate_xp_
-- reward/forge_calculate_competition_score, never from the client.
create or replace function public.forge_submit_mission(
  p_command_id text,
  p_idempotency_key text,
  p_mission_instance_id uuid,
  p_sequence integer,
  p_request_hash text,
  p_progress_type text,
  p_progress jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_mission public.mission_instances;
  v_cached jsonb;
  v_now timestamptz := timezone('utc', now());
  v_validation record;
  v_response jsonb;

  v_definition record;
  v_difficulty text;
  v_base_xp_hint integer;
  v_recovery boolean;
  v_completion_quality text;

  v_prior_category_completions integer;
  v_streak_days integer;
  v_recent_same_definition_count integer;
  v_xp_earned_today integer;
  v_xp_calc record;
  v_xp_awarded integer;

  v_prev_confirmed_xp bigint;
  v_prev_level integer;
  v_new_confirmed_xp bigint;
  v_new_level integer;

  v_unlocked jsonb := '[]'::jsonb;
  v_unlocked_row record;

  v_integrity record;
  v_competition_week record;
  v_prior_category_this_week integer;
  v_diversity numeric;
  v_score_calc record;
  v_score_amount numeric;
  v_prior_category_day numeric;
  v_prior_day numeric;
  v_prior_week numeric;
  v_remaining numeric;
begin
  if v_user_id is null then
    perform public.forge_raise('unauthenticated', 'No authenticated user for this request.');
  end if;

  v_mission := public.forge_lock_owned_mission(v_user_id, p_mission_instance_id);
  v_cached := public.forge_check_idempotency_and_sequence(
    v_mission, p_command_id, p_idempotency_key, p_sequence, p_request_hash
  );
  if v_cached is not null then
    return v_cached;
  end if;

  if v_mission.status not in ('active', 'paused') then
    perform public.forge_raise('invalid_transition',
      format('Mission cannot be submitted from status "%s".', v_mission.status));
  end if;

  -- Step: append the factual "submitted" event first, always — mirrors
  -- SubmitMissionUseCase appending MissionSubmitted before any
  -- validation runs.
  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'submitted', '{}'::jsonb, v_now
  );
  update public.mission_instances set submitted_at = v_now where id = p_mission_instance_id;

  select passed, reason_codes into v_validation
  from public.forge_validate_completion(p_progress_type, p_progress);

  if not v_validation.passed then
    perform public.forge_append_event(
      p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
      'validation_failed',
      jsonb_build_object('reasonCodes', to_jsonb(v_validation.reason_codes)),
      v_now
    );
    -- Mission stays open — status reverts to its pre-submission bucket
    -- rather than a distinct 'validation_failed' status value (Phase
    -- 10B's mission_instances.status enum doesn't have one; see
    -- supabase/README.md for why this is a deliberate simplification,
    -- not an oversight). The authoritative record of the failure is
    -- the mission_events row above, which never disappears.
    update public.mission_instances set status = v_mission.status where id = p_mission_instance_id;

    v_response := jsonb_build_object(
      'status', 'rejected',
      'missionInstanceId', p_mission_instance_id,
      'confirmedMissionState', 'rejected',
      'confirmedXpReward', 0,
      'progressionUpdate', jsonb_build_object(
        'previousLevel', null, 'newLevel', null, 'confirmedTotalXp', null
      ),
      'achievementUpdates', '[]'::jsonb,
      'competitionScoreUpdate', 0,
      'integrityStatus', 'clean',
      'serverTimestamp', v_now,
      'confirmationId', p_command_id || ':confirm',
      'reasons', to_jsonb(v_validation.reason_codes),
      'errorCode', 'completion_requirements_not_met'
    );

    perform public.forge_record_processed_command(
      p_mission_instance_id, p_command_id, v_user_id, p_idempotency_key,
      'submit_mission', p_request_hash, v_response, p_sequence
    );

    return v_response;
  end if;

  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'validation_passed', '{}'::jsonb, v_now
  );
  perform public.forge_append_event(
    p_mission_instance_id, v_user_id, p_command_id, p_idempotency_key,
    'completed', '{}'::jsonb, v_now
  );

  update public.mission_instances
  set status = 'completed', completed_at = v_now
  where id = p_mission_instance_id;

  -- ---- Reward pipeline (steps 10-18) -----------------------------------

  select md.category, md.difficulty, md.base_xp_hint
  into v_definition
  from public.mission_definitions md
  where md.id = v_mission.mission_definition_id;

  v_difficulty := coalesce(v_mission.resolved_difficulty, v_definition.difficulty);
  v_base_xp_hint := coalesce(v_mission.base_xp_hint, v_definition.base_xp_hint);
  v_recovery := v_mission.recovery_mission;
  v_completion_quality := coalesce(v_mission.completion_quality, 'standard');

  select count(*) into v_prior_category_completions
  from public.mission_instances mi
  join public.mission_definitions md on md.id = mi.mission_definition_id
  where mi.user_id = v_user_id and mi.status = 'completed' and md.category = v_definition.category
    and mi.id <> p_mission_instance_id;

  select count(*) into v_recent_same_definition_count
  from public.mission_instances
  where user_id = v_user_id and status = 'completed'
    and mission_definition_id = v_mission.mission_definition_id
    and id <> p_mission_instance_id;

  v_streak_days := public.forge_current_streak_days(v_user_id, v_now, p_mission_instance_id);

  select coalesce(sum(amount), 0) into v_xp_earned_today
  from public.xp_ledger
  where user_id = v_user_id and source_type = 'mission_completion' and amount > 0
    and (created_at at time zone 'utc')::date = (v_now at time zone 'utc')::date;

  select final_xp, breakdown into v_xp_calc
  from public.forge_calculate_xp_reward(
    v_difficulty, v_recovery, v_base_xp_hint, v_prior_category_completions,
    v_streak_days, v_recent_same_definition_count, v_xp_earned_today
  );
  v_xp_awarded := v_xp_calc.final_xp;

  select confirmed_xp, level into v_prev_confirmed_xp, v_prev_level
  from public.user_progression where user_id = v_user_id;

  v_new_confirmed_xp := v_prev_confirmed_xp;
  v_new_level := v_prev_level;

  -- xp_ledger.amount has a nonzero CHECK constraint — a 0-XP outcome
  -- (fully capped by the daily allowance) legitimately grants no ledger
  -- row, matching "this completion earned zero XP" rather than forcing
  -- a meaningless zero-amount row past the constraint.
  if v_xp_awarded > 0 then
    insert into public.xp_ledger (user_id, mission_instance_id, source_type, source_id, amount, reason)
    values (v_user_id, p_mission_instance_id, 'mission_completion', p_mission_instance_id::text,
      v_xp_awarded, 'Mission completion — ' || (v_xp_calc.breakdown ->> 'policyVersion'));

    insert into public.audit_log (actor_type, actor_id, action, target_type, target_id, metadata)
    values ('service', v_user_id, 'xp_grant', 'mission_instance', p_mission_instance_id::text,
      jsonb_build_object('amount', v_xp_awarded, 'breakdown', v_xp_calc.breakdown));

    v_new_confirmed_xp := v_prev_confirmed_xp + v_xp_awarded;
    v_new_level := public.forge_level_for_xp(v_new_confirmed_xp);

    update public.user_progression
    set confirmed_xp = v_new_confirmed_xp, level = v_new_level, version = version + 1
    where user_id = v_user_id;

    insert into public.audit_log (actor_type, actor_id, action, target_type, target_id, metadata)
    values ('service', v_user_id, 'progression_update', 'user', v_user_id::text,
      jsonb_build_object('previousLevel', v_prev_level, 'newLevel', v_new_level,
        'confirmedTotalXp', v_new_confirmed_xp));
  end if;

  -- Achievements: evaluated regardless of whether XP was awarded this
  -- time (a milestone like "5 distinct categories" can be crossed by a
  -- 0-XP-today completion just as validly).
  for v_unlocked_row in
    select * from public.forge_evaluate_achievements(v_user_id, p_mission_instance_id)
  loop
    v_unlocked := v_unlocked || jsonb_build_array(v_unlocked_row.stable_key);
    insert into public.audit_log (actor_type, actor_id, action, target_type, target_id, metadata)
    values ('service', v_user_id, 'achievement_grant', 'achievement', v_unlocked_row.achievement_id::text,
      jsonb_build_object('missionInstanceId', p_mission_instance_id, 'title', v_unlocked_row.title));
  end loop;

  -- Integrity evaluation — always runs; only ever written to the
  -- private integrity_events table, never surfaced beyond the neutral
  -- clean/warning status in the response (spec section 17).
  select state, signals into v_integrity
  from public.forge_evaluate_integrity(
    v_user_id, v_now, v_now, v_recent_same_definition_count, v_xp_awarded, p_mission_instance_id
  );

  if array_length(v_integrity.signals, 1) > 0 then
    insert into public.integrity_events (user_id, mission_instance_id, signal_type, severity, metadata)
    select v_user_id, p_mission_instance_id, s, v_integrity.state,
      jsonb_build_object('missionInstanceId', p_mission_instance_id)
    from unnest(v_integrity.signals) as s;
  end if;

  -- Competitive score — only if a competition week is actually
  -- configured right now; otherwise this completion simply doesn't
  -- contribute one (no season/week is not an error condition).
  select season_id, week_number into v_competition_week
  from public.forge_current_competition_week(v_now);

  v_score_amount := 0;

  if v_competition_week.season_id is not null then
    select count(*) into v_prior_category_this_week
    from public.competition_score_ledger csl
    join public.mission_instances mi2 on mi2.id = csl.mission_instance_id
    join public.mission_definitions md2 on md2.id = mi2.mission_definition_id
    where csl.user_id = v_user_id
      and csl.season_id = v_competition_week.season_id
      and csl.week_number = v_competition_week.week_number
      and md2.category = v_definition.category;

    v_diversity := public.forge_diversity_factor(v_prior_category_this_week);

    select final_score, breakdown into v_score_calc
    from public.forge_calculate_competition_score(
      v_difficulty, v_recovery, v_completion_quality, v_diversity,
      v_recent_same_definition_count, v_integrity.state
    );
    v_score_amount := v_score_calc.final_score;

    -- Apply category/day/week caps eagerly, at write time, rather than
    -- at a later weekly-aggregation pass (spec section 16's caps are
    -- respected here more strictly than Dart's own architecture, which
    -- applies them during weekly aggregation instead — a deliberate,
    -- documented difference: an authoritative write-time cap can never
    -- be bypassed by a weekly job that hasn't run yet). See
    -- supabase/README.md.
    if v_score_amount > 0 then
      select coalesce(sum(csl.amount), 0) into v_prior_category_day
      from public.competition_score_ledger csl
      join public.mission_instances mi3 on mi3.id = csl.mission_instance_id
      join public.mission_definitions md3 on md3.id = mi3.mission_definition_id
      where csl.user_id = v_user_id and md3.category = v_definition.category
        and (csl.created_at at time zone 'utc')::date = (v_now at time zone 'utc')::date;
      v_remaining := greatest(40.0 - v_prior_category_day, 0);
      v_score_amount := least(v_score_amount, v_remaining);
    end if;

    if v_score_amount > 0 then
      select coalesce(sum(amount), 0) into v_prior_day
      from public.competition_score_ledger
      where user_id = v_user_id
        and (created_at at time zone 'utc')::date = (v_now at time zone 'utc')::date;
      v_remaining := greatest(80.0 - v_prior_day, 0);
      v_score_amount := least(v_score_amount, v_remaining);
    end if;

    if v_score_amount > 0 then
      select coalesce(sum(amount), 0) into v_prior_week
      from public.competition_score_ledger
      where user_id = v_user_id and season_id = v_competition_week.season_id
        and week_number = v_competition_week.week_number;
      v_remaining := greatest(400.0 - v_prior_week, 0);
      v_score_amount := least(v_score_amount, v_remaining);
    end if;

    insert into public.competition_score_ledger
      (user_id, season_id, week_number, mission_instance_id, source_type, source_id, amount)
    values
      (v_user_id, v_competition_week.season_id, v_competition_week.week_number,
       p_mission_instance_id, 'mission_completion', p_mission_instance_id::text, v_score_amount);

    insert into public.audit_log (actor_type, actor_id, action, target_type, target_id, metadata)
    values ('service', v_user_id, 'competition_score_award', 'mission_instance', p_mission_instance_id::text,
      jsonb_build_object('amount', v_score_amount, 'breakdown', v_score_calc.breakdown));
  end if;

  v_response := jsonb_build_object(
    'status', 'accepted',
    'missionInstanceId', p_mission_instance_id,
    'confirmedMissionState', 'completed',
    'confirmedXpReward', v_xp_awarded,
    'progressionUpdate', jsonb_build_object(
      'previousLevel', v_prev_level,
      'newLevel', v_new_level,
      'confirmedTotalXp', v_new_confirmed_xp
    ),
    'achievementUpdates', v_unlocked,
    'competitionScoreUpdate', v_score_amount,
    'integrityStatus', v_integrity.state,
    'serverTimestamp', v_now,
    'confirmationId', p_command_id || ':confirm',
    'reasons', '[]'::jsonb
  );

  perform public.forge_record_processed_command(
    p_mission_instance_id, p_command_id, v_user_id, p_idempotency_key,
    'submit_mission', p_request_hash, v_response, p_sequence
  );

  return v_response;
end;
$$;

-- =======================================================================
-- Section 4: least-privilege grants. Every function in this migration
-- is created with EXECUTE revoked from PUBLIC by default behavior
-- overridden below — only the five command entrypoints are callable by
-- `authenticated`; every helper function stays uncallable directly
-- (Supabase exposes any function with EXECUTE granted to a client role
-- as an RPC endpoint, so leaving helpers open would let a client bypass
-- the ownership/idempotency/validation wrapper entirely).
-- =======================================================================

revoke all on function public.forge_xp_required_for_level(integer) from public;
revoke all on function public.forge_level_for_xp(bigint) from public;
revoke all on function public.forge_category_tier_multiplier(integer) from public;
revoke all on function public.forge_calculate_xp_reward(text, boolean, integer, integer, integer, integer, integer) from public;
revoke all on function public.forge_current_streak_days(uuid, timestamptz, uuid) from public;
revoke all on function public.forge_validate_completion(text, jsonb) from public;
revoke all on function public.forge_current_competition_week(timestamptz) from public;
revoke all on function public.forge_diversity_factor(integer) from public;
revoke all on function public.forge_evaluate_integrity(uuid, timestamptz, timestamptz, integer, integer, uuid) from public;
revoke all on function public.forge_calculate_competition_score(text, boolean, text, numeric, integer, text) from public;
revoke all on function public.forge_evaluate_achievements(uuid, uuid) from public;
revoke all on function public.forge_raise(text, text) from public;
revoke all on function public.forge_lock_owned_mission(uuid, uuid) from public;
revoke all on function public.forge_check_idempotency_and_sequence(public.mission_instances, text, text, integer, text) from public;
revoke all on function public.forge_record_processed_command(uuid, text, uuid, text, text, text, jsonb, integer) from public;
revoke all on function public.forge_append_event(uuid, uuid, text, text, text, jsonb, timestamptz) from public;

revoke all on function public.forge_accept_mission(text, text, uuid, integer, text) from public;
revoke all on function public.forge_start_mission(text, text, uuid, integer, text) from public;
revoke all on function public.forge_record_mission_progress(text, text, uuid, integer, text, text, jsonb) from public;
revoke all on function public.forge_cancel_mission(text, text, uuid, integer, text, text) from public;
revoke all on function public.forge_submit_mission(text, text, uuid, integer, text, text, jsonb) from public;

grant execute on function public.forge_accept_mission(text, text, uuid, integer, text) to authenticated;
grant execute on function public.forge_start_mission(text, text, uuid, integer, text) to authenticated;
grant execute on function public.forge_record_mission_progress(text, text, uuid, integer, text, text, jsonb) to authenticated;
grant execute on function public.forge_cancel_mission(text, text, uuid, integer, text, text) to authenticated;
grant execute on function public.forge_submit_mission(text, text, uuid, integer, text, text, jsonb) to authenticated;
