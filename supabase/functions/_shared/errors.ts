// Stable, machine-readable error codes (spec section 21) plus the HTTP
// status each maps to. Every Forge Edge Function funnels its failures
// through `errorResponse` so a client never sees a raw SQL error, a
// stack trace, or an inconsistent shape — only `{ errorCode, message }`.
//
// The paired SQL layer (supabase/migrations/20260817090100_mission_
// reward_functions.sql) raises exceptions formatted as
// 'error_code|human message' via forge_raise() — `parsePostgresError`
// is what turns that back into a stable code here, so the database is
// the single source of truth for *why* something failed and this file
// only translates it into a transport-level response.

export const ErrorCode = {
  Unauthenticated: "unauthenticated",
  Forbidden: "forbidden",
  InvalidPayload: "invalid_payload",
  ForbiddenAuthorityField: "forbidden_authority_field",
  MissionNotFound: "mission_not_found",
  InvalidTransition: "invalid_transition",
  StaleSequence: "stale_sequence",
  OutOfOrder: "out_of_order",
  DuplicateCommand: "duplicate_command",
  IdempotencyConflict: "idempotency_conflict",
  CompletionRequirementsNotMet: "completion_requirements_not_met",
  IntegrityRejected: "integrity_rejected",
  InvalidMissionSelection: "invalid_mission_selection",
  InternalError: "internal_error",
  RateLimited: "rate_limited",
  ProviderError: "provider_error",
} as const;

export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode];

const STATUS_BY_CODE: Record<ErrorCodeValue, number> = {
  [ErrorCode.Unauthenticated]: 401,
  [ErrorCode.Forbidden]: 403,
  [ErrorCode.InvalidPayload]: 400,
  [ErrorCode.ForbiddenAuthorityField]: 400,
  [ErrorCode.MissionNotFound]: 404,
  [ErrorCode.InvalidTransition]: 409,
  [ErrorCode.StaleSequence]: 409,
  [ErrorCode.OutOfOrder]: 409,
  [ErrorCode.DuplicateCommand]: 409,
  [ErrorCode.IdempotencyConflict]: 409,
  [ErrorCode.CompletionRequirementsNotMet]: 422,
  [ErrorCode.IntegrityRejected]: 403,
  [ErrorCode.InvalidMissionSelection]: 422,
  [ErrorCode.InternalError]: 500,
  [ErrorCode.RateLimited]: 429,
  [ErrorCode.ProviderError]: 502,
};

export class ForgeError extends Error {
  readonly errorCode: ErrorCodeValue;
  readonly details?: unknown;

  constructor(errorCode: ErrorCodeValue, message: string, details?: unknown) {
    super(message);
    this.errorCode = errorCode;
    this.details = details;
  }
}

const KNOWN_CODES = new Set<string>(Object.values(ErrorCode));

/** Extracts a usable message string from whatever `client.rpc()` handed
 * back. Deliberately duck-types on a `message` property rather than
 * checking `err instanceof Error`: supabase-js's `PostgrestError` is not
 * reliably a real `Error` instance across every runtime/bundling
 * combination (confirmed via a real HTTP call against a live Supabase
 * project during Roadmap Item 13 — the RPC-level error's `message` field
 * was correct and present, but `instanceof Error` was false, so this
 * used to fall through to `String(err)` -> the literal text
 * "[object Object]", silently mapping every genuine RPC rejection
 * — stale_sequence, invalid_transition, idempotency_conflict, and every
 * other business-logic error this whole error-code system exists to
 * carry — to a generic, useless internal_error/500). Never caught
 * before because no earlier test exercised a real RPC-raised exception
 * through an actual deployed HTTP call; local unit tests only ever
 * passed already-well-formed Error instances directly. */
function extractMessage(err: unknown): string {
  if (
    err !== null &&
    typeof err === "object" &&
    "message" in err &&
    typeof (err as { message: unknown }).message === "string"
  ) {
    return (err as { message: string }).message;
  }
  if (err instanceof Error) return err.message;
  return String(err);
}

/** Parses a `forge_raise()` exception message ('code|message') back into
 * a ForgeError. Postgres unique_violation (23505) from a raw insert race
 * (e.g. two concurrent submits both losing the row lock race in a way
 * that surfaces as a constraint violation rather than a clean
 * stale-sequence rejection) is mapped to duplicate_command as a safe
 * fallback — never surfaced as a raw constraint-name error. */
export function parsePostgresError(err: unknown): ForgeError {
  const message = extractMessage(err);
  const pgCode = (err as { code?: string } | undefined)?.code;

  const pipeIndex = message.indexOf("|");
  if (pipeIndex > 0) {
    const code = message.slice(0, pipeIndex);
    const human = message.slice(pipeIndex + 1);
    if (KNOWN_CODES.has(code)) {
      return new ForgeError(code as ErrorCodeValue, human);
    }
  }

  if (pgCode === "23505") {
    return new ForgeError(
      ErrorCode.DuplicateCommand,
      "This command has already been processed.",
    );
  }

  // Never leak the raw Postgres error text to the client — log it
  // server-side (console.error goes to the function's own logs) and
  // return a generic, safe message instead.
  console.error("Unmapped internal error:", message);
  return new ForgeError(ErrorCode.InternalError, "An internal error occurred.");
}

export function errorResponse(err: ForgeError, corsHeaders: Record<string, string>): Response {
  return new Response(
    JSON.stringify({
      status: "rejected",
      errorCode: err.errorCode,
      message: err.message,
    }),
    {
      status: STATUS_BY_CODE[err.errorCode],
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}
