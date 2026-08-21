// Shared CORS handling for every Forge Edge Function. Kept intentionally
// permissive on origin (mirroring Supabase's own function-invoke default)
// since these endpoints are already gated by JWT auth + RLS/ownership
// checks inside the database functions — CORS here is about letting a
// browser client call the function at all, not about authorization.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function handlePreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
