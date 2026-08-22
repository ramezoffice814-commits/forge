import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sanitizeContext } from "./context.ts";

Deno.test("sanitizeContext reads every allow-listed field", () => {
  const context = sanitizeContext({
    displayName: "Alex",
    currentMissionTitle: "Morning run",
    currentMissionCategory: "fitness",
    currentMissionDifficulty: "medium",
    availableMinutesToday: 45,
    recentCompletionRatePercent: 80,
    activeDaysThisWeek: 5,
    currentLevel: 12,
    currentTitle: "Disciplined",
    currentLeagueName: "Silver",
    recentCategoryUsage: ["fitness", "reading"],
    consistencySummary: "steady this week",
    isRecoveryMode: false,
    preferredCategories: ["fitness"],
    dislikedCategories: ["cold exposure"],
    goalFocusLabel: "consistency",
    coachingTone: "direct",
    userMessage: "how am I doing?",
  });

  assertEquals(context.displayName, "Alex");
  assertEquals(context.currentMissionTitle, "Morning run");
  assertEquals(context.availableMinutesToday, 45);
  assertEquals(context.coachingTone, "direct");
  assertEquals(context.userMessage, "how am I doing?");
});

Deno.test("sanitizeContext drops fields not on the allow-list, does not throw", () => {
  const context = sanitizeContext({
    displayName: "Alex",
    email: "alex@example.com",
    password: "hunter2",
    jwt: "eyJhbGciOi...",
    serviceRoleKey: "sb-service-role-abc",
    rawStreakCount: 999,
  });

  assertEquals(context.displayName, "Alex");
  assertEquals(Object.keys(context).includes("email"), false);
  assertEquals(Object.keys(context).includes("password"), false);
  assertEquals(Object.keys(context).includes("jwt"), false);
  const serialized = JSON.stringify(context).toLowerCase();
  assertEquals(serialized.includes("hunter2"), false);
  assertEquals(serialized.includes("eyjhbgci"), false);
  assertEquals(serialized.includes("service-role"), false);
});

Deno.test("sanitizeContext falls back to safe defaults for a missing/malformed body", () => {
  const context = sanitizeContext(null);
  assertEquals(context.displayName, "friend");
  assertEquals(context.availableMinutesToday, 0);
  assertEquals(context.currentLevel, 1);
  assertEquals(context.recentCategoryUsage, []);
  assertEquals(context.userMessage, null);
});

Deno.test("sanitizeContext clamps out-of-range numbers into bounds", () => {
  const context = sanitizeContext({
    availableMinutesToday: 999999,
    recentCompletionRatePercent: -50,
    activeDaysThisWeek: 100,
    currentLevel: -5,
  });
  assertEquals(context.availableMinutesToday, 1440);
  assertEquals(context.recentCompletionRatePercent, 0);
  assertEquals(context.activeDaysThisWeek, 7);
  assertEquals(context.currentLevel, 1);
});

Deno.test("sanitizeContext truncates an overlong user message rather than rejecting it", () => {
  const longMessage = "a".repeat(1000);
  const context = sanitizeContext({ userMessage: longMessage });
  assertEquals(context.userMessage!.length, 500);
});

Deno.test("sanitizeContext falls back to 'calm' for an unrecognized coaching tone", () => {
  const context = sanitizeContext({ coachingTone: "aggressive" });
  assertEquals(context.coachingTone, "calm");
});

Deno.test("sanitizeContext caps list fields at a bounded length", () => {
  const context = sanitizeContext({
    recentCategoryUsage: Array.from({ length: 50 }, (_, i) => `cat-${i}`),
  });
  assertEquals(context.recentCategoryUsage.length <= 20, true);
});
