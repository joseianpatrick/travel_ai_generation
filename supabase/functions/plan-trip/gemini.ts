// The trip-planning brain: calls Google Gemini (AI Studio free tier) with a
// forced function-call schema that mirrors the app's Trip model and shapes the
// result for the client.
//
// Secrets: GOOGLE_STUDIO_FREE_KEY (required), GEMINI_MODEL (optional).

import { fetchDestinationPhoto } from "./photo.ts";

const SYSTEM_PROMPT = `You are the trip-planning agent inside Kalsada, a
Philippines-focused group travel app for motorbike rides, food trips, and
treks. Given a user's trip idea, design one complete, realistic trip.

Rules:
- Default to the Philippines unless the user names another destination.
- Give every day real coordinates (latitude/longitude) for where that day's
  travel STARTS — the departure point of that leg, not the destination. Day 1's
  start is the group's origin: when the user says they are traveling "from" a
  place, day 1 MUST start there (a trip "from Ilocos Sur to Zambales" has day 1
  starting in Ilocos Sur, NOT at the Zambales destination). Each later day
  starts where that day's ride begins. Coordinates must be accurate enough to
  plot on a map.
- Give every stop within a day real coordinates for that stop's own place
  (not the day's start point) — accurate enough to plot on a map.
- Route days must be physically plausible: real roads, ferries where needed,
  sane daily distances for the travel mode.
- Formats must match these examples exactly in style:
  datesLabel: "Aug 14–19, 2026" — the date range ONLY; NEVER append
  "· N nights" (the app adds the nights label itself). Pick sensible
  near-future dates. Put the night count in the separate "nights" field.
  distance per day: "146 km" · distanceTotal: "612 km" · duration: "4.5 hrs"
  money: "₱7,850" (Philippine peso, comma-separated thousands)
- totalGroup = totalPerRider × number of riders (rounded naturally).
- Budget items are per person: fuel/transport, lodging, food, fees, etc.
- 5-10 gear items tailored to the trip. 2-5 stops per day with times like
  "7:00 AM".
- stay: for each day with an overnight, name the hotel/lodging/campsite the
  group stays at (e.g. "Port Barton Beach Camp"). Leave it "" for a day that
  ends back home or has no overnight (e.g. the final return day).
- stayPrice: an estimated nightly price RANGE for that stay in the style
  "₱1,500–2,500 / night" (peso, en-dash between the low and high). Base it on
  typical local rates for that kind of lodging and area. Leave it "" whenever
  stay is "".
- Honor the lodging budget in the constraints when choosing each stay and its
  stayPrice: "budget" = hostels/homestays/campsites at the low end, "mid" =
  comfortable mid-range inns/resorts, "premium" = upscale hotels/resorts at the
  high end. Match the price ranges to the chosen tier.
- riders: one entry per traveler with two-letter initials (invent names for
  the group). When the constraints specify a group size, output EXACTLY that
  many riders; otherwise default to 2.
- Honor any travel mode and expressway preference in the constraints: match
  distances, durations, gear, and road choices to them (e.g. motorcycle gear
  and scenic roads when avoiding expressways).
- destination: the specific place the trip is centered on, e.g. "Palawan,
  Philippines" or "Baguio, Philippines" — a clean location string (distinct
  from the creative trip name) used to look up destination photos.
- summary: one warm sentence confirming the plan, mentioning the trip name,
  day count, and total distance.
- When revising a supplied trip, preserve the existing id and status of every
  unchanged day and stop, even if you reorder it. New days/stops may omit id;
  never reset an existing stop's done/skipped status.
- Always call the create_trip function with the full plan.`;

/// Options that steer generation, mirroring the client's PlannerOptions plus an
/// optional baseTrip for AI refine.
interface PlanOptions {
  travelMode?: string;
  avoidExpressways?: boolean;
  groupSize?: number;
  pace?: string;
  lodgingBudget?: string;
  days?: number | null;
  baseTrip?: Record<string, unknown>;
}

/// Builds the user turn: the raw prompt, a constraints block from [options],
/// and — for refine — the existing trip to revise.
function buildUserContent(prompt: string, options?: PlanOptions): string {
  let content = prompt.trim().slice(0, 2000);
  const lines: string[] = [];
  if (options) {
    if (options.travelMode) {
      lines.push(`- Travel mode: ${options.travelMode}`);
    }
    if (typeof options.avoidExpressways === "boolean") {
      lines.push(
        options.avoidExpressways
          ? "- Roads: avoid expressways; prefer scenic and local roads"
          : "- Roads: expressways are fine where they save meaningful time",
      );
    }
    if (options.groupSize && options.groupSize > 0) {
      lines.push(
        `- Group size: exactly ${options.groupSize} rider(s) — output exactly ${options.groupSize} riders`,
      );
    }
    if (options.pace) {
      lines.push(`- Pace: ${options.pace}`);
    }
    if (options.lodgingBudget) {
      lines.push(
        `- Lodging budget: ${options.lodgingBudget} — pick stays and stayPrice ranges at this tier`,
      );
    }
    if (options.days && options.days > 0) {
      lines.push(`- Length: about ${options.days} day(s)`);
    }
  }
  if (lines.length > 0) {
    content += `\n\nTrip constraints:\n${lines.join("\n")}`;
  }
  if (options?.baseTrip) {
    content +=
      "\n\nRevise this existing trip by applying the instruction above. " +
      "Keep everything the user did not ask to change, and return the FULL " +
      `updated trip:\n${JSON.stringify(options.baseTrip)}`;
  }
  return content;
}

// Gemini function declaration. Schema types use the uppercase Type enum the
// Generative Language API expects (OBJECT/ARRAY/STRING/INTEGER/NUMBER).
const TRIP_TOOL = {
  name: "create_trip",
  description: "Record the fully planned trip in the app's format.",
  parameters: {
    type: "OBJECT",
    required: [
      "name",
      "destination",
      "datesLabel",
      "nights",
      "distanceTotal",
      "totalPerRider",
      "totalGroup",
      "days",
      "budgetItems",
      "gearItems",
      "riders",
      "summary",
    ],
    properties: {
      name: {
        type: "STRING",
        description: "Trip name, e.g. 'Palawan Coastal Loop'",
      },
      destination: {
        type: "STRING",
        description:
          "Clean location string for photo lookup, e.g. 'Palawan, " +
          "Philippines' — distinct from the creative trip name.",
      },
      datesLabel: { type: "STRING" },
      nights: { type: "INTEGER" },
      distanceTotal: { type: "STRING" },
      totalPerRider: { type: "STRING" },
      totalGroup: { type: "STRING" },
      status: {
        type: "STRING",
        enum: ["planning", "done", "skipped"],
      },
      days: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: [
            "day",
            "title",
            "distance",
            "duration",
            "latitude",
            "longitude",
            "stops",
          ],
          properties: {
            id: {
              type: "STRING",
              description: "Stable existing day id when refining.",
            },
            day: { type: "INTEGER" },
            title: {
              type: "STRING",
              description: "e.g. 'Puerto Princesa → Port Barton'",
            },
            distance: { type: "STRING" },
            duration: { type: "STRING" },
            latitude: {
              type: "NUMBER",
              description:
                "Latitude where this day's travel STARTS (day 1 = the trip's " +
                "origin/home the user is traveling from).",
            },
            longitude: {
              type: "NUMBER",
              description: "Longitude of this day's starting point.",
            },
            stay: {
              type: "STRING",
              description:
                "Hotel/lodging/campsite for that night's overnight; " +
                '"" if the day has no overnight stay.',
            },
            stayPrice: {
              type: "STRING",
              description:
                'Estimated nightly price range, e.g. "₱1,500–2,500 / night". ' +
                '"" when stay is "".',
            },
            stops: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                required: ["time", "place", "note"],
                properties: {
                  id: {
                    type: "STRING",
                    description: "Stable existing stop id when refining.",
                  },
                  time: { type: "STRING" },
                  place: { type: "STRING" },
                  note: { type: "STRING" },
                  latitude: {
                    type: "NUMBER",
                    description:
                      "Real latitude of this specific stop's own place " +
                      "(not the day's start point) — accurate enough to " +
                      "plot on a map.",
                  },
                  longitude: {
                    type: "NUMBER",
                    description: "Longitude of this specific stop's own place.",
                  },
                  status: {
                    type: "STRING",
                    enum: ["pending", "done", "skipped"],
                  },
                },
              },
            },
          },
        },
      },
      budgetItems: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: ["label", "amount"],
          properties: {
            label: { type: "STRING" },
            amount: { type: "STRING" },
          },
        },
      },
      gearItems: { type: "ARRAY", items: { type: "STRING" } },
      riders: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          required: ["initials"],
          properties: { initials: { type: "STRING" } },
        },
      },
      summary: { type: "STRING" },
    },
  },
};

// Avatar palette matching the app's onboarding accent colors.
const RIDER_PALETTE = [
  0xff2b6f63,
  0xff1f5f8b,
  0xff8a5a2b,
  0xff5b3b8a,
  0xffb2554b,
  0xff3a7ca5,
];

/// Thrown when the trip cannot be produced; carries the HTTP status and a
/// message safe to show the user.
export class PlanTripError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

/// Asks Gemini to plan the trip. Returns the client payload
/// `{ trip, summary }` or throws [PlanTripError]. [options] carries the user's
/// steering choices and, for refine, the existing trip to revise.
export async function planTrip(
  prompt: string,
  options?: Record<string, unknown>,
): Promise<{ trip: Record<string, unknown>; summary: string }> {
  const opts = options as PlanOptions | undefined;
  const apiKey = Deno.env.get("GOOGLE_STUDIO_FREE_KEY");
  if (!apiKey) {
    throw new PlanTripError("The trip agent is not configured yet.", 500);
  }
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [
          { role: "user", parts: [{ text: buildUserContent(prompt, opts) }] },
        ],
        tools: [{ function_declarations: [TRIP_TOOL] }],
        tool_config: {
          function_calling_config: {
            mode: "ANY",
            allowed_function_names: ["create_trip"],
          },
        },
        generationConfig: { maxOutputTokens: 8192, temperature: 0.7 },
      }),
    },
  );
  if (!geminiRes.ok) {
    const body = await geminiRes.text();
    console.error("Gemini error", geminiRes.status, body);
    throw new PlanTripError(
      `The trip agent hit a snag (${geminiRes.status}). Try again.`,
      502,
    );
  }

  const completion = await geminiRes.json();
  const parts = completion.candidates?.[0]?.content?.parts ?? [];
  const call = parts.find(
    (part: { functionCall?: { name?: string } }) =>
      part.functionCall?.name === "create_trip",
  );
  if (!call?.functionCall?.args) {
    console.error("No create_trip functionCall in response", completion);
    throw new PlanTripError(
      "The trip agent returned no trip. Try again.",
      502,
    );
  }

  const t = call.functionCall.args;
  const destination = t.destination ?? "";
  const trip = {
    id: "",
    isPast: false,
    name: t.name ?? "",
    destination,
    coverImageUrl: "",
    datesLabel: t.datesLabel ?? "",
    nights: t.nights ?? 0,
    distanceTotal: t.distanceTotal ?? "",
    totalPerRider: t.totalPerRider ?? "",
    totalGroup: t.totalGroup ?? "",
    status: t.status ?? "planning",
    days: t.days ?? [],
    budgetItems: t.budgetItems ?? [],
    gearItems: t.gearItems ?? [],
    riders: (t.riders ?? []).map(
      (rider: { initials?: string }, index: number) => ({
        initials: rider.initials ?? "??",
        colorValue: RIDER_PALETTE[index % RIDER_PALETTE.length],
      }),
    ),
  };
  try {
    trip.coverImageUrl = (await fetchDestinationPhoto(destination)) ?? "";
  } catch (error) {
    console.error("Destination photo lookup failed", error);
  }
  const summary = t.summary ??
    `Your ${trip.name} is mapped out — ${trip.days.length} days, ready to go.`;

  return { trip, summary };
}
