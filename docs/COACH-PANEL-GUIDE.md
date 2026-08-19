# Coach panel — how to run a review (owner guide)

*Live since 19 Aug 2026. Everything below is deployed and smoke-tested.*

## Where things are

| Thing | Link |
|---|---|
| **The panel you work in** | https://samosfi.com/coach |
| Panel password | `~/.appstore-keys/coach_panel_password.txt` (local file, never in git) |
| Supabase functions dashboard | https://supabase.com/dashboard/project/ybnodzzrkwennzpwyjmr/functions |
| Function logs (debug a failed order) | https://supabase.com/dashboard/project/ybnodzzrkwennzpwyjmr/logs/edge-functions |
| Orders table | https://supabase.com/dashboard/project/ybnodzzrkwennzpwyjmr/editor → `coach_review_orders` |
| Videos (private bucket) | https://supabase.com/dashboard/project/ybnodzzrkwennzpwyjmr/storage/buckets/coach-reviews |
| Vercel deployment | https://vercel.com/canayan1s-projects/canayan-ios-apps |

## The loop, end to end

1. **Player buys** — swing result screen → "Get a real coach review" → consent
   (a real coach may watch this + 18+) → StoreKit `$19.99` → clip uploads.
2. **Order lands** — row in `coach_review_orders` (status `submitted`), clip in
   the private bucket, 72-hour SLA clock starts.
3. **You review** — open the panel on your phone, tap the order, do the work
   (below), hit **Deliver review**.
4. **Player sees it** — status flips to `delivered`; the app pulls the report
   and shows the One Thing screen with your voice note.

## Doing one review (12–15 min)

Open https://samosfi.com/coach → password → tap the order at the top (the
queue is sorted by SLA, and anything under 12h left turns clay-red).

1. **Watch the clip once.** It streams from a 2-hour signed link — it can't be
   downloaded from the panel, by design.
2. **Scorecard** — 5 checkpoints, 1–5. If the camera angle genuinely doesn't
   let you judge one, press **—**. An honest gap beats a polite guess; the app
   renders it as "—" too.
3. **The One Thing** — one sentence, the single highest-leverage fix. Pause the
   video at the moment that proves it and press **Stamp time**, then add a
   **cue word** the player can say to themselves on court.
4. **Moments** (max 3) — press **+ Strength** or **+ Fault** at the right
   moment, then type ≤10 words. These timestamps are the proof you watched.
5. **Drill** — name it, two lines, include a rep count.
6. **Voice review** — press **● Record**, speak 2–3 minutes covering only the
   items above, warmly and by name. Press **■ Stop**. (Safari will ask for mic
   permission the first time.)
7. **Deliver review.**

Total written words should stay under ~100. If it doesn't fit, the review isn't
finished being prioritised — see `COACH-REVIEW-TEMPLATE.md` §6 and the worked
example in §4.

## Rules that keep this honest

- Only claim what's visible in the clip; every claim gets a timestamp.
- Never diagnose injuries or give medical advice. Refer out.
- Never post or share a player's clip. Marketing use requires their separate
  per-video opt-in (`COACH-REVIEW-POLICY.md` §1).
- Raw videos auto-expire 90 days after delivery; deliverables stay in the
  player's account.

## If something breaks

| Symptom | Where to look |
|---|---|
| Panel says "Not authorised." | wrong password — re-copy from the local file |
| Queue empty but a player says they paid | Supabase → `coach_review_orders`; if no row, check the function logs for `coach-review-order` |
| Deliver fails | function logs for `coach-review-queue`; the voice note may be over the ~9 MB cap |
| Video won't play | the signed URL expired (2h) — press **Refresh** in the queue |

## Still to do before this can earn money

1. **You:** create the consumable IAP in App Store Connect —
   Product ID `com.canayan93.courtiq.coachreview1`, $19.99, "One coach review".
   https://appstoreconnect.apple.com → DropVolley → In-App Purchases.
   (Tax/banking info must be complete or purchases fail.)
2. **You:** App Privacy labels — user video is now shared with a service
   provider (the coach). Web UI only.
3. Ship a build containing the order flow (currently only in the working tree,
   not yet in a submitted build).
