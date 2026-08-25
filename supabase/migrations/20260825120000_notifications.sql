-- Roadmap Item 15: Notifications, Retention & Daily Operating Loop.
--
-- Trust boundary (see lib/core/security/trust_boundary.dart): the four
-- notification types below (achievement unlock, level-up, weekly
-- competition result, season result) all report on SERVER AUTHORITATIVE
-- facts — a client must never be able to mint one of these rows itself.
-- They are created exclusively inside the same transaction as the
-- authoritative state change they describe (forge_submit_mission,
-- forge_finalize_season_week, forge_finalize_season), via the
-- forge_create_notification() helper below, which is never granted to
-- `authenticated`. This closes exactly the race the spec calls out:
-- "mission submitted -> UI guesses achievement -> notification emitted
-- -> server later disagrees" is structurally impossible here, because
-- the notification row and the fact it describes are written by the
-- same statement-sequence inside the same Postgres transaction.
--
-- Daily Mission / Daily Transmission / Mission Follow-up reminders are
-- deliberately NOT modeled here — trust_boundary.dart already classifies
-- "local notification scheduling" as CLIENT OWNED (the *when* to remind
-- is a local-time/quiet-hours decision with no server fact to get
-- wrong), and inventing a new per-user, timezone-aware, cron-driven
-- pre-assignment pipeline to manufacture a server-side version of that
-- would duplicate Item 13C's own client-request-driven assignment
-- architecture rather than reuse it. See the Item 15 PR description for
-- the full reasoning; those three types are implemented purely in
-- Flutter, computed from state the client already authoritatively has
-- (resolvedMissionInstanceProvider, MissionLifecycleController).

-- =======================================================================
-- notifications — server-authoritative, one row per (user, dedup_key).
-- =======================================================================

create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  dedup_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),

  constraint notifications_type_check check (type in (
    'achievement_unlock', 'level_up', 'week_result', 'season_result', 'weekly_recap'
  )),
  -- The concrete duplicate-prevention mechanism (spec section 8): a
  -- retried/idempotent finalization re-running forge_create_notification
  -- with the same dedup_key is a harmless ON CONFLICT DO NOTHING, not a
  -- second row.
  constraint notifications_dedup_unique unique (user_id, dedup_key)
);

comment on table public.notifications is
  'Server-authoritative notification record for events a client must '
  'never be able to mint itself (achievement/level/competition). '
  'Own-row SELECT for clients; only read_at is client-updatable '
  '(column-level GRANT below) — type/metadata/dedup_key are immutable '
  'once written. All INSERTs come from forge_create_notification(), '
  'never granted to `authenticated`.';

-- Inbox listing (newest first) and the unread-count query are the two
-- access patterns this table exists for (spec section 25) — both served
-- by this one composite index; the partial second index keeps an
-- unread-count query from ever scanning read rows.
create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index notifications_user_unread_idx
  on public.notifications (user_id)
  where read_at is null;

alter table public.notifications enable row level security;

create policy notifications_select_own
  on public.notifications
  for select
  to authenticated
  using (user_id = auth.uid());

-- No INSERT policy for `authenticated` at all — mirrors
-- user_achievements' own "self-awarding is structurally impossible, not
-- just discouraged" comment exactly.
create policy notifications_update_own
  on public.notifications
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Baseline table-level grant (see 20260821090000_baseline_authenticated_
-- grants.sql's own header: a `create policy` alone grants no table
-- access at all — RLS only restricts rows once a base GRANT exists).
-- SELECT is unrestricted at the column level; UPDATE is immediately
-- narrowed to read_at only — a client can mark a notification read but
-- cannot rewrite its type, metadata, or dedup_key even though the
-- row-level policy above would otherwise permit updating the whole row.
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

-- =======================================================================
-- notification_preferences — CLIENT OWNED (trust_boundary.dart): the
-- user is the source of truth for their own delivery/quiet-hours
-- choices. Persisted server-side (not device-local storage) so
-- preferences survive reinstall/sync across devices and so
-- account-switch isolation is enforced structurally by RLS rather than
-- by careful client-side keying (spec section 10/18).
-- =======================================================================

create table public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  master_enabled boolean not null default true,
  daily_mission_enabled boolean not null default true,
  daily_transmission_enabled boolean not null default true,
  mission_followup_enabled boolean not null default true,
  achievement_enabled boolean not null default true,
  progression_enabled boolean not null default true,
  weekly_recap_enabled boolean not null default true,
  competition_result_enabled boolean not null default true,
  -- Re-engagement defaults OFF (opt-in, not opt-out) — spec section 4H:
  -- "no manipulative come-back spam." A user who never turns this on
  -- never gets one.
  re_engagement_enabled boolean not null default false,
  quiet_hours_enabled boolean not null default false,
  -- Minutes since local midnight (0-1439), not a time-of-day type — the
  -- simplest representation that both (a) needs no timezone awareness
  -- of its own (the paired `timezone` column supplies that separately)
  -- and (b) makes the overnight-wraparound case (22:30 -> 07:00) a
  -- plain numeric comparison client-side, not a date-arithmetic problem.
  quiet_hours_start_minute integer not null default 1350,
  quiet_hours_end_minute integer not null default 420,
  -- IANA identifier (e.g. "Africa/Cairo"), supplied by the client from
  -- the device's own timezone — never assumed to be UTC (spec section
  -- 9: "do not silently assume UTC represents the user's local
  -- notification time").
  timezone text not null default 'UTC',
  updated_at timestamptz not null default timezone('utc', now()),

  constraint notification_preferences_quiet_hours_range check (
    quiet_hours_start_minute between 0 and 1439
    and quiet_hours_end_minute between 0 and 1439
  ),
  constraint notification_preferences_timezone_not_blank check (
    char_length(timezone) > 0
  )
);

comment on table public.notification_preferences is
  'Client-owned notification preferences (trust_boundary.dart: local '
  'notification scheduling). One row per user, bootstrapped on signup, '
  'own-row read/update only — RLS is what actually enforces '
  'account-switch isolation here, not client-side care.';

create trigger notification_preferences_set_updated_at
  before update on public.notification_preferences
  for each row
  execute function public.forge_set_updated_at();

alter table public.notification_preferences enable row level security;

create policy notification_preferences_select_own
  on public.notification_preferences
  for select
  to authenticated
  using (user_id = auth.uid());

create policy notification_preferences_update_own
  on public.notification_preferences
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Baseline table-level grant — see the comment on the notifications
-- grant above for why this is required in addition to the policies.
-- Unlike notifications, every column here is legitimately user-owned,
-- so no column-level narrowing is needed.
grant select, update on public.notification_preferences to authenticated;

-- Bootstrap: one notification_preferences row per new auth.users row,
-- exactly mirroring handle_new_user()'s own pattern (see
-- 20260816120100_profiles.sql) — a separate trigger/function rather
-- than editing that one, so this migration never touches already-
-- deployed, already-working bootstrap behavior.
create or replace function public.handle_new_user_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

comment on function public.handle_new_user_notification_preferences() is
  'SECURITY DEFINER bootstrap trigger: creates exactly one '
  'notification_preferences row (all defaults) per new auth.users row. '
  'Idempotent, insert-only, explicit search_path.';

create trigger on_auth_user_created_notification_preferences
  after insert on auth.users
  for each row
  execute function public.handle_new_user_notification_preferences();

-- Backfill: every already-existing user gets a default-preferences row
-- too, so this feature works immediately for accounts created before
-- this migration ran (staging already has synthetic test users).
insert into public.notification_preferences (user_id)
select id from auth.users
on conflict (user_id) do nothing;

-- =======================================================================
-- forge_create_notification — the one place a notification row is ever
-- inserted. Never granted to `authenticated`; only called from inside
-- the other SECURITY DEFINER functions below, in the same transaction
-- as the fact it records.
-- =======================================================================

create or replace function public.forge_create_notification(
  p_user_id uuid,
  p_type text,
  p_dedup_key text,
  p_metadata jsonb
)
returns void
language plpgsql
as $$
begin
  insert into public.notifications (user_id, type, dedup_key, metadata)
  values (p_user_id, p_type, p_dedup_key, p_metadata)
  on conflict (user_id, dedup_key) do nothing;
end;
$$;

revoke all on function public.forge_create_notification(uuid, text, text, jsonb) from public;

-- =======================================================================
-- forge_submit_mission — re-created with two additive notification
-- hooks, achievement unlock and level-up, both inside the achievement/
-- XP blocks that already exist. No other line of the function changes;
-- see 20260817090100_mission_reward_functions.sql for the original.
-- =======================================================================

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

    -- Item 15: level-up notification, atomically with the confirmed
    -- level change above — never a separate, later, potentially-
    -- disagreeing write. Dedup key includes the level reached, so a
    -- retried/idempotent replay of this same command (which returns the
    -- cached response above and never reaches this code a second time
    -- anyway) or a future genuine level-up both behave correctly.
    if v_new_level > v_prev_level then
      perform public.forge_create_notification(
        v_user_id, 'level_up',
        'level_up:' || v_user_id::text || ':' || v_new_level::text,
        jsonb_build_object('previousLevel', v_prev_level, 'newLevel', v_new_level)
      );
    end if;
  end if;

  for v_unlocked_row in
    select * from public.forge_evaluate_achievements(v_user_id, p_mission_instance_id)
  loop
    v_unlocked := v_unlocked || jsonb_build_array(v_unlocked_row.stable_key);
    insert into public.audit_log (actor_type, actor_id, action, target_type, target_id, metadata)
    values ('service', v_user_id, 'achievement_grant', 'achievement', v_unlocked_row.achievement_id::text,
      jsonb_build_object('missionInstanceId', p_mission_instance_id, 'title', v_unlocked_row.title));

    -- Item 15: one notification per unlocked achievement, atomically.
    -- Dedup key is the achievement id itself — unique(user_id,
    -- achievement_id) on user_achievements already makes a duplicate
    -- unlock structurally impossible, so this can never double-fire.
    perform public.forge_create_notification(
      v_user_id, 'achievement_unlock',
      'achievement:' || v_user_id::text || ':' || v_unlocked_row.achievement_id::text,
      jsonb_build_object(
        'achievementId', v_unlocked_row.achievement_id,
        'stableKey', v_unlocked_row.stable_key,
        'title', v_unlocked_row.title
      )
    );
  end loop;

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

revoke all on function public.forge_submit_mission(text, text, uuid, integer, text, text, jsonb) from public;
grant execute on function public.forge_submit_mission(text, text, uuid, integer, text, text, jsonb) to authenticated;

-- =======================================================================
-- forge_finalize_season_week — re-created with an additive notification
-- pass after the existing per-league ranking insert loop. Iterates the
-- just-upserted competition_week_results rows for this (season, week)
-- and creates a week_result + weekly_recap notification for each — both
-- keyed by (user, season, week), so a duplicate/idempotent re-run of
-- this same finalization (the whole reason competition_week_results
-- itself is an upsert) never creates duplicate notifications either.
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
  v_result_row record;
begin
  select * into v_week from public.competition_weeks
  where season_id = p_season_id and week_number = p_week_number;
  if not found then
    raise exception 'forge_finalize_season_week: no such (season, week): (%, %)', p_season_id, p_week_number;
  end if;

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

  -- Item 15: one week_result + one weekly_recap notification per
  -- participant, derived from the results just written above — no
  -- extra ranking computation, just reading back what was upserted.
  for v_result_row in
    select * from public.competition_week_results
    where season_id = p_season_id and week_number = p_week_number
  loop
    perform public.forge_create_notification(
      v_result_row.user_id, 'week_result',
      'week_result:' || v_result_row.user_id::text || ':' || p_season_id::text || ':' || p_week_number::text,
      jsonb_build_object(
        'seasonId', p_season_id,
        'weekNumber', p_week_number,
        'rank', v_result_row.rank,
        'promotionStatus', v_result_row.promotion_status,
        'leagueId', v_result_row.league_id,
        'targetLeagueId', v_result_row.target_league_id
      )
    );
    perform public.forge_create_notification(
      v_result_row.user_id, 'weekly_recap',
      'weekly_recap:' || v_result_row.user_id::text || ':' || p_season_id::text || ':' || p_week_number::text,
      jsonb_build_object(
        'seasonId', p_season_id,
        'weekNumber', p_week_number,
        'weeklyScore', v_result_row.weekly_score,
        'activeDays', v_result_row.active_days
      )
    );
  end loop;

  insert into public.audit_log (actor_type, action, target_type, target_id, metadata)
  values ('service', 'league_assignment', 'competition_week',
    p_season_id::text || ':' || p_week_number::text,
    jsonb_build_object('seasonId', p_season_id, 'weekNumber', p_week_number, 'rowsWritten', v_written));

  return v_written;
end;
$$;

revoke all on function public.forge_finalize_season_week(uuid, integer) from public;
-- Deliberately no grant to `authenticated` — see original migration.

-- =======================================================================
-- forge_finalize_season — re-created with an additive notification pass
-- after the existing season_results upsert, keyed by (user, season) —
-- the same key season_results itself is uniquely constrained on, so a
-- re-run of this idempotent finalization never duplicates.
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
  v_season_result_row record;
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

  -- Item 15: one season_result notification per participant — the
  -- season's one-time wrap-up, not a repeated nudge (spec section 4G).
  for v_season_result_row in
    select * from public.season_results where season_id = p_season_id
  loop
    perform public.forge_create_notification(
      v_season_result_row.user_id, 'season_result',
      'season_result:' || v_season_result_row.user_id::text || ':' || p_season_id::text,
      jsonb_build_object(
        'seasonId', p_season_id,
        'finalLeagueId', v_season_result_row.final_league_id,
        'totalSeasonScore', v_season_result_row.total_season_score,
        'rankInLeague', v_season_result_row.rank_in_league,
        'promoted', v_season_result_row.promoted,
        'demoted', v_season_result_row.demoted
      )
    );
  end loop;

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
-- Deliberately no grant to `authenticated` — see original migration.
