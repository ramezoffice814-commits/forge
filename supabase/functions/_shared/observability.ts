// Minimal, staging-safe observability (Roadmap Item 13B step 12). One
// structured JSON line per invocation via console.log, which Supabase's
// platform already captures as Edge Function logs — no external logging
// service, no new dependency.
//
// Deliberately narrow: only ever the five fields below. This is enforced
// by the function's own signature, not by a redaction step applied
// afterward — there is no code path here that could accept a JWT, a
// password, a service-role key, a cron secret, a reflection response, or
// any other request/response body content, because none of those are
// parameters this function even takes. See observability_test.ts for the
// mechanical check that the emitted object never contains a forbidden key.

export interface OutcomeLogFields {
  /** The Edge Function's own name, e.g. "accept-mission". */
  function: string;
  /** commandId (mission commands) or a short fixed label (cron functions)
   * — never anything containing user-supplied free text. */
  commandId: string | null;
  /** A stable result/error code (e.g. "accepted", "stale_sequence",
   * "forbidden") — never a raw message string. */
  resultCode: string;
  durationMs: number;
  success: boolean;
}

export function logOutcome(fields: OutcomeLogFields): void {
  console.log(
    JSON.stringify({
      event: "forge_function_outcome",
      function: fields.function,
      commandId: fields.commandId,
      resultCode: fields.resultCode,
      durationMs: fields.durationMs,
      success: fields.success,
    }),
  );
}

/** Times one async call and logs its outcome — the one seam every
 * function's handler wraps its core logic in, so the logging call site
 * itself can never accidentally have access to the request body, headers,
 * or any secret to leak in the first place. */
export async function withOutcomeLogging<T>(
  functionName: string,
  commandId: string | null,
  run: () => Promise<T>,
  resultCodeOf: (result: T) => string,
  successOf: (result: T) => boolean,
): Promise<T> {
  const start = performance.now();
  try {
    const result = await run();
    logOutcome({
      function: functionName,
      commandId,
      resultCode: resultCodeOf(result),
      durationMs: Math.round(performance.now() - start),
      success: successOf(result),
    });
    return result;
  } catch (err) {
    const resultCode = (err as { errorCode?: string } | undefined)
      ?.errorCode ?? "internal_error";
    logOutcome({
      function: functionName,
      commandId,
      resultCode,
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    throw err;
  }
}
