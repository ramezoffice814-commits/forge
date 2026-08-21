// Progress payload shape + sane-bounds validation (spec section 10).
// Mirrors the numeric ceilings MissionProgressPolicy already enforces
// client-side (lib/features/missions/domain/progress/mission_progress_
// policy.dart: maxCounterValue/maxQuantityValue/maxHydrationServings/
// maxReflectionLength) so a malformed or hostile payload is rejected
// here, before it ever reaches forge_validate_completion.
//
// Deliberate, documented scope limit: this validates *shape and static
// bounds* only (never negative, never above a sane ceiling) — it does
// NOT replicate MissionProgressPolicy's stateful rules (decrease-
// requires-correction, implausible-single-interval-jump), since those
// compare against the mission's *prior* progress state, which would
// require loading and folding the full mission_events history here just
// to validate a payload shape. That stateful comparison is left to the
// client's own local MissionProgressPolicy (already enforced before a
// progress update is ever queued) — see supabase/README.md.

import { ErrorCode, ForgeError } from "./errors.ts";

const MAX_COUNTER_VALUE = 100_000;
const MAX_QUANTITY_VALUE = 100_000;
const MAX_HYDRATION_SERVINGS = 50;
const MAX_REFLECTION_LENGTH = 5_000;
const MAX_DURATION_SECONDS = 24 * 60 * 60; // one day — a generous sanity ceiling.

const KNOWN_PROGRESS_TYPES = new Set([
  "binary",
  "counter",
  "timer",
  "checklist",
  "percentage",
  "quantity",
  "reflection",
  "reading",
  "codingSession",
  "hydration",
]);

function num(progress: Record<string, unknown>, field: string): number {
  const value = progress[field];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ForgeError(ErrorCode.InvalidPayload, `progress.${field} must be a finite number.`);
  }
  return value;
}

function bounded(progress: Record<string, unknown>, field: string, max: number): void {
  const value = num(progress, field);
  if (value < 0 || value > max) {
    throw new ForgeError(
      ErrorCode.InvalidPayload,
      `progress.${field} must be between 0 and ${max}.`,
    );
  }
}

function stringArray(progress: Record<string, unknown>, field: string): string[] {
  const value = progress[field];
  if (value === undefined) return [];
  if (!Array.isArray(value) || !value.every((v) => typeof v === "string")) {
    throw new ForgeError(ErrorCode.InvalidPayload, `progress.${field} must be an array of strings.`);
  }
  return value as string[];
}

/** Validates `{ progressType, progress }` shape and bounds. Throws
 * `invalid_payload` on anything malformed, impossible, or out of bounds
 * — never silently clamps (this is request validation, not the
 * completion-criteria check forge_validate_completion performs later). */
export function validateProgressPayload(
  progressType: unknown,
  progress: unknown,
): { progressType: string; progress: Record<string, unknown> } {
  if (typeof progressType !== "string" || !KNOWN_PROGRESS_TYPES.has(progressType)) {
    throw new ForgeError(ErrorCode.InvalidPayload, `Unsupported or missing progressType.`);
  }
  if (progress === null || typeof progress !== "object" || Array.isArray(progress)) {
    throw new ForgeError(ErrorCode.InvalidPayload, "progress must be a JSON object.");
  }
  const p = progress as Record<string, unknown>;

  switch (progressType) {
    case "binary":
      if (typeof p["completed"] !== "boolean") {
        throw new ForgeError(ErrorCode.InvalidPayload, "progress.completed must be a boolean.");
      }
      break;
    case "counter":
      bounded(p, "currentCount", MAX_COUNTER_VALUE);
      bounded(p, "targetCount", MAX_COUNTER_VALUE);
      break;
    case "quantity":
      bounded(p, "currentValue", MAX_QUANTITY_VALUE);
      bounded(p, "targetValue", MAX_QUANTITY_VALUE);
      break;
    case "hydration":
      bounded(p, "currentServings", MAX_HYDRATION_SERVINGS);
      bounded(p, "targetServings", MAX_HYDRATION_SERVINGS);
      break;
    case "percentage":
      bounded(p, "percentage", 100);
      bounded(p, "thresholdPercentage", 100);
      break;
    case "timer":
      bounded(p, "accumulatedSeconds", MAX_DURATION_SECONDS);
      bounded(p, "targetSeconds", MAX_DURATION_SECONDS);
      break;
    case "reading":
      bounded(p, "durationReadSeconds", MAX_DURATION_SECONDS);
      bounded(p, "targetSeconds", MAX_DURATION_SECONDS);
      break;
    case "codingSession":
      bounded(p, "activeSeconds", MAX_DURATION_SECONDS);
      bounded(p, "targetSeconds", MAX_DURATION_SECONDS);
      stringArray(p, "itemIds");
      stringArray(p, "completedItemIds");
      break;
    case "checklist":
      stringArray(p, "itemIds");
      stringArray(p, "completedItemIds");
      break;
    case "reflection": {
      if (typeof p["responsePresent"] !== "boolean") {
        throw new ForgeError(ErrorCode.InvalidPayload, "progress.responsePresent must be a boolean.");
      }
      bounded(p, "responseLength", MAX_REFLECTION_LENGTH);
      bounded(p, "minimumLength", MAX_REFLECTION_LENGTH);
      break;
    }
  }

  return { progressType, progress: p };
}
