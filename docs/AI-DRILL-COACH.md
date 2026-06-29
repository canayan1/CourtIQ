# AI Drill Coach — separate premium project (planning only)

> **Status: PLAN ONLY — not yet built.** This is a future, separately-sold premium
> add-on. It must NOT touch the in-review app (build 25, version 1.0). When we
> build it: new branch, feature-flagged, its own ASC/IAP setup, new build/version.
> Do not start implementation until build 25's review outcome is known.

## 1. What it is
A premium **on-court drill coaching** experience, sold as its own higher-priced
subscription (separate from base Premium). The player runs structured drills,
films a 5-minute set, and an AI watches it and returns a **session score +
qualitative feedback**. Optional **Apple Watch** companion gives real-time,
on-wrist nudges + the end-of-set score.

Positioning: turns DropVolley from "analyze a swing / a match" into "**a coach
that runs your practice and grades it**." Clear justification for a higher tier.

## 2. Scope
- **IN — Level 1 (this project):** drill library + programmed 5-min sets +
  AI watches the filmed set → qualitative feedback + 0–100 session score + top
  fixes. Reuses/extends the proven Gemini video-understanding pipeline.
- **OUT — Level 2 (explicitly deferred):** precise shot-by-shot metrics
  (cross-court accuracy %, ball-in-zone, rally counts, depth) via specialized
  ball/court CV tracking. Not in scope now. Revisit only if demand is proven.

## 3. UX flow
1. Pick a **program** (e.g. 8-week) or a single **drill set**.
2. App shows the drill: goal, setup, target zone, cues, diagram/animation.
3. Prop the phone on a tripod → **film the 5-min set** (guided timer).
4. (Optional) **Apple Watch** on wrist gives live haptic nudges during the set.
5. Set ends → video analyzed → **session score + feedback + 2–3 fixes** shown
   on phone (and pushed to the watch).
6. Progress tracked across the program (scores trend, streak, next session).

## 4. Drill library — starter set
> **Drafted, research-grounded library + program + scoring rubric (for coach
> vetting): see [AI-DRILL-COACH-CONTENT.md](AI-DRILL-COACH-CONTENT.md).**
Each drill = {name, goal, setup, target zone, success criteria, coaching cues,
diagram}. Starter examples:
- **Cross-court forehand** (rally cross-court FH, depth + margin)
- **Cross-court backhand**
- **One up / one back** (one player straight, one cross — control + recognition)
- **Tramline rally** (keep the ball inside the doubles alley — precision)
- **Approach & volley** (mid-court ball → approach → put-away)
- **Serve + 1** (serve to a spot, then the expected next ball)
- **Figure-8 / dead-zone clears** (consistency + footwork patterns)
- **Recovery rally** (hit + recover to center between shots)
> Content (text + diagrams/animation) must be authored. ~15–25 drills for v1.

## 5. Program structure (example: 8 weeks)
- 3 sessions/week, each = 3–4 × 5-min sets (≈20–30 min).
- Themes ramp: consistency → direction control → depth → patterns → pressure.
- Each session ends with a logged session score; weekly summary + trend.

## 6. Architecture

### 6a. Long-video AI pipeline (the core change vs swing analysis)
The existing `swing-analysis` path sends a short clip as **inline base64 ≤19 MB**
to Gemini (`gemini-2.5-flash`). A 5-min 720p set is ~50–150 MB → inline won't work.
- **New, SEPARATE edge function** `drill-analysis` (do not modify `swing-analysis`).
- Phone: downscale (≤720p, consider 1 fps where acceptable) → upload via the
  **Gemini Files API** (not inline) → **async** processing → poll/callback.
- **Drill-aware prompt:** the request includes which drill(s) the set contains,
  the target/success criteria, and the player's Tennis Profile, so the model
  scores against the drill's intent (technique, effort, rhythm, consistency,
  recognizable success) rather than generic commentary.
- Returns: `{ sessionScore: 0–100, summary, strengths[], fixes[], perDrillNotes[] }`.
- Reliability note: Gemini gives reliable **qualitative** feedback + rough
  counts; it does NOT give exact ball-in-zone metrics (that's Level 2 / CV).

### 6b. Apple Watch companion (real-time = on-device, ~zero cloud cost)
The watch is on the **wrist** → it senses wrist motion + heart rate, NOT feet.
- **watchOS companion target** + `WatchConnectivity`.
- Real-time, on-device (no cloud/AI): **CoreMotion** (stroke detection/count,
  swing intensity, cadence/reps-per-min) + **HealthKit** (heart rate / effort
  zone) + **WatchKit haptics** + set/rest timer.
- Real-time haptic nudges: "swing speed dropping", "good rhythm", effort/HR
  zone, "you're fatiguing — reset your base".
- **Footwork caveat:** the wrist cannot directly measure footwork. Real-time
  "footwork slowed" is only an **effort/intensity proxy** ("you're slowing down
  → reset your feet"), not a measurement. True footwork = camera (Level 2).
- **Score-to-watch:** after the phone's Gemini analysis returns, push the
  session score + top fix to the watch (display + haptic).

### 6c. Split (important)
- **Real-time during the set = WATCH** (motion/HR heuristics, on-device, instant).
- **Deep analysis after the set = PHONE + Gemini** (video → score/feedback).
- Results synced to phone + watch.

## 7. Monetization — separate higher-priced subscription
Sold apart from base Premium. **Open decision (pick one):**
- **(A) Higher "Pro" tier (upgrade):** same subscription group, level above base;
  Apple handles upgrade/downgrade; user can't hold both. Simplest, higher ARPU.
- **(B) Add-on (separate group):** user keeps base + buys Drill Coach on top
  (both active). True "extra package", more flexible, slightly more StoreKit work.
- **Billing via RevenueCat (decided).** The current app already ships a dormant
  `COURTIQ_REVENUECAT_API_KEY` in Info.plist — wire it up for this tier.
  RevenueCat manages entitlements, tiers, and paywalls (and cross-platform
  later), and makes either (A) or (B) straightforward.
- New product(s) + their own ASC setup. **First submission of the new IAP must
  go with a new app version** (same flow we just did for build 25).
- **Price ≈ 2× base (decided):** base $9.99/wk · $59.99/yr → Drill Coach
  ~$19.99/wk · ~$119.99/yr (exact TBD).

## 8. Cost
- **Gemini API:** ~$0.03/5-min set (flash) to ~$0.12–0.25 (pro). Even 20
  sets/mo ≈ cents–few dollars. **Not the bottleneck.**
- **Apple Watch real-time:** on-device → **zero marginal/cloud cost.**
- **Real cost = engineering:** Level 1 phone feature ~weeks; watchOS companion
  ~weeks; drill content authoring; QA. No recurring infra cost beyond Gemini.
- **User-side:** 5-min video upload ~50–150 MB — mitigate with on-device
  downscale; surface a Wi-Fi hint.

## 9. Isolation & sequencing (why this is a separate project)
- Build 25 (v1.0) is in App Review. **Do not add this feature's code to the
  in-review app** — a rejection may require another quick build/resubmit, and
  this must not be entangled.
- When we build: **separate branch**, behind a **feature flag / new tier
  entitlement**, its own IAP + ASC review. Ship as a later version.

## 10. Build phases (when greenlit)
1. **Spec + content:** finalize drill library + program + scoring rubric.
2. **Drill-aware prompt** + `drill-analysis` edge fn (Gemini Files API, async).
3. **Phone feature:** library UI, set timer/capture, upload, results/score UI,
   program progress. Behind feature flag.
4. **Apple Watch companion:** CoreMotion/HealthKit real-time + haptics +
   score-to-watch.
5. **New subscription tier** (A or B) + entitlement gating.
6. **ASC:** new IAP, screenshots, submit with the new version.

## 11. Decisions
**Resolved (owner, Jun 2026):**
- **Drill content:** drafted by Claude (deep-research-grounded) and **vetted by
  the owner, who is a tennis coach — v2 signed off Jun 2026** (ladder, depth %,
  recognition-as-beta, net-play numbers, balanced rubric, 8-wk program + session
  list). See [AI-DRILL-COACH-CONTENT.md](AI-DRILL-COACH-CONTENT.md) §6.
- **Price:** ≈ **2× base**.
- **Billing:** **RevenueCat**.
- **Apple Watch:** wanted **early — possibly before this feature's v1**; and the
  **current app also gets its own watchOS companion** (separate main-app track, §12).

**Still open:**
- Tier model: **(A) Pro upgrade** vs **(B) parallel add-on** (RevenueCat does both).
- Exact price.
- Video capture: one 5-min continuous clip vs a clip per drill.

## 12. Related workstream — watchOS companion for the CURRENT app
The existing DropVolley app warrants its own Apple Watch app, independent of (and
possibly before) Drill Coach: e.g. quick swing-record handoff, today's drill,
fast match logging, rings/streak + notifications on the wrist. This is a
**main-app** feature → a future version AFTER build 25 is approved (do NOT add to
the in-review build). Will be specced as its own doc when greenlit.
