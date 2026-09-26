// daily-one — the crowd split behind DropVolley's shared daily question.
//
// Everybody gets the same scenario each day. This counts what they chose and
// hands back the totals, so the app can say "61% of players chose the same as
// you" — and, below a threshold, say nothing at all.
//
// Body: { day: "YYYY-MM-DD", option?: 0..7 }
//   with `option`  — records the vote (once per voter per day) and returns totals
//   without it     — just returns totals, for a player reopening the screen
//
// Returns: { total: number, counts: number[] }  counts indexed by the option's
// index in the bundled question JSON, which is the only stable name an option
// has: the app permutes the display order by date.
//
// Auth: the anon key, like any public endpoint. There is no account here and
// nothing identifying is stored — see the migration.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// Salts the per-day voter hash. Without it the hash would be a plain digest of
// an IP — guessable by anyone with the address. Set it once and leave it.
const VOTER_SALT        = Deno.env.get("DAILY_ONE_VOTER_SALT") ?? "";

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

/** A day identifier, or null. Refuses anything that is not a plain ISO date. */
function cleanDay(raw: unknown): string | null {
  if (typeof raw !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  const parsed = new Date(`${raw}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) return null;
  // A vote for next week is either a broken clock or someone testing the
  // endpoint; either way it is not a day anybody is playing. One day of slack
  // covers a device sitting on the wrong side of midnight UTC.
  const now = Date.now();
  if (parsed.getTime() > now + 86_400_000) return null;
  if (parsed.getTime() < now - 400 * 86_400_000) return null;
  return raw;
}

function cleanOption(raw: unknown): number | null {
  if (typeof raw !== "number" || !Number.isInteger(raw)) return null;
  if (raw < 0 || raw > 7) return null;
  return raw;
}

/** sha256(salt + day + ip), hex. Scoped to the day so it cannot be joined
 *  across days into anything resembling a person. */
async function voterHash(day: string, ip: string): Promise<string> {
  const data = new TextEncoder().encode(`${VOTER_SALT}|${day}|${ip}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function clientIP(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const first = forwarded.split(",")[0]?.trim();
  return first || req.headers.get("cf-connecting-ip") || "unknown";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    // Misconfigured is not the player's problem: the app treats any failure
    // as "no split yet" and the question still works.
    return json({ error: "not_configured" }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const day = cleanDay(body.day);
  if (!day) return json({ error: "bad_day" }, 400);
  const option = "option" in body ? cleanOption(body.option) : null;
  if ("option" in body && option === null) return json({ error: "bad_option" }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const voter = option === null ? null : await voterHash(day, clientIP(req));

  const { data, error } = await admin.rpc("daily_one_cast", {
    p_day: day,
    p_option: option,
    p_voter: voter,
  });

  if (error) return json({ error: "unavailable" }, 503);

  // `opt` / `cnt` rather than `option` / `votes` — see the migration for why
  // the SQL function cannot name them after the columns.
  const rows = (data ?? []) as Array<{ opt: number; cnt: number }>;
  const width = Math.max(4, ...rows.map((r) => r.opt + 1));
  const counts = new Array<number>(width).fill(0);
  let total = 0;
  for (const row of rows) {
    counts[row.opt] = row.cnt;
    total += row.cnt;
  }

  return json({ total, counts });
});
