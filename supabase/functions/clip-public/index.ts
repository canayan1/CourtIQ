// clip-public — the browser half of the loop (docs/CLIPS-SPEC.md §10).
//
// Someone taps a friend's link. No account, no install. They watch the clip,
// answer the four questions, and see their view next to everyone else's.
// Only then are they offered the app. This is the step that gives value
// before asking for anything, and it is the step that decides whether the
// loop closes.
//
// Deployed with --no-verify-jwt. Gated by the clip code (10 chars, 31^10
// space) and a salted IP-day hash for one answer per person per clip — the
// Daily One pattern. Web answers are a separate tally (`web`) and never mix
// into coach/player views.
//
// POST { action: "view", code }                     → clip + questions + tallies
// POST { action: "answer", code, q1, q2?, q3Ms?, q4? } → { yours, tally }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { CLIP_QUESTIONS, cleanVote } from "../_shared/clipQuestions.ts";

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SALT             = Deno.env.get("DAILY_ONE_VOTER_SALT") ?? "";
const BUCKET           = "clips";
const PLAYBACK_TTL     = 10 * 60;
const WEB_DAILY_CAP_PER_CLIP = 500;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

async function voterHash(code: string, ip: string): Promise<string> {
  const day = new Date().toISOString().slice(0, 10);
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${SALT}|${day}|${code}|${ip}`));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
const clientIP = (req: Request) =>
  (req.headers.get("x-forwarded-for") ?? "").split(",")[0]?.trim() || req.headers.get("cf-connecting-ip") || "unknown";

/** Aggregates per kind, with the same thresholds as clip_tally(). The owner's
 *  declared rating is never included here — this endpoint has no owner. */
async function tallies(admin: ReturnType<typeof createClient>, clipId: string) {
  const { data: votes } = await admin.from("clip_votes").select("rater_kind, q1, q2, q3_ms, q4_guess").eq("clip_id", clipId);
  const out: Record<string, unknown> = {};
  for (const kind of ["coach", "player", "web", "ai"]) {
    const vs = (votes ?? []).filter((v) => v.rater_kind === kind);
    const n = vs.length;
    const shown = n > 0 && !((kind === "player" || kind === "web") && n < CLIP_QUESTIONS.minVotesForCrowd);
    if (!shown) { out[kind] = { n, shown: false }; continue; }
    const count = (f: (v: typeof vs[number]) => string | null) => {
      const m: Record<string, number> = {};
      for (const v of vs) { const k = f(v); if (k) m[k] = (m[k] ?? 0) + 1; }
      return m;
    };
    const q3 = vs.map((v) => v.q3_ms).filter((x): x is number => typeof x === "number").sort((a, b) => a - b);
    const q4 = vs.map((v) => v.q4_guess).filter((x): x is number => typeof x === "number");
    out[kind] = {
      n, shown: true,
      q1: count((v) => v.q1), q2: count((v) => v.q2),
      q3_median_ms: q3.length ? q3[Math.floor(q3.length / 2)] : null,
      q4_mean: q4.length ? Math.round((q4.reduce((a, b) => a + b, 0) / q4.length) * 100) / 100 : null,
      q4_n: q4.length,
    };
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!SERVICE_ROLE_KEY) return json({ error: "not_configured" }, 503);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "bad_json" }, 400); }
  const code = String(body.code ?? "").toLowerCase();
  if (!/^[a-z0-9]{10}$/.test(code)) return json({ error: "bad_code" }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: clip } = await admin.from("clips")
    .select("id, code, owner, stroke, duration_ms, storage_path, poster_path, status, uploaded_at, purged_at")
    .eq("code", code).maybeSingle();
  if (!clip || clip.status !== "active" || !clip.uploaded_at || clip.purged_at) return json({ error: "not_found" }, 404);

  const hash = await voterHash(code, clientIP(req));
  const { data: mine } = await admin.from("clip_votes").select("q1, q2, q3_ms, q4_guess").eq("clip_id", clip.id).eq("voter_hash", hash).maybeSingle();

  if (body.action === "view") {
    const { data: s } = await admin.storage.from(BUCKET).createSignedUrl(clip.storage_path, PLAYBACK_TTL);
    const { data: p } = clip.poster_path ? await admin.storage.from(BUCKET).createSignedUrl(clip.poster_path, PLAYBACK_TTL) : { data: null };
    return json({
      stroke: clip.stroke, durationMs: clip.duration_ms,
      url: s?.signedUrl ?? null, poster: p?.signedUrl ?? null,
      questions: CLIP_QUESTIONS,
      // Hidden-vote rule: the crowd is shown only to someone who has answered.
      yours: mine ? { q1: mine.q1, q2: mine.q2, q3Ms: mine.q3_ms, q4: mine.q4_guess } : null,
      tally: mine ? await tallies(admin, clip.id) : null,
      ownerCode: code,   // the link to redeem after install → friendship
    });
  }

  if (body.action === "answer") {
    if (mine) return json({ error: "already_answered", yours: mine, tally: await tallies(admin, clip.id) }, 409);
    const v = cleanVote(body, clip.duration_ms);
    if (typeof v === "string") return json({ error: v }, 400);
    const { count } = await admin.from("clip_votes").select("id", { count: "exact", head: true })
      .eq("clip_id", clip.id).eq("rater_kind", "web").gte("answered_at", new Date(Date.now() - 86_400_000).toISOString());
    if ((count ?? 0) >= WEB_DAILY_CAP_PER_CLIP) return json({ error: "busy" }, 429);
    const { error } = await admin.from("clip_votes").insert({
      clip_id: clip.id, rater: null, rater_kind: "web", voter_hash: hash,
      q1: v.q1, q2: v.q2, q3_ms: v.q3Ms, q4_guess: v.q4,
    });
    if (error) return json({ error: "insert" }, 500);
    return json({ ok: true, yours: v, tally: await tallies(admin, clip.id) });
  }

  return json({ error: "unknown_action" }, 400);
});
