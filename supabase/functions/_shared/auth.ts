// Authentication boundary (spec section 2). Every authoritative command
// derives the acting user from the incoming request's own Supabase JWT
// — never from a client-supplied userId field, and never using a
// service-role key. The client returned here is created with the
// caller's own Authorization header, so every RPC call it makes runs as
// that user for RLS/auth.uid() purposes, exactly like a real client SDK
// call would. No service-role key exists anywhere in this module.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ErrorCode, ForgeError } from "./errors.ts";

export interface AuthenticatedRequest {
  client: SupabaseClient;
  userId: string;
}

/** Verifies the request's Authorization header against Supabase Auth and
 * returns a client scoped to that same JWT. Throws `ForgeError`
 * (unauthenticated) if the header is missing or the token doesn't
 * resolve to a real user — this is the one gate every function must
 * pass through before touching anything else. */
export async function authenticate(req: Request): Promise<AuthenticatedRequest> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new ForgeError(ErrorCode.Unauthenticated, "Missing Authorization header.");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    throw new ForgeError(ErrorCode.InternalError, "Function is missing Supabase configuration.");
  }

  // Anon key + the caller's own JWT forwarded as-is — never the
  // service-role key. Every downstream call (in particular the
  // forge_* RPCs) therefore runs with auth.uid() resolving to this
  // same user, and RLS applies exactly as it would for any other
  // authenticated client request.
  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new ForgeError(ErrorCode.Unauthenticated, "The provided token is not a valid session.");
  }

  return { client, userId: data.user.id };
}
