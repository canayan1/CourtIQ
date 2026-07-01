# DropVolley — Full-App QC Findings (multi-agent, Jun 2026)

> Source: 4 parallel read-only audit agents (correctness/crash, architecture, security/monetization, UX/a11y/localization) over the current working tree (incl. the freemium relaunch). Prioritized; `file:line` + fix + status. Check off as done.

## Progress log (this session)
**Fixed + build-green:** C1 Coach-bypass · CourtTapDrill coord-guard · QuizView localized-options crash · VoiceNoteRecorder hang (resume-once+timeout) · VoiceOver labels (SelfAssessmentStep raw-slug, MentalCheckView/MatchFormComponents English) · ProfileView "IQ RATING" · Spanish hidden from the language picker (no `es.lproj`).
**Verified non-issue:** M1 product IDs (real products match code defaults). **Batch C** (no decode bug — all 3 services match their functions' camelCase contracts; the audit's `.convertToSnakeCase` re-route would have BROKEN swing's `mimeType` → left as-is).
**Also localized:** TrainingHubView (10 EN+TR keys — plan-match, frequency notes, 8-week block). Remaining Training: TrainProgramsView/DetailView chrome + the program-content data-layer (separate translation project).
**Discovered:** `StreakCelebrationView` is **dead code** (never instantiated) — remove or wire up.
**Deliberately deferred:** day-key timezone (changing it risks shifting existing streak keys — needs a migration); Training label localization (partial — program *content* is English at the data layer, a larger translation effort); TennisVisuals "DAYS" (reusable component, needs `lang` threaded carefully); Batch C networking dedup (live-working code — do with verification).

---

**Headline:** the codebase is fundamentally healthy — **no reachable crashes**, RLS sound, **no secrets shipped in the app**, App Store compliance **PASSes** (paywall/health/privacy exemplary). The real issues cluster in (1) money-burn gating from the freemium pivot, (2) architectural drift from CLAUDE.md, (3) localization leaks to Turkish users.

---

## 🔴 CRITICAL — resolved this session
- [x] **C1 — "Discuss with Coach" bypassed the Coach paywall** (`SwingAnalysisView.swift:311`): non-premium user on the free-swing result could open a full paid Anthropic chat. **My free-entry relaunch opened it.** → **FIXED** (gated the hand-off on `entitlementState.isPremium`; build green).
- [x] **M1 — product-ID mismatch suspicion** (`Info.plist` MONTHLY/YEARLY vs code WEEKLY/ANNUAL): **VERIFIED via ASC = non-issue.** Real products `com.courtiq.premium.weekly`/`.annual` (both APPROVED) match the code's defaults → paywall sells fine. The MONTHLY/YEARLY plist keys are stale clutter (cleanup below).

## 🟠 HIGH — monetization (couples with the RevenueCat work → needs keys)
- [ ] **Server gate is dark + fails open.** `REQUIRE_ENTITLEMENT=false` in all 4 edge fns → anyone with the public anon key + anonymous auth calls paid functions directly. And `isEntitled` **fails open** on any RevenueCat error. → flip `=true` for ai-chat + swing once the RC build is live, AND add a **hard global daily budget breaker** (not just the $50 email) + per-IP anon-signup throttle.
- [ ] **Paid swing key can spill onto the free quota — and vice-versa.** `swing-analysis` uses `GEMINI_VIDEO_API_KEY ?? GEMINI_API_KEY`; match/doubles are **uncapped** on the free key. Exhausting the free key (uncapped match/doubles spam) degrades/bills the swing path. → add per-user daily caps to match/doubles; put the **paid video key in a SEPARATE Google project** from the free key.
- [ ] **Free "taste" is client-only + resettable.** `FreeTaste.swingUsed` (UserDefaults) is cosmetic — the real server limit is `SWING_DAILY_CAP=3`/day, reset by reinstall (new anon id). So non-premium = 3 paid swings/day, not 1. → enforce a per-user **lifetime** free swing server-side when the gate flips.
- [ ] **Ensure App Store/TestFlight builds are Release.** DEBUG auto-grants premium (`UserSession.swift:434`, correctly `#if DEBUG`) → any Debug-config dogfood build burns the LLM budget freely.

## 🟠 HIGH — correctness / latent bugs
- [x] **"Latent decode-mismatch" — INVESTIGATED → NO bug, and the proposed fix was dangerous.** All 3 services' fields already match their edge functions' **camelCase** contracts (match `{mode,summary}`/`{report,error}` + doubles `{summary}`/`{...}` are single-word; swing sends `mimeType` and the function reads `body.mimeType` at swing-analysis:198). Routing through the `.convertToSnakeCase` client (the audit's suggestion) would send `mime_type` and **break swing analysis**. → **Left serialization unchanged.** Only real value left is a boilerplate-only dedup that *preserves* each camelCase contract — low payoff (no bug), deferred.
- [ ] **`CourtTapDrill.swift:67/71`** — force-indexes coordinate pairs `$0[0]/$0[1]` from `[[Double]]` JSON; a pair with <2 elements crashes. (JSON currently clean.) → guard `count >= 2`.
- [ ] **`QuizView.swift:154`** — iterates `question.options.indices` but indexes `localizedOptions` (`optionsTr ?? options`); a TR translation with a different count → out-of-range crash in Turkish. (JSON currently clean.) → iterate `localizedOptions.indices` / validate parity.
- [ ] **`VoiceNoteRecorder.swift:282`** — the transcription continuation never resumes if recognition yields neither a final result nor an error → `stop()` hangs in `.transcribing`. → add a timeout / terminal resume.
- [ ] Add **content-validation at JSON decode** (quiz option-count parity, drill coord-pair length) so future content edits fail in tests, not on users' devices.

## 🟡 MEDIUM — localization (Turkish users currently see English)
- [ ] **`StreakCelebrationView.swift`** — 100% hardcoded English (7 strings + share text). High-emotion free-tier moment.
- [ ] **Training hub/detail** (`TrainingHubView.swift`, `TrainProgramsView.swift`, `TrainingProgramDetailView.swift`) — ~8 hardcoded English strings beside already-localized copy.
- [ ] **`ProfileView.swift:250`** `"IQ RATING"` + **`TennisVisuals.swift:393`** `"DAYS"` — prominent, shared, hardcoded.
- [ ] **VoiceOver leaks raw slugs + English:** `SelfAssessmentStep.swift:125` reads *"3 of 5 for open_court"*; `MentalCheckView.swift:213` + `MatchFormComponents.swift:201` read English "of 5".
- [ ] **Spanish is half-supported:** `es` is in `AppLanguage` + the picker but has **no `es.lproj`** → silently falls back to English. → ship `es.lproj` or remove Spanish from the picker.

## 🟡 MEDIUM — architecture (bigger refactors; CLAUDE.md drift)
- [ ] **No ViewModel layer** (only `QuizViewModel`); the analyze-flow is **copy-pasted into 8 Views** → not unit-testable (CLAUDE.md mandates VM tests). `AIChatClient` is the template to follow.
- [x] **Central `PremiumGate`** — DONE. `PremiumGate` (AppConfiguration.swift) is now the single source: `isPremium`/`canUseAICoach`/`canUseSwingAnalysis`/`contentUnlocked` + the dev-allowlist + kill-switch moved in. AICoachTabRoot + SwingAnalysisView route through it; `isPremiumUnlocked` delegates to `PremiumGate.contentUnlocked` (one content-free switch). The 3 scattered idioms are consolidated.
- [ ] **`ensureSessionWithRetry` copy-pasted in 8 Views** → hoist to `UserSessionManager`.
- [ ] **Edge entitlement gate copy-pasted in 4 functions** (no `_shared/`) → extract `supabase/functions/_shared/entitlement.ts`.
- [ ] App-wide `ObservableObject`/Combine instead of mandated `@Observable`; inline `t(en:tr:)` bilingual literals in 9 files instead of the `.strings` catalog.

## 🟢 LOW / hygiene
- [ ] **Day-key timezone skew** (`DailyQuizManager.swift:363` + mirrors): `startOfDay` local vs UTC formatter → midnight streak attribution off-by-one at negative UTC offsets.
- [ ] **Dynamic Type** largely unsupported (198 fixed `.font(.system(size:))` vs 9 `dynamicTypeSize`); **decorative images** rarely `.accessibilityHidden(true)` (3 vs 223 `Image(systemName:)`); ~19 icon-only buttons need a label sweep.
- [ ] Remove stale `COURTIQ_MONTHLY/YEARLY_PRODUCT_ID` plist keys; fix stale "replicated from ProfileView" comments in `AICoachTabRoot`; update `PaywallView` header doc (says "no free tier" — stale post-pivot).
- [ ] Repo hygiene: `CourtIQ.zip` + ~12 planning `*.md` at repo root → move under `docs/`. Split oversized `UserSession.swift` (1083 lines) / `AppConfiguration.swift` (767 lines, also holds `SupabaseRESTClient`).

## ✅ Verified GOOD (don't spend effort)
No reachable crashes; no force-`try!`/`as!`/`fatalError`; shared stores are `@MainActor`. No LLM/secret keys in the client (anon key is public by design). RLS sound + `ai_usage_daily` tamper-proof (service-role only). AIConsent gating + prompt-injection hardening present. Compliance: paywall (price-prominent, Restore/Terms/Privacy, retry, 5.6 escape), health disclaimer (blocking + versioned), Info.plist usage strings — all strong.
