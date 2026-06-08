# POLISH PHASE — plan & progress (read after any context reset)

Post-1.0-submission polish, while 1.0 (build 14) is in App Store review.
Three workstreams, done in order. Branch: **`feat/polish`** (off the
build-14 / `fix/app-store-rejection-build11`+fixes state). Do NOT touch the
in-review 1.0 binary/metadata. Screenshots are metadata → upload AFTER 1.0
clears (or with the next version); designing them now is safe.

Doubles (1.1) work is paused on `feat/doubles-v1.1` — resume after 1.0
ships. Polish may ship as 1.0.1 or merge into 1.1 (decide later).

## Order & status
- [ ] **1. Content QC** — deep audit of all in-app content for accuracy,
      consistency, EN/TR parity, typos, evidence basis. Files:
      `CourtIQ/Resources/Content/*.json` (court_tap_drills, pro_shot_patterns,
      training_programs, mobility_flows, + quizzes/tips/FAQ wherever they
      live) + `Resources/{en,tr}.lproj/Localizable.strings`. Produce a
      findings list → fix the real issues. (Earlier audit was shallow; this
      is the deep pass.)
- [ ] **2. Limits & promises** — make the free/premium gates AND the
      advertised claims consistent + correct in code. Single source of truth
      for gating (`PremiumGate`, `isPremiumUnlocked` hard-true for content,
      AI Coach gated on real entitlement, daily quiz limits). Verify every
      paywall/marketing claim is actually delivered (we already fixed AI
      catalog + privacy copy). Apple-compliance: content-free model, AI-Coach
      = only paid feature, disclaimers present.
- [ ] **3. Panoramic App Store screenshots** — capture real screens from the
      iOS simulator (Today/daily drill, Court Tap Drill, AI Coach, Match
      journal, Progress charts, Training, Mobility), design a panoramic set
      (continuous background in the app palette — clay/moss/cream — + device
      mockups + headlines) as an HTML/CSS template rendered to App Store
      sizes (6.9" = 1290×2796) via headless Chrome. Store under `marketing/`.
      Upload to ASC after 1.0 clears.

## Build/asset notes
- Simulators: iPhone 17 / 17 Pro / 17 Pro Max. Build:
  `xcodebuild build -project CourtIQ.xcodeproj -scheme CourtIQ -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO`
- App palette (AppPalette.swift): clay #C65C31, moss #6C8366, cream #F4ECDD,
  parchment #FCF7EE, sand #E1D1B8, ink #1E2938, gold #D99E19.
- ASC helper: `/tmp/asc.py GET/POST/PATCH/DELETE <path> [json]`.

## STATUS LOG
- 2026-06-08 — 1.0 (build 14) + both subs all WAITING_FOR_REVIEW (submitted).
  Started polish phase. Order: Content QC → Limits/Promises → Screenshots.
  Created `feat/polish`. **Next: Content QC (inventory + audit content files).**
