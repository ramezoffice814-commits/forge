// Deno unit tests for errors.ts. See validation_test.ts's header note on
// executability in this environment.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { ErrorCode, parsePostgresError } from "./errors.ts";

Deno.test("parses a forge_raise 'code|message' exception into a ForgeError", () => {
  const err = parsePostgresError(new Error("stale_sequence|Expected sequence 3 but received 2."));
  assertEquals(err.errorCode, ErrorCode.StaleSequence);
  assertEquals(err.message, "Expected sequence 3 but received 2.");
});

Deno.test("maps a raw Postgres unique_violation (23505) to duplicate_command", () => {
  const pgError = Object.assign(new Error("duplicate key value violates unique constraint"), {
    code: "23505",
  });
  const err = parsePostgresError(pgError);
  assertEquals(err.errorCode, ErrorCode.DuplicateCommand);
});

Deno.test("never leaks a raw, unrecognized Postgres error message to the client", () => {
  const err = parsePostgresError(new Error("relation \"public.secret_table\" does not exist"));
  assertEquals(err.errorCode, ErrorCode.InternalError);
  assertEquals(err.message, "An internal error occurred.");
});

Deno.test("falls back to internal_error for an unknown error-code prefix", () => {
  const err = parsePostgresError(new Error("not_a_real_code|something"));
  assertEquals(err.errorCode, ErrorCode.InternalError);
});

// Regression test for a real Roadmap Item 13 finding: a genuine RPC
// rejection from a live Supabase project's client.rpc() call was
// silently mapped to internal_error/500 because supabase-js's
// PostgrestError is not reliably `instanceof Error` — only a plain
// object shaped like one, with `code`/`details`/`hint`/`message`
// fields. Every prior test here used a real `new Error(...)`, which
// masked this for the whole life of the project until an actual HTTP
// call against a live database exercised it for the first time.
Deno.test("parses a plain-object PostgrestError (not an Error instance) exactly like a real Error", () => {
  const plainObjectError = {
    code: "P0001",
    details: null,
    hint: null,
    message: "idempotency_conflict|This idempotency key was already used for a different request payload.",
  };
  const err = parsePostgresError(plainObjectError);
  assertEquals(err.errorCode, ErrorCode.IdempotencyConflict);
  assertEquals(err.message, "This idempotency key was already used for a different request payload.");
});

Deno.test("plain-object PostgrestError with an unrecognized message still falls back safely, never '[object Object]'", () => {
  const plainObjectError = { code: "42501", details: null, hint: null, message: "permission denied for table foo" };
  const err = parsePostgresError(plainObjectError);
  assertEquals(err.errorCode, ErrorCode.InternalError);
  assertEquals(err.message, "An internal error occurred.");
});
