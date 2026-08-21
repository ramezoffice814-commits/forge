-- Phase 10B: integrity_events (private anti-abuse signals) and
-- audit_log (server-side action trail). Both are fully locked down from
-- every client role — no `authenticated` policy exists on either table,
-- so under RLS's default-deny, normal users have precisely zero access
-- (no SELECT, no INSERT, no UPDATE, no DELETE). Only `service_role`
-- (which bypasses RLS by Supabase design) or a future narrowly-scoped
-- SECURITY DEFINER function can touch these.
--
-- If a user-facing integrity status is ever needed, spec section 12 is
-- explicit: expose a *separate*, neutral derived status (e.g. "some
-- activity is pending verification" — the same neutral framing the
-- existing Dart `CompetitionIntegrityPolicy` already uses), never a
-- read path into this table itself.

create table public.integrity_events (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  mission_instance_id uuid references public.mission_instances (id) on delete set null,
  signal_type text not null,
  severity text not null,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  created_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz,

  constraint integrity_events_signal_type_check check (
    signal_type in (
      'duplicate_completion', 'impossible_sequence', 'excessive_volume',
      'repeated_farming', 'abnormal_score_jump', 'timestamp_anomaly',
      'invalid_validation_state', 'local_only_unconfirmed'
    )
  ),
  constraint integrity_events_severity_check check (
    severity in ('clean', 'warning', 'excluded')
  ),
  constraint integrity_events_status_check check (
    status in ('open', 'reviewed', 'resolved', 'dismissed')
  )
);

comment on table public.integrity_events is
  'PRIVATE. Internal anti-abuse signals — no authenticated-role policy '
  'exists at all. Never expose this table (or a view over it) to '
  'normal users; if a user-facing status is needed, derive a separate '
  'neutral value instead. See spec section 12 / README.';

create index integrity_events_user_id_idx on public.integrity_events (user_id);
create index integrity_events_status_idx on public.integrity_events (status);

alter table public.integrity_events enable row level security;
-- No policies for `authenticated` — intentional. Do not add a "select
-- own" policy here without a deliberate design decision; owning your
-- own integrity signal is not the same as being allowed to see it.

create table public.audit_log (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_type text not null,
  actor_id uuid,
  action text not null,
  target_type text not null,
  target_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),

  constraint audit_log_actor_type_check check (
    actor_type in ('system', 'service', 'admin', 'user')
  ),
  constraint audit_log_action_check check (
    action in (
      'xp_grant', 'xp_reversal', 'achievement_grant', 'league_assignment',
      'season_finalization', 'integrity_exclusion'
    )
  )
);

comment on table public.audit_log is
  'PRIVATE. Server-side trail of sensitive authoritative operations — '
  'no authenticated-role policy exists. Written only by future '
  'service-role/SECURITY DEFINER server code, never by application '
  'clients.';

create index audit_log_target_idx on public.audit_log (target_type, target_id);
create index audit_log_created_at_idx on public.audit_log (created_at);

alter table public.audit_log enable row level security;
-- No policies for `authenticated` — intentional, see table comment.
