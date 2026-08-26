-- Roadmap Item 18 (Production Hardening & Release Readiness) — purely
-- additive, non-destructive: two composite indexes supporting the
-- daily/weekly cap lookups already inside forge_submit_mission
-- (20260825120000_notifications.sql), which previously only had
-- xp_ledger_user_id_idx / competition_score_ledger_user_season_week_idx
-- to work with. Bounded by one user's own row count today, but both
-- ledgers grow per-user for the lifetime of an account, so these keep
-- "sum today's XP/score for this user" from degrading from an index
-- scan over a handful of rows into one over the user's entire history.
--
-- created_at is filtered via `(created_at at time zone 'utc')::date`
-- in the existing queries, not indexed as an expression here — the
-- real win is narrowing by (user_id, source_type) / (user_id) first,
-- which these composite indexes already support; adding the exact
-- expression index is a separate, lower-priority optimization if the
-- date-cast filter itself ever shows up as the bottleneck.
create index if not exists xp_ledger_user_source_created_idx
  on public.xp_ledger (user_id, source_type, created_at);

create index if not exists competition_score_ledger_user_created_idx
  on public.competition_score_ledger (user_id, created_at);
