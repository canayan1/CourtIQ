// coach-review-queue — the COACH side of the P0 pipeline.
//
// One function, three actions, all gated by a shared COACH_PANEL_SECRET (the
// owner is coach #1; a real per-coach auth layer lands at P2 with the
// marketplace). Never exposed to the app client.
//
//   POST { action: "list" }
//     → { orders: [{ id, stroke, handedness, note, createdAt, slaDueAt, status, videoUrl }] }
//       videoUrl is a SHORT-LIVED signed URL (2h) — stream only, never a
//       permanent link (docs/COACH-REVIEW-POLICY.md §4).
//
//   POST { action: "claim", orderId }
//     → flips submitted → in_review
//
//   POST { action: "deliver", orderId, deliverable: {...}, voiceBase64? }
//     → stores the voice note, inserts the deliverable, flips → delivered
//
// The deliverable shape is the "One Thing" format (TEMPLATE §6): a scorecard,
// ONE fix (sentence + timestamp + cue), 3 micro-notes, 1 drill, 2-3 min voice.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PANEL_SECRET     = Deno.env.get("COACH_PANEL_SECRET") ?? "";
const BUCKET           = "coach-reviews";
const SIGNED_URL_TTL   = 2 * 60 * 60;          // 2 hours
const MAX_VOICE_BASE64 = 12 * 1024 * 1024;     // ~9 MB of m4a

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-coach-secret",
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

/** Constant-time-ish comparison so the secret can't be probed by timing. */
function secretMatches(given: string): boolean {
  if (!PANEL_SECRET || given.length !== PANEL_SECRET.length) return false;
  let diff = 0;
  for (let i = 0; i < given.length; i++) diff |= given.charCodeAt(i) ^ PANEL_SECRET.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders, status: 204 });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!SERVICE_ROLE_KEY || !PANEL_SECRET) return json({ error: "Coach panel is not configured." }, 503);

  if (!secretMatches(req.headers.get("x-coach-secret") ?? "")) {
    return json({ error: "Not authorised." }, 401);
  }

  let body: {
    action?: string; orderId?: string; voiceBase64?: string;
    deliverable?: {
      scorecard?: Record<string, number | null>;
      oneThing?: string; oneThingAt?: number; oneThingCue?: string;
      microNotes?: Array<{ at: number; kind: string; text: string }>;
      drillTitle?: string; drillBody?: string;
    };
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const action = body.action ?? "list";

  // ------------------------------------------------------------------ list --
  if (action === "list") {
    const { data, error } = await admin
      .from("coach_review_orders")
      .select("id, stroke, handedness, note, created_at, sla_due_at, status, video_path")
      .in("status", ["submitted", "in_review"])
      .order("sla_due_at", { ascending: true })
      .limit(50);
    if (error) return json({ error: "Could not read the queue." }, 500);

    const orders = await Promise.all((data ?? []).map(async (o) => {
      const { data: signed } = await admin.storage
        .from(BUCKET)
        .createSignedUrl(o.video_path, SIGNED_URL_TTL);
      return {
        id: o.id,
        stroke: o.stroke,
        handedness: o.handedness,
        note: o.note,
        createdAt: o.created_at,
        slaDueAt: o.sla_due_at,
        status: o.status,
        videoUrl: signed?.signedUrl ?? null,
      };
    }));
    return json({ orders });
  }

  const orderId = (body.orderId ?? "").trim();
  if (!orderId) return json({ error: "No order id." }, 400);

  // ----------------------------------------------------------------- claim --
  if (action === "claim") {
    const { error } = await admin
      .from("coach_review_orders")
      .update({ status: "in_review" })
      .eq("id", orderId)
      .eq("status", "submitted");
    if (error) return json({ error: "Could not claim the order." }, 500);
    return json({ ok: true });
  }

  // --------------------------------------------------------------- deliver --
  if (action === "deliver") {
    const d = body.deliverable ?? {};
    const oneThing = (d.oneThing ?? "").trim();
    if (!oneThing) return json({ error: "The One Thing is required." }, 400);

    let voicePath: string | null = null;
    if (body.voiceBase64) {
      if (body.voiceBase64.length > MAX_VOICE_BASE64) {
        return json({ error: "Voice note is too large." }, 413);
      }
      const { data: order } = await admin
        .from("coach_review_orders").select("user_id").eq("id", orderId).single();
      if (!order) return json({ error: "Order not found." }, 404);
      voicePath = `${order.user_id}/${orderId}/voice.m4a`;
      const { error: upErr } = await admin.storage
        .from(BUCKET)
        .upload(voicePath, decodeBase64(body.voiceBase64), {
          contentType: "audio/m4a", upsert: true,
        });
      if (upErr) return json({ error: "Could not store the voice note." }, 500);
    }

    const { error: insErr } = await admin.from("coach_review_deliverables").upsert({
      order_id: orderId,
      scorecard: d.scorecard ?? {},
      one_thing: oneThing,
      one_thing_at: d.oneThingAt ?? null,
      one_thing_cue: d.oneThingCue ?? null,
      micro_notes: d.microNotes ?? [],
      drill_title: d.drillTitle ?? null,
      drill_body: d.drillBody ?? null,
      voice_path: voicePath,
    }, { onConflict: "order_id" });
    if (insErr) return json({ error: "Could not save the review." }, 500);

    const { error: updErr } = await admin
      .from("coach_review_orders")
      .update({ status: "delivered", delivered_at: new Date().toISOString() })
      .eq("id", orderId);
    if (updErr) return json({ error: "Could not mark it delivered." }, 500);

    return json({ ok: true });
  }

  return json({ error: "Unknown action." }, 400);
});
