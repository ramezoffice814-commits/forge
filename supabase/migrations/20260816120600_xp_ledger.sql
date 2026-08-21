-- Phase 10B: xp_ledger — the single authoritative, append-only record of
-- every XP grant (and, via a negative amount, every reversal). Every
-- other XP-shaped number in the system (user_progression.confirmed_xp,
-- future leaderboard inputs) must eventually be derivable from this
-- table — never the other way around.
--
-- The real XP calculation engine is explicitly out of scope for this
-- phase (spec section 8: "This phase establishes secure storage only").
-- What this migration guarantees is that *whenever* that engine exists,
-- the client structurally cannot forge, alter, or erase an XP grant.

create table public.xp_ledger (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  mission_instance_id uuid references public.mission_instances (id) on delete set null,
  source_type text not null,
  source_id text not null,
  amount integer not null,
  reason text not null,
  created_at timestamptz not null default timezone('utc', now()),

  constraint xp_ledger_amount_nonzero check (amount <> 0),
  constraint xp_ledger_source_type_check check (
    source_type in (
      'mission_completion', 'achievement_bonus', 'admin_adjustment',
      'reversal'
    )
  ),
  -- One XP grant per source, ever — the concrete mechanism that makes
  -- duplicate XP for the same mission completion / achievement
  -- structurally impossible (spec: "enforce uniqueness for reward
  -- source where necessary to prevent duplicate XP"). A correction is a
  -- new row with source_type = 'reversal', never an edit to this one.
  constraint xp_ledger_source_unique unique (source_type, source_id)
);

comment on table public.xp_ledger is
  'Authoritative, append-only XP ledger. unique(source_type, source_id) '
  'prevents the same mission/achievement from ever granting XP twice. '
  'No authenticated-role INSERT/UPDATE/DELETE policy exists — only '
  'SELECT of one''s own rows. Corrections are new rows '
  '(source_type=''reversal''), never edits.';

create index xp_ledger_user_id_idx on public.xp_ledger (user_id);
create index xp_ledger_mission_instance_id_idx
  on public.xp_ledger (mission_instance_id);

alter table public.xp_ledger enable row level security;

-- Read-only, own rows — spec section 14: "own read if product needs
-- it." No insert/update/delete policy for `authenticated` at all; a
-- future server-side function (running as service_role or a narrowly
-- scoped SECURITY DEFINER function with its own validation) is the only
-- writer.
create policy xp_ledger_select_own
  on public.xp_ledger
  for select
  to authenticated
  using (user_id = auth.uid());
