# Data Retention Decisions

Roadmap Item 20 ("Production Release & Store Submission Prep"). Item 18
([docs/RELEASE_READINESS.md](RELEASE_READINESS.md), "Privacy /
data-retention findings") first documented that several tables and
local stores grow without a retention policy. This document separates
that into three tiers — what's a fact today, what a real engineer could
choose between, and what needs an actual product/legal decision — so
that decision doesn't get made silently inside an unrelated future
change. **No retention period below has been chosen or implemented by
this document.**

## Tier 1 — technical facts (not in question)

| Store | Growth | Why |
|---|---|---|
| `notifications` (Supabase table) | Unbounded rows, one per generated notification, per user, forever | No TTL, no archival job. Read-side is bounded (`fetchInbox()` uses `.limit(200)`, Item 18) — this bounds query cost, not table size. |
| `mission_events` (Supabase table) | Unbounded, append-only by design | Event-sourced ledger — this table's whole purpose is to never lose a row. Not a retention gap; a deliberate architectural property. |
| `xp_ledger` / `competition_score_ledger` (Supabase tables) | Unbounded, append-only by design | Authoritative reward ledgers — season/Hall-of-Fame aggregates read from history. Same as above: intentional. |
| `integrity_events` / `audit_log` (Supabase tables) | Unbounded, has a review-status lifecycle but no purge job | Grows forever once written; nothing currently deletes or archives a resolved entry. |
| `AiCoachCacheStore` (on-device secure storage) | Unbounded in the worst case | Stale entries from a superseded `contextVersion` are never actively deleted — bounded in practice only by there being just 3 cacheable task types, not by any expiry logic. |
| `LocalReminderStore` (on-device secure storage) | Unbounded for the life of an install | One new entry per user, per reminder type, per day — no cleanup or expiry logic exists at all. |

None of the above has changed since Item 18 re-confirmed it; re-verified
this pass by re-reading each store's implementation, no drift found.

## Tier 2 — engineering options (facts about what's *possible*, not a recommendation)

These are technically available mechanisms, listed so a future decision
doesn't have to re-derive them from scratch. Choosing between them is a
product/legal call (Tier 3), not something this document decides.

- **`notifications`**: a scheduled `pg_cron` job (the project already
  uses `pg_cron` for `finalize-week`/`finalize-season`) could delete or
  archive rows older than a chosen age, or older than N per user. Read
  access is already scoped by RLS per user, so a delete job would be
  the only new surface.
- **`integrity_events` / `audit_log`**: could be archived (moved to
  cold storage) rather than deleted outright, preserving an audit trail
  while keeping the hot table small — common for tables with a
  compliance/dispute-resolution purpose.
- **`mission_events` / `xp_ledger` / `competition_score_ledger`**: any
  retention change here is materially riskier than the others — these
  are the source of truth for a user's own history and for
  cross-user aggregates (season standings, Hall of Fame). Deleting or
  archiving rows here without first deciding how existing aggregates
  should be affected risks silently corrupting another user's
  historical standings, not just the deleting user's own data. See
  [docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md)'s "open
  design question" for the same tension in the deletion context.
- **`AiCoachCacheStore` / `LocalReminderStore`**: both are on-device
  only (never synced, never backed up — see
  [docs/RECOVERY.md](RECOVERY.md)'s "Local (on-device) data" section),
  so any retention fix here is a pure client-side change with no
  server/legal exposure: e.g. drop entries whose `contextVersion` no
  longer matches on next read, or cap `LocalReminderStore` to the
  trailing N days per user. Lowest-risk tier to fix, whenever it's
  prioritized.

## Tier 3 — decisions that need a human (product/legal), not invented here

- **How long should a `notifications` row live** after being read (or
  after being created, if unread) before it's eligible for deletion or
  archival? No answer is proposed here — an arbitrary number (e.g. "90
  days") would be exactly the kind of silent, unreviewed policy this
  item's own instructions prohibit inventing.
- **Delete vs. archive** for `integrity_events`/`audit_log` — if these
  ever need to support a dispute or an abuse investigation, deleting
  too aggressively could remove exactly the record that mattered.
  Needs a decision informed by whatever anti-cheat/trust-and-safety
  policy Forge eventually adopts, not an engineering default.
- **Anonymize-in-place vs. hard-delete** for ledger/event tables when a
  user's account is deleted — this is the same open question already
  raised in [docs/ACCOUNT_DELETION_DESIGN.md](ACCOUNT_DELETION_DESIGN.md)
  and is a prerequisite for any real account-deletion implementation,
  not just a retention nicety.
- **Whether retention policy needs to vary by jurisdiction** (e.g. a
  user-initiated deletion right under a specific privacy law) — this
  depends on which markets Forge is actually released into, a decision
  this document has no authority to make.
- **Whether any of this needs to be reflected in the Privacy Policy**
  before store submission — the current `PrivacyPolicyPage` (Item 19)
  correctly avoids making a retention-period promise it can't yet keep;
  once Tier 3 decisions above are made, the Privacy Policy needs a
  human legal pass to reflect them accurately (tracked in
  [docs/RC1_CHECKLIST.md](RC1_CHECKLIST.md)'s "Human legal-review
  blockers").

## What this document does not do

It does not implement a retention job, a TTL, a cron cleanup, or any
deletion logic. It does not choose a retention period for any table or
local store. It exists so that when someone does make these decisions,
they're making them deliberately, against a complete and accurate list
of what actually needs deciding.
