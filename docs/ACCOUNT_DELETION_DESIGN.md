# Account Deletion — Design Notes

Roadmap Item 20 ("Production Release & Store Submission Prep"). Play
Store policy requires apps that support account creation to provide an
in-app account-deletion path (or, at minimum, a clearly documented
deletion process) once published. Today, `DeleteAccountRequestUseCase`
→ `AuthRepository.requestAccountDeletion()` is a deliberate, honest
placeholder — it throws `NotSupportedYetFailure` in both
`MockAuthRepository` and `SupabaseAuthRepository`, unchanged since Item
16's own decision not to fake destructive deletion. This document is
the design groundwork for closing that gap: a data map, a proposed
flow, and the decisions a human still needs to make before it's safe to
build. **No destructive deletion logic is implemented by this
document.**

## Data map

Every table below has a foreign key to `auth.users(id) on delete
cascade` — a Supabase Auth user-delete already cascades to all of them
automatically at the database level:

| Table | What it holds | Deletion sensitivity |
|---|---|---|
| `profiles` | Display name, avatar, account-level settings | Low — purely owned by the user. |
| `mission_instances` | The user's own assigned/completed missions | Low — purely owned by the user. |
| `mission_events` | Append-only event log backing mission history | **See "open design question" below.** |
| `processed_commands` | Idempotency ledger for command submission | Low — internal bookkeeping, safe to lose. |
| `xp_ledger` | Append-only XP award history | **See "open design question" below.** |
| `user_progression` | Current level/XP/title snapshot | Low — purely owned by the user. |
| `achievements` | Unlocked achievement records | Low — purely owned by the user. |
| `competition_memberships` | Which league/group the user belongs to | Low — membership record, not shared history. |
| `season_results` | The user's own past season standings | **See "open design question" below** (Hall of Fame implications). |
| `competition_week_results` | The user's own weekly competition results | **See "open design question" below.** |
| weekly-group membership table | Which weekly competition group the user was placed in | Low, but affects other members' group composition for that week (historical, not live). |
| `integrity_events` | Anti-cheat/audit trail entries referencing the user | Needs a trust-and-safety decision — see [docs/DATA_RETENTION_DECISIONS.md](DATA_RETENTION_DECISIONS.md) Tier 3. |
| `notifications` | The user's own notification inbox | Low — purely owned by the user. |
| `notification_preferences` | The user's own notification settings | Low — purely owned by the user. |

Local (on-device) data (`flutter_secure_storage`-backed: session,
onboarding flag, AI privacy choice, `LocalReminderStore`,
`AiCoachCacheStore`) is not part of server-side deletion — it's
disposable by design (see [docs/RECOVERY.md](RECOVERY.md), "Local
(on-device) data") and would naturally go stale/unused once the account
no longer authenticates; no explicit local wipe is strictly required
for correctness, though a real implementation may still choose to clear
it proactively as good UX on the device that requested deletion.

## Open design question (blocks a safe implementation)

`xp_ledger`, `mission_events`, and the competition-result tables
(`season_results`, `competition_week_results`) being cascade-deleted
would also destroy history that **other users'** aggregate data may
reference — a season's best-N-of-M scoring, league standings computed
from group members' weekly results, and the Hall of Fame. A raw
`on delete cascade` is correct for tables the user exclusively owns; it
is very likely *wrong* for these, because it would silently corrupt
other people's historical/aggregate records the moment one user in a
shared season deletes their account.

Two real options exist, and this document does not choose between them:

1. **Anonymize-in-place**: replace the user's identifying fields
   (`profiles.display_name`, anything else that renders publicly) with
   a generic "deleted user" placeholder, but keep the ledger/result rows
   themselves so aggregates stay correct. Requires deciding exactly
   which columns count as "identifying" and confirming no leaderboard/
   Hall-of-Fame view re-derives the real name from a different table.
2. **Cascade-delete with aggregate backfill**: let the cascade happen
   as the schema already defines, but add logic that recomputes or
   adjusts affected aggregates (season standings, Hall of Fame entries)
   at deletion time so they don't silently go stale or wrong. More
   complex, but avoids retaining any trace of the deleted user at all —
   relevant if a "right to erasure" legal requirement applies in a
   target market.

**This decision needs to be made by whoever owns the product/legal
call on deletion completeness vs. other users' data integrity** — it
determines the entire shape of the implementation, not a detail to
fill in afterward.

## Proposed flow (not implemented)

1. User initiates deletion from Settings (a `DeleteAccountRequestUseCase`
   call site already exists in the domain layer, currently wired to the
   placeholder failure).
2. A confirmation step makes the irreversibility explicit — this is a
   destructive, unrecoverable action once executed; the UI must not let
   it happen from a single accidental tap.
3. Server-side, once the anonymize-vs-cascade decision above is made:
   either an Edge Function (following the existing pattern used by
   `finalize-week`/`finalize-season` — a `SUPABASE_SERVICE_ROLE_KEY`-
   backed function, not a client-callable RLS path, since this needs to
   touch tables the user's own RLS policy shouldn't grant a direct
   delete on) or a `SECURITY DEFINER` Postgres function performs the
   actual deletion/anonymization, then the Supabase Auth user record
   itself is deleted, triggering the cascade for the tables that should
   cascade.
4. Local on-device state is cleared on successful completion, matching
   the existing sign-out cleanup path (`LocalNotificationScheduler.
   cancelAllForSignOut()` and friends).
5. The user is signed out and returned to the unauthenticated entry
   point.

## What still blocks building this for real

- The anonymize-vs-cascade decision above (product/legal).
- A decision on `integrity_events` handling (trust-and-safety —
  deleting evidence of confirmed cheating while investigations are
  active would be its own problem).
- Whether deletion should be immediate or have a grace/cool-off period
  (some platforms require or recommend this) — a product decision.
- The Privacy Policy currently describes deletion honestly as "not yet
  available" (Item 19) — once this is implemented, that page needs a
  factual update, and a full legal pass over the *whole* Privacy
  Policy is still separately outstanding regardless (see
  [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md)'s "Human legal-review
  blockers").

## What this document does not do

It does not implement `requestAccountDeletion()`. It does not change
`NotSupportedYetFailure`'s behavior. It does not run any destructive
operation against any environment. It is the design record needed
before a future item can safely build this.
