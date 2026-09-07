// Server-side rate limiting (Roadmap Item 14 section 17). This is the
// *authoritative* limit — unlike the Flutter-side `AiCoachRateLimiter`,
// which is only a cheap first line of defense a modified client could
// skip entirely, this one is the one that actually matters.
//
// Known limitation, honestly documented rather than hidden: this is an
// in-memory, per-warm-isolate counter, not a persistent, cross-instance
// store. It resets on cold start and does not coordinate across
// concurrently warm instances. That is an acceptable gap for this pass
// specifically *because* the only provider wired is the free, local mock
// (mock_provider.ts) — there is no real per-request cost to bound yet.
// Before any real, paid provider is wired, this must be replaced with a
// persistent counter (e.g. a Postgres table keyed by user+task+window)
// so the limit holds under real concurrent traffic.

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const WINDOW_MS = 60_000;
const MAX_REQUESTS_PER_WINDOW = 10;

const recentRequests = new Map<string, number[]>();

export function isRateLimited(userId: string, task: string): boolean {
  const key = `${userId}:${task}`;
  const now = Date.now();
  const cutoff = now - WINDOW_MS;

  const existing = (recentRequests.get(key) ?? []).filter((t) => t > cutoff);

  if (existing.length >= MAX_REQUESTS_PER_WINDOW) {
    recentRequests.set(key, existing);
    return true;
  }

  existing.push(now);
  recentRequests.set(key, existing);
  return false;
}

// Roadmap Item 14C: the global counterpart to the per-user limiter
// above — see supabase/migrations/20260827090000_ai_coach_global_rate_
// limit.sql for why a real (non-mock) provider needs a persistent,
// cross-instance cap on top of the per-user one. Only called by
// index.ts when a real provider is selected; the mock-only default path
// never touches Postgres for this.
//
// Fails *open* (returns false, i.e. "not exceeded") on any RPC/network
// error — a transient Postgres hiccup should not silently degrade every
// user's AI Coach to the mock fallback. The per-user limiter above and
// the provider's own error handling remain the backstop for that case.
export async function isGlobalDailyCapExceeded(
  admin: SupabaseClient,
  dailyCap: number,
): Promise<boolean> {
  const { data, error } = await admin.rpc(
    "forge_check_and_increment_ai_coach_global_usage",
    { p_daily_cap: dailyCap },
  );
  if (error) return false;
  return data === false;
}
