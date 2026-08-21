-- Phase 11: achievement catalog canonicalization (spec section 6).
--
-- AUDIT (see the Phase 10D final report, item #7, for how this
-- mismatch was first found): Phase 10B's seed.sql invented five
-- placeholder achievements with its own ad hoc stable_keys
-- ('first-steps', 'consistent-week', 'category-explorer',
-- 'early-riser', 'recovery-respected') and criteria shapes that were
-- never reconciled against lib/features/progression/data/catalog/
-- achievement_catalog.dart's twelve real, hand-authored achievements
-- ('first_mission', 'momentum_3_day', 'consistency_7_day',
-- 'tried_3_categories', 'tried_all_categories', 'coding_10',
-- 'reading_10', 'fitness_10', 'returned_from_break', 'recovery_5',
-- 'advanced_10', 'mastery_50_total').
--
-- DECISION: the Flutter catalog is canonical. It's the richer,
-- intentionally-designed set (rarity tiers, hiddenUntilUnlocked,
-- real criteria types); the seed's five were always placeholders. This
-- migration UPDATEs (never DELETEs) the five existing rows to reuse
-- their ids under new canonical stable_keys/criteria, then INSERTs the
-- remaining seven — never a delete+reinsert, so a hypothetical
-- existing user_achievements FK reference stays valid (see the FK on
-- that table: `references achievement_definitions (id)`, no explicit
-- cascade, so a delete would have been a foreign-key hazard if any
-- real unlock data existed).
--
-- forge_evaluate_achievements (redefined below) now genuinely computes
-- all twelve — not a subset. Every jsonb criteria key it reads is one
-- of: missions_completed, streak_days, distinct_categories,
-- category_completions, recovery_completions, difficulty_completions,
-- returned_from_break.

update public.achievement_definitions set
  stable_key = 'first_mission', title = 'First Steps',
  description = 'Complete your first mission.',
  criteria = '{"missions_completed": 1}'
where stable_key = 'first-steps';

update public.achievement_definitions set
  stable_key = 'consistency_7_day', title = 'Steady Hands',
  description = 'Maintain a 7-day streak.',
  criteria = '{"streak_days": 7}'
where stable_key = 'consistent-week';

update public.achievement_definitions set
  stable_key = 'tried_3_categories', title = 'Curious Mind',
  description = 'Try 3 different mission categories.',
  criteria = '{"distinct_categories": 3}'
where stable_key = 'category-explorer';

update public.achievement_definitions set
  stable_key = 'momentum_3_day', title = 'Momentum',
  description = 'Maintain a 3-day streak.',
  criteria = '{"streak_days": 3}'
where stable_key = 'early-riser';

update public.achievement_definitions set
  stable_key = 'recovery_5', title = 'Gentle Progress',
  description = 'Complete 5 recovery missions.',
  criteria = '{"recovery_completions": 5}'
where stable_key = 'recovery-respected';

insert into public.achievement_definitions (stable_key, title, description, criteria) values
  ('tried_all_categories', 'Full Spectrum', 'Try every mission category at least once.',
    '{"distinct_categories": 12}'),
  ('coding_10', 'Code Momentum', 'Complete 10 coding missions.',
    '{"category_completions": {"category": "coding", "target": 10}}'),
  ('reading_10', 'Bookworm', 'Complete 10 reading missions.',
    '{"category_completions": {"category": "reading", "target": 10}}'),
  ('fitness_10', 'Iron Habit', 'Complete 10 fitness missions.',
    '{"category_completions": {"category": "fitness", "target": 10}}'),
  ('returned_from_break', 'Welcome Back', 'Returned to a mission after some time away.',
    '{"returned_from_break": true}'),
  ('advanced_10', 'Pushing Limits', 'Complete 10 challenging-or-above missions.',
    '{"difficulty_completions": {"min_difficulty": "challenging", "target": 10}}'),
  ('mastery_50_total', 'Forged in Repetition', 'Complete 50 missions total.',
    '{"missions_completed": 50}')
on conflict (stable_key) do nothing;

-- Redefine forge_evaluate_achievements to cover all seven criteria
-- shapes above (was: missions_completed, distinct_categories,
-- recovery_completions only — see 20260817090100_mission_reward_
-- functions.sql's original version and its own doc comment, now
-- superseded by this one).
create or replace function public.forge_evaluate_achievements(p_user_id uuid, p_mission_instance_id uuid)
returns table(achievement_id uuid, stable_key text, title text)
language plpgsql
as $$
#variable_conflict use_column
-- Without this, `on conflict (user_id, achievement_id)` below is
-- ambiguous: `achievement_id` could mean either this function's own OUT
-- parameter or the user_achievements.achievement_id column, and
-- Postgres refuses to guess (caught only by actually running this
-- function for the first time). This pragma resolves every such bare
-- reference to the table column; the one assignment target
-- (`achievement_id := v_def.id;`) is unaffected since `:=` always
-- means the variable.
declare
  v_def record;
  v_current integer;
  v_target integer;
  v_category text;
  v_min_difficulty text;
  v_gap_days integer;
  v_dates date[];
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

    elsif v_def.criteria ? 'streak_days' then
      v_target := (v_def.criteria ->> 'streak_days')::integer;
      -- Not "exclude self" here, deliberately: unlike the reward
      -- engine's mid-transaction streak lookup (which must not count
      -- the mission still being scored), an achievement check runs
      -- after the mission is already durably completed, so today's
      -- completion legitimately counts toward the streak, matching
      -- Dart's own MissionHistorySnapshotBuilder semantics.
      select public.forge_current_streak_days(p_user_id, timezone('utc', now())) into v_current;

    elsif v_def.criteria ? 'category_completions' then
      v_target := (v_def.criteria -> 'category_completions' ->> 'target')::integer;
      v_category := v_def.criteria -> 'category_completions' ->> 'category';
      select count(*) into v_current
      from public.mission_instances mi
      join public.mission_definitions md on md.id = mi.mission_definition_id
      where mi.user_id = p_user_id and mi.status = 'completed' and md.category = v_category;

    elsif v_def.criteria ? 'difficulty_completions' then
      v_target := (v_def.criteria -> 'difficulty_completions' ->> 'target')::integer;
      v_min_difficulty := v_def.criteria -> 'difficulty_completions' ->> 'min_difficulty';
      select count(*) into v_current
      from public.mission_instances mi
      join public.mission_definitions md on md.id = mi.mission_definition_id
      where mi.user_id = p_user_id and mi.status = 'completed'
        and public.forge_difficulty_weight(coalesce(mi.resolved_difficulty, md.difficulty))
          >= public.forge_difficulty_weight(v_min_difficulty);

    elsif v_def.criteria ? 'returned_from_break' then
      -- Mirrors ReturnedFromInactivityCriteria: true iff the most
      -- recent completion followed a 3+ day gap since the one before
      -- it. Binary criteria — target is always 1.
      v_target := 1;
      select array_agg(d order by d) into v_dates
      from (
        select distinct (mi.completed_at at time zone 'utc')::date as d
        from public.mission_instances mi
        where mi.user_id = p_user_id and mi.status = 'completed' and mi.completed_at is not null
      ) s;
      if coalesce(array_length(v_dates, 1), 0) >= 2 then
        v_gap_days := v_dates[array_length(v_dates, 1)] - v_dates[array_length(v_dates, 1) - 1];
        v_current := case when v_gap_days >= 3 then 1 else 0 end;
      else
        v_current := 0;
      end if;

    else
      continue; -- unrecognized criteria shape — skip, never guess.
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

revoke all on function public.forge_evaluate_achievements(uuid, uuid) from public;
