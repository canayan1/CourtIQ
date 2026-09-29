# DropVolley — Full-App QC Findings (multi-agent, Jun 2026)

> Source: 4 parallel read-only audit agents (correctness/crash, architecture, security/monetization, UX/a11y/localization) over the current working tree (incl. the freemium relaunch). Prioritized; `file:line` + fix + status. Check off as done.

## Re-verified 29 Sep 2026

This list was written in Jun 2026 and its boxes had not been touched since, so
a sweep for open work counted 21 items that nobody owed. Every item was checked
against the tree on 29 Sep 2026; what a check actually looked at is named in the
item, so the next person can disagree with it.

- **6 were already fixed** and never ticked (CourtTapDrill, QuizView, VoiceNoteRecorder, Spanish, stale plist keys, and the edge copy-paste which was fixed that day).
- **3 no longer exist** — the file the finding pointed at is gone.
- **1 was overstated**: Dynamic Type is largely handled now (198 raw fixed fonts → 28, plus a `ScaledFont` modifier).
- **2 got worse**: `ensureSessionWithRetry` spread from 8 files to 11; `UserSession.swift` and `AppConfiguration.swift` both grew.
- **The money item is unchanged and still first.** `REQUIRE_ENTITLEMENT` is not set. The global call cap is the only thing holding the line.

Unchecked and not re-verified in that pass: the day-key timezone skew (item under
Correctness) — `startOfDay` is still there, but confirming the off-by-one needs
more than a grep.

---

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
- [ ] **Server gate is dark.** Still the top item. `REQUIRE_ENTITLEMENT` is **not set as a secret** (verified 29 Sep), so all four functions read the `"false"` default and `isEntitled` returns true for everyone. `GLOBAL_DAILY_CALL_CAP` *is* set and is currently the only thing standing between an anonymous account and the AI budget. **29 Sep: shadow mode now deployed** — `ENTITLEMENT_SHADOW=true` makes the gate decide and log without blocking, because flipping blind can lock out subscribers (see `_shared/entitlement.ts` for why "fails open on error" does not cover it). Read the log before enforcing. Per-IP anonymous-signup throttle still not done.
- [ ] **Paid swing key can spill onto the free quota — and vice-versa.** `swing-analysis` uses `GEMINI_VIDEO_API_KEY ?? GEMINI_API_KEY`; match/doubles are **uncapped** on the free key. Exhausting the free key (uncapped match/doubles spam) degrades/bills the swing path. → add per-user daily caps to match/doubles; put the **paid video key in a SEPARATE Google project** from the free key.
- [ ] **Free "taste" is client-only + resettable.** `FreeTaste.swingUsed` (UserDefaults) is cosmetic — the real server limit is `SWING_DAILY_CAP=3`/day, reset by reinstall (new anon id). So non-premium = 3 paid swings/day, not 1. → enforce a per-user **lifetime** free swing server-side when the gate flips.
- [ ] **Ensure App Store/TestFlight builds are Release.** DEBUG auto-grants premium (`UserSession.swift:434`, correctly `#if DEBUG`) → any Debug-config dogfood build burns the LLM budget freely.

## 🟠 HIGH — correctness / latent bugs
- [x] **"Latent decode-mismatch" — INVESTIGATED → NO bug, and the proposed fix was dangerous.** All 3 services' fields already match their edge functions' **camelCase** contracts (match `{mode,summary}`/`{report,error}` + doubles `{summary}`/`{...}` are single-word; swing sends `mimeType` and the function reads `body.mimeType` at swing-analysis:198). Routing through the `.convertToSnakeCase` client (the audit's suggestion) would send `mime_type` and **break swing analysis**. → **Left serialization unchanged.** Only real value left is a boilerplate-only dedup that *preserves* each camelCase contract — low payoff (no bug), deferred.
- [x] ~~**`CourtTapDrill.swift`**~~ **DONE** (verified 29 Sep: two `count >= 2` guards present).
- [x] ~~**`QuizView.swift`**~~ **DONE** (verified 29 Sep: iterates `localizedOptions.indices`).
- [x] ~~**`VoiceNoteRecorder.swift`**~~ **DONE** (verified 29 Sep: timeout + terminal resume present).
- [ ] Add **content-validation at JSON decode** (quiz option-count parity, drill coord-pair length) so future content edits fail in tests, not on users' devices.

## 🟡 MEDIUM — localization (Turkish users currently see English)
- [x] ~~**`StreakCelebrationView.swift`**~~ **OBSOLETE** (29 Sep: the file no longer exists).
- [x] ~~**Training hub/detail**~~ **OBSOLETE** (29 Sep: `TrainingHubView.swift` no longer exists; the hub was restructured).
- [ ] **`ProfileView.swift:250`** `"IQ RATING"` + **`TennisVisuals.swift:393`** `"DAYS"` — prominent, shared, hardcoded.
- [x] ~~**VoiceOver leaks raw slugs**~~ **OBSOLETE** (29 Sep: `SelfAssessmentStep.swift` no longer exists). The wider VoiceOver sweep is still open — see the Dynamic Type / a11y item.
- [x] ~~**Spanish is half-supported**~~ **DONE** (verified 29 Sep: `AppLanguage.shipped` excludes it; never offered, never auto-selected).

## 🟡 MEDIUM — architecture (bigger refactors; CLAUDE.md drift)
- [ ] **No ViewModel layer** (only `QuizViewModel`); the analyze-flow is **copy-pasted into 8 Views** → not unit-testable (CLAUDE.md mandates VM tests). `AIChatClient` is the template to follow.
- [x] **Central `PremiumGate`** — DONE. `PremiumGate` (AppConfiguration.swift) is now the single source: `isPremium`/`canUseAICoach`/`canUseSwingAnalysis`/`contentUnlocked` + the dev-allowlist + kill-switch moved in. AICoachTabRoot + SwingAnalysisView route through it; `isPremiumUnlocked` delegates to `PremiumGate.contentUnlocked` (one content-free switch). The 3 scattered idioms are consolidated.
- [ ] **`ensureSessionWithRetry` copy-pasted — now in 11 files, not 8** (verified 29 Sep). It has spread since June. → hoist to `UserSessionManager`.
- [x] ~~**Edge entitlement gate copy-pasted in 4 functions**~~ **DONE 29 Sep** — extracted to `supabase/functions/_shared/entitlement.ts` and deployed. The four copies had already drifted (whitespace only, but drift).
- [ ] App-wide `ObservableObject`/Combine instead of mandated `@Observable`; inline `t(en:tr:)` bilingual literals in 9 files instead of the `.strings` catalog.

## 🟢 LOW / hygiene
- [ ] **Day-key timezone skew** (`DailyQuizManager.swift:363` + mirrors): `startOfDay` local vs UTC formatter → midnight streak attribution off-by-one at negative UTC offsets.
- [ ] **Accessibility sweep.** Dynamic Type is now *mostly* handled — `SharedUI/DesignSystem.swift` has a `ScaledFont` modifier built on `@ScaledMetric`, and the raw `.system(size:)` count is down from 198 to **28** (verified 29 Sep). What remains: decorative images are still almost never `.accessibilityHidden(true)` (**9** vs **303** `Image(systemName:)`), and the icon-only-button label sweep has not happened.
- [x] ~~Remove stale `COURTIQ_MONTHLY/YEARLY_PRODUCT_ID` plist keys~~ **DONE** (verified 29 Sep: 0 occurrences). Stale header docs elsewhere not re-checked.
- [ ] Repo hygiene: **partly done** — root `*.md` is down to 3 (was ~12), but `CourtIQ.zip` is still committed at the root. `UserSession.swift` is **1104** lines and `AppConfiguration.swift` **827** (both grew since June). (verified 29 Sep)

## ✅ Verified GOOD (don't spend effort)
No reachable crashes; no force-`try!`/`as!`/`fatalError`; shared stores are `@MainActor`. No LLM/secret keys in the client (anon key is public by design). RLS sound + `ai_usage_daily` tamper-proof (service-role only). AIConsent gating + prompt-injection hardening present. Compliance: paywall (price-prominent, Restore/Terms/Privacy, retry, 5.6 escape), health disclaimer (blocking + versioned), Info.plist usage strings — all strong.
