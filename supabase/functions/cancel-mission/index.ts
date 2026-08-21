// POST /functions/v1/cancel-mission
// Thin wrapper around forge_cancel_mission. Never grants any reward —
// see the RPC's own doc comment.

import { handlePreflight, corsHeaders } from "../_shared/cors.ts";
import { authenticate } from "../_shared/auth.ts";
import { errorResponse, ForgeError, parsePostgresError } from "../_shared/errors.ts";
import { assertNoForbiddenAuthorityFields } from "../_shared/validation.ts";
import {
  hashRequest,
  optionalString,
  parseJsonBody,
  requireSequence,
  requireString,
  requireUuid,
} from "../_shared/request.ts";

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const { client } = await authenticate(req);
    const body = await parseJsonBody(req);
    assertNoForbiddenAuthorityFields(body);

    const commandId = requireString(body, "commandId");
    const idempotencyKey = requireString(body, "idempotencyKey");
    const missionInstanceId = requireUuid(body, "missionInstanceId");
    const sequence = requireSequence(body);
    const reason = optionalString(body, "reason");
    const requestHash = await hashRequest(body);

    const { data, error } = await client.rpc("forge_cancel_mission", {
      p_command_id: commandId,
      p_idempotency_key: idempotencyKey,
      p_mission_instance_id: missionInstanceId,
      p_sequence: sequence,
      p_request_hash: requestHash,
      p_reason: reason,
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
