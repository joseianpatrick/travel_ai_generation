// Destination cover-photo lookup — provider not wired up yet.
//
// TODO: pick a photo provider (e.g. Pexels or Unsplash), then:
//   1. Get a free API key from that provider.
//   2. Add it as an Edge Function secret:
//        supabase secrets set PEXELS_API_KEY=xxxxx
//   3. Implement the fetch below and return the first result's image URL.
// Until then this returns null and the app falls back to its striped
// placeholder banner, captioned with the trip's `destination` text.

/// Looks up a representative photo URL for [destination]. Must never throw —
/// a missing/failing photo lookup should never block trip generation.
export async function fetchDestinationPhoto(
  destination: string,
): Promise<string | null> {
  if (!destination.trim()) return null;
  // TODO: replace with a real provider call, e.g.:
  // const apiKey = Deno.env.get("PEXELS_API_KEY");
  // if (!apiKey) return null;
  // const res = await fetch(
  //   `https://api.pexels.com/v1/search?query=${encodeURIComponent(destination)}&per_page=1`,
  //   { headers: { Authorization: apiKey } },
  // );
  // if (!res.ok) return null;
  // const data = await res.json();
  // return data.photos?.[0]?.src?.large ?? null;
  return null;
}
