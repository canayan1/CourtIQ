// match-analysis — DropVolley AI match analysis (Google Gemini, text).
//
// Two modes:
//  - "pre":      a short tactical take on the player's pre-match plan.
//  - "compound": a full post-match analysis tying the plan (if any) to the
//                result, self-ratings, and notes.
//
// Body: { mode: "pre" | "compound", summary: string }   (client formats the
//        match summary; the function wraps it in the coaching prompt)
// Auth: Bearer <Supabase JWT>. Uses the same free GEMINI_API_KEY as swing.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { entitlementAllows } from "../_shared/entitlement.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL   = Deno.env.get("MATCH_GEMINI_MODEL") ?? "gemini-2.5-flash";
const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// --- RevenueCat server-side entitlement gate ---
// Lives in _shared/entitlement.ts now, with the four copies of it that had
// already drifted apart. Read that file before flipping the gate on: failing
// open on a RevenueCat *error* is not the same as being safe, because an id
// RevenueCat has never seen comes back 200 with no entitlements and looks
// exactly like a free rider.

const MAX_SUMMARY = 6000;
const GLOBAL_DAILY_CAP = Number(Deno.env.get("GLOBAL_DAILY_CALL_CAP") ?? "1500");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function systemPrompt(mode: string): string {
  if (mode === "pre") {
    return [
      "You are an expert, encouraging tennis coach. The player shares their PLAN/intention for an UPCOMING match (it has not been played yet).",
      "Give a short, practical take on the plan with short bold headers:",
      "• **Smart** — what's good about the plan (1-2 points).",
      "• **Add this** — 1-2 concrete tactical additions or adjustments.",
      "• **Key focus** — the single most important thing to hold onto out there.",
      "• **Mindset** — one practical mental-prep cue tuned to this player and plan: a pre-match routine, a way to settle nerves (e.g. a slow breathing reset before serving), a focus/reframe, or a between-point routine. Keep it concrete, not generic positivity.",
      "Rules: ~160-200 words. Be specific and motivating. Don't invent details the player didn't give. This is performance/mental-game coaching, not therapy or medical advice. Plain text with the bold headers, no preamble. Address the player as 'you'.",
    ].join("\n");
  }
  if (mode === "mental") {
    return [
      "You are an expert tennis performance/mental-game coach. The player gives a quick PRE-MATCH mental self-check: energy, confidence, and nerves (each 1–5) and optional context (opponent/situation).",
      "Return a SHORT, concrete pre-match mental routine with short bold headers:",
      "• **Settle** — one cue to calm nerves now (e.g. a slow breathing reset before serving).",
      "• **Focus** — the single thing to lock onto out there (a process goal, not outcome).",
      "• **Reframe** — turn their stated nerves/doubt into a constructive thought.",
      "• **Between points** — one simple reset routine.",
      "Rules: ~120-160 words, specific to THEIR numbers/context, encouraging, performance coaching NOT therapy or medical advice, no preamble, address as 'you'.",
    ].join("\n");
  }
  // compound
  return [
    "You are an expert, encouraging tennis coach reviewing a match the player just logged.",
    "You are given the match summary — opponent/surface/result/score, the player's self-ratings (1-5), their pre-match plan if they had one, and their notes.",
    "Give a compound analysis with short bold headers:",
    "• **How it went** — read the result, score, and ratings together; if there was a plan, say honestly how it played out.",
    "• **What's working** — 2-3 genuine strengths.",
    "• **Priorities** — 2-3 things to work on, each with a concrete cue or drill.",
    "• **Next match** — one focus to carry forward.",
    "Rules: ~220-280 words. Be specific, honest, and motivating. Base everything on what the player actually reported; don't invent details. Plain text with the bold headers, no preamble. Address the player as 'you'.",
  ].join("\n");
}

// Compact club-level match-coaching reference, injected as a second system
// instruction so the analysis is grounded in real tennis (not vibes). Kept short
// (single-shot call, no prompt caching) to bound token cost.
const MATCH_REFERENCE = [
  "Club-level match-coaching reference — ground your advice in this and keep it appropriate to a RECREATIONAL player, not a pro:",
  "• Winning club patterns: a reliable second serve, high cross-court rally tolerance, hitting to the opponent's weaker wing, and taking the first strike after a short ball. Depth and margin beat flashy winners.",
  "• Surface tilts: clay rewards patience, spin and movement; hard courts reward first-strike and taking time away; fast courts reward the serve and short points.",
  "• Mental game: a between-points routine (breathe, reset, plan the next ball) and a fixed serve routine steady nerves; play the big points (30-30, break points, 4-4) more simply, not more spectacularly; reset fast after errors.",
  "• Match-craft: commit to a plan, then adjust ONE variable at a time (target, spin, court position) if it isn't working; find what the opponent dislikes and go back to it.",
  "• Reading the score: a tight/tiebreak loss is a small-margin problem (routines, second serve, one more ball), not a technical overhaul; a lopsided set is momentum/pattern, not a broken game.",
  "Weigh any 'Signals' provided in the summary. Never invent shots, scores, or events the player did not report.",
].join("\n");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders, status: 204 });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!GEMINI_API_KEY) return json({ error: "AI is not configured." }, 503);

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await supabase.auth.getUser();
  if (userErr || !user) return json({ error: "Not authenticated." }, 401);

  // Server-side entitlement gate — see _shared/entitlement.ts.
  if (!(await entitlementAllows("match-analysis", user.id))) return json({ error: "entitlement_required", needsUpgrade: true }, 402);

  let body: { mode?: string; summary?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const mode = body.mode === "pre" ? "pre" : body.mode === "mental" ? "mental" : "compound";
  const summary = (typeof body.summary === "string" ? body.summary : "").trim();
  if (!summary) return json({ error: "No match details provided." }, 400);
  if (summary.length > MAX_SUMMARY) return json({ error: "Too much detail." }, 413);

  // Global daily budget breaker (cost cap). Atomically bumps a shared counter
  // and refuses once the whole app crosses GLOBAL_DAILY_CALL_CAP for the day, so
  // a spam/abuse burst can never drain the prepaid AI budget. Fails OPEN on a DB
  // blip — the ceiling is a backstop, not a reason to break a legit request.
  try {
    const { data: globalCount } = await supabase.rpc("bump_global_usage");
    if (typeof globalCount === "number" && globalCount > GLOBAL_DAILY_CAP) {
      return json({ error: "The AI service is busy right now. Please try again shortly." }, 503);
    }
  } catch (_e) { /* fail open */ }

  const geminiBody = {
    systemInstruction: { parts: [{ text: systemPrompt(mode) }, { text: MATCH_REFERENCE }] },
    contents: [{ role: "user", parts: [{ text: summary }] }],
    // maxOutputTokens INCLUDES thinking tokens on gemini-2.5 models; 1024 can be
    // eaten by thinking and truncate the report mid-sentence. Give it room.
    generationConfig: { maxOutputTokens: 4096, temperature: 0.6 },
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
    console.error("gemini error", resp.status, (await resp.text()).slice(0, 400));
    return json({ error: "The analysis service returned an error." }, 502);
  }

  const data = await resp.json();
  const parts = data?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts.map((p: { text?: string }) => p.text ?? "").join("\n").trim()
    : "";
  if (!text) return json({ error: "Empty analysis." }, 502);

  return json({ report: text, mode, model: GEMINI_MODEL }, 200);
});

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
