-- Phase 10B: processed_commands — server-side idempotency persistence
-- (spec section 7). Phase 10A's `IdempotencyReplayGuard` is in-memory
-- only and resets on every app/process restart; this table is the
-- durable backing store a future Edge Function will consult so a
-- duplicate submission is caught even across restarts, redeploys, or
-- concurrent requests.
--
-- Entirely server-internal: no `authenticated` policy exists at all, so
-- normal clients have zero access (SELECT/INSERT/UPDATE/DELETE all deny
-- by default under RLS). Only `service_role` — which bypasses RLS by
-- Supabase design — reads or writes this table, from a future Edge
-- Function. That function's own logic (not this migration) is
-- responsible for the "same key + same request -> same cached result;
-- same key + conflicting request -> reject" behavior; this table only
-- provides the durable, uniquely-constrained storage that makes it
-- possible.

create table public.processed_commands (
  command_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  idempotency_key text not null,
  command_type text not null,
  request_hash text not null,
  response_payload jsonb not null,
  processed_at timestamptz not null default timezone('utc', now()),

  constraint processed_commands_idempotency_key_unique unique (idempotency_key)
);

comment on table public.processed_commands is
  'Durable idempotency ledger for the future authoritative mission '
  'pipeline. Server-internal only — no authenticated-role policy exists. '
  'unique(idempotency_key) is what makes duplicate reward processing '
  'structurally impossible even across process restarts.';

create index processed_commands_user_id_idx on public.processed_commands (user_id);

alter table public.processed_commands enable row level security;
-- No policies created for `authenticated` — every operation denies by
-- default. Intentionally left without a comment-only "no access" policy
-- since RLS's default-deny already provides this; adding a permissive
-- policy here would be the mistake, not omitting one.
