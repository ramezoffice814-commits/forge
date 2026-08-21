// Reward-authority field rejection (spec section 3). Mirrors and
// extends lib/core/backend/commands/backend_command.dart's
// `forbiddenClientFields` — the Dart list is the canonical minimal set
// checked on the client before a command is even constructed; this list
// is deliberately broader (the spec explicitly calls out more
// variations for the server boundary) since the server is the last line
// of defense and a client bug or a hostile client are exactly the cases
// this exists for.
//
// Scans the *entire* request body recursively, not just top-level keys
// — a client nesting a forbidden field inside `progress: { xp: 999 }`
// must be rejected exactly as loudly as a top-level one. Deliberately a
// hard rejection (never a silent strip): "Do not silently ignore
// reward-authority fields. Reject them."

import { ErrorCode, ForgeError } from "./errors.ts";

const FORBIDDEN_FIELD_TOKENS = new Set([
  "xp",
  "xpreward",
  "confirmedxp",
  "level",
  "rank",
  "league",
  "leagueid",
  "leagueplacement",
  "competitivescore",
  "competitionscore",
  "achievement",
  "achievements",
  "achievementunlocked",
  "seasonreward",
  "promotion",
  "demotion",
]);

function normalize(key: string): string {
  return key.toLowerCase().replace(/[^a-z]/g, "");
}

function scan(value: unknown, path: string[]): string | null {
  if (value === null || value === undefined) return null;

  if (Array.isArray(value)) {
    for (const item of value) {
      const found = scan(item, path);
      if (found) return found;
    }
    return null;
  }

  if (typeof value === "object") {
    for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
      if (FORBIDDEN_FIELD_TOKENS.has(normalize(key))) {
        return [...path, key].join(".");
      }
      const found = scan(nested, [...path, key]);
      if (found) return found;
    }
  }

  return null;
}

/** Throws `forbidden_authority_field` if `body` contains, anywhere at
 * any nesting depth, a key that looks like a reward-shaped field a
 * client must never be able to set directly. */
export function assertNoForbiddenAuthorityFields(body: Record<string, unknown>): void {
  const found = scan(body, []);
  if (found) {
    throw new ForgeError(
      ErrorCode.ForbiddenAuthorityField,
      `Request payload contains a forbidden reward-authority field: "${found}". ` +
        "XP, level, rank, league, achievements, and competitive/competition score " +
        "are server-calculated outputs — never client-supplied input.",
    );
  }
}
