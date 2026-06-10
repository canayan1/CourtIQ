// swing-analysis — DropVolley AI swing analysis.
//
// Receives a handful of JPEG frames sampled from a short swing video and asks
// Claude (vision) to coach the player's stroke technique. Mirrors the ai-chat
// function's auth (Supabase JWT) + Anthropic call. Off until the user opts in
// (the client gates on an explicit consent screen disclosing that frames are
// sent to Anthropic).
//
// Body: { stroke: "forehand"|"backhand"|"serve"|"volley", handedness?: "right"|"left",
//         frames: string[] (base64 JPEG, no data: prefix) }
// Auth: Bearer <Supabase JWT> (Authorization header)

import { createClient } from "jsr:@supabase/supabase-js@2";

const ANTHROPIC_API_KEY   = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
// Vision analysis benefits from a stronger model than the chat coach; tunable.
const SWING_MODEL         = Deno.env.get("SWING_MODEL") ?? "claude-sonnet-4-6";
const SUPABASE_URL        = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY   = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Hard usage caps (cost control for the Claude vision calls). Tunable via env.
const DAILY_CAP   = Number(Deno.env.get("SWING_DAILY_CAP") ?? "3");
const MONTHLY_CAP = Number(Deno.env.get("SWING_MONTHLY_CAP") ?? "30");

const MAX_FRAMES = 10;
const MAX_FRAME_BYTES = 1_600_000; // ~1.6MB base64 per frame

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const STROKES: Record<string, string> = {
  forehand: "forehand groundstroke",
  backhand: "backhand groundstroke",
  serve: "serve",
  volley: "volley",
};

function systemPrompt(stroke: string, handedness: string | null, frameCount: number): string {
  const hand = handedness ? `The player is ${handedness}-handed. ` : "";
  return [
    "You are an expert, encouraging tennis coach giving a player feedback on their technique.",
    `You are shown ${frameCount} still frames sampled in time order from a short video of the player hitting a ${STROKES[stroke] ?? stroke}. ${hand}`,
    "Analyze ONLY what you can actually see across the frames — preparation and grip, unit turn and backswing, stance and balance, contact point and racquet position, follow-through, and footwork/recovery. ",
    "Then give feedback in this structure with short bold headers:",
    "• **What's working** — 2-3 specific strengths you can see.",
    "• **Top fixes** — 2-3 prioritized improvements, each with a concrete cue or a quick drill.",
    "• **One thing to try next session** — a single focus.",
    "Rules: Be specific and honest but constructive and motivating. If a frame is too blurry or the angle hides something (e.g. you can't see the grip or the contact point), say so plainly instead of guessing. Do not invent details you cannot see. Keep it ~200-280 words. Address the player as 'you'.",
  ].join("\n");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders, status: 204 });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!ANTHROPIC_API_KEY) {
    return json({ error: "AI is not configured." }, 503);
  }

  // Auth — same Supabase JWT scheme as ai-chat.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await supabase.auth.getUser();
  if (userErr || !user) {
    return json({ error: "Not authenticated." }, 401);
  }

  let body: { stroke?: string; handedness?: string; frames?: string[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const stroke = (body.stroke ?? "").toLowerCase();
  if (!STROKES[stroke]) {
    return json({ error: "Unknown stroke." }, 400);
  }
  const handedness = body.handedness === "left" || body.handedness === "right" ? body.handedness : null;
  const frames = Array.isArray(body.frames) ? body.frames : [];
  if (frames.length < 2) {
    return json({ error: "Need at least 2 frames." }, 400);
  }
  if (frames.length > MAX_FRAMES) {
    return json({ error: `Too many frames (max ${MAX_FRAMES}).` }, 400);
  }
  for (const f of frames) {
    if (typeof f !== "string" || f.length === 0 || f.length > MAX_FRAME_BYTES) {
      return json({ error: "A frame is missing or too large." }, 400);
    }
  }

  // Hard usage cap (cost control). RLS scopes the count to this user's own rows.
  const now = new Date();
  const dayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
  const { count: dayCount } = await supabase
    .from("swing_analyses").select("id", { count: "exact", head: true })
    .gte("created_at", dayStart);
  if ((dayCount ?? 0) >= DAILY_CAP) {
    return json({ error: `You've reached today's limit of ${DAILY_CAP} swing analyses. Come back tomorrow.` }, 429);
  }
  const { count: monthCount } = await supabase
    .from("swing_analyses").select("id", { count: "exact", head: true })
    .gte("created_at", monthStart);
  if ((monthCount ?? 0) >= MONTHLY_CAP) {
    return json({ error: `You've reached this month's limit of ${MONTHLY_CAP} swing analyses.` }, 429);
  }

  // Build the vision message: frames in order, then the instruction.
  const content: unknown[] = frames.map((data, i) => ([
    { type: "text", text: `Frame ${i + 1} of ${frames.length}:` },
    { type: "image", source: { type: "base64", media_type: "image/jpeg", data } },
  ])).flat();
  content.push({ type: "text", text: `Coach my ${STROKES[stroke] ?? stroke} based on these frames.` });

  let resp: Response;
  try {
    resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: SWING_MODEL,
        max_tokens: 1024,
        system: systemPrompt(stroke, handedness, frames.length),
        messages: [{ role: "user", content }],
      }),
    });
  } catch (_e) {
    return json({ error: "Could not reach the analysis service." }, 502);
  }

  if (!resp.ok) {
    const detail = await resp.text();
    console.error("anthropic error", resp.status, detail.slice(0, 300));
    return json({ error: "The analysis service returned an error." }, 502);
  }

  const data = await resp.json();
  const text = Array.isArray(data?.content)
    ? data.content.filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join("\n").trim()
    : "";
  if (!text) {
    return json({ error: "Empty analysis." }, 502);
  }

  // Record successful usage against the cap (best-effort; RLS enforces own-row).
  await supabase.from("swing_analyses").insert({ user_id: user.id });

  return json({ analysis: text, stroke, model: SWING_MODEL }, 200);
});

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
