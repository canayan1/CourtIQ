# DOUBLES BUILD — MEMORY & PLAN (read this first after any context reset)

This file is the single source of truth for the **v1.1 Doubles
Compatibility** build. If my memory was auto-compacted, READ THIS to
resume exactly where we left off. Update the STATUS LOG at the bottom
after every step.

---

## 0. Macro context (where the whole project stands)
- App: **CourtIQ** (iOS, SwiftUI + Supabase backend). Owner communicates
  in Turkish.
- **1.0 (build 13) is in App Store review** ("Waiting for Review",
  **manual release** — won't publish until owner clicks Release). Both
  prior rejection causes are fixed & submitted: Apple Sign-In (Supabase
  project was paused + Apple provider was off → both fixed) and IAP
  (subscriptions now Waiting for Review alongside the version).
- **Pricing model (final):** AI Coach is the ONE paid feature; everything
  else is free. In code, content gate `UserSessionManager.isPremiumUnlocked`
  is hard-wired `true`; AI Coach gates on real entitlement
  (`entitlementState.isPremium`). Paywall (`PaywallView`) sells AI Coach
  as a normal subscription (`isTipJar = false`).
- This doubles work is **v1.1, AFTER 1.0** — do NOT touch the in-review
  1.0. All doubles work is on branch **`feat/doubles-v1.1`** (off the
  `fix/app-store-rejection-build11` branch, which has all 1.0 fixes).

## 1. What we're building (see FEATURE_SPEC_doubles_v1.1.md for full detail)
A doubles compatibility test: two players answer ~8 quick questions, get a
0–100 compatibility score + per-dimension breakdown + team setup (serve
order, return sides, formation) + strengths/watch-outs. FREE. A premium AI
game-plan layers on top.

**Locked decisions (REVISED 2026-06-08 after device dogfooding):**
- Vision: personal trainer + strong doubles tool. A private 1:1 partner
  link is fine (NOT a public social feed → no heavy Guideline 1.2 UGC).
- **PAIRING PIVOT → account-linked invite link (was A.5/QR).** On-court QR
  & single-device hand-off felt awkward in real use. New primary flow:
  inviter does their half → shares a **WhatsApp/universal link** → partner
  **installs the app + creates an account** → does their own half → **both
  accounts see the compatibility score**. Keep single-device "fill both
  yourself" as a quick fallback. (QR/MultipeerConnectivity is dropped for
  v1.1.)
- **Accounts REQUIRED** for the invite flow (reuses existing Supabase Auth:
  Apple + anonymous + email; account deletion already exists via edge fn →
  App Store 5.1.1(v) satisfied). Privacy label must disclose profile shared
  with the invited partner.
- **Joint doubles MATCH LOGGING is IN this version** (owner's call): once
  two accounts are linked as partners, either can log a doubles match and
  both see it.
- Entry: prominent Doubles card on Today (tab bar full at 5; final
  placement deferred).
- FREE: test + score + static prep + match logging. PREMIUM: AI plan
  (reuses AI Coach gate + ai-chat) — later step.

## 2. Key build facts / gotchas
- **Xcode project uses EXPLICIT file references** (no
  PBXFileSystemSynchronizedRootGroup). New `.swift` files MUST be
  registered in `CourtIQ.xcodeproj/project.pbxproj` (PBXFileReference +
  PBXBuildFile + group child + Sources build phase) or they won't compile.
- **There is NO XCTest target.** Validate the pure scoring logic with a
  standalone `swiftc` harness (the scorer must be pure Swift — no UIKit /
  SwiftUI / SwiftData / app deps). Do NOT rely on `xcodebuild test`.
- Build (Debug, no signing):
  `xcodebuild build -project CourtIQ.xcodeproj -scheme CourtIQ -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO`
- Simulators available: iPhone 17 / 17 Pro / 17 Pro Max (NOT iPhone 16).
- Reuse for QR pairing: `CourtIQ/Features/CoachMode/CoachSession.swift`
  (MCSession host/guest, QR via discoveryInfo, `Submission: Codable`
  exchange, `bothSubmitted` state). `CoachPairView.swift`, `CoachReveal.swift`.
- Supabase: project ref `ybnodzzrkwennzpwyjmr`. Migrations in
  `supabase/migrations/`. Edge function `supabase/functions/ai-chat/`
  (index.ts + tennis_manual.ts). Client REST in
  `CourtIQ/Core/Models/AppConfiguration.swift` (SupabaseRESTClient).
- AI context payload: `CourtIQ/Core/Models/AIChatModels.swift`
  (`AIChatContextPayload`). Client encodes with `.convertToSnakeCase`;
  fields WITH explicit CodingKeys keep their raw value (strategy NOT
  applied to them). The edge function reads `snake ?? camel` defensively
  (we fixed a serialization bug there).
- Localization: user-facing strings via `LanguageManager` (`lang.t("key")`)
  + `Localizable.strings` (en + tr). EN/TR both required.
- Conventions: MVVM, `@Observable`/`ObservableObject` view models/managers,
  managers are `@MainActor` singletons persisting via UserDefaults+Codable
  JSON (see DailyQuizManager / CourtTapDrillManager patterns).

## 3. Data models (target)
```
DoublesProfile: preferredSide(deuce|ad|either), netComfort(net|mixed|baseline),
  poach(aggressive|selective|holds), comms(vocal|some|quiet),
  pressure(goForIt|percentage|defend), formation(flexible|standardOnly),
  handedness(right|left), serveStrength 1..5, returnStrength 1..5
DoublesResult: score 0..100, band(strong|workable|needsPlan),
  dimensions[{key,rating(green|yellow|red),note}], serveFirst(A|B),
  deuceReturner/adReturner(A|B), startingFormation, strengths[], watchOuts[]
Partnership (persisted): id, partnerName, createdAt, updatedAt, myProfile,
  partnerProfile, result, aiPlan?
```

## 4. Scoring engine (FREE, pure, the heart) — weights
court-side fit 25 · net/baseline balance 20 · comms 15 · risk/pressure 15 ·
formation range 10 · handedness synergy 10 · serve cohesion 5  → 0–100.
Bands: ≥80 strong, 60–79 workable, <60 needs-plan. Recommendations
(serve order by serveStrength; ad court to higher returnStrength on clash;
formation by net/baseline mix). Full rules in FEATURE_SPEC_doubles_v1.1.md §3.

## 5. Implementation sequence (CHECK OFF AS DONE)
- [x] **Step 1 DONE**: `DoublesProfile`, `DoublesResult`,
      `DoublesCompatibility` (pure scorer) in `CourtIQ/Features/Doubles/`.
      Validated via `./Scripts/check_doubles_scorer.sh` (22/22 pass).
      Registered in pbxproj via the `xcodeproj` ruby gem (user-installed:
      `gem install --user-install xcodeproj`; helper script was
      `/tmp/add_doubles.rb`). App build green (all 3 compile in target).
      Result is language-neutral (keys + ratings + slots) → UI localizes
      in Step 2.
- [x] **Step 2 DONE**: Doubles UI (single-device flow) — `DoublesCopy`
      (EN/TR inline), `DoublesPartnership` + `DoublesStore` (UserDefaults
      persistence), `DoublesHomeView` (list + new test), `DoublesQuestionnaireView`
      (name → your 8 answers → partner's 8 → result), `DoublesResultView`
      (score ring, dimension breakdown, team setup, strengths/watch-outs,
      static prep sheet, AI-plan teaser). Entry = a prominent "Doubles
      compatibility" card on TodayView (tab bar is full at 5; final tab
      placement deferred). Models made Hashable for navigationDestination.
      App build SUCCEEDED. NOTE: QR pairing/invite/AI-plan still later steps.
  ⚠️ Steps 3–7 below were REVISED 2026-06-08 (account-linked pivot). The
  two-axis engine (§4) and single-device UI (kept as fallback) stand.
- [ ] **Step 3 (REVISED)**: Backend schema — Supabase migration
      `doubles_partnerships` (code, inviter/invitee user_id + name + profile
      jsonb, status) + `doubles_matches` (partnership_id, logged_by, date,
      won, score, opponents, notes) + RLS (both participants r/w) + two
      SECURITY DEFINER RPCs: `peek_doubles_invite(code)` and
      `accept_doubles_invite(code,name,profile)`. Write file now; DEPLOY TO
      PROD NEEDS OWNER APPROVAL (additive/safe; shared project with in-review
      1.0 but doesn't touch existing tables).
- [ ] **Step 4**: `DoublesService` (client) — REST/RPC: createInvite,
      peekInvite, acceptInvite, listPartnerships, getPartnership, logMatch,
      listMatches + sign-in gating (Apple/anonymous). PostgREST path exists
      in AppConfiguration (`rest/v1/<table>`, ~line 417) + `functionRequest`
      for RPCs.
- [ ] **Step 5**: Invite + join UX — after my half → "Invite partner" →
      share universal link; join → sign in → test → both see score. Replace
      local-only partnerships with server-backed (keep single-device "fill
      both" fallback).
- [ ] **Step 6**: Universal Links — AASA at
      `canayan-ios-apps.vercel.app/.well-known/apple-app-site-association`
      (appID `DC8ALPY949.com.canayan93.courtiq`, paths `/d/*`) + Associated
      Domains entitlement `applinks:canayan-ios-apps.vercel.app` + URL
      handling in app + web fallback page `/d/<code>` on the Next.js site.
- [ ] **Step 7**: Joint doubles match logging UI (log against a partnership;
      both partners see the list).
- [ ] **Step 8 (later)**: Premium AI doubles game-plan (ai-chat context +
      tennis_manual doubles section; deploy).
- App Store: account deletion already exists (5.1.1(v) ✓); add privacy
  disclosure that the profile is shared with the invited partner.

## 6. How to resume after a reset
1. `git branch --show-current` → should be `feat/doubles-v1.1`. If not,
   `git checkout feat/doubles-v1.1`.
2. Read this file's STATUS LOG (bottom) for the last completed step.
3. Read `docs/FEATURE_SPEC_doubles_v1.1.md` for full design.
4. `git log --oneline feat/doubles-v1.1` to see what's committed.
5. Continue the next unchecked step. Commit after each step with a clear
   message. Keep everything on this branch (reversible, isolated).

---

## STATUS LOG (update after every step)
- 2026-06-08 — Branch `feat/doubles-v1.1` created off the 1.0-fix branch.
  Wrote this memory doc + FEATURE_SPEC_doubles_v1.1.md. Confirmed: explicit
  pbxproj refs, no XCTest target.
- 2026-06-08 — **Step 1 DONE.** Models + pure scorer in
  `CourtIQ/Features/Doubles/` (DoublesProfile, DoublesResult,
  DoublesCompatibility). swiftc harness `Scripts/doubles_scorer_check.swift`
  + runner `Scripts/check_doubles_scorer.sh` → 22/22 pass. Files registered
  in pbxproj (xcodeproj gem); app `xcodebuild build` SUCCEEDED. Ideal pair
  → 99/strong; worst → 36/needsPlan.
- 2026-06-08 — **Step 2 DONE.** Full single-device doubles UI (6 files in
  Features/Doubles) + Today entry card; EN/TR via DoublesCopy; partnerships
  persist via DoublesStore (UserDefaults). Installed dev build on owner's
  iPhone 13 (iOS 26.5) — does NOT touch the in-review 1.0.
- 2026-06-08 — **Step 2 REWORKED per device feedback** ("score unclear,
  recommendations odd, questions insufficient"). Engine is now TWO-AXIS:
  TACTICAL (courtSide, netBaseline, handedness, formation, serve) +
  CHEMISTRY (comms, temperament[NEW], goal[NEW]); dropped poach/pressure.
  9 questions (6 tactical + 3 chemistry). DoublesResult gained
  tacticalScore/chemistryScore; DoublesDimension gained `axis`. Result
  screen now shows overall + two axis bars, a per-dimension breakdown with
  BOTH players' answers, and team-setup recommendations WITH reasons.
  DoublesStore key bumped v1→v2 (profile shape changed). Scorer harness
  rewritten → 26/26 pass (ideal 100; tac-good/chem-bad 68 [tac100/chem35];
  tac-bad/chem-good 64 [tac36/chem91]). App build SUCCEEDED; reinstalled on
  iPhone 13.
- 2026-06-08 — **PAIRING PIVOT** (owner feedback: on-court QR/hand-off too
  awkward; WhatsApp link is better). New model = account-linked invite link;
  partner installs + signs up; both see the score; joint match logging is
  in v1.1 too. Updated §1 decisions + §5 step plan. **Step 3 schema written:**
  `supabase/migrations/20260608000000_doubles_tables.sql` (partnerships +
  matches + RLS + peek/accept RPCs). NOT YET DEPLOYED — needs owner approval
  to push to prod Supabase (additive/safe). **Next: get deploy approval, then
  Step 4 (DoublesService client).**
