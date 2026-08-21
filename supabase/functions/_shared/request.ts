// Request parsing + the deterministic hash idempotency conflict
// detection is built on (spec section 5: "same idempotency key but
// different request payload/hash: reject"). `hashRequest` must be
// stable for the *same* logical request across retries — a naive
// `JSON.stringify` is good enough here because every caller of this
// module builds its request body from a fixed, known key set (never
// user-controlled key ordering), so key order is already deterministic
// per call site.

import { ErrorCode, ForgeError } from "./errors.ts";

export async function parseJsonBody(req: Request): Promise<Record<string, unknown>> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    throw new ForgeError(ErrorCode.InvalidPayload, "Request body is not valid JSON.");
  }
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new ForgeError(ErrorCode.InvalidPayload, "Request body must be a JSON object.");
  }
  return raw as Record<string, unknown>;
}

export async function hashRequest(body: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(body));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function requireString(body: Record<string, unknown>, field: string): string {
  const value = body[field];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ForgeError(ErrorCode.InvalidPayload, `Missing or invalid required field: ${field}.`);
  }
  return value;
}

export function requireUuid(body: Record<string, unknown>, field: string): string {
  const value = requireString(body, field);
  const uuidPattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(value)) {
    throw new ForgeError(ErrorCode.InvalidPayload, `Field "${field}" is not a valid id.`);
  }
  return value;
}

export function requireSequence(body: Record<string, unknown>): number {
  const value = body["sequence"];
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
    throw new ForgeError(
      ErrorCode.InvalidPayload,
      "Field \"sequence\" must be a positive integer.",
    );
  }
  return value;
}

export function optionalString(body: Record<string, unknown>, field: string): string | null {
  const value = body[field];
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") {
    throw new ForgeError(ErrorCode.InvalidPayload, `Field "${field}" must be a string if present.`);
  }
  return value;
}
