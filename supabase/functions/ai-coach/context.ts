// Server-side mirror of lib/features/ai_coach/domain/entities/ai_coach_context.dart
// — the same privacy contract enforced a second time, at the boundary
// the client-supplied JSON actually crosses. This is deliberately an
// allow-list *read*, never a passthrough: every field is picked off the
// raw body by exact name and coerced/validated, so a client that sends
// extra keys (a JWT, an email, a raw streak count) has them silently
// dropped, never merged into what reaches the prompt template.

export interface AiCoachContext {
  displayName: string;
  currentMissionTitle: string | null;
  currentMissionCategory: string | null;
  currentMissionDifficulty: string | null;
  availableMinutesToday: number;
  recentCompletionRatePercent: number;
  activeDaysThisWeek: number;
  currentLevel: number;
  currentTitle: string;
  currentLeagueName: string | null;
  recentCategoryUsage: string[];
  consistencySummary: string;
  isRecoveryMode: boolean;
  preferredCategories: string[];
  dislikedCategories: string[];
  goalFocusLabel: string | null;
  coachingTone: string;
  userMessage: string | null;
}

const MAX_USER_MESSAGE_LENGTH = 500;
const MAX_LIST_LENGTH = 20;
const MAX_LABEL_LENGTH = 200;

const COACHING_TONES = new Set(["calm", "direct", "energetic", "strategic"]);

function optionalString(value: unknown, maxLength = MAX_LABEL_LENGTH): string | null {
  if (typeof value !== "string" || value.length === 0) return null;
  return value.length > maxLength ? value.slice(0, maxLength) : value;
}

function requiredString(value: unknown, fallback: string, maxLength = MAX_LABEL_LENGTH): string {
  if (typeof value !== "string" || value.length === 0) return fallback;
  return value.length > maxLength ? value.slice(0, maxLength) : value;
}

function boundedInt(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  const rounded = Math.round(value);
  return Math.min(max, Math.max(min, rounded));
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is string => typeof entry === "string" && entry.length > 0)
    .slice(0, MAX_LIST_LENGTH)
    .map((entry) => (entry.length > MAX_LABEL_LENGTH ? entry.slice(0, MAX_LABEL_LENGTH) : entry));
}

/** Reads only the named, typed fields off `raw` — nothing else in `raw`
 * can ever reach the returned object. Unknown/malformed values fall back
 * to safe defaults rather than throwing, since a slightly-off context
 * (e.g. a stale client build sending one fewer field) should degrade to
 * a blander prompt, not a hard failure of the whole request. */
export function sanitizeContext(raw: unknown): AiCoachContext {
  const body = raw !== null && typeof raw === "object" ? (raw as Record<string, unknown>) : {};

  const toneRaw = body["coachingTone"];
  const coachingTone =
    typeof toneRaw === "string" && COACHING_TONES.has(toneRaw) ? toneRaw : "calm";

  return {
    displayName: requiredString(body["displayName"], "friend", 100),
    currentMissionTitle: optionalString(body["currentMissionTitle"]),
    currentMissionCategory: optionalString(body["currentMissionCategory"]),
    currentMissionDifficulty: optionalString(body["currentMissionDifficulty"]),
    availableMinutesToday: boundedInt(body["availableMinutesToday"], 0, 1440, 0),
    recentCompletionRatePercent: boundedInt(body["recentCompletionRatePercent"], 0, 100, 0),
    activeDaysThisWeek: boundedInt(body["activeDaysThisWeek"], 0, 7, 0),
    currentLevel: boundedInt(body["currentLevel"], 1, 1000, 1),
    currentTitle: requiredString(body["currentTitle"], "Novice", 100),
    currentLeagueName: optionalString(body["currentLeagueName"]),
    recentCategoryUsage: stringList(body["recentCategoryUsage"]),
    consistencySummary: requiredString(body["consistencySummary"], "just getting started", 200),
    isRecoveryMode: body["isRecoveryMode"] === true,
    preferredCategories: stringList(body["preferredCategories"]),
    dislikedCategories: stringList(body["dislikedCategories"]),
    goalFocusLabel: optionalString(body["goalFocusLabel"]),
    coachingTone,
    userMessage: optionalString(body["userMessage"], MAX_USER_MESSAGE_LENGTH),
  };
}
