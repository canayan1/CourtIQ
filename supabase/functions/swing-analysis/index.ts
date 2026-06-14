// swing-analysis — DropVolley AI swing & footwork analysis (Google Gemini).
//
// Receives a short swing/footwork video and asks Gemini (native video
// understanding) to coach the player's technique or movement. Mirrors the
// ai-chat auth (Supabase JWT) + the swing_analyses usage cap. Off until the
// user opts in (the client gates on an explicit consent screen).
//
// Body: { stroke: "forehand"|"backhand"|"serve"|"volley"|"footwork",
//         handedness?: "right"|"left",
//         video: <base64 (no data: prefix)>, mimeType: "video/mp4" }
// Auth: Bearer <Supabase JWT> (Authorization header)

import { createClient } from "jsr:@supabase/supabase-js@2";

// Video uses a dedicated BILLED key (no training on user video + higher limits);
// falls back to the shared key if the dedicated one isn't set.
const GEMINI_API_KEY = Deno.env.get("GEMINI_VIDEO_API_KEY") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
// Premium hero feature → default to the stronger Pro model. Tunable via env.
const GEMINI_MODEL   = Deno.env.get("SWING_GEMINI_MODEL") ?? "gemini-2.5-pro";
const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Hard usage caps (cost control). Tunable via env.
const DAILY_CAP   = Number(Deno.env.get("SWING_DAILY_CAP") ?? "3");
const MONTHLY_CAP = Number(Deno.env.get("SWING_MONTHLY_CAP") ?? "30");

// Gemini inline-data requests cap at ~20MB total. The client compresses to
// 720p; this guards the request from overflowing inline limits.
const MAX_VIDEO_B64 = 20_000_000;

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
  footwork: "footwork and on-court movement",
};

function systemPrompt(stroke: string, handedness: string | null): string {
  const hand = handedness ? `The player is ${handedness}-handed. ` : "";
  if (stroke === "footwork") {
    return [
      "You are an expert, encouraging tennis coach giving a player feedback on their FOOTWORK and on-court movement.",
      `You are shown a short video of the player moving and hitting on court. ${hand}`,
      "Analyze ONLY what you can actually see — split-step timing, first-step explosiveness and direction, distance and spacing to the ball, base and stance width, balance through the shot, and recovery back toward the middle of the court.",
      "Give feedback in this structure with short bold headers:",
      "• **What's working** — 2-3 specific strengths you can see.",
      "• **Top fixes** — 2-3 prioritized improvements, each with a concrete cue or a quick footwork drill.",
      "• **One thing to try next session** — a single focus.",
      "Rules: Watch the whole clip carefully first. Begin your reply DIRECTLY with the line '**What's working**' — NO opening or summary paragraph. Cite SPECIFIC things you actually see in THIS clip (e.g. 'you stay flat-footed before the ball lands', 'you recover toward the ball not the middle') — never generic tips that could apply to anyone. Be honest but constructive and motivating. If the angle hides the feet/split-step/recovery, say so plainly instead of guessing; don't invent details. ~200-280 words, plain text with the bold headers, address the player as 'you'.",
    ].join("\n");
  }
  return [
    "You are an expert, encouraging tennis coach giving a player feedback on their technique.",
    `You are shown a short video of the player hitting a ${STROKES[stroke] ?? stroke}. ${hand}`,
    "Analyze ONLY what you can actually see — preparation and grip, unit turn and backswing, stance and balance, contact point and racquet position, follow-through, and footwork/recovery.",
    "Give feedback in this structure with short bold headers:",
    "• **What's working** — 2-3 specific strengths you can see.",
    "• **Top fixes** — 2-3 prioritized improvements, each with a concrete cue or a quick drill.",
    "• **One thing to try next session** — a single focus.",
    "Rules: Watch the whole clip carefully first. Begin your reply DIRECTLY with the line '**What's working**' — NO opening or summary paragraph. Cite SPECIFIC things you actually see in THIS swing (e.g. 'your racquet face is open at contact', 'your hips stop rotating before you hit') — never generic tennis tips that could apply to anyone. Be honest but constructive and motivating. If the video is too blurry or the angle hides something (grip, contact point), say so plainly instead of guessing; don't invent details. ~200-280 words, plain text with the bold headers, address the player as 'you'.",
  ].join("\n");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders, status: 204 });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!GEMINI_API_KEY) return json({ error: "AI is not configured." }, 503);

  // Auth — same Supabase JWT scheme as ai-chat.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await supabase.auth.getUser();
  if (userErr || !user) return json({ error: "Not authenticated." }, 401);

  let body: { stroke?: string; handedness?: string; video?: string; mimeType?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const stroke = (body.stroke ?? "").toLowerCase();
  if (!STROKES[stroke]) return json({ error: "Unknown stroke." }, 400);
  const handedness = body.handedness === "left" || body.handedness === "right" ? body.handedness : null;
  const video = typeof body.video === "string" ? body.video : "";
  const mimeType = typeof body.mimeType === "string" && body.mimeType ? body.mimeType : "video/mp4";
  if (!video) return json({ error: "No video provided." }, 400);
  if (video.length > MAX_VIDEO_B64) {
    return json({ error: "That clip is too large. Use a shorter clip." }, 413);
  }

  // Hard usage cap (cost control). RLS scopes the count to this user's rows.
  const now = new Date();
  const dayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString();
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
  const { count: dayCount } = await supabase
    .from("swing_analyses").select("id", { count: "exact", head: true }).gte("created_at", dayStart);
  if ((dayCount ?? 0) >= DAILY_CAP) {
    return json({ error: `You've reached today's limit of ${DAILY_CAP} swing analyses. Come back tomorrow.` }, 429);
  }
  const { count: monthCount } = await supabase
    .from("swing_analyses").select("id", { count: "exact", head: true }).gte("created_at", monthStart);
  if ((monthCount ?? 0) >= MONTHLY_CAP) {
    return json({ error: `You've reached this month's limit of ${MONTHLY_CAP} swing analyses.` }, 429);
  }

  // Gemini: native video understanding via inline data.
  const geminiBody = {
    systemInstruction: { parts: [{ text: systemPrompt(stroke, handedness) }] },
    contents: [{
      role: "user",
      parts: [
        { inline_data: { mime_type: mimeType, data: video } },
        { text: `Coach my ${STROKES[stroke] ?? stroke} from this video.` },
      ],
    }],
    // maxOutputTokens INCLUDES thinking tokens on 2.5 models — keep it well
    // above (thinking budget + the ~300-word answer) so the visible reply is
    // never truncated.
    generationConfig: {
      maxOutputTokens: 4096,
      temperature: 0.5,
      thinkingConfig: { thinkingBudget: 2048 },
    },
  };

  let resp: Response;
  try {
    resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(geminiBody) },
    );
  } catch (_e) {
    return json({ error: "Could not reach the analysis service." }, 502);
  }

  if (!resp.ok) {
    const detail = await resp.text();
    console.error("gemini error", resp.status, detail.slice(0, 400));
    return json({ error: "The analysis service returned an error." }, 502);
  }

  const data = await resp.json();
  const parts = data?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts.map((p: { text?: string }) => p.text ?? "").join("\n").trim()
    : "";
  if (!text) {
    console.error("gemini empty", JSON.stringify(data).slice(0, 400));
    return json({ error: "Empty analysis." }, 502);
  }

  // Record successful usage against the cap (best-effort; RLS enforces own-row).
  await supabase.from("swing_analyses").insert({ user_id: user.id });

  return json({ analysis: text, stroke, model: GEMINI_MODEL }, 200);
});

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
