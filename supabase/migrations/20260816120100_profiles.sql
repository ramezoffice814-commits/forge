-- Phase 10B: profiles — the minimal, safe application identity record
-- tied 1:1 to a Supabase Auth user. Deliberately holds nothing beyond
-- display identity: no email, no auth credentials, no behavioral data.
--
-- Privacy: this table's RLS is OWN-ROW-ONLY (spec section 3: "public
-- profile exposure must be explicitly separate if necessary"). A
-- friends/leaderboard-facing public-profile read path is explicitly
-- Phase 10B out-of-scope (social/competition backend wiring lands in a
-- later phase) — building a public view now would be exposing a read
-- path before the feature that needs it, and every additional exposed
-- surface is something to get wrong. See supabase/README.md.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  avatar_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint profiles_display_name_length check (
    char_length(display_name) between 1 and 60
  )
);

comment on table public.profiles is
  'Safe application identity only — never auth credentials, never '
  'behavioral/recovery data. See RLS policies below.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.forge_set_updated_at();

alter table public.profiles enable row level security;

-- Own-row read/update only. No client INSERT policy at all — rows are
-- created exclusively by the bootstrap trigger below (SECURITY DEFINER),
-- so a client can never create a profile for an id they don't control
-- and can never create more than one profile for themselves.
create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (user_id = auth.uid());

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Bootstrap: one profiles row per new auth.users row.
-- ---------------------------------------------------------------------
-- SECURITY DEFINER is required here: this trigger fires on `auth.users`
-- (owned by the `supabase_auth_admin` role), and the inserting context
-- has no standing grant to write `public.profiles`. Running as the
-- function's owner (a superuser-equivalent role at migration time) is
-- the standard, documented Supabase pattern for this exact bootstrap
-- case. Kept intentionally minimal and idempotent:
--   - only ever inserts, never updates or deletes
--   - `on conflict do nothing` makes a duplicate trigger fire (or a
--     retried signup) a harmless no-op rather than an error
--   - explicit `search_path` prevents search-path hijacking, the classic
--     SECURITY DEFINER foot-gun
--   - reads only `NEW.id`/`NEW.raw_user_meta_data`, nothing else off the
--     auth row
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(new.email, '@', 1),
      'Forge Player'
    )
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

comment on function public.handle_new_user() is
  'SECURITY DEFINER bootstrap trigger: creates exactly one profiles row '
  'per new auth.users row. Idempotent (ON CONFLICT DO NOTHING), '
  'insert-only, explicit search_path. Never touches any table besides '
  'public.profiles.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
