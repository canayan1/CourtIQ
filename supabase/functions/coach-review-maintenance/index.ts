// coach-review-maintenance — the daily job (pg_cron → pg_net → here).
//
//   POST { action: "daily" }   header x-maintenance-secret
//     → { purged, open, atRisk: [...], overdue: [...] }
//
// Two duties, both promises made elsewhere:
//  • purge raw clips 90 days after creation (consent screen, policy §5);
//  • surface orders inside 24 h of the SLA or past it, so a missed promise
//    is at least visible. The panel shows the same list; this exists for
//    the day nobody opens the panel.
//
// Deployed with --no-verify-jwt; the shared secret is the whole gate, and
// the only caller is the cron job reading it from Vault.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { purgeOverdueClips } from "../_shared/coachReviewPurge.ts";

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SECRET           = Deno.env.get("COACH_MAINTENANCE_SECRET") ?? "";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json" },
  });
}

function secretMatches(given: string): boolean {
  if (!SECRET || given.length !== SECRET.length) return false;
  let diff = 0;
  for (let i = 0; i < given.length; i++) diff |= given.charCodeAt(i) ^ SECRET.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!SERVICE_ROLE_KEY || !SECRET) return json({ error: "Not configured." }, 503);
  if (!secretMatches(req.headers.get("x-maintenance-secret") ?? "")) return json({ error: "Not authorised." }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const purged = await purgeOverdueClips(admin, 200);

  const { data: open } = await admin
    .from("coach_review_orders")
    .select("id, status, sla_due_at, created_at, review_language")
    .in("status", ["submitted", "in_review"])
    .order("sla_due_at", { ascending: true });

  const now = Date.now();
  const rows = (open ?? []).map((o) => ({
    id: o.id, status: o.status, language: o.review_language,
    hoursLeft: Math.round((new Date(o.sla_due_at).getTime() - now) / 3600_000),
  }));
  return json({
    purged,
    open: rows.length,
    atRisk: rows.filter((r) => r.hoursLeft >= 0 && r.hoursLeft < 24),
    overdue: rows.filter((r) => r.hoursLeft < 0),
  });
});
