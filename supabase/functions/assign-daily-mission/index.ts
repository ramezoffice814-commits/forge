// POST /functions/v1/assign-daily-mission
// Thin wrapper around forge_assign_daily_mission — same shape as the
// five Phase 10C mission-command functions (authenticate with the
// caller's own JWT, validate shape, call one RPC, map the result). The
// client may propose a mission (what its local selection engine
// picked); the server independently validates it and creates the
// authoritative mission_instances row — see forge_assign_daily_mission's
// own doc comment in supabase/migrations/20260820090000_mission_
// assignment.sql for the full selection-authority reasoning.

import { handlePreflight, corsHeaders } from "../_shared/cors.ts";
import { authenticate } from "../_shared/auth.ts";
import { errorResponse, ForgeError, parsePostgresError } from "../_shared/errors.ts";
import { assertNoForbiddenAuthorityFields } from "../_shared/validation.ts";
import { hashRequest, parseJsonBody, requireString } from "../_shared/request.ts";

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const { client } = await authenticate(req);
    const body = await parseJsonBody(req);
    assertNoForbiddenAuthorityFields(body);

    const commandId = requireString(body, "commandId");
    const idempotencyKey = requireString(body, "idempotencyKey");
    const requestedMissionDefinitionId =
      typeof body["requestedMissionDefinitionId"] === "string"
        ? (body["requestedMissionDefinitionId"] as string)
        : null;
    const requestedCategory =
      typeof body["requestedCategory"] === "string" ? (body["requestedCategory"] as string) : null;
    const requestHash = await hashRequest(body);

    const { data, error } = await client.rpc("forge_assign_daily_mission", {
      p_command_id: commandId,
      p_idempotency_key: idempotencyKey,
      p_request_hash: requestHash,
      p_requested_mission_definition_id: requestedMissionDefinitionId,
      p_requested_category: requestedCategory,
    });

    if (error) throw parsePostgresError(error);

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const forgeError = err instanceof ForgeError ? err : parsePostgresError(err);
    return errorResponse(forgeError, corsHeaders);
  }
});
