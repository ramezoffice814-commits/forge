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

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const expectedSecret = Deno.env.get("FORGE_CRON_SECRET");
  const providedSecret = req.headers.get("x-cron-secret");
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "forbidden", message: "Not authorized." }),
      { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  let body: { seasonId?: string; weekNumber?: number };
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "invalid_payload", message: "Body must be JSON." }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  if (typeof body.seasonId !== "string" || typeof body.weekNumber !== "number") {
    return new Response(
      JSON.stringify({
        status: "rejected",
        errorCode: "invalid_payload",
        message: "seasonId (string) and weekNumber (number) are required.",
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
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
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "internal_error", message: "Finalization failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ status: "accepted", rowsWritten: data }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
