// Kalsada trip-planning agent — entrypoint.
//
// POST { prompt: string } with a signed-in user's Authorization header.
// Responds { trip: {...}, summary: string }.
//
// Modules: auth.ts (session check) · gemini.ts (Gemini call + trip shaping)
// · http.ts (CORS/JSON helpers).

import { authenticatedUserId } from "./auth.ts";
import { PlanTripError, planTrip } from "./gemini.ts";
import { corsHeaders, json } from "./http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Use POST." }, 405);
  }

  const userId = await authenticatedUserId(req);
  if (!userId) {
    return json({ error: "Sign in to plan trips." }, 401);
  }

  let prompt: unknown;
  let options: unknown;
  try {
    ({ prompt, options } = await req.json());
  } catch {
    return json({ error: "Body must be JSON." }, 400);
  }
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    return json({ error: "Tell me about the trip you want." }, 400);
  }
  const opts = options && typeof options === "object"
    ? options as Record<string, unknown>
    : undefined;

  try {
    return json(await planTrip(prompt, opts));
  } catch (error) {
    if (error instanceof PlanTripError) {
      return json({ error: error.message }, error.status);
    }
    console.error("Unexpected plan-trip failure", error);
    return json({ error: "The trip agent failed unexpectedly." }, 500);
  }
});
