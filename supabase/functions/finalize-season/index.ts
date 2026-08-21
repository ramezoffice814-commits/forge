// POST /functions/v1/finalize-season
// Server-only entrypoint for forge_finalize_season — see finalize-week/
// index.ts's header comment for the full rationale (identical shape:
// zero grants on the underlying SQL function + a shared-secret gate,
// service-role key read only from this function's own environment).

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

  let body: { seasonId?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "invalid_payload", message: "Body must be JSON." }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
  if (typeof body.seasonId !== "string") {
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "invalid_payload", message: "seasonId (string) is required." }),
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

  const { data, error } = await admin.rpc("forge_finalize_season", {
    p_season_id: body.seasonId,
  });

  if (error) {
    console.error("finalize-season failed:", error.message);
    return new Response(
      JSON.stringify({ status: "rejected", errorCode: "internal_error", message: "Finalization failed." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ status: "accepted", participantsFinalized: data }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
