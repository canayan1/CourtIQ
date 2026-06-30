# DropVolley — Development Handover

> **Purpose:** single entry point to continue development in a fresh chat.
> New session: read this file + `CLAUDE.md` first, then proceed.
> **Last updated:** 2026-06-30.

## TL;DR
- **App is LIVE** on the App Store: *DropVolley: Tennis IQ Coach* (App ID `6773753464`), **v1.0 approved**.
- Repo working tree is **clean**; branch `fix/app-store-rejection-build14` is the de-facto working line (stale name — see Housekeeping).
- This session shipped: **Doubles quiz feature** (committed, build-complete) + **AI Drill Coach content v2** (committed, coach-vetted, build NOT started).
- The old "do not touch the in-review app" constraint is **lifted** (app is live) — future changes go into a new version.

## 2026-06-30 session — fixes, deploys, GEO, 1.0.1 submitted
**App Store:** **v1.0.1 (build 26) submitted → `WAITING_FOR_REVIEW`.** Archived/uploaded via Xcode 26 + the ASC API key; reworded "What's New" (polish tone, EN+TR); **upgraded App Store screenshots uploaded via the ASC API** (7 each for en-US + tr, all `COMPLETE`). **Expedited review = a pending MANUAL step for the owner** (no API): developer.apple.com/contact/app-store/?topic=expedite.
> ⚠️ Build 26 was archived BEFORE the doubles quiz + peak-moment haptics were committed → those are **NOT in 1.0.1**; they ship in the **next build (1.0.2)**. The edge-function changes below are **already live for every app version**.

**Edge functions deployed — LIVE now (project `ybnodzzrkwennzpwyjmr`):**
- `doubles-analysis` + `match-analysis` — `maxOutputTokens` 1024→4096 (gemini-2.5-flash *thinking* was eating the budget → reports truncated mid-sentence, leaving a raw `**`).
- `swing-analysis` — prompt calibration: hedge hard-to-judge visual calls (e.g. ball-toss direction); prioritise faults that **recur** across multiple reps; filming tip now asks for 2–3 reps.
- `ai-chat` — manual **v1.2.0** adds **SECTION 11 — Doubles strategy** (A4-grounded). The Coach now knows doubles.

**App fixes/improvements (committed; ship in 1.0.2):**
- **Home profile icon opened Swing, not Profile** — the hero's iOS-18 zoom-transition source bled its tap region into the header. Fixed (header pinned in `safeAreaInset` + zoom dropped). Verified in the simulator.
- **Swing "Record a swing" crashed** — `cameraCaptureMode = .video` set before `mediaTypes` included movie. Fixed (mediaTypes first).
- **Swing capture auto-closed before consent** — two `.sheet`s raced; consent now fires in the picker's `onDismiss`.
- **AI Coach:** long-press a thread → Delete.
- **Swing result → "Discuss with Coach"** — opens a new Coach thread seeded with the analysis.
- **Matches → "Re-analyze"** an edited match (stale `aiReport` no longer sticks; read live from the store).
- **Peak-moment haptics:** quiz completion + doubles partnership report reveal (the ScoreRings were already in place).

**Web GEO (deployed to PRODUCTION — repo `~/Projects/canayanIOSapps`, `canayan-ios-apps.vercel.app`):** DropVolley flipped from in-review/waitlist → **live + App Store download link**; added **MobileApplication JSON-LD** per app + rich metadata/keywords/OpenGraph + `metadataBase`. Deploys via `vercel --prod` CLI (no git remote; scope `canayan1`, project `canayan-ios-apps`).

**Doubles content (P0):** quiz ✓ (10 bilingual scenarios `doubles_001–010`) + AI manual SECTION 11 ✓ (live). **Remaining:** doubles tips (DailyTip pool), Pro Shot doubles patterns, Court Tap doubles drill.

**Repo:** branch was **ahead 17 of origin (unpushed)** at this update. Owner commits in parallel (the doubles quiz landed across `66a2e11`/`30cf1a7`/`62b0081` from concurrent committing — content is clean, no dupes).

## App Store status
- **v1.0 was rejected Jun 16 (build 24):**
  - **Guideline 5.6** — hard paywall: user couldn't leave the "Go Premium" page without buying or force-quitting.
  - **Guideline 3.1.2(c)** — missing Terms of Use (EULA) link for auto-renewable subscriptions.
- **Build 25 (Jun 17) fixed both → APPROVED:**
  - Launch-gate paywall now has a **"Back" control** (`onExit`) → see `CourtIQApp.swift:240` + `PaywallView.swift:91-100`. Other paywalls are dismissible (`allowsDismiss: true`).
  - EULA link added to the App Description.
- Agreements/Tax/Banking are **active**. App is **not login-gated for review** → "Sign-in required" stays **unchecked**, no demo account needed (Apple accessed it fine).
- **Optional bulletproofing:** also set the EULA in ASC → App Information → *License Agreement* (standard Apple EULA or custom).
- **Lesson learned:** lots of submit→"Removed" churn in the history reset the queue repeatedly. **Don't churn**; don't remove/resubmit without a real fix; pause any API/CI auto-submitter.

## Repo state
- **Branch:** `fix/app-store-rejection-build14` (working line; recent app commits all here).
- **Live version:** 1.0. Repo has a `1.0.1 (build 26)` bump commit; **doubles quizzes will ship in the next update** (version/build bump + ASC pending).
- **Working tree:** clean as of handover.
- **Git identity warning:** commits are auto-attributed to `Can <can@Cans-MacBook-Pro.local>` — set `git config user.email` if you want clean attribution.
- **Concurrent edits:** the owner commits in parallel from their own tools — be careful with history rewrites (rebase/squash) and re-check `git status` before acting.

## Work consolidated this session
### Doubles quiz feature (DONE, build-complete)
| Commit | Content |
|---|---|
| `66a2e11` | `Quiz.swift` — added `.doubles` to `QuizCategory` (name, icon, blurb, net-poach court diagram) |
| `30cf1a7` | `quiz_questions.json` — 10 doubles questions (`doubles_001`–`010`, `category: doubles`) |
| `62b0081` | `PracticeView.swift` + `TrainPracticeView.swift` — `.doubles` switch-case completions (owner) |
- Verified: valid JSON, 10 unique entries (no dupes), **no QuizCategory switch left missing `.doubles`** (exhaustiveness checked), real tactical content.
- **Not yet build-verified via `xcodebuild`** — recommend a compile check before the next release.
- Doubles quizzes are bundled content; the existing Doubles *feature* (partnership analysis, `Features/Doubles/`) is separate and already shipped.

### AI Drill Coach — content v2 (DONE; build NOT started)
- Committed: `7992306 docs: AI Drill Coach project plan + drill content`.
- Docs: `docs/AI-DRILL-COACH.md` (plan/architecture/monetization) + `docs/AI-DRILL-COACH-CONTENT.md` (drill library + program + rubric, **coach-vetted**).
- **This is a SEPARATE, higher-priced premium add-on — do not entangle with the main app.** Build only after owner greenlight + the open decisions below.

## AI Drill Coach — vetting decisions (locked Jun 2026)
- **Adaptive difficulty:** every target is a **Seviye 1/2/3** ladder; user self-selects; AI scores against the chosen tier.
- **Library:** ~22 drills across 7 themes; **basic equipment** (partner + court's own lines; no-cone variants).
- **Consistency ladder:** typical "medium" 10–12 consecutive balls; solid-player ceiling 20+ (NTRP-banded table in CONTENT §1).
- **Depth:** two-tier gate (+1 past service line / +2 deep third); % deep by level **35 / 60 / 85**.
- **Recognition drills** (Read & Call, Call the Corner): ship **as beta**, trigger = **"step-in ball"** (no validated source exists).
- **Net play:** approach/volley **6–7/10**, overhead **5–6/10** (medium).
- **Rubric:** balanced **30·25·25·20** (Consistency·Execution·Intent·Drill-success); per-theme overrides proposed.
- **Program:** 8 weeks × 3/week; per-set **~1–2 min blocked → variable**; full session-by-session list in CONTENT §5.
- **Honest caveats kept:** ≈65–77% (not ~90%) of points end ≤4 shots; "Serve +1" (not "3-1"); CI nuance for adults.

### AI Drill Coach — OPEN decisions (ask owner before building)
1. **Tier model:** (A) higher "Pro" upgrade tier vs (B) parallel add-on (RevenueCat does both).
2. **Exact price:** ~2× base ($9.99/wk · $59.99/yr) → ~$19.99/wk · ~$119.99/yr.
3. **Video capture:** one 5-min continuous clip vs a clip per drill.

### AI Drill Coach — build phases (when greenlit; AI-DRILL-COACH.md §10)
1. Drill-aware prompt + **new** `drill-analysis` edge fn (Gemini **Files API**, async long video) — do NOT modify `swing-analysis`.
2. Phone UI (library, set timer/capture, upload, results/score, program progress) behind a feature flag.
3. watchOS companion (CoreMotion + HealthKit + WatchKit haptics, on-device real-time; score-to-watch). Owner wants this **early**.
4. RevenueCat tier + entitlement gating (wire the dormant `COURTIQ_REVENUECAT_API_KEY`).
5. ASC: new IAP + submit with a new app version.
- Related: a **watchOS companion for the MAIN app** is also wanted (separate track, AI-DRILL-COACH.md §12).

## Key technical facts
- **Monetization:** StoreKit 2 direct; products `com.courtiq.premium.weekly` + `com.courtiq.premium.annual`; entitlement `premium_all_access`. RevenueCat key is **empty/dormant** in Info.plist.
  - ⚠️ Info.plist still has unused `COURTIQ_MONTHLY_PRODUCT_ID` / `COURTIQ_YEARLY_PRODUCT_ID` (`.monthly`/`.yearly`) — **stale, not read by code** (`AppConfiguration.swift:26-27` uses weekly/annual). Harmless; clean up someday.
- **Paywall:** single hard paywall (no free tier); launch gate escapable via Back; `PaywallView.swift`.
- **AI backend:** Supabase edge functions (`ai-chat`, `delete-account`, `swing-analysis`) + Gemini. Existing short-clip pipeline: `Features/SwingAnalysis/SwingAnalysisService.swift` (inline base64 ≤19MB). Drill Coach extends this to long video via a new edge fn.
- **Consent pattern to reuse:** `Features/SwingAnalysis/SwingAnalysisConsentView.swift` + `AIConsent`.
- **Naming:** internal bundle/executable is `CourtIQ`; display name **DropVolley**; config keys prefixed `COURTIQ_`. No user-facing "CourtIQ" leftovers (verified).
- **URLs:** privacy/terms/support at `canayan-ios-apps.vercel.app/apps/dropvolley/...`. Feedback email `info@kalibrefin.com`.
- **Compliance assets present:** `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption=false`, Sign in with Apple, account deletion, Restore Purchases, permission usage strings.

## Next steps (suggested order)
1. **Build-verify** the doubles changes (`xcodebuild` / Xcode) before release.
2. **Ship doubles quizzes:** version/build bump + new ASC submission (don't churn).
3. **Branch hygiene:** merge/rename `fix/app-store-rejection-build14` → align with whatever branch releases are cut from.
4. **AI Drill Coach:** resolve the 3 open decisions → greenlight → start build phase 1.
5. (Optional) add EULA to ASC License Agreement field.

## Pointers
- `CLAUDE.md` — project overview, architecture (MVVM), conventions.
- `docs/AI-DRILL-COACH.md` + `docs/AI-DRILL-COACH-CONTENT.md` — Drill Coach plan + vetted content.
- `CourtIQ/Core/Models/AppConfiguration.swift`, `UserSession.swift` — config + entitlements/StoreKit.
- `CourtIQ/Features/Paywall/PaywallView.swift` — paywall + compliance notes.
- `CourtIQ/Features/SwingAnalysis/` — existing Gemini video pipeline (to extend for Drill Coach).
