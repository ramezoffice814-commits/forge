-- Phase 10C: additive columns the authoritative mission-command pipeline
-- needs and Phase 10B did not yet provide, plus one additive audit_log
-- action-code expansion. Nothing here rewrites a Phase 10B migration —
-- every change is a new, forward-only ALTER in its own migration file
-- (spec: "Do not rewrite Phase 10B migrations").
--
-- Why these are needed now and weren't in Phase 10B: Phase 10B explicitly
-- deferred "real XP calculation" and "full transition-legality
-- validation" to a future Edge Function (see mission_instances.sql's own
-- comment). This migration is that future arriving — the reward engine
-- in 20260817090100_mission_reward_functions.sql needs a few per-mission
-- facts that were never stored because nothing computed with them yet.

-- mission_definitions.base_xp_hint: XpCalculationPolicy.evaluate's
-- `summary.baseXpHint` input (lib/features/progression/domain/policies/
-- xp_calculation_policy.dart) has no server-side source at all today —
-- mission_definitions never carried an XP value. Default 10 is a
-- conservative placeholder for the 9 seeded missions (see the seed.sql
-- update alongside this migration for curated per-mission values).
alter table public.mission_definitions
  add column base_xp_hint integer not null default 10;

alter table public.mission_definitions
  add constraint mission_definitions_base_xp_hint_check
  check (base_xp_hint > 0 and base_xp_hint <= 100);

comment on column public.mission_definitions.base_xp_hint is
  'Server-side base XP input for XpCalculationPolicy parity — the '
  'authoritative counterpart to the Dart engine''s MissionDefinition.'
  'baseXpHint. System-managed, same read-only policy as the rest of '
  'this table.';

-- mission_instances: three per-instance facts the Dart mission-selection
-- engine resolves dynamically (resolvedDifficulty can differ from the
-- catalog's base difficulty; recoveryMission is decided per assignment,
-- not per catalog entry) and one optional per-instance XP override —
-- none of which existed as columns because nothing server-side needed
-- them until this phase's reward engine.
alter table public.mission_instances
  add column resolved_difficulty text,
  add column recovery_mission boolean not null default false,
  add column base_xp_hint integer,
  add column completion_quality text;

alter table public.mission_instances
  add constraint mission_instances_resolved_difficulty_check check (
    resolved_difficulty is null or resolved_difficulty in (
      'restorative', 'easy', 'moderate', 'challenging', 'advanced'
    )
  ),
  add constraint mission_instances_base_xp_hint_check check (
    base_xp_hint is null or (base_xp_hint > 0 and base_xp_hint <= 100)
  ),
  add constraint mission_instances_completion_quality_check check (
    completion_quality is null or completion_quality in ('low', 'standard', 'high')
  );

comment on column public.mission_instances.resolved_difficulty is
  'Per-instance resolved difficulty (mirrors MissionInstance.'
  'resolvedDifficulty). NULL falls back to the mission_definitions row''s '
  'catalog difficulty — the reward engine always reads '
  'coalesce(resolved_difficulty, mission_definitions.difficulty).';

comment on column public.mission_instances.recovery_mission is
  'Per-instance recovery flag (mirrors MissionInstance.recoveryMission). '
  'Not derivable from the catalog alone — the mission-selection engine '
  'decides this per assignment. Defaults false; assignment is out of '
  'scope for Phase 10C (see supabase/README.md), so this column exists '
  'for the reward engine to read but nothing in this phase writes a '
  'non-default value for it yet.';

comment on column public.mission_instances.base_xp_hint is
  'Optional per-instance XP hint override. NULL falls back to '
  'mission_definitions.base_xp_hint.';

comment on column public.mission_instances.completion_quality is
  'Optional per-instance quality signal for '
  'ForgeCompetitiveScorePolicy''s quality factor (low/standard/high). '
  'NULL is treated as ''standard'' by the reward engine — no proof-'
  'quality evidence pipeline exists yet to set this to anything else '
  '(documented limitation, see supabase/README.md).';

-- audit_log: section 18 of the Phase 10C spec asks for audit records on
-- "confirmed XP grant, progression update, achievement unlock,
-- competition score award, integrity exclusion/restriction". Phase 10B's
-- audit_log_action_check already covers xp_grant/xp_reversal/
-- achievement_grant/integrity_exclusion but not progression_update or
-- competition_score_award — add them via a fresh constraint (drop +
-- recreate is the standard way to widen a CHECK; the old migration file
-- itself is untouched).
alter table public.audit_log drop constraint audit_log_action_check;
alter table public.audit_log add constraint audit_log_action_check check (
  action in (
    'xp_grant', 'xp_reversal', 'achievement_grant', 'league_assignment',
    'season_finalization', 'integrity_exclusion', 'progression_update',
    'competition_score_award'
  )
);
