// Deno unit tests for progress.ts. See validation_test.ts's header note
// on executability in this environment.

import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateProgressPayload } from "./progress.ts";
import { ForgeError } from "./errors.ts";

Deno.test("accepts a valid counter progress payload", () => {
  const result = validateProgressPayload("counter", { currentCount: 8, targetCount: 10 });
  assertEquals(result.progressType, "counter");
});

Deno.test("rejects an unsupported progressType", () => {
  assertThrows(
    () => validateProgressPayload("focusSession", { anything: 1 }),
    ForgeError,
  );
});

Deno.test("rejects a negative counter value", () => {
  assertThrows(
    () => validateProgressPayload("counter", { currentCount: -1, targetCount: 10 }),
    ForgeError,
  );
});

Deno.test("rejects a percentage above 100", () => {
  assertThrows(
    () => validateProgressPayload("percentage", { percentage: 150, thresholdPercentage: 100 }),
    ForgeError,
  );
});

Deno.test("rejects a hydration serving count above the 50 ceiling", () => {
  assertThrows(
    () => validateProgressPayload("hydration", { currentServings: 51, targetServings: 8 }),
    ForgeError,
  );
});

Deno.test("rejects a non-boolean completed field for binary progress", () => {
  assertThrows(
    () => validateProgressPayload("binary", { completed: "yes" }),
    ForgeError,
  );
});

Deno.test("rejects a reflection response length above the 5000-char ceiling", () => {
  assertThrows(
    () =>
      validateProgressPayload("reflection", {
        responsePresent: true,
        responseLength: 6000,
        minimumLength: 100,
      }),
    ForgeError,
  );
});

Deno.test("accepts a checklist payload with string-array item ids", () => {
  const result = validateProgressPayload("checklist", {
    itemIds: ["a", "b"],
    completedItemIds: ["a"],
  });
  assertEquals(result.progressType, "checklist");
});

Deno.test("rejects a checklist payload with non-string item ids", () => {
  assertThrows(
    () => validateProgressPayload("checklist", { itemIds: [1, 2], completedItemIds: [] }),
    ForgeError,
  );
});
