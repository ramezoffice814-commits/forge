// POST /functions/v1/record-progress
// Validates progress shape/bounds (spec section 10) before ever calling
// forge_record_mission_progress — the RPC itself only checks ownership/
// transition/idempotency, not progress-type-specific bounds.

import { handlePreflight, corsHeaders } from "../_shared/cors.ts";
import { authenticate } from "../_shared/auth.ts";
import { errorResponse, ForgeError, parsePostgresError } from "../_shared/errors.ts";
import { assertNoForbiddenAuthorityFields } from "../_shared/validation.ts";
import { validateProgressPayload } from "../_shared/progress.ts";
import {
  hashRequest,
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
    const { progressType, progress } = validateProgressPayload(
      body["progressType"],
      body["progress"],
    );
    const requestHash = await hashRequest(body);

    const { data, error } = await client.rpc("forge_record_mission_progress", {
      p_command_id: commandId,
      p_idempotency_key: idempotencyKey,
      p_mission_instance_id: missionInstanceId,
      p_sequence: sequence,
      p_request_hash: requestHash,
      p_progress_type: progressType,
      p_progress: progress,
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
