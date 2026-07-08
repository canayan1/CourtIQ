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

const STROKES: Record<string, string> = {
  forehand: "forehand groundstroke",
  backhand: "backhand groundstroke",
  serve: "serve",
  volley: "volley",
  session: "full hitting session with multiple stroke types",
  footwork: "footwork and on-court movement",
};

// FORMAT guidance ONLY. We deliberately DON'T ship worked examples any more:
// the old forehand + serve few-shots were being parroted VERBATIM (Gemini Flash,
// when it couldn't actually read the 1 fps video, reproduced the serve example —
// toss, pronation, "palm in → palm flat → palm out", shadow serves — for clips
// with no serve at all). This note carries the structure with NOTHING to copy.
const FORMAT_NOTE = `FORMAT (structure only — contains no observations to copy): after the SCORE line, group feedback under bold headers for the stroke(s) you actually observed. Under each, a short "**What's working**" then "**Top fixes**". Write every fix as: the specific fault you SEE in THIS clip → "Cue:" a short feel the player can use → "Drill:" a way to groove it. End with "**One thing to try next**". Be concrete to what is on screen; never fall back on generic textbook phrasing.`;

// Body-aware coaching: the model SEES the player, so it must adapt to them —
// silently. Uniform "textbook mechanics" cues (deep knee bends, jump serves,
// plyometric drills) are an injury risk for heavier-set, older, or
// mobility-limited players, and body commentary is never acceptable.
const ADAPTATION_SAFETY = `ADAPTATION & SAFETY (applies to every cue and drill you give):
• Adapt silently to the body you actually see. NEVER comment on the player's body, weight, age, or fitness level — no observations, no euphemisms. Coach the technique, adapted.
• If the player appears heavier-set, older, or shows limited knee/hip/shoulder mobility in the clip, do NOT prescribe deep knee bends, jump-through serves, exaggerated loading, or plyometric drills. Prefer low-impact fixes with the same payoff: compact loading, timing, toss placement, contact point, grip, swing path.
• Any cue that loads a joint (knees, shoulder, lower back) gets a brief within-comfort qualifier (e.g. "as deep as feels comfortable") and a gradual progression, never a maximal version on day one.
• If the PLAYER CONTEXT includes PHYSICAL NOTES, treat them as hard constraints: never prescribe high-load work for a flagged area; give the low-impact alternative instead.
• The few-shot examples are STYLE guides, not templates — if one of their drills conflicts with these rules for THIS player, substitute an appropriate alternative instead of copying it.`;

// Expert coaching reference (USTA / Tennis Australia / peer-reviewed
// biomechanics). The checkpoints + faults to assess against, and — critically —
// an honest list of what a single side-on phone clip CANNOT show, so the AI
// never fabricates a measurement.
const COACHING_REFERENCE = `COACHING REFERENCE — assess what you actually see against these expert checkpoints (USTA / Tennis Australia / biomechanics). Apply them; don't recite them.

GROUNDSTROKES (forehand, backhand): ready position & early prep → UNIT TURN first (shoulders/trunk turn before the arm — "show your back shoulder to the net"; "arming the ball" with no turn is the #1 club fault) → racquet drops BELOW the ball → low-to-high swing through a long hitting zone with a stable racquet face (scooping/hitting UP instead of swinging low-to-high THROUGH is common — cue "drop under it, finish high over the shoulder") → CONTACT out in front of the front hip (late contact behind the hip is usually caused by LATE PREP/footwork — diagnose the root, not just the swing) → balanced, high finish. One-handed backhand: a firm, laid-back wrist at contact (a wristy, collapsing wrist is the classic 1HBH fault).
SERVE: stance + relaxed Continental grip → knee bend & LEG DRIVE up into the ball ("push the ground away / jump to the ball"; no leg drive is a top club fault) → racquet drops behind the back (tip down), elbow leads up → contact at FULL EXTENSION, up and slightly in front → PRONATION through contact ("palm in → palm flat → palm out"; a flat "frying-pan/waiter's" finish with no pronation is the classic weak-serve fault).
VOLLEY: short backswing, Continental grip, step in, BLOCK/punch (not a full swing), contact in front.
FOOTWORK: split-step AS the opponent strikes ("small hop, land as they hit"; no/late split is the root of most late, off-balance shots) → explosive first step pushing off the outside foot → spacing about an arm's length from the ball (adjust with small steps, don't reach) → recover toward the middle after each ball.

WHAT A SIDE-ON PHONE CLIP CAN vs CANNOT SHOW — be honest, NEVER fabricate a number:
• You CAN judge: swing path (low-to-high), racquet drop, contact point relative to the front hip, leg drive & extension, balance, finish height, split-step timing.
• You CANNOT reliably judge from one side-on clip: exact joint angles in degrees, shoulder/hip "separation angle", internal shoulder rotation, the grip on the far hand, lateral spacing, or court positioning/recovery geometry. Describe DIRECTION ("wrist laid back vs collapsing", "deep vs shallow knee bend"), never invent degrees. If the angle hides something, say so plainly instead of guessing.
The kinetic chain (legs→hips→trunk→shoulder→arm→racquet) is the right teaching lens but a heuristic, not a rigid law — cue smooth, sequenced acceleration; don't be dogmatic about exact timing.`;

function systemPrompt(stroke: string, handedness: string | null): string {
  const hand = handedness ? `The player is ${handedness}-handed. ` : "";
  if (stroke === "session") {
    return [
      "You are an expert, encouraging tennis coach reviewing a hitting session that may contain multiple stroke types (forehands, backhands, serves, volleys, overheads).",
      `${hand}Work through these steps IN ORDER and label them exactly.`,
      "STEP 1 — COUNT WHAT YOU SEE (mandatory first line): state the strokes you can actually identify and how many, e.g. 'I can see 2 forehands and 1 backhand.' Count ONLY strokes you genuinely watch the player hit. This count must match the video.",
      "STEP 2 — QUALITY GATE: if the player is partly out of frame, the angle hides the swing, the clip is blurry or too far, or you cannot tell what is being hit, say so plainly (e.g. 'The framing cuts off your contact point' / 'From this angle I can't clearly see your swing'), ask for a better clip, and STOP. NEVER invent a stroke you did not see — in particular do NOT mention a serve, toss, or overhead unless the player clearly hits one on screen. Inventing an unseen stroke is the single worst failure here.",
      "STEP 3 — SHORT READ: 2-3 sentences on the single biggest takeaway across the strokes you actually saw.",
      "STEP 4 — DETAILED BREAKDOWN: under a bold header for EACH observed stroke ('**Forehand**', '**Backhand**', …), give what's working + the top fix you can actually see. End with '**Overall**' — the #1 priority.",
      "Cite SPECIFIC things you see in THIS clip, never generic tips. Be honest but motivating. Address the player as 'you'. Plain text with the bold headers.",
    ].join("\n");
  }
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
    "Analyze ONLY what you can actually see — preparation and grip, unit turn and backswing, stance and balance, contact point and racquet position, follow-through, and footwork/recovery. If the video doesn't clearly show the stroke (bad angle, too far, nothing hit), say so plainly and suggest re-filming — never describe a generic or textbook version you did not actually see.",
    "CALIBRATION (critical for trust): a spatial detail that is hard to judge from a single camera angle — ball-toss direction (front/back/left/right), exact contact location relative to the body, swing-path depth, racquet-face angle — should only be stated as fact when it is CLEARLY visible. If it is ambiguous from this angle, either hedge ('from this view your toss looks slightly...') or skip it. One confidently WRONG call makes the player distrust the whole report, so prefer fewer certain points over more shaky ones.",
    "If the clip shows MULTIPLE reps of the stroke, base your feedback on faults that REPEAT across them — a recurring pattern is reliable, a one-off may be noise. If only ONE rep is shown, note that your read is from a single swing and may not be fully representative, and suggest filming a few reps for a sharper read.",
    "Give feedback in this structure with short bold headers:",
    "• **What's working** — 2-3 specific strengths you can see.",
    "• **Top fixes** — 2-3 prioritized improvements, each with a concrete cue or a quick drill.",
    "• **One thing to try next session** — a single focus.",
    "Rules: OPEN with one short line confirming what you actually see — the stroke and roughly how many reps, e.g. 'I can see 3 forehands.' If the clip is too blurry, too far, or the angle hides the swing (grip, contact point), say so plainly and ask for a better clip instead of analyzing — do NOT guess or describe a generic version. THEN give '**What's working**', '**Top fixes**', and '**One thing to try next session**'. Cite SPECIFIC things you actually see in THIS swing (e.g. 'your racquet face is open at contact', 'your hips stop rotating before you hit') — never generic tennis tips that could apply to anyone. Be honest but constructive and motivating. ~200-280 words, plain text with the bold headers, address the player as 'you'.",
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
  const systemParts: Array<{ text: string }> = [
    { text: systemPrompt(stroke, handedness) },
    { text: ADAPTATION_SAFETY },
    { text: COACHING_REFERENCE },
    { text: "Begin your ENTIRE reply with a line exactly like 'SCORE: 63' — a single integer 0-100 rating the overall technique shown (for a Whole session, an overall score across the strokes). Be discerning: most recreational players land 40-70; reserve 85+ for genuinely advanced technique. Put a blank line after that score line, then the analysis." },
    { text: FORMAT_NOTE },
  ];
  // Personalization: when the client sends player context, give the coach a
  // second instruction part so it tailors the feedback to this player. Optional
  // — absent context leaves the prompt unchanged.
  if (context) {
    systemParts.push({
      text: `PLAYER CONTEXT (use this to personalize your coaching — reference it where relevant, do NOT just repeat it back): ${context}`,
    });
  }
  const geminiBody = {
    systemInstruction: { parts: systemParts },
    contents: [{
      role: "user",
      parts: [
        // fps:5 — the DEFAULT is 1 fps, which misses a tennis swing entirely
        // (contact lasts a fraction of a second). Sampling ~5 fps lets the model
        // actually SEE prep→backswing→contact→follow-through. Costs more video
        // tokens (still Flash-priced, well under Pro) but it's the real grounding fix.
        { inline_data: { mime_type: mimeType, data: video }, video_metadata: { fps: 5 } },
        { text: `Coach my ${STROKES[stroke] ?? stroke} from this video. Base everything on what you actually see in the frames; if you can't see it clearly, say so — do not describe a generic version.` },
      ],
    }],
    // maxOutputTokens INCLUDES thinking tokens on 2.5 models — keep it well
    // above (thinking budget + the ~300-word answer) so the visible reply is
    // never truncated.
    generationConfig: { maxOutputTokens: 4096, temperature: 0.5 },
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
  let score: number | null = null;
  let analysis = text.trim();
  const firstLine = analysis.split("\n")[0] ?? "";
  const m = firstLine.match(/SCORE:\s*(\d{1,3})/i);
  if (m) {
    const n = parseInt(m[1], 10);
    if (n >= 0 && n <= 100) score = n;
    analysis = analysis.split("\n").slice(1).join("\n").trim();
  }

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
