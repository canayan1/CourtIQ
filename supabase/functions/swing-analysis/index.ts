// swing-analysis — DropVolley AI swing & footwork analysis (Google Gemini).
//
// Receives a short swing/footwork video and asks Gemini (native video
// understanding) to coach the player's technique or movement. Mirrors the
// ai-chat auth (Supabase JWT) + the swing_analyses usage cap. Off until the
// user opts in (the client gates on an explicit consent screen).
//
// Body: { stroke: "forehand"|"backhand"|"serve"|"volley"|"footwork",
//         handedness?: "right"|"left",
//         video: <base64 (no data: prefix)>, mimeType: "video/mp4",
//         context?: <compact, privacy-safe player context to personalize coaching> }
// Auth: Bearer <Supabase JWT> (Authorization header)

import { createClient } from "jsr:@supabase/supabase-js@2";
// Prompt logic lives in prompts.mjs — a single source of truth shared with
// tools/swing-bench, so offline evaluation always tests EXACTLY what prod sends.
import {
  STROKES,
  buildSystemParts,
  GENERATION_CONFIG,
  parseScoredAnalysis,
  userPrompt,
} from "./prompts.mjs";

// Video uses a dedicated BILLED key (no training on user video + higher limits);
// falls back to the shared key if the dedicated one isn't set.
const GEMINI_API_KEY = Deno.env.get("GEMINI_VIDEO_API_KEY") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
// Free tier can't reliably serve Pro — default to Flash. Set SWING_GEMINI_MODEL
// to gemini-2.5-pro on the BILLED video key for premium quality.
const GEMINI_MODEL   = Deno.env.get("SWING_GEMINI_MODEL") ?? "gemini-2.5-flash";
const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// --- RevenueCat server-side entitlement gate (see ai-chat for full rationale) ---
// Ships behind REQUIRE_ENTITLEMENT (dark until flipped on post-1.0.2). Fails OPEN
// on any RevenueCat error so an outage never locks out paying users; the prepaid
// budget cap is the backstop for the brief abuse window that would open.
const REVENUECAT_SECRET_KEY = Deno.env.get("REVENUECAT_SECRET_KEY") ?? "";
const REQUIRE_ENTITLEMENT   = (Deno.env.get("REQUIRE_ENTITLEMENT") ?? "false").toLowerCase() === "true";
const ENTITLEMENT_ID        = Deno.env.get("PREMIUM_ENTITLEMENT_ID") ?? "premium_all_access";
const entitlementCache = new Map<string, { entitled: boolean; at: number }>();
const ENTITLEMENT_TTL_MS = 10 * 60 * 1000;
async function isEntitled(userId: string): Promise<boolean> {
  if (!REQUIRE_ENTITLEMENT) return true;          // gate dark -> allow (rollout)
  if (!REVENUECAT_SECRET_KEY) return true;        // misconfigured -> fail open
  const hit = entitlementCache.get(userId);
  if (hit && Date.now() - hit.at < ENTITLEMENT_TTL_MS) return hit.entitled;
  try {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
      { headers: { Authorization: `Bearer ${REVENUECAT_SECRET_KEY}` } },
    );
    if (!res.ok) return true;                     // RC error -> fail open
    const body = await res.json();
    // Single premium entitlement in this project + its RC identifier is a
    // display-style string, so treat ANY active (non-expired) entitlement as
    // premium instead of matching an exact key. Robust to the identifier/renames.
    const ents = (body?.subscriber?.entitlements ?? {}) as Record<string, { expires_date?: string | null }>;
    const nowMs = Date.now();
    const entitled = Object.values(ents).some((e) => e && (e.expires_date == null || new Date(e.expires_date).getTime() > nowMs));
    entitlementCache.set(userId, { entitled, at: Date.now() });
    return entitled;
  } catch {
    return true;                                  // network error -> fail open
  }
}

// Hard usage caps (cost control). Tunable via env.
const DAILY_CAP   = Number(Deno.env.get("SWING_DAILY_CAP") ?? "3");
const MONTHLY_CAP = Number(Deno.env.get("SWING_MONTHLY_CAP") ?? "30");
const GLOBAL_DAILY_CAP = Number(Deno.env.get("GLOBAL_DAILY_CALL_CAP") ?? "1500");

// Gemini inline-data requests cap at ~20MB total. The client compresses to
// 720p; this guards the request from overflowing inline limits.
const MAX_VIDEO_B64 = 20_000_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// STROKES + all prompt text now come from ./prompts.mjs (shared with swing-bench).

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

  // Server-side entitlement gate (no-op until REQUIRE_ENTITLEMENT is flipped on).
  if (!(await isEntitled(user.id))) return json({ error: "entitlement_required", needsUpgrade: true }, 402);

  let body: { stroke?: string; handedness?: string; video?: string; mimeType?: string; context?: string };
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
  // Optional, compact, privacy-safe player context (profile + recent scores)
  // the client builds to PERSONALIZE the coaching. Trimmed + length-capped so a
  // malformed client can't bloat the prompt. Stays fully optional.
  const context = typeof body.context === "string"
    ? body.context.trim().slice(0, 800)
    : "";
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

  // Global daily budget breaker (cost cap). Atomically bumps a shared counter
  // and refuses once the whole app crosses GLOBAL_DAILY_CALL_CAP for the day, so
  // an abuse burst (incl. the reinstall bypass of the per-user cap above) can
  // never drain the prepaid AI budget. Fails OPEN on a DB blip.
  try {
    const { data: globalCount } = await supabase.rpc("bump_global_usage");
    if (typeof globalCount === "number" && globalCount > GLOBAL_DAILY_CAP) {
      return json({ error: "The AI service is busy right now. Please try again shortly." }, 503);
    }
  } catch (_e) { /* fail open */ }

  // Gemini: native video understanding via inline data.
  const geminiBody = {
    systemInstruction: { parts: buildSystemParts(stroke, handedness, context) },
    contents: [{
      role: "user",
      parts: [
        // fps:5 — the DEFAULT is 1 fps, which misses a tennis swing entirely
        // (contact lasts a fraction of a second). Sampling ~5 fps lets the model
        // actually SEE prep→backswing→contact→follow-through. Costs more video
        // tokens (still Flash-priced, well under Pro) but it's the real grounding fix.
        { inline_data: { mime_type: mimeType, data: video }, video_metadata: { fps: 5 } },
        { text: userPrompt(stroke) },
      ],
    }],
    generationConfig: GENERATION_CONFIG,
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

  // Pull the leading "SCORE: NN" line out into a structured field.
  const { analysis, score } = parseScoredAnalysis(text);

  // Record successful usage against the cap (best-effort; RLS enforces own-row).
  await supabase.from("swing_analyses").insert({ user_id: user.id });

  return json({ analysis, score, stroke, model: GEMINI_MODEL }, 200);
});

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
