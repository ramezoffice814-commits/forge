// POST /functions/v1/finalize-season
// Server-only entrypoint for forge_finalize_season — see finalize-week/
// index.ts's header comment for the full rationale (identical shape:
// zero grants on the underlying SQL function + a shared-secret gate,
// service-role key read only from this function's own environment).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handlePreflight } from "../_shared/cors.ts";
import { logOutcome } from "../_shared/observability.ts";

const FUNCTION_NAME = "finalize-season";

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const start = performance.now();

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

  let body: { seasonId?: string };
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
  if (typeof body.seasonId !== "string") {
    logOutcome({
      function: FUNCTION_NAME,
      commandId: "cron:invalid-body",
      resultCode: "invalid_payload",
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "invalid_payload", message: "seasonId (string) is required." }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  const commandId = `finalize-season:${body.seasonId}`;

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

  const { data, error } = await admin.rpc("forge_finalize_season", {
    p_season_id: body.seasonId,
  });

  if (error) {
    console.error("finalize-season failed:", error.message);
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
    JSON.stringify({ status: "accepted", participantsFinalized: data }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
