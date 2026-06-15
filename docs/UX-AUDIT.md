# DropVolley — UX Audit & Remediation Plan

_Research → whole-app evaluation → synthesis. Agent-driven, design-canon-grounded. Date: 2026-06._

**App-wide UX score ≈ 3.3 / 5** — competent and distinctive, but held back by a handful of **systemic** gaps. Fixing the systemic layer lifts every screen at once.

---

## 1. The rubric (10 scored dimensions, 1–5)

Distilled from Apple HIG, Dieter Rams' 10 principles, _Refactoring UI_ (Wathan/Schoger), Nielsen's 10 heuristics, Laws of UX, and teardowns of Apple Design Award winners.

| Dim | Name | What "5" looks like |
|---|---|---|
| D1 | Clarity & visual hierarchy | One focal point, one primary CTA, ~3 emphasis levels |
| D2 | Simplicity & restraint | Ruthless signal-to-noise; progressive disclosure; nothing unearned |
| D3 | IA & navigation | Always know where you are; marked exit from modals; ≤3 taps; iOS conventions |
| D4 | Typography | Constrained scale; body ≥16pt; ≤2 weights; Dynamic Type; line length ≤~75 |
| D5 | Color & contrast | Constrained semantic palette; text ≥4.5:1; color never the sole signal |
| D6 | Layout, spacing & rhythm | 8pt spacing scale; inter-group space > intra-group; consistent margins |
| D7 | Motion, feedback & microinteractions | <400ms feedback; pressed/loading/disabled states; spatial transitions; tasteful delight |
| D8 | Affordance, discoverability & first-run | ≥44pt targets; looks tappable; hinted gestures; value before signup/paywall |
| D9 | States (empty/error/loading/offline) | Empty teaches + CTA; plain-language errors + recovery; skeleton over spinner |
| D10 | Consistency, accessibility & brand | One design language; VoiceOver; Dynamic Type; Reduce Motion; distinct personality. _Accessibility failures cap D10 ≤2._ |

**Cross-cutting canon principles:** design in grayscale first; de-emphasize secondary (don't shout the primary); constrain to systems (spacing/type scales); more space between groups than within; less but better; match platform conventions; feedback <400ms; recognition over recall; reduce decision cost; ≥44pt reachable targets; engineer the peak & the end; polish to the last detail.

---

## 2. Heatmap (area × dimension, area-level means)

| Area | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | D9 | D10 | Avg |
|---|--|--|--|--|--|--|--|--|--|--|--|
| Home | 4 | 4 | 4 | 2 | 2 | 4 | 3 | 3 | 4 | 2 | 3.2 |
| Train | 4 | 3 | 3 | 4 | 3 | 4 | 3 | 3 | 3 | 2 | 3.1 |
| Matches | 4 | 4 | 4 | 4 | 4 | 4 | 3 | 3 | 4 | 2 | 3.6 |
| Doubles | 4 | 4 | 4 | 4 | 3 | 4 | 2 | 4 | 3 | 2 | 3.2 |
| Coach·Onboarding·Paywall | 4 | 4 | 4 | 4 | 4 | 4 | 2 | 4 | 3 | 3 | 3.4 |
| Me·Profile·Swing | 4 | 3 | 4 | 4 | 4 | 4 | 2 | 4 | 4 | 3 | 3.5 |

**Weakest columns app-wide: D7 (motion/feedback/haptics) and D10 (consistency/accessibility/dark-mode)**, plus D4/D5 on Home.

---

## 3. Systemic findings (the highest-leverage fixes)

These are not per-screen bugs; they are app-wide and each fix lifts many screens.

1. **Dark mode broken + hardcoded palette.** `AppPalette` (`CourtIQ/Core/Models/AppPalette.swift:4-14`) is fixed sRGB with no `colorScheme` adaptation → cream/parchment stay light in dark mode. Caps D10 ≤2 on every screen. **#1 fix.**
2. **Contrast failures.** `inkSoft` (96,91,84) on `parchment` (252,247,238) ≈ **3.0:1**, below WCAG 4.5:1 — used for captions/eyebrows/relative-time across the app.
3. **Dynamic Type broken.** Fixed `.system(size:)` everywhere (DesignSystem.swift, RecentActivity.swift, HomeView.swift, etc.); body-equivalent text drops below 16pt and doesn't scale.
4. **DesignSystem not adopted app-wide.** `Eyebrow`, `PressableCardStyle`, `Motion`, `FeatureTile`, `ScoreRing` exist (CourtIQ/SharedUI/DesignSystem.swift) but only Home/Train use them. Matches, Doubles, Coach, Onboarding, Paywall, Profile, Swing hand-roll the old palette-card style. **`ScoreRing` is effectively dead code.**
5. **Flagship "peak moments" are flat + haptics nearly absent.** The 0–100 **swing score** (`SwingReportText.swift:69` `SwingScoreView` = static `Text`) and **doubles compatibility score** (`DoublesScoreViews.swift:13`) have no ring/count-up/haptic. Haptics exist only in Drill + Avatar; missing on swing score, match saved, doubles invite/accept/score, profile built.
6. **Reduce Motion not honored** in several animated screens: MatchAnalyzingView (`:109`), LevelProgressionPathView path pulse (`:239`), OnboardingBuildingView, Coach `thinkingDots`.
7. **Tap targets <44pt:** Home avatar 30pt (`HomeView.swift:133`), match rating dots 22pt (`MatchFormComponents.swift:182`), surface swatches 40×44, doubles pending-row icon buttons.

### Strategic flag (conversion + App Review risk)
**Value-after-commitment paywall.** After ~15 onboarding steps the app shows a **non-dismissible paywall** (`CourtIQApp.swift:160-166`); the only "win" before it is an informational profile reveal — zero free functional usage. Violates the Duolingo "deliver value before asking commitment" principle and risks App Review friction. Consider granting a thin free taste (1 drill / 1 quiz / 1 Coach message) before the wall.

---

## 4. Per-area highlights (top issues)

**Home (3.2)** — Strong action-first concept. Worst: dark mode + contrast + Dynamic Type (D4/D5/D10); avatar 30pt target; recent-strip uses a brittle `padding(.horizontal,-20)` bleed; no haptic when the score ring fills.

**Train (3.1)** — Hub genuinely de-cluttered, but: **TrainRecoverView is a hollow one-row corridor** (delete it; link Recover card straight to MobilityLibraryView); **Practice relocated the wall** (5 quiz tiles + 2 rows); **MobilityLibraryView never got the redesign** (text-heavy, `.plain` buttons, no motion/haptics); **locked Programs card navigates instead of gating**; component triplication (FeatureTile / CategoryCard / quizTile); hardcoded "8-Week Training Block" string.

**Matches (3.6)** — List + calendar are excellent (near-wordless, real empty states). But: ignores DesignSystem (hand-rolls everything); **Played form is long**; completed matches open the heavy 798-line MatchJournalEntryView; **12s forced "analyzing" hold** (`Task.sleep(12s)`) even when the network is fast; **no Reduce-Motion fallback** in MatchAnalyzingView; no success/error haptic on report reveal; no copy/share on the AI report; rating dots <44pt.

**Doubles (3.2)** — Invite loop is frictionless and well-architected, but **visually a generation behind**: zero DesignSystem adoption, **zero haptics**, and the compatibility **score renders as static `Text`** instead of `ScoreRing`. **Accept sheet ignores `status`/`alreadyMember`** from `peek()` → an already-accepted/expired code falls through to a raw server error instead of "You're already paired." Pending-row buttons <44pt.

**Coach·Onboarding·Paywall (3.4)** — Paywall is the best-built screen (fair, honest, on-brand, 3.8). Coach chat is strong (great empty state + animated typing indicator) but **has no quota-reached state** (`send()` ignores `remainingToday` → user types, waits, gets a generic error). Onboarding has a great labor-illusion + profile reveal but the **hard paywall** (strategic flag). No haptics; Reduce Motion ignored in building/result/typing.

**Me·Profile·Swing (3.5)** — Reformed but **ProfileView is still ~13 ungrouped sections** in one scroll (coherently styled, not coherently organized → group into Identity / Game / Progress / Account bands). **Swing result is the biggest single miss**: flat number, no ring/count-up/haptic/transition despite `ScoreRing` sitting one import away. Questionnaire length is fine; lacks tactile reward. Avatar locker is the area's best motion/haptic adoption.

---

## 5. Craft checklist — recurring gaps

Missing across most areas: haptics on key results (`.sensoryFeedback`); skeleton loading (naked spinners instead); Reduce-Motion guards; 44pt hit areas; dark-mode-safe colors. Present & good: empty states (Home/Matches/Swing/Coach), the Coach typing indicator, Drill haptics, save-before-analyze in Matches, the Paywall.

---

## 6. Remediation roadmap (by ROI)

### Wave 1 — Foundation (lifts every screen at once)
1. Make `AppPalette` adaptive (asset catalog or dynamic `UIColor` providers) with dark variants → fixes dark mode app-wide.
2. Darken `inkSoft` to ~RGB(74,70,64) for ≥4.5:1 on parchment/cream.
3. Replace fixed `.system(size:)` with semantic text styles (restore Dynamic Type); keep `.rounded` only for hero numerals + eyebrows.
4. Adopt DesignSystem app-wide (Eyebrow / PressableCardStyle / Motion / cards) in Matches, Doubles, Coach, Onboarding, Profile, Swing.
5. **Make the peak moments delightful:** route the swing score (`SwingScoreView`) and doubles score (`DoublesScoreView`) through `ScoreRing` (count-up + fill) + fire `.success` haptic on landing.

### Wave 2 — Per-area polish
- **Train:** delete TrainRecoverView (link Recover → MobilityLibraryView directly); gate the locked Programs card to the paywall; redesign MobilityLibraryView in the new language; collapse FeatureTile/CategoryCard/quizTile into one shared `LockableTile`.
- **Matches:** adopt DesignSystem primitives; shorten the Played form; drop the forced 12s hold (reveal as soon as the call returns past a short minimum); add report reveal haptic + copy/share affordance.
- **Doubles:** ScoreRing + haptics on create/accept/score; branch `peek()` on status (handle already-paired/expired); 44pt pending-row buttons; auto-reset "Copied".
- **Profile:** group the ~13 sections into 3–4 labeled bands (Identity / Game / Progress / Account).

### Wave 3 — Strategic & finishing touches
- Grant a thin free taste before the hard paywall (conversion + fairness + review safety).
- Coach quota-reached state (disable composer + "resets at…" banner).
- Reduce-Motion guards on all remaining animated screens.
- Enforce 44pt hit areas (avatar, rating dots, swatches).
- Skeleton/optimistic loading where content hydrates.

---

## Sources
Apple HIG (Typography/Color/Dark Mode/Layout/SF Symbols/Motion); Apple Design Awards 2023–25 (Flighty, Halide); Nielsen's 10 Usability Heuristics (NN/g); Laws of UX (Yablonski); _Refactoring UI_ (Wathan/Schoger); Dieter Rams' 10 Principles; teardowns of Things 3, WHOOP/Oura, Linear, Stripe, Duolingo, Robinhood, Headspace, Carrot Weather, Apple Fitness/Weather/Clock; Dan Saffer _Microinteractions_; AASP; SwiftUI motion/haptics references (Hacking with Swift, Sarunw, Swift with Majid, createwithswift).
