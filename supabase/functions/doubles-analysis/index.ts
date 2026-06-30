// doubles-analysis — DropVolley doubles compatibility (Google Gemini, text).
//
// Given the player's profile + a prospective partner's mini-profile, assesses
// how well the pair complements and how they should play together. Returns a
// 0-100 compatibility score + a coaching report. Mirrors match-analysis auth.
//
// Body: { summary: string }   (client formats both players' profiles)
// Auth: Bearer <Supabase JWT>. Uses the shared free GEMINI_API_KEY.

import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL   = Deno.env.get("DOUBLES_GEMINI_MODEL") ?? "gemini-2.5-flash";
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
    const ent = body?.subscriber?.entitlements?.[ENTITLEMENT_ID];
    const expires = ent?.expires_date as string | null | undefined;
    const entitled = !!ent && (expires == null || new Date(expires).getTime() > Date.now());
    entitlementCache.set(userId, { entitled, at: Date.now() });
    return entitled;
  } catch {
    return true;                                  // network error -> fail open
  }
}

const MAX_SUMMARY = 6000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT = [
  "You are an expert doubles tennis coach. You are given two players' profiles — the player ('you') and a prospective doubles partner: level, handedness, play style, strengths, and weaknesses.",
  "Assess how well their games COMPLEMENT each other as a doubles pair, and how they should play together.",
  "Start your ENTIRE reply with a line exactly like 'SCORE: 72' — an integer 0-100 compatibility score (how well the two games fit as a doubles team). Be discerning: complementary styles + covered weaknesses score high; two players with the same gap (e.g. both avoid the net, both weak second serve) score lower. Put a blank line after the score, then:",
  "• **Your pairing's strengths** — 2-3 specific things that work because of how your games fit (complementary styles/strengths).",
  "• **Gaps to cover** — 1-2 shared weaknesses or overlaps the pair must manage.",
  "• **Game plan** — concrete doubles tactics for THIS pair: starting formation (one-up-one-back / both-back / both-up), who serves first, who takes the deuce vs ad side, who should poach, who covers the middle and the lobs, and one communication cue.",
  "Rules: Be specific to THESE two players — use their actual styles, strengths, and weaknesses, not generic doubles advice. Handedness matters (a lefty/righty pair can cover both alleys on serve and stack returns). Be honest but encouraging. ~220-300 words, plain text with the bold headers, no preamble, address the player as 'you'.",
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

  // Server-side entitlement gate (no-op until REQUIRE_ENTITLEMENT is flipped on).
  if (!(await isEntitled(user.id))) return json({ error: "entitlement_required", needsUpgrade: true }, 402);

  let body: { summary?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }
  const summary = (typeof body.summary === "string" ? body.summary : "").trim();
  if (!summary) return json({ error: "No player details provided." }, 400);
  if (summary.length > MAX_SUMMARY) return json({ error: "Too much detail." }, 413);

  const geminiBody = {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
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
