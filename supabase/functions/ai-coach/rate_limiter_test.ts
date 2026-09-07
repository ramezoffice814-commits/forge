import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isGlobalDailyCapExceeded, isRateLimited } from "./rate_limiter.ts";

Deno.test("isRateLimited allows requests under the per-window cap", () => {
  const userId = `user-${crypto.randomUUID()}`;
  for (let i = 0; i < 10; i++) {
    assertEquals(isRateLimited(userId, "coachChat"), false);
  }
});

Deno.test("isRateLimited blocks the 11th request within the same window", () => {
  const userId = `user-${crypto.randomUUID()}`;
  for (let i = 0; i < 10; i++) {
    isRateLimited(userId, "coachChat");
  }
  assertEquals(isRateLimited(userId, "coachChat"), true);
});

Deno.test("isRateLimited tracks limits independently per task", () => {
  const userId = `user-${crypto.randomUUID()}`;
  for (let i = 0; i < 10; i++) {
    isRateLimited(userId, "coachChat");
  }
  assertEquals(isRateLimited(userId, "coachChat"), true);
  assertEquals(isRateLimited(userId, "weeklyRecap"), false);
});

Deno.test("isRateLimited tracks limits independently per user", () => {
  const userA = `user-${crypto.randomUUID()}`;
  const userB = `user-${crypto.randomUUID()}`;
  for (let i = 0; i < 10; i++) {
    isRateLimited(userA, "coachChat");
  }
  assertEquals(isRateLimited(userA, "coachChat"), true);
  assertEquals(isRateLimited(userB, "coachChat"), false);
});

// Fake Supabase admin client — only `.rpc()` is ever called by
// isGlobalDailyCapExceeded, so that's all these fakes need to implement.
function fakeAdmin(
  rpcImpl: (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: unknown }>,
): SupabaseClient {
  return { rpc: rpcImpl } as unknown as SupabaseClient;
}

Deno.test("isGlobalDailyCapExceeded returns false when the RPC allows the call", async () => {
  const admin = fakeAdmin((fn, args) => {
    assertEquals(fn, "forge_check_and_increment_ai_coach_global_usage");
    assertEquals(args, { p_daily_cap: 100 });
    return Promise.resolve({ data: true, error: null });
  });
  assertEquals(await isGlobalDailyCapExceeded(admin, 100), false);
});

Deno.test("isGlobalDailyCapExceeded returns true when the RPC reports the cap reached", async () => {
  const admin = fakeAdmin(() => Promise.resolve({ data: false, error: null }));
  assertEquals(await isGlobalDailyCapExceeded(admin, 100), true);
});

Deno.test("isGlobalDailyCapExceeded fails open (returns false) on an RPC error", async () => {
  const admin = fakeAdmin(() =>
    Promise.resolve({ data: null, error: { message: "connection reset" } })
  );
  assertEquals(await isGlobalDailyCapExceeded(admin, 100), false);
});
