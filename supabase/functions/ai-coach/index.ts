// POST /functions/v1/ai-coach
// Roadmap Item 14 (14C: real provider wiring): the one server-side
// gateway every AI Coach request goes through. The Flutter app never
// talks to a provider directly and never holds a provider credential —
// this function is the only place one could ever exist. Defaults to
// mock_provider.ts; AI_PROVIDER=gemini (an Edge Function secret) opts a
// deployment into gemini_provider.ts instead, gated by a global daily
// cap (rate_limiter.ts's isGlobalDailyCapExceeded) that fails toward
// mock on any misconfiguration or provider error — see provider.ts for
// the interface either implements.
//
// Auth is mandatory and derives the acting user the same way every
// other Forge function does (see _shared/auth.ts) — the context body a
// client sends is used only for coaching *content* (mission title,
// consistency phrasing, tone), never for identity or authority.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, corsHeaders } from "../_shared/cors.ts";
import { authenticate, AuthenticatedRequest } from "../_shared/auth.ts";
import { errorResponse, ForgeError, ErrorCode } from "../_shared/errors.ts";
import { logOutcome } from "../_shared/observability.ts";
import { parseJsonBody, requireString } from "../_shared/request.ts";
import { assertNoForbiddenAuthorityFields } from "../_shared/validation.ts";
import { sanitizeContext } from "./context.ts";
import { buildPrompt } from "./prompt_templates.ts";
import { generateMockResponse } from "./mock_provider.ts";
import { GeminiProvider } from "./gemini_provider.ts";
import { Provider } from "./provider.ts";
import { isUnsafe, withinSizeLimits } from "./response.ts";
import { isRateLimited, isGlobalDailyCapExceeded } from "./rate_limiter.ts";

const FUNCTION_NAME = "ai-coach";

const VALID_TASKS = new Set([
  "missionExplanation",
  "dailyTransmissionDialogue",
  "postMissionCoaching",
  "weeklyRecap",
  "coachChat",
]);

/** Roadmap Item 14C. `AI_PROVIDER` is an Edge Function secret, defaulting
 * to "mock" — an unconfigured deploy is always inert, never accidentally
 * calling a network provider. */
function buildRealProvider(name: string): Provider {
  if (name === "gemini") {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY is not configured.");
    return new GeminiProvider({ apiKey });
  }
  throw new Error(`Unknown AI_PROVIDER: ${name}`);
}

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

    const AI_PROVIDER = Deno.env.get("AI_PROVIDER") ?? "mock";
    let response = generateMockResponse(task, context, template);
    let resultCode = "generated";

    if (AI_PROVIDER !== "mock") {
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      const dailyCapRaw = Deno.env.get("AI_COACH_DAILY_CAP");
      const dailyCap = dailyCapRaw ? Number(dailyCapRaw) : NaN;

      // Misconfiguration (missing URL/key/cap) fails toward mock, never
      // toward an uncapped real-provider call — see rate_limit
      // migration's own comment for why an uncapped call to a shared
      // free-tier quota is the one thing this must never do.
      if (!supabaseUrl || !serviceRoleKey || !Number.isFinite(dailyCap) || dailyCap <= 0) {
        resultCode = "generated_capped_fallback";
      } else {
        const admin = createClient(supabaseUrl, serviceRoleKey);
        const capExceeded = await isGlobalDailyCapExceeded(admin, dailyCap);
        if (capExceeded) {
          resultCode = "generated_capped_fallback";
        } else {
          try {
            const provider = buildRealProvider(AI_PROVIDER);
            response = await provider.generate(task, context, template);
          } catch (_err) {
            // Provider outage/misconfig degrades to the same mock
            // response already computed above — never surfaces as an
            // error to the user, matching AiCoachRepository's own
            // never-throws contract on the Flutter side.
            resultCode = "generated_provider_fallback";
          }
        }
      }
    }

    if (!withinSizeLimits(response) || isUnsafe(response)) {
      throw new ForgeError(ErrorCode.ProviderError, "Provider response failed validation.");
    }

    logOutcome({
      function: FUNCTION_NAME,
      commandId: requestId,
      resultCode,
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
