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

## RELEASE DECISION (2026-06-08)
**Ship polish + doubles together as 1.1 (owner chose option B).** Polish
(`feat/polish`) is done and waits for doubles. 1.0 (build 14) is in review;
neither polish nor doubles is in it. Path to 1.1: 1.0 clears → finish doubles
(`feat/doubles-v1.1`, resume Step 5 invite/join UX) → merge `feat/polish` +
doubles → bump 1.1 + new build → submit. Doubles is now the critical path.
**Before the 1.1 submit archive:** (1) add a Doubles frame to the App Store
visuals (video + panorama) since 1.1 introduces doubles; (2) strip the
launch-arg seed (`CourtIQApp.seedPreviewData` / `debugMarkOnboarded`) or add
DEBUG to the Debug config so it compiles out of the release build.

## STATUS LOG
- 2026-06-08 — 1.0 (build 14) + both subs all WAITING_FOR_REVIEW (submitted).
  Started polish phase. Order: Content QC → Limits/Promises → Screenshots.
  Created `feat/polish`.
- 2026-06-08 — **Workstream 1 (Content QC) DONE.** Audited all 5 content
  JSONs via parallel agents (verdict: genuinely high-quality, evidence-based,
  NO fabrication; quiz answers all correct, training/mobility sound). Fixed
  (CRITICAL+MAJOR+MINOR): court_tap_drills (9-drill Y-geometry mirror +
  drill_004/015/025/065/072 labels + 065 title FH/BH + 069/070 corner wording
  + 007 chip); pro_shot_patterns (nadal_banana geometry, rublev→inside-out,
  fed_sabr 2nd-serve, TR taglines); mobility_flows (9 duration headers
  recomputed + ~10 TR typos); quiz_questions (rally_023 açıortay, km/h→
  qualitative, line-judge→self-officiated, net_022, tacticalCategory tags
  re-derived — IS used by QuizViewModel.buildTacticalBuckets); training_programs
  (deload weeks added to 4 advanced progressions, footwork TR inversion,
  flexibility level→intermediate, overclaims softened, recovery→hybrid day
  types, TR typos, **FULL EN/TR localization** of program/phase/day fields).
  Model: added *Tr fields + localizedX(for:) accessors to TrainingProgram/
  Phase/DayPlan. Views: wired TrainingProgramDetailView + TrainingHubView (16
  sites) to localized accessors. All JSON valid; app BUILD SUCCEEDED; 10
  programs fully localized (0 missing *Tr).
- 2026-06-08 — **Workstream 2 (Limits & promises) — owner confirmed content
  is fully free, AI Coach the only paid feature.** Done: set all 10 training
  programs accessTier premium→free; restructured TrainingHubView (removed the
  empty "Premium Tracks"/locked framing → unified "More Tracks" list, neutral
  styling, no crowns/locks); fixed frequencyBanner "once premium unlocked"
  copy; added training.more_tracks/pick_focus strings (EN+TR); updated
  CLAUDE.md Monetization Model (content free, AI Coach only paid, 50 msg/day —
  was a stale freemium table). Verified AI Coach "50 messages/day" claim
  matches the server cap (MAX_DAILY_MESSAGES_PREMIUM ?? 50). Build SUCCEEDED.
  REMAINING (optional, non-visible): vestigial `isPremiumUnlocked` dead
  branches in TodayView/MobilityLibraryView/PracticeView/ProfileView/
  LevelProgressionPathView evaluate to "unlocked" (true) so they don't show
  premium framing — harmless dead code, tidy later.
- 2026-06-08 — **Workstream 3 (App Store visuals) DONE.** Owner pivoted to a
  ~20s preview VIDEO + panoramic static set. macOS Accessibility blocks
  cliclick/osascript (even after grant, needs Claude restart), so capture is
  done via an XCUITest harness (`CourtIQUITests` target + shared scheme):
  `testAppPreviewTour` launches with `-seedPreviewData`, tours the app, and
  saves named XCUIScreenshots → exported from the .xcresult → assembled with
  ffmpeg. Added a launch-arg-gated `CourtIQApp.seedPreviewData()` (+
  `UserSessionManager.debugMarkOnboarded()`, `HealthAcknowledgment` accept)
  that seeds 7 matches (upward trend) + 3 quizzes so Matches + the trend
  dashboard render populated. NOTE: not `#if DEBUG` because this project's
  Debug config doesn't define the DEBUG condition — the seed ships but is
  inert (only the preview UI test passes the arg). **Pre-1.1-submit TODO:
  strip the seed/`debugMarkOnboarded` or add DEBUG to the Debug config so it
  compiles out of the release archive.**
  Deliverables in `marketing/`: `courtiq_preview.mp4` (19.8s, 1320×2868, 9
  populated screens, crossfades); `appstore/01-drill..05-today.png` (5
  panoramic App Store frames, 1320×2868, continuous clay→moss background +
  headlines + device mockups); `panorama.html` + `panorama_full.png` (source
  + 6600×2868 master); `screens/` (raw clean captures, 9:41 status bar).
  Upload to ASC after 1.0 clears. Optional refinements not done: in-app
  Mobility frame (test couldn't find the entry), Ken Burns motion, headline
  captions burned into the video.
