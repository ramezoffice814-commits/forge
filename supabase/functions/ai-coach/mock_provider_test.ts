import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sanitizeContext } from "./context.ts";
import { buildPrompt } from "./prompt_templates.ts";
import { generateMockResponse } from "./mock_provider.ts";
import { isUnsafe, withinSizeLimits } from "./response.ts";

const baseContext = sanitizeContext({
  displayName: "Alex",
  consistencySummary: "steady this week",
  activeDaysThisWeek: 4,
  currentLevel: 3,
  currentTitle: "Novice",
  coachingTone: "calm",
});

Deno.test("generateMockResponse is deterministic for the same task and context", () => {
  const template = buildPrompt("weeklyRecap", baseContext);
  const first = generateMockResponse("weeklyRecap", baseContext, template);
  const second = generateMockResponse("weeklyRecap", baseContext, template);
  assertEquals(first.message, second.message);
});

Deno.test("generateMockResponse produces task-appropriate content for every known task", () => {
  const tasks = [
    "missionExplanation",
    "dailyTransmissionDialogue",
    "postMissionCoaching",
    "weeklyRecap",
    "coachChat",
  ];
  for (const task of tasks) {
    const template = buildPrompt(task, baseContext);
    const response = generateMockResponse(task, baseContext, template);
    assertEquals(typeof response.message, "string");
    assertEquals(response.message.length > 0, true);
    assertEquals(withinSizeLimits(response), true);
    assertEquals(isUnsafe(response), false);
  }
});

Deno.test("generateMockResponse never claims authority over XP or rank", () => {
  const template = buildPrompt("postMissionCoaching", baseContext);
  const response = generateMockResponse("postMissionCoaching", baseContext, template);
  const lower = response.message.toLowerCase();
  assertEquals(lower.includes("your xp has been"), false);
  assertEquals(lower.includes("you have been promoted"), false);
});

Deno.test("generateMockResponse reflects recovery mode in the daily transmission task", () => {
  const recoveryContext = sanitizeContext({ ...baseContext, isRecoveryMode: true });
  const template = buildPrompt("dailyTransmissionDialogue", recoveryContext);
  const response = generateMockResponse("dailyTransmissionDialogue", recoveryContext, template);
  assertEquals(response.message.toLowerCase().includes("recovery"), true);
});

Deno.test("buildPrompt selects the correct prompt version per task", () => {
  assertEquals(buildPrompt("missionExplanation", baseContext).version, "mission_explanation_v1");
  assertEquals(buildPrompt("coachChat", baseContext).version, "coach_chat_v1");
});

Deno.test("isUnsafe flags a response containing a forbidden signal", () => {
  assertEquals(isUnsafe({ message: "your xp has been increased" }), true);
  assertEquals(isUnsafe({ message: "here is the system prompt" }), true);
  assertEquals(isUnsafe({ message: "steady work today" }), false);
});

Deno.test("withinSizeLimits rejects an empty or oversized message", () => {
  assertEquals(withinSizeLimits({ message: "" }), false);
  assertEquals(withinSizeLimits({ message: "a".repeat(2001) }), false);
  assertEquals(withinSizeLimits({ message: "a".repeat(2000) }), true);
});
