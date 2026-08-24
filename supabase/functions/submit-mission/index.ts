// POST /functions/v1/submit-mission
// The core of Phase 10C (spec section 11). Validates the final progress
// snapshot's shape/bounds here, then hands everything else — ownership,
// sequence, idempotency, completion-criteria re-validation, XP/
// progression/achievement/competition-score calculation, integrity
// evaluation, and audit logging — to forge_submit_mission as a single
// atomic RPC call. This file contains zero reward logic: every number
// in the response came back from the database, never computed here.

import { handlePreflight, corsHeaders } from "../_shared/cors.ts";
import { authenticate } from "../_shared/auth.ts";
import { errorResponse, ForgeError, parsePostgresError } from "../_shared/errors.ts";
import { logOutcome } from "../_shared/observability.ts";
import { assertNoForbiddenAuthorityFields } from "../_shared/validation.ts";
import { validateProgressPayload } from "../_shared/progress.ts";
import {
  hashRequest,
  parseJsonBody,
  requireSequence,
  requireString,
  requireUuid,
} from "../_shared/request.ts";

const FUNCTION_NAME = "submit-mission";

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const start = performance.now();
  let commandId: string | null = null;

  try {
    const { client } = await authenticate(req);
    const body = await parseJsonBody(req);
    assertNoForbiddenAuthorityFields(body);

    commandId = requireString(body, "commandId");
    const idempotencyKey = requireString(body, "idempotencyKey");
    const missionInstanceId = requireUuid(body, "missionInstanceId");
    const sequence = requireSequence(body);
    const { progressType, progress } = validateProgressPayload(
      body["progressType"],
      body["progress"],
    );
    const requestHash = await hashRequest(body);

    const { data, error } = await client.rpc("forge_submit_mission", {
      p_command_id: commandId,
      p_idempotency_key: idempotencyKey,
      p_mission_instance_id: missionInstanceId,
      p_sequence: sequence,
      p_request_hash: requestHash,
      p_progress_type: progressType,
      p_progress: progress,
    });

    if (error) throw parsePostgresError(error);

    logOutcome({
      function: FUNCTION_NAME,
      commandId,
      resultCode: (data as { status?: string })?.status ?? "accepted",
      durationMs: Math.round(performance.now() - start),
      success: (data as { status?: string })?.status !== "rejected",
    });
    // forge_submit_mission returns a rejected-but-not-thrown envelope
    // for "completion requirements not met" (the mission stays open,
    // so this is a normal, expected outcome — not a transport error).
    // Surface it as HTTP 200 with status:"rejected" in the body so the
    // Flutter adapter can distinguish it from an actual server error.
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const forgeError = err instanceof ForgeError ? err : parsePostgresError(err);
    logOutcome({
      function: FUNCTION_NAME,
      commandId,
      resultCode: forgeError.errorCode,
      durationMs: Math.round(performance.now() - start),
      success: false,
    });
    return errorResponse(forgeError, corsHeaders);
  }
});
