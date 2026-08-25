import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isRateLimited } from "./rate_limiter.ts";

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
