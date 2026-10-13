// clips — the signed-in half of "what do you see in this stroke?"
// (docs/CLIPS-SPEC.md §1, §2, §10)
//
// Auth: Bearer <Supabase JWT> (verify_jwt on). Every action is for the
// caller only; RLS does the reading, the service role does the writes that
// need a minted code or a shaped storage path.
//
// POST { action, ... }
//   create      { stroke, durationMs, rating? {system,value|band}, recipients? [uid] }
//               → { clipId, code, uploadUrl, posterUploadUrl, url }
//   finalize    { clipId }        bytes landed → AI view (capped) → recipients
//   playback    { clipId }        → { url } 10-minute signed URL (owner/recipient)
//   vote        { clipId, q1, q2?, q3Ms?, q4? }   one per user; coach if verified
//   tally       { clipId }        → clip_tally()
//   mine        { }               → my clips with tally sizes
//   inbox       { }               → clips sent to me I have not answered
//   friends     { }               → my friends
//   invite_code { }               → my code (minted on first ask)
//   redeem      { code }          the link I installed from → friendship
//   report      { clipId, reason }
//   delete      { clipId }
//   coach_apply { credentialType, credentialRef }  (document upload is a later step)

import { createClient } from "jsr:@supabase/supabase-js@2";
import { CLIP_QUESTIONS, cleanVote } from "../_shared/clipQuestions.ts";

const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY    = Deno.env.get("GEMINI_API_KEY") ?? "";
const AI_MODEL          = Deno.env.get("CLIP_AI_MODEL") ?? "gemini-2.5-flash";
const AI_DAILY_CAP      = Number(Deno.env.get("CLIP_AI_DAILY_CAP") ?? "5");
const CLIP_DAILY_CAP    = Number(Deno.env.get("CLIP_DAILY_CAP") ?? "10");
const BUCKET            = "clips";
const PLAYBACK_TTL      = 10 * 60;
const LINK_BASE         = "https://samosfi.com/k/";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789";
function code(n: number): string {
  const bytes = crypto.getRandomValues(new Uint8Array(n));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!SERVICE_ROLE_KEY) return json({ error: "not_configured" }, 503);

  const auth = req.headers.get("Authorization") ?? "";
  const user = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: auth } } });
  const { data: { user: me }, error: uerr } = await user.auth.getUser();
  if (uerr || !me) return json({ error: "unauthenticated" }, 401);
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "bad_json" }, 400); }
  const action = String(body.action ?? "");

  // ------------------------------------------------------------- create --
  if (action === "create") {
    const stroke = String(body.stroke ?? "");
    const durationMs = Number(body.durationMs);
    if (!CLIP_QUESTIONS.strokes.includes(stroke)) return json({ error: "bad_stroke" }, 400);
    if (!Number.isFinite(durationMs) || durationMs < 500 || durationMs > CLIP_QUESTIONS.maxClipMs + 2000) {
      return json({ error: "bad_duration" }, 400);
    }
    // Per-user daily cap, counted off the JWT (see 20261002000000).
    const { data: n } = await user.rpc("bump_feature_usage", { p_feature: "clip_upload" });
    if (typeof n === "number" && n > CLIP_DAILY_CAP) return json({ error: "daily_cap", cap: CLIP_DAILY_CAP }, 429);

    const id = crypto.randomUUID();
    const clipCode = code(10);
    const path = `${me.id}/${id}/clip.mp4`;
    const poster = `${me.id}/${id}/poster.jpg`;
    const { error: ins } = await admin.from("clips").insert({
      id, code: clipCode, owner: me.id, stroke, duration_ms: Math.round(durationMs),
      storage_path: path, poster_path: poster,
    });
    if (ins) return json({ error: "insert", detail: ins.message }, 500);

    // Declared rating — owner-only table, never returned to viewers.
    const rating = body.rating as { system?: string; value?: number; band?: string } | undefined;
    if (rating && typeof rating.system === "string" && CLIP_QUESTIONS.q4[rating.system]) {
      await admin.from("clip_private").insert({
        clip_id: id, rating_system: rating.system,
        rating_value: typeof rating.value === "number" ? rating.value : null,
        rating_band: typeof rating.band === "string" ? rating.band : null,
      });
    }

    const { data: up, error: upErr } = await admin.storage.from(BUCKET).createSignedUploadUrl(path);
    const { data: pup } = await admin.storage.from(BUCKET).createSignedUploadUrl(poster);
    if (upErr || !up) return json({ error: "upload_url" }, 500);
    return json({
      clipId: id, code: clipCode, url: LINK_BASE + clipCode,
      uploadUrl: up.signedUrl, posterUploadUrl: pup?.signedUrl ?? null,
    });
  }

  // ----------------------------------------------------------- finalize --
  if (action === "finalize") {
    const clipId = String(body.clipId ?? "");
    const { data: clip } = await admin.from("clips").select("id, owner, stroke, storage_path, duration_ms, uploaded_at").eq("id", clipId).maybeSingle();
    if (!clip || clip.owner !== me.id) return json({ error: "not_found" }, 404);

    // Did the bytes actually land? Trust the bucket, not the client.
    const dir = clip.storage_path.slice(0, clip.storage_path.lastIndexOf("/"));
    const { data: objs } = await admin.storage.from(BUCKET).list(dir);
    if (!objs?.some((o) => o.name === "clip.mp4")) return json({ error: "no_bytes" }, 409);
    if (!clip.uploaded_at) await admin.from("clips").update({ uploaded_at: new Date().toISOString() }).eq("id", clipId);

    // Recipients: everyone I am friends with, plus any explicit list.
    const { data: fr } = await user.rpc("my_friends");
    const explicit = Array.isArray(body.recipients) ? (body.recipients as unknown[]).filter((x) => typeof x === "string") as string[] : [];
    const ids = new Set<string>([...(fr ?? []).map((f: { friend: string }) => f.friend), ...explicit]);
    ids.delete(me.id);
    if (ids.size) {
      await admin.from("clip_recipients").upsert(
        Array.from(ids).map((uid) => ({ clip_id: clipId, user_id: uid })), { onConflict: "clip_id,user_id" });
    }

    // The AI view: fills the first day, labelled as a view, never a verdict.
    let aiNote = "no_key";
    if (GEMINI_API_KEY) {
      const { data: used, error: capErr } = await user.rpc("bump_feature_usage", { p_feature: "clip_ai" });
      if (capErr) aiNote = "cap_rpc:" + capErr.message.slice(0, 60);
      else if (typeof used === "number" && used > AI_DAILY_CAP) aiNote = "capped";
      else {
        const r = await aiView(admin, clip.storage_path, clip.stroke, clip.duration_ms);
        if (typeof r === "string") aiNote = r;
        else {
          const { error: vErr } = await admin.from("clip_votes").upsert({
            clip_id: clipId, rater: null, rater_kind: "ai", voter_hash: "ai",
            q1: r.q1, q2: r.q2, q3_ms: r.q3Ms, q4_guess: r.q4,
          }, { onConflict: "clip_id,voter_hash" });
          aiNote = vErr ? "vote_insert:" + vErr.message.slice(0, 60) : "ok";
        }
      }
    }
    await admin.from("clips").update({ ai_note: aiNote }).eq("id", clipId);
    return json({ ok: true, recipients: ids.size, ai: aiNote === "ok", aiNote });
  }

  // ----------------------------------------------------------- playback --
  if (action === "playback") {
    const clipId = String(body.clipId ?? "");
    // RLS answers "may I see this clip" — if the user client can read the row, yes.
    const { data: clip } = await user.from("clips").select("id, storage_path, poster_path, stroke, duration_ms, status").eq("id", clipId).maybeSingle();
    if (!clip || clip.status === "removed") return json({ error: "not_found" }, 404);
    const { data: s } = await admin.storage.from(BUCKET).createSignedUrl(clip.storage_path, PLAYBACK_TTL);
    const { data: p } = clip.poster_path ? await admin.storage.from(BUCKET).createSignedUrl(clip.poster_path, PLAYBACK_TTL) : { data: null };
    return json({ url: s?.signedUrl ?? null, poster: p?.signedUrl ?? null, stroke: clip.stroke, durationMs: clip.duration_ms });
  }

  // --------------------------------------------------------------- vote --
  if (action === "vote") {
    const clipId = String(body.clipId ?? "");
    const { data: clip } = await user.from("clips").select("id, owner, duration_ms, status").eq("id", clipId).maybeSingle();
    if (!clip || clip.status === "removed") return json({ error: "not_found" }, 404);
    if (clip.owner === me.id) return json({ error: "own_clip" }, 400);
    const v = cleanVote(body, clip.duration_ms);
    if (typeof v === "string") return json({ error: v }, 400);

    const { data: coach } = await admin.from("coach_review_coaches").select("verified_at, active").eq("user_id", me.id).maybeSingle();
    const kind = coach?.verified_at && coach.active ? "coach" : "player";
    const { error } = await admin.from("clip_votes").insert({
      clip_id: clipId, rater: me.id, rater_kind: kind, q1: v.q1, q2: v.q2, q3_ms: v.q3Ms, q4_guess: v.q4,
    });
    if (error) {
      if ((error as { code?: string }).code === "23505") return json({ error: "already_voted" }, 409);
      return json({ error: "insert" }, 500);
    }
    const { data: tally } = await user.rpc("clip_tally", { p_clip: clipId });
    return json({ ok: true, kind, tally });
  }

  // -------------------------------------------------------------- tally --
  if (action === "tally") {
    const { data: tally, error } = await user.rpc("clip_tally", { p_clip: String(body.clipId ?? "") });
    if (error) return json({ error: "not_allowed" }, 403);
    return json({ tally });
  }

  // --------------------------------------------------------------- mine --
  if (action === "mine") {
    const { data } = await user.from("clips").select("id, code, stroke, duration_ms, created_at, uploaded_at, status")
      .eq("owner", me.id).neq("status", "removed").order("created_at", { ascending: false }).limit(50);
    const out = [];
    for (const c of data ?? []) {
      const { count } = await admin.from("clip_votes").select("id", { count: "exact", head: true }).eq("clip_id", c.id).neq("rater_kind", "ai");
      out.push({ ...c, url: LINK_BASE + c.code, views: count ?? 0 });
    }
    return json({ clips: out });
  }

  // -------------------------------------------------------------- inbox --
  if (action === "inbox") {
    const { data: rec } = await user.from("clip_recipients").select("clip_id, sent_at").eq("user_id", me.id).order("sent_at", { ascending: false }).limit(50);
    const ids = (rec ?? []).map((r) => r.clip_id);
    if (!ids.length) return json({ clips: [] });
    const { data: voted } = await user.from("clip_votes").select("clip_id").eq("rater", me.id).in("clip_id", ids);
    const done = new Set((voted ?? []).map((v) => v.clip_id));
    const { data: clips } = await user.from("clips").select("id, owner, stroke, duration_ms, created_at, status").in("id", ids).neq("status", "removed");
    return json({ clips: (clips ?? []).map((c) => ({ ...c, answered: done.has(c.id) })) });
  }

  // ------------------------------------------------------------ friends --
  if (action === "friends") {
    const { data } = await user.rpc("my_friends");
    return json({ friends: data ?? [] });
  }

  // -------------------------------------------------------- invite_code --
  if (action === "invite_code") {
    const { data: row } = await admin.from("user_invite_codes").select("code").eq("user_id", me.id).maybeSingle();
    if (row) return json({ code: row.code, url: `https://samosfi.com/f/${row.code}` });
    const c = code(8);
    const { error } = await admin.from("user_invite_codes").insert({ user_id: me.id, code: c });
    if (error) return json({ error: "mint" }, 500);
    return json({ code: c, url: `https://samosfi.com/f/${c}` });
  }

  // ------------------------------------------------------------- redeem --
  // The code carried by the link I installed from (friend code or clip code).
  if (action === "redeem") {
    const c = String(body.code ?? "").toLowerCase();
    let other: string | null = null;
    const { data: inv } = await admin.from("user_invite_codes").select("user_id").eq("code", c).maybeSingle();
    if (inv) other = inv.user_id;
    if (!other) {
      const { data: clip } = await admin.from("clips").select("owner").eq("code", c).maybeSingle();
      if (clip) other = clip.owner;
    }
    if (!other || other === me.id) return json({ error: "no_match" }, 404);
    const [a, b] = other < me.id ? [other, me.id] : [me.id, other];
    await admin.from("friendships").upsert({ user_a: a, user_b: b, source: "link" }, { onConflict: "user_a,user_b" });
    // Opening a friend's clip link should also put that clip in my inbox.
    const { data: clip } = await admin.from("clips").select("id").eq("code", c).maybeSingle();
    if (clip) await admin.from("clip_recipients").upsert({ clip_id: clip.id, user_id: me.id }, { onConflict: "clip_id,user_id" });
    return json({ ok: true, friend: other, clipId: clip?.id ?? null });
  }

  // ------------------------------------------------------------- report --
  if (action === "report") {
    const clipId = String(body.clipId ?? ""); const reason = String(body.reason ?? "").slice(0, 300);
    if (!reason) return json({ error: "reason" }, 400);
    const { error } = await user.from("clip_reports").insert({ clip_id: clipId, reporter: me.id, reason });
    if (error) return json({ error: "not_allowed" }, 403);
    // Hide on report; a human decides within 24 h (Apple 1.2).
    await admin.from("clips").update({ status: "reported" }).eq("id", clipId).eq("status", "active");
    return json({ ok: true });
  }

  // ------------------------------------------------------------- delete --
  if (action === "delete") {
    const clipId = String(body.clipId ?? "");
    const { data: clip } = await admin.from("clips").select("owner, storage_path, poster_path").eq("id", clipId).maybeSingle();
    if (!clip || clip.owner !== me.id) return json({ error: "not_found" }, 404);
    await admin.storage.from(BUCKET).remove([clip.storage_path, clip.poster_path].filter(Boolean) as string[]);
    await admin.from("clips").delete().eq("id", clipId);
    return json({ ok: true });
  }

  // -------------------------------------------------------- coach_apply --
  if (action === "coach_apply") {
    const t = String(body.credentialType ?? "").slice(0, 40); const r = String(body.credentialRef ?? "").slice(0, 120);
    if (!t) return json({ error: "credential_type" }, 400);
    await admin.from("coach_review_coaches").upsert({
      user_id: me.id, display_tier: "applicant", active: true,
      credential_type: t, credential_ref: r || null, applied_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    return json({ ok: true, verified: false });
  }

  return json({ error: "unknown_action" }, 400);
});

/**
 * A fourth view of the clip, from a vision model, with the same four answers a
 * person gives. Labelled "ai" in the tally; the app never calls it a verdict.
 * The team's own research (docs/SWING-ANALYSIS-RESEARCH.md) found these models
 * motion-blind, so the prompt invites "unclear" and the output is one view
 * among several — its only job is that a first user with no friends still has
 * something to look at.
 */
async function aiView(admin: ReturnType<typeof createClient>, path: string, stroke: string, durationMs: number):
  Promise<{ q1: string; q2: string | null; q3Ms: number | null; q4: number | null } | string> {
  try {
    const { data: file, error: dlErr } = await admin.storage.from(BUCKET).download(path);
    if (dlErr || !file) return "download:" + (dlErr?.message ?? "empty").slice(0, 60);
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length > 12 * 1024 * 1024) return "too_large";
    let bin = ""; for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    const b64 = btoa(bin);

    const q2 = CLIP_QUESTIONS.q2;
    const prompt =
      `You are one of several viewers of a ${durationMs} ms amateur tennis ${stroke} clip. ` +
      `Answer ONLY with JSON: {"q1": one of ["footwork","technique","decision","unclear"], ` +
      `"q2": one id from the matching list or null, "q3Ms": integer millisecond offset of the moment that best shows it or null, ` +
      `"q4": a World Tennis Number estimate 1-40 (lower is better) or null}. ` +
      `Lists: footwork ${JSON.stringify(q2.footwork)}, technique ${JSON.stringify(q2.technique)}, decision ${JSON.stringify(q2.decision)}. ` +
      `If the angle or quality does not let you judge, answer "unclear" with nulls. Do not guess to be helpful.`;

    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL}:generateContent?key=${GEMINI_API_KEY}`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ inline_data: { mime_type: "video/mp4", data: b64 } }, { text: prompt }] }],
        // maxOutputTokens INCLUDES thinking tokens on gemini-2.5 models (see
        // match-analysis): 256 was eaten entirely by thinking and the visible
        // text came back empty — "Unexpected end of JSON input" on the first
        // live clip. No thinking needed for a four-field pick.
        generationConfig: {
          responseMimeType: "application/json", temperature: 0.2, maxOutputTokens: 2048,
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    });
    if (!res.ok) return "gemini_" + res.status + ":" + (await res.text()).slice(0, 80).replace(/\s+/g, " ");
    const out = await res.json();
    const parts = out?.candidates?.[0]?.content?.parts ?? [];
    const text = parts.map((p: { text?: string }) => p.text ?? "").join("").trim()
      .replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "");
    // An empty answer is the model declining; say so instead of throwing.
    if (!text) return "empty:" + String(out?.candidates?.[0]?.finishReason ?? "none");
    const parsed = JSON.parse(text);
    const v = cleanVote({ q1: parsed.q1, q2: parsed.q2, q3Ms: parsed.q3Ms, q4: parsed.q4 }, durationMs);
    // A shape the bank rejects is the model refusing to pick: record it as "unclear".
    return typeof v === "string" ? { q1: "unclear", q2: null, q3Ms: null, q4: null } : v;
  } catch (e) {
    return "exception:" + String((e as Error)?.message ?? e).slice(0, 60);
  }
}
