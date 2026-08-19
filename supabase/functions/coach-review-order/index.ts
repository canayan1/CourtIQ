// coach-review-order — create a paid human-review order (docs/COACH-REVIEW-PLAN.md P0).
//
// The user has already completed a consumable IAP in the app. This function
// stores their clip in the PRIVATE `coach-reviews` bucket and inserts the
// order row (service role — a client can never fabricate an order).
//
// Body: { videoBase64, stroke, handedness?, note?, transactionId?, mimeType? }
// Auth: Bearer <Supabase JWT>
// Returns: { orderId, slaDueAt }
//
// Honesty/privacy invariants (docs/COACH-REVIEW-POLICY.md):
//  • video lands under <uid>/<orderId>/clip.mp4 — RLS lets ONLY that user read it
//  • coaches stream via short-lived signed URLs minted server-side, never a
//    permanent link, and never a download
//  • purge_video_at is stamped at +90 days from creation (retention §5)

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL       = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY  = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BUCKET             = "coach-reviews";
const MAX_BASE64         = 26 * 1024 * 1024;   // ~19 MB of video
const SLA_HOURS          = 72;
const RETENTION_DAYS     = 90;

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
    videoBase64?: string; stroke?: string; handedness?: string;
    note?: string; transactionId?: string; mimeType?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const videoBase64 = (body.videoBase64 ?? "").trim();
  const stroke = (body.stroke ?? "").trim();
  if (!videoBase64) return json({ error: "No video provided." }, 400);
  if (!stroke) return json({ error: "No stroke selected." }, 400);
  if (videoBase64.length > MAX_BASE64) return json({ error: "Video is too large." }, 413);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 1. Reserve the order id so the storage path can carry it.
  const orderId = crypto.randomUUID();
  const path = `${user.id}/${orderId}/clip.mp4`;

  // 2. Store the clip privately.
  const bytes = decodeBase64(videoBase64);
  const { error: upErr } = await admin.storage.from(BUCKET).upload(path, bytes, {
    contentType: body.mimeType ?? "video/mp4",
    upsert: false,
  });
  if (upErr) return json({ error: "Could not store the video." }, 500);

  // 3. Insert the order.
  const now = Date.now();
  const slaDueAt = new Date(now + SLA_HOURS * 3600_000).toISOString();
  const purgeAt  = new Date(now + RETENTION_DAYS * 86_400_000).toISOString();
  const { error: insErr } = await admin.from("coach_review_orders").insert({
    id: orderId,
    user_id: user.id,
    status: "submitted",
    stroke,
    handedness: body.handedness ?? null,
    note: (body.note ?? "").slice(0, 500) || null,
    video_path: path,
    iap_txn_id: body.transactionId ?? null,
    sla_due_at: slaDueAt,
    purge_video_at: purgeAt,
  });
  if (insErr) {
    // Roll the object back so a failed insert never orphans a video.
    await admin.storage.from(BUCKET).remove([path]);
    return json({ error: "Could not create the order." }, 500);
  }

  return json({ orderId, slaDueAt });
});
