// Validates the caller's Supabase session.
//
// Per current Supabase guidance we verify the JWT in-function via
// auth.getClaims() rather than relying on the legacy Verify JWT setting.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";

/// Returns the signed-in user's id, or null when the request is anonymous
/// or carries an invalid/expired token.
export async function authenticatedUserId(
  req: Request,
): Promise<string | null> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return null;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const { data, error } = await supabase.auth.getClaims(token);
  if (error || !data?.claims?.sub) return null;
  return data.claims.sub as string;
}
