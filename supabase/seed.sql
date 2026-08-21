-- Local-dev-only seed data for system-managed catalogs. Safe to re-run
-- (every insert is idempotent via ON CONFLICT). Never seeds any
-- user-tied row (profiles/progression/etc.) — those are created by the
-- bootstrap triggers when a real (local) auth user signs up.
--
-- League catalog mirrors lib/features/competition/data/mock/league_catalog.dart
-- exactly, so local Postgres data and the Dart mock catalog agree.

insert into public.league_definitions
  (stable_key, name, tier, min_placement_rating, max_group_size, promotion_count, demotion_count, protected_placement_days, visual_tier)
values
  ('league-ember',    'Ember',    0,    0, 25, 5, 0, 7, 0),
  ('league-iron',     'Iron',     1,  400, 25, 5, 5, 7, 1),
  ('league-steel',    'Steel',    2,  900, 25, 5, 5, 7, 2),
  ('league-titanium', 'Titanium', 3, 1600, 25, 5, 5, 7, 3),
  ('league-obsidian', 'Obsidian', 4, 2500, 25, 5, 5, 7, 4),
  ('league-mythic',   'Mythic',   5, 3600, 25, 0, 5, 7, 5)
on conflict (stable_key) do nothing;

insert into public.competition_seasons
  (stable_key, name, starts_at, ends_at, status, week_count, active)
values
  ('season-1', 'Season 1: Ember Rising', '2026-08-03T00:00:00Z', '2026-09-28T00:00:00Z', 'active', 8, true)
on conflict (stable_key) do nothing;

insert into public.competition_weeks (season_id, week_number, starts_at, ends_at, status)
select
  s.id,
  week_number,
  s.starts_at + (week_number - 1) * interval '7 days',
  s.starts_at + week_number * interval '7 days',
  case
    when week_number = 1 then 'active'
    else 'upcoming'
  end
from public.competition_seasons s
cross join generate_series(1, 8) as week_number
where s.stable_key = 'season-1'
on conflict (season_id, week_number) do nothing;

insert into public.mission_definitions
  (stable_key, title, description, category, difficulty, expected_duration_minutes, base_xp_hint, rules)
values
  ('fitness-10min-stretch', '10-Minute Full-Body Stretch', 'A guided full-body stretch routine.', 'fitness', 'easy', 10, 12, '{}'),
  ('coding-25min-focus', '25-Minute Focused Coding Session', 'One uninterrupted coding session.', 'coding', 'moderate', 25, 18, '{}'),
  ('reading-15min-book', '15 Minutes of Reading', 'Read anything that isn''t a screen.', 'reading', 'easy', 15, 12, '{}'),
  ('mindfulness-5min-breathing', '5-Minute Breathing Exercise', 'A short guided breathing exercise.', 'mindfulness', 'restorative', 5, 8, '{}'),
  ('hydration-daily-water', 'Daily Hydration Check-in', 'Log your water intake for the day.', 'hydration', 'restorative', 2, 5, '{}'),
  ('planning-tomorrow-outline', 'Plan Tomorrow', 'Outline tomorrow''s top three priorities.', 'planning', 'easy', 10, 12, '{}'),
  ('focus-45min-deepwork', '45-Minute Deep Work Block', 'One long, distraction-free work block.', 'focus', 'challenging', 45, 22, '{}'),
  ('creative-20min-practice', '20 Minutes of Creative Practice', 'Any creative practice — drawing, writing, music.', 'creative', 'moderate', 20, 18, '{}'),
  ('recovery-gentle-walk', 'Gentle Recovery Walk', 'A slow, easy walk — recovery mode.', 'recovery', 'restorative', 15, 8, '{}')
on conflict (stable_key) do nothing;

-- Canonical achievement catalog (spec section 6 / migration
-- 20260820090100_achievement_canonical_ids.sql). Seeded directly here
-- with the FINAL canonical stable_keys/criteria — not the old
-- Phase 10B placeholder keys — because `supabase db reset` runs every
-- migration BEFORE this file, so the migration's UPDATE-based rename
-- (which targets a real, already-deployed project's existing rows) has
-- nothing to rename on a from-zero reset: the rows it looks for
-- ('first-steps', 'consistent-week', etc.) don't exist yet at that
-- point. Seeding the canonical values directly here keeps a fresh local
-- reset and a real upgraded deployment converging on the identical
-- final state. This file is local-dev/CI-only (see header) and is never
-- run against a real deployed project, so it never conflicts with the
-- migration's separate, FK-safe UPDATE path.
insert into public.achievement_definitions (stable_key, title, description, criteria)
values
  ('first_mission', 'First Steps', 'Complete your first mission.', '{"missions_completed": 1}'),
  ('consistency_7_day', 'Steady Hands', 'Maintain a 7-day streak.', '{"streak_days": 7}'),
  ('tried_3_categories', 'Curious Mind', 'Try 3 different mission categories.', '{"distinct_categories": 3}'),
  ('momentum_3_day', 'Momentum', 'Maintain a 3-day streak.', '{"streak_days": 3}'),
  ('recovery_5', 'Gentle Progress', 'Complete 5 recovery missions.', '{"recovery_completions": 5}')
on conflict (stable_key) do nothing;
