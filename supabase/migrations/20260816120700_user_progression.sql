-- Phase 10B: user_progression — server-authoritative cached state,
-- always intended to be re-derivable from xp_ledger (a materialized
-- summary, not an independent source of truth). `version` supports
-- future optimistic-concurrency updates from the server-side
-- transaction that will eventually maintain this row.
--
-- No real server XP-calculation engine exists yet (spec section 9) — a
-- fresh row starts at confirmed_xp=0/level=1 and stays there until a
-- future authoritative pipeline updates it transactionally alongside an
-- xp_ledger insert.

create table public.user_progression (
  user_id uuid primary key references auth.users (id) on delete cascade,
  confirmed_xp bigint not null default 0,
  level integer not null default 1,
  title_key text,
  version integer not null default 0,
  updated_at timestamptz not null default timezone('utc', now()),

  constraint user_progression_confirmed_xp_nonnegative check (confirmed_xp >= 0),
  constraint user_progression_level_positive check (level >= 1),
  constraint user_progression_version_nonnegative check (version >= 0)
);

comment on table public.user_progression is
  'Server-authoritative cached progression state, derived from '
  'xp_ledger. Own-row SELECT only for authenticated clients — no client '
  'INSERT/UPDATE/DELETE policy exists. A future transactional server '
  'process is the only writer.';

create trigger user_progression_set_updated_at
  before update on public.user_progression
  for each row
  execute function public.forge_set_updated_at();

alter table public.user_progression enable row level security;

create policy user_progression_select_own
  on public.user_progression
  for select
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Bootstrap: one user_progression row per new auth.users row.
-- ---------------------------------------------------------------------
-- A separate, single-purpose trigger/function rather than folding this
-- into handle_new_user() (see 20260816120100_profiles.sql) — each
-- bootstrap trigger stays narrowly scoped to exactly one table, so a
-- future change to one never risks the other. Same safety properties as
-- handle_new_user(): SECURITY DEFINER (required — the auth.users
-- insert context has no standing grant on public.user_progression),
-- explicit search_path, insert-only, idempotent via ON CONFLICT.
create or replace function public.handle_new_user_progression()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_progression (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

comment on function public.handle_new_user_progression() is
  'SECURITY DEFINER bootstrap trigger: creates exactly one '
  'user_progression row (confirmed_xp=0, level=1) per new auth.users '
  'row. Idempotent, insert-only, explicit search_path.';

create trigger on_auth_user_created_progression
  after insert on auth.users
  for each row
  execute function public.handle_new_user_progression();
