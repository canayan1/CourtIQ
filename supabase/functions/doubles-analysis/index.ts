// doubles-analysis — DropVolley doubles compatibility (Google Gemini, text).
//
// Given the player's profile + a prospective partner's mini-profile, assesses
// how well the pair complements and how they should play together. Returns a
// 0-100 compatibility score + a coaching report. Mirrors match-analysis auth.
//
// Body: { summary: string }   (client formats both players' profiles)
// Auth: Bearer <Supabase JWT>. Uses the shared free GEMINI_API_KEY.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { entitlementAllows } from "../_shared/entitlement.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL   = Deno.env.get("DOUBLES_GEMINI_MODEL") ?? "gemini-2.5-flash";
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

const SYSTEM_PROMPT = [
  "You are an expert doubles tennis coach. You are given two players' profiles — the player ('you') and a prospective doubles partner: level, handedness, play style, strengths, and weaknesses.",
  "Assess how well their games COMPLEMENT each other as a doubles pair, and how they should play together.",
  "The summary gives a 'Computed fit tier' (Great fit / Solid team / Complementary) plus Strengths and Watch-outs. Do NOT output any numeric score — no 'SCORE:' line, no 'NN/100', no percentages anywhere. Open with ONE short sentence affirming that tier in plain words, grounded in the given strengths and watch-outs, then a blank line, then:",
  "• **Your pairing's strengths** — 2-3 specific things that work because of how your games fit (complementary styles/strengths).",
  "• **Gaps to cover** — 1-2 shared weaknesses or overlaps the pair must manage.",
  "• **Game plan** — concrete doubles tactics for THIS pair: starting formation (one-up-one-back / both-back / both-up), who serves first, who takes the deuce vs ad side, who should poach, who covers the middle and the lobs, and one communication cue.",
  "Rules: Be specific to THESE two players — use their actual styles, strengths, and weaknesses, not generic doubles advice. Handedness matters (a lefty/righty pair can cover both alleys on serve and stack returns). Be honest but encouraging. ~220-300 words, plain text with the bold headers, no preamble, address the player as 'you'.",
].join("\n");

// Compact club-level doubles reference, injected as a second system instruction
// so pairing advice is grounded in real doubles tactics. Kept short (single-shot
// call, no prompt caching) to bound token cost.
const DOUBLES_REFERENCE = [
  "Club-level doubles reference — ground your pairing advice in this:",
  "• Formations: one-up-one-back is the club default; both-back defends lobs and big serves; both-up wins the net battle but is exposed to lobs. Pick based on the pair's comfort and the opponents.",
  "• Roles: the stronger volleyer looks to close and poach; the server's partner starts at net and reads the return; on return, the steadier returner takes the tougher side.",
  "• Sides: a left-hander on the ad side keeps both forehands in the middle and both serves swinging wide — a real asset.",
  "• Middle + poaching: someone must own the middle ball (usually the net player); call 'mine/yours' early; in doubles the middle beats the alley, so take the middle away first.",
  "• Complementary pairs: an aggressive net-rusher + a steady baseline anchor cover more court than two of a kind; two players who both avoid the net leave it open.",
  "• Communication: a quick pre-point signal (who poaches, where the serve goes) plus a between-points reset is worth more than any single shot.",
  "Be specific to THESE two players' actual styles, strengths, and weaknesses.",
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
  if (!(await entitlementAllows("doubles-analysis", user.id))) return json({ error: "entitlement_required", needsUpgrade: true }, 402);

  let body: { summary?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }
  const summary = (typeof body.summary === "string" ? body.summary : "").trim();
  if (!summary) return json({ error: "No player details provided." }, 400);
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
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }, { text: DOUBLES_REFERENCE }] },
    contents: [{ role: "user", parts: [{ text: summary }] }],
    // maxOutputTokens INCLUDES thinking tokens on gemini-2.5 models. 1024 was
    // being consumed by the model's thinking, truncating the ~250-word report
    // mid-sentence (and leaving an unclosed **bold** that rendered as raw "**").
    // Give the report ample room above the thinking budget — matches swing.
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

  // Pull the leading "SCORE: NN" line into a structured field.
  let score: number | null = null;
  let report = text;
  const firstLine = report.split("\n")[0] ?? "";
  const m = firstLine.match(/SCORE:\s*(\d{1,3})/i);
  if (m) {
    const n = parseInt(m[1], 10);
    if (n >= 0 && n <= 100) score = n;
    report = report.split("\n").slice(1).join("\n").trim();
  }

  return json({ report, score, model: GEMINI_MODEL }, 200);
});

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
