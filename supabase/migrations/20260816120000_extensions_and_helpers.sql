-- Phase 10B: extensions and shared helper functions.
--
-- Everything in this migration is infrastructure every later migration
-- depends on: UUID generation and one small, narrowly-scoped
-- `updated_at` trigger function. No table-specific logic lives here.

-- gen_random_uuid() — used as the default for every primary key in this
-- schema (spec: "Use UUID primary keys unless there is a compelling
-- reason otherwise").
create extension if not exists pgcrypto with schema extensions;

-- Shared `updated_at` maintenance — one trigger function reused by every
-- table that has a mutable `updated_at` column, so "now" is always the
-- database's own clock (never a client-supplied timestamp) and every
-- table gets identical behavior.
--
-- SECURITY DEFINER is deliberately NOT used here: this function only
-- ever runs as a BEFORE UPDATE trigger in the context of the triggering
-- statement's own role, and only ever touches `NEW`, so it needs no
-- elevated privilege.
create or replace function public.forge_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

comment on function public.forge_set_updated_at() is
  'BEFORE UPDATE trigger: stamps NEW.updated_at with the database''s own '
  'UTC clock. Attach to any table with a mutable updated_at column.';
