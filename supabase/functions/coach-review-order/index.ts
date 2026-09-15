// coach-review-order — create a paid human-review order (docs/COACH-REVIEW-ACTIVATION.md).
//
// The user has completed a consumable IAP in the app. This function
//   1. verifies that purchase with Apple's signature chain (never the
//      client's word for it),
//   2. returns the EXISTING order if this transaction already has one — the
//      app retries the same transaction after a crash, and a retry must
//      never double-order or double-upload,
//   3. refuses when the coach's open-order cap is reached (409), so demand
//      cannot turn into missed 72-hour promises,
//   4. stores the clip in the PRIVATE `coach-reviews` bucket and inserts the
//      order row (service role — a client can never fabricate an order).
//
// Body: { videoBase64, stroke, handedness?, note?, reviewLanguage?,
//         transactionId, transactionJws, mimeType? }
//   or, to replace the clip on an order the coach sent back (no new purchase):
//       { reuploadOrderId, videoBase64, mimeType? }
// Auth: Bearer <Supabase JWT>
// Returns: { orderId, slaDueAt }              200
//          { error: "capacity" }              409  (nothing consumed; app retries later)
//          { error: "purchase", reason }      402  (app keeps the transaction unfinished)
//
// Honesty/privacy invariants (docs/COACH-REVIEW-POLICY.md):
//  • video lands under <uid>/<orderId>/clip.mp4 — RLS lets ONLY that user read it
//  • coaches stream via short-lived signed URLs minted server-side, never a
//    permanent link, and never a download
//  • purge_video_at is stamped at +90 days (retention §5) and the purge is
//    run opportunistically here as well as by the daily job

import { createClient } from "jsr:@supabase/supabase-js@2";
import { purgeOverdueClips } from "../_shared/coachReviewPurge.ts";
import { verifyCoachReviewPurchase } from "../_shared/appleTransaction.ts";

const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PRODUCT_ID        = Deno.env.get("COACH_REVIEW_PRODUCT_ID") ?? "com.canayan93.courtiq.coachreview1";
const MAX_OPEN          = Number(Deno.env.get("COACH_REVIEW_MAX_OPEN") ?? "5");
const ALLOW_SANDBOX     = Deno.env.get("COACH_REVIEW_ALLOW_SANDBOX") === "1";
const BUCKET            = "coach-reviews";
const MAX_BASE64        = 26 * 1024 * 1024;   // ~19 MB of video
const SLA_HOURS         = 72;
const RETENTION_DAYS    = 90;
const LANGUAGES         = new Set(["en", "tr", "fr"]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function decodeBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders, status: 204 });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!SERVICE_ROLE_KEY) return json({ error: "Coach review is not configured." }, 503);

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return json({ error: "Not authenticated." }, 401);

  let body: {
    videoBase64?: string; stroke?: string; handedness?: string; note?: string;
    reviewLanguage?: string; transactionId?: string; transactionJws?: string; mimeType?: string;
    reuploadOrderId?: string;
    preflight?: boolean;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  // ---- Pre-flight: is a slot free? Asked BEFORE the App Store sheet opens,
  // so "all slots are taken" is told to the player before any charge, not
  // after. The post-purchase 409 below is then only a race between two
  // buyers, and the app treats it as a held credit, not a refusal.
  if (body.preflight) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { count: open } = await admin
      .from("coach_review_orders")
      .select("id", { count: "exact", head: true })
      .in("status", ["submitted", "in_review"]);
    return json({ accepting: (open ?? 0) < MAX_OPEN, open: open ?? 0, max: MAX_OPEN });
  }

  const videoBase64   = (body.videoBase64 ?? "").trim();
  if (!videoBase64)    return json({ error: "No video provided." }, 400);
  if (videoBase64.length > MAX_BASE64) return json({ error: "Video is too large." }, 413);

  // ---- Re-upload: the order is already paid; only ownership and state matter.
  const reuploadOrderId = (body.reuploadOrderId ?? "").trim();
  if (reuploadOrderId) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: order } = await admin
      .from("coach_review_orders")
      .select("id, user_id, status, video_path, reupload_count")
      .eq("id", reuploadOrderId)
      .maybeSingle();
    if (!order || order.user_id !== user.id) return json({ error: "Order not found." }, 404);
    if (order.status !== "needs_reupload") return json({ error: "Order is not waiting for a clip." }, 409);

    const { error: upErr } = await admin.storage.from(BUCKET).upload(order.video_path, decodeBase64(videoBase64), {
      contentType: body.mimeType ?? "video/mp4",
      upsert: true,
    });
    if (upErr) return json({ error: "Could not store the video." }, 500);

    const now = Date.now();
    const slaDueAt = new Date(now + SLA_HOURS * 3600_000).toISOString();
    const purgeAt  = new Date(now + RETENTION_DAYS * 86_400_000).toISOString();
    const { error: updErr } = await admin.from("coach_review_orders").update({
      status: "submitted",
      coach_message: null,
      reupload_count: (order.reupload_count ?? 0) + 1,
      sla_due_at: slaDueAt,          // the clock restarts: the coach could not work before
      purge_video_at: purgeAt,
      video_purged_at: null,
    }).eq("id", order.id);
    if (updErr) return json({ error: "Could not update the order." }, 500);
    await admin.from("coach_review_access_log").insert({ order_id: order.id, action: "reupload" });
    await notifyCoach(`Clip re-sent on order ${order.id.slice(0, 8)}`, `The player sent a new clip. SLA restarted: ${slaDueAt}`);
    return json({ orderId: order.id, slaDueAt });
  }

  const stroke        = (body.stroke ?? "").trim();
  const transactionId = (body.transactionId ?? "").trim();
  const transactionJws = (body.transactionJws ?? "").trim();
  if (!stroke)         return json({ error: "No stroke selected." }, 400);
  if (!transactionId || !transactionJws) return json({ error: "purchase", reason: "missing" }, 402);

  // 1. The purchase, verified against Apple's certificate chain.
  const verified = await verifyCoachReviewPurchase(transactionJws, PRODUCT_ID, ALLOW_SANDBOX);
  if ("error" in verified) return json({ error: "purchase", reason: verified.error }, 402);
  if (verified.transactionId !== transactionId) return json({ error: "purchase", reason: "id-mismatch" }, 402);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 2. Idempotent retry: this transaction may already have its order.
  const { data: existing } = await admin
    .from("coach_review_orders")
    .select("id, user_id, sla_due_at")
    .eq("iap_txn_id", verified.transactionId)
    .maybeSingle();
  if (existing) {
    if (existing.user_id !== user.id) return json({ error: "purchase", reason: "owner" }, 402);
    return json({ orderId: existing.id, slaDueAt: existing.sla_due_at });
  }

  // 3. Capacity: one coach, a 72-hour clock, no assignment yet.
  const { count: open } = await admin
    .from("coach_review_orders")
    .select("id", { count: "exact", head: true })
    .in("status", ["submitted", "in_review"]);
  if ((open ?? 0) >= MAX_OPEN) return json({ error: "capacity" }, 409);

  // 4. Store the clip privately, then the order.
  const orderId = crypto.randomUUID();
  const path = `${user.id}/${orderId}/clip.mp4`;
  const bytes = decodeBase64(videoBase64);
  const { error: upErr } = await admin.storage.from(BUCKET).upload(path, bytes, {
    contentType: body.mimeType ?? "video/mp4",
    upsert: false,
  });
  if (upErr) return json({ error: "Could not store the video." }, 500);

  const now = Date.now();
  const slaDueAt = new Date(now + SLA_HOURS * 3600_000).toISOString();
  const purgeAt  = new Date(now + RETENTION_DAYS * 86_400_000).toISOString();
  const language = LANGUAGES.has(body.reviewLanguage ?? "") ? body.reviewLanguage! : "en";
  const { error: insErr } = await admin.from("coach_review_orders").insert({
    id: orderId,
    user_id: user.id,
    status: "submitted",
    stroke,
    handedness: body.handedness ?? null,
    note: (body.note ?? "").slice(0, 500) || null,
    review_language: language,
    video_path: path,
    iap_txn_id: verified.transactionId,
    iap_environment: verified.environment,
    sla_due_at: slaDueAt,
    purge_video_at: purgeAt,
  });
  if (insErr) {
    // Roll the object back so a failed insert never orphans a video.
    await admin.storage.from(BUCKET).remove([path]);
    // A concurrent retry won the unique index: hand back its order.
    if ((insErr as { code?: string }).code === "23505") {
      const { data: winner } = await admin
        .from("coach_review_orders").select("id, sla_due_at")
        .eq("iap_txn_id", verified.transactionId).maybeSingle();
      if (winner) return json({ orderId: winner.id, slaDueAt: winner.sla_due_at });
    }
    return json({ error: "Could not create the order." }, 500);
  }

  // 5. Keep the retention promise even if the daily job is asleep.
  try { await purgeOverdueClips(admin, 10); } catch { /* best effort */ }

  await notifyCoach(`New coach review: ${stroke}`,
    `Order ${orderId.slice(0, 8)} · ${stroke} · ${body.handedness ?? "—"} · player reads ${language.toUpperCase()}\n` +
    `Due ${slaDueAt}\n${(body.note ?? "").slice(0, 200) || "(no note)"}\n\nhttps://samosfi.com/coach`);

  return json({ orderId, slaDueAt });
});

/**
 * Tells the coach an order landed. Optional: does nothing until RESEND_API_KEY
 * and COACH_NOTIFY_EMAIL are set. Failure never fails the order — the panel
 * queue is the source of truth, this is only the doorbell.
 */
async function notifyCoach(subject: string, text: string): Promise<void> {
  const key = Deno.env.get("RESEND_API_KEY");
  const to = Deno.env.get("COACH_NOTIFY_EMAIL");
  const from = Deno.env.get("COACH_NOTIFY_FROM") ?? "DropVolley <onboarding@resend.dev>";
  if (!key || !to) return;
  try {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to, subject, text }),
    });
  } catch { /* doorbell only */ }
}
