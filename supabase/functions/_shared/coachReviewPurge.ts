// Deletes raw clips whose retention window has passed. Called by the daily
// maintenance job AND opportunistically by the order/queue functions, so the
// consent screen's "auto-deletes 90 days after delivery" holds even if the
// cron ever stops firing.
//
// Deliverables (voice note, notes, scorecard) are NOT touched: policy §5
// keeps them in the player's account until they delete it.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const BUCKET = "coach-reviews";

export async function purgeOverdueClips(admin: SupabaseClient, limit = 50): Promise<number> {
  const { data, error } = await admin
    .from("coach_review_orders")
    .select("id, video_path")
    .lt("purge_video_at", new Date().toISOString())
    .is("video_purged_at", null)
    .not("video_path", "is", null)
    .limit(limit);
  if (error || !data?.length) return 0;

  let purged = 0;
  for (const row of data) {
    const { error: rmErr } = await admin.storage.from(BUCKET).remove([row.video_path]);
    // A missing object is still "purged" — the goal is that it does not exist.
    if (rmErr && !/not found/i.test(rmErr.message ?? "")) continue;
    const { error: upErr } = await admin
      .from("coach_review_orders")
      .update({ video_purged_at: new Date().toISOString() })
      .eq("id", row.id);
    if (upErr) continue;
    await admin.from("coach_review_access_log").insert({ order_id: row.id, action: "purge" });
    purged++;
  }
  return purged;
}
