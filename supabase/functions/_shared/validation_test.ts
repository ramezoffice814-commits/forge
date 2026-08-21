// Deno unit tests for validation.ts. Genuinely executable — no network,
// no database — via `deno test supabase/functions/_shared/`. Not run in
// this environment because the Deno CLI is not installed here; see the
// Phase 10C final report for what was and wasn't actually executed.

import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertNoForbiddenAuthorityFields } from "./validation.ts";
import { ForgeError } from "./errors.ts";

Deno.test("allows a normal command payload with no reward-shaped fields", () => {
  assertNoForbiddenAuthorityFields({
    commandId: "cmd-1",
    idempotencyKey: "key-1",
    missionInstanceId: "11111111-1111-1111-1111-111111111111",
    sequence: 1,
    progress: { currentCount: 5, targetCount: 10 },
  });
});

Deno.test("rejects a top-level xp field", () => {
  const err = assertThrows(
    () => assertNoForbiddenAuthorityFields({ xp: 999 }),
    ForgeError,
  );
  assertEquals(err.errorCode, "forbidden_authority_field");
});

Deno.test("rejects a nested confirmedXp field inside progress", () => {
  assertThrows(
    () =>
      assertNoForbiddenAuthorityFields({
        progress: { confirmedXp: 999 },
      }),
    ForgeError,
  );
});

Deno.test("rejects competitiveScore regardless of casing/underscores", () => {
  assertThrows(
    () => assertNoForbiddenAuthorityFields({ competitive_score: 10 }),
    ForgeError,
  );
});

Deno.test("rejects an achievements array field", () => {
  assertThrows(
    () => assertNoForbiddenAuthorityFields({ achievements: ["first-steps"] }),
    ForgeError,
  );
});

Deno.test("rejects a forbidden field nested inside an array of objects", () => {
  assertThrows(
    () =>
      assertNoForbiddenAuthorityFields({
        items: [{ ok: true }, { leagueId: "league-mythic" }],
      }),
    ForgeError,
  );
});
