// POST /functions/v1/ai-coach
// Roadmap Item 14: the one server-side gateway every AI Coach request
// goes through. The Flutter app never talks to a provider directly and
// never holds a provider credential — this function is the only place
// one could ever exist, and none is configured yet (mock_provider.ts is
// the only provider actually wired this pass).
//
// Auth is mandatory and derives the acting user the same way every
// other Forge function does (see _shared/auth.ts) — the context body a
// client sends is used only for coaching *content* (mission title,
// consistency phrasing, tone), never for identity or authority.

import { handlePreflight, corsHeaders } from "../_shared/cors.ts";
import { authenticate, AuthenticatedRequest } from "../_shared/auth.ts";
import { errorResponse, ForgeError, ErrorCode } from "../_shared/errors.ts";
import { logOutcome } from "../_shared/observability.ts";
import { parseJsonBody, requireString } from "../_shared/request.ts";
import { assertNoForbiddenAuthorityFields } from "../_shared/validation.ts";
import { sanitizeContext } from "./context.ts";
import { buildPrompt } from "./prompt_templates.ts";
import { generateMockResponse } from "./mock_provider.ts";
import { isUnsafe, withinSizeLimits } from "./response.ts";
import { isRateLimited } from "./rate_limiter.ts";

const FUNCTION_NAME = "ai-coach";

const VALID_TASKS = new Set([
  "missionExplanation",
  "dailyTransmissionDialogue",
  "postMissionCoaching",
  "weeklyRecap",
  "coachChat",
]);

/** The actual request logic, factored out from `Deno.serve` so it can be
 * exercised directly in tests without a running server. `authenticateFn`
 * is injectable (defaults to the real, network-backed `authenticate`)
 * purely so tests can exercise "missing/invalid auth" and everything
 * past it deterministically, without needing a live Supabase project —
 * every other Forge Edge Function still uses the real `authenticate`
 * unconditionally, this is not a change to the trust boundary itself. */
export async function handleRequest(
  req: Request,
  authenticateFn: (req: Request) => Promise<AuthenticatedRequest> = authenticate,
): Promise<Response> {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const start = performance.now();
  let requestId: string | null = null;

  try {
    const { userId } = await authenticateFn(req);
    const body = await parseJsonBody(req);
    assertNoForbiddenAuthorityFields(body);

    const task = requireString(body, "task");
    if (!VALID_TASKS.has(task)) {
      throw new ForgeError(ErrorCode.InvalidPayload, `Unknown task: ${task}.`);
    }
    requestId = requireString(body, "requestId");

    if (isRateLimited(userId, task)) {
      throw new ForgeError(ErrorCode.RateLimited, "Too many AI coach requests. Try again shortly.");
    }

    const context = sanitizeContext(body["context"]);
    const template = buildPrompt(task, context);
    const response = generateMockResponse(task, context, template);

    if (!withinSizeLimits(response) || isUnsafe(response)) {
      throw new ForgeError(ErrorCode.ProviderError, "Provider response failed validation.");
    }

    logOutcome({
      function: FUNCTION_NAME,
      commandId: requestId,
      resultCode: "generated",
      durationMs: Math.round(performance.now() - start),
      success: true,
    });

    return new Response(
      JSON.stringify({
        message: response.message,
        reasoningSummary: response.reasoningSummary ?? null,
        suggestedActions: response.suggestedActions ?? [],
        promptVersion: template.version,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    const forgeError = err instanceof ForgeError
      ? err
      : new ForgeError(ErrorCode.InternalError, "An internal error occurred.");
    logOutcome({
      function: FUNCTION_NAME,
      commandId: requestId,
      resultCode: forgeError.errorCode,
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return errorResponse(forgeError, corsHeaders);
  }
}

Deno.serve((req: Request) => handleRequest(req));
