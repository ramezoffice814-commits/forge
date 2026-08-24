// POST /functions/v1/finalize-week
// Server-only entrypoint for forge_finalize_season_week (spec section
// 14). Never callable by a normal authenticated user — the underlying
// SQL function has zero grants to `authenticated` at all (see
// supabase/migrations/20260819090000_season_finalization.sql), and this
// wrapper adds a second, independent gate: a shared secret header
// (FORGE_CRON_SECRET) that only a trusted invoker (Supabase Cron, or an
// operator running this by hand) would know. No production secret is
// configured yet — until FORGE_CRON_SECRET is set as a real Edge
// Function environment variable, this function rejects every request.
//
// Uses the service-role key, read only from this function's own
// runtime environment — never sent to, or readable by, the Flutter app.
// See supabase/README.md's cron-readiness section for the intended
// invocation schedule.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handlePreflight } from "../_shared/cors.ts";
import { logOutcome } from "../_shared/observability.ts";

const FUNCTION_NAME = "finalize-week";

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const start = performance.now();

  // Never logged: the secret's actual value, or the header carrying it —
  // only whether the check passed. commandId is a fixed, request-body-
  // independent label until the body is parsed below, matching the
  // "commandId (mission commands) or a short fixed label (cron
  // functions)" contract in observability.ts.
  const expectedSecret = Deno.env.get("FORGE_CRON_SECRET");
  const providedSecret = req.headers.get("x-cron-secret");
  if (!expectedSecret || providedSecret !== expectedSecret) {
    logOutcome({
      function: FUNCTION_NAME,
      commandId: "cron:unauthenticated",
      resultCode: "forbidden",
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "forbidden", message: "Not authorized." }),
      { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  let body: { seasonId?: string; weekNumber?: number };
  try {
    body = await req.json();
  } catch {
    logOutcome({
      function: FUNCTION_NAME,
      commandId: "cron:invalid-body",
      resultCode: "invalid_payload",
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "invalid_payload", message: "Body must be JSON." }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  if (typeof body.seasonId !== "string" || typeof body.weekNumber !== "number") {
    logOutcome({
      function: FUNCTION_NAME,
      commandId: "cron:invalid-body",
      resultCode: "invalid_payload",
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return new Response(
      JSON.stringify({
        status: "rejected",
        errorCode: "invalid_payload",
        message: "seasonId (string) and weekNumber (number) are required.",
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  const commandId = `finalize-week:${body.seasonId}:${body.weekNumber}`;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    logOutcome({
      function: FUNCTION_NAME,
      commandId,
      resultCode: "internal_error",
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "internal_error", message: "Function misconfigured." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data, error } = await admin.rpc("forge_finalize_season_week", {
    p_season_id: body.seasonId,
    p_week_number: body.weekNumber,
  });

  if (error) {
    console.error("finalize-week failed:", error.message);
    logOutcome({
      function: FUNCTION_NAME,
      commandId,
      resultCode: "internal_error",
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "internal_error", message: "Finalization failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  logOutcome({
    function: FUNCTION_NAME,
    commandId,
    resultCode: "accepted",
    durationMs: Math.round(performance.now() - start),
    success: true,
  });
  return new Response(
    JSON.stringify({ status: "accepted", rowsWritten: data }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
