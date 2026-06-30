# DropVolley — Product & Monetization Strategy

> Owner-approved direction (Jun 2026). This is the canonical strategy doc. The
> 1.0.2 "relaunch" build executes the freemium pivot below. Supersedes the
> hard-paywall model noted in older docs.

## 1. Thesis (the one thing we sell)
**DropVolley = a personal AI coach that knows your whole game.**

Everything ladders to that. Injury-awareness, gear, movement, doubles, quizzes,
match logs are **not separate towers** — they are **inputs to, or lenses of,
that one coach.** The #1 way apps in this space die is scope creep; every feature
must pass one test: *does it feed the coach / the Tennis-IQ positioning?*

## 2. Positioning / moat — the uncontested lane
Two independent research passes agree: **the entire tennis-app market sells
"video → fix your strokes"** (SwingVision 4.7★/~4.7K and a crowded field of
AI-swing apps; plus $700–1,499 hardware ball machines — Tenniix, Volley,
Tennibot, PONGBOT, Acemate). We **do not** win that war.

**The "Tennis IQ / strategy / decision-making / doubles" lane is essentially
unclaimed** (the one occupant, "Tennis IQ — Mind & Match Coach," has ~37 ratings,
no video, no quizzes, no doubles). That is our moat: **"what shot, why, and when"
— the tennis brain**, plus a coach that personalizes off *your* data.

## 3. Monetization — freemium split by COGS (not by value)
Our "free" usage is **not free to serve** — every AI call costs real money
(Anthropic / Gemini). So the split is by **cost to serve**, not by how valuable
a feature is:

| Tier | What | COGS | Purpose |
|---|---|---|---|
| **Free (≈$0)** | scenario quizzes (Tennis IQ), strategy/doubles content, tips, FAQ; **match logging + AI match commentary**; **AI doubles analysis**; tennis profile, **gear profile**, goals | ~$0 — match/doubles use the **FREE Gemini key** | brand, **ratings**, ASO discoverability, habit, **data that feeds the coach**, and a hook that **sells the premium coach** |
| **Taste (once)** | 1 free swing analysis + a few coach messages | ~$0.10 once | the "wow" → drives upgrade |
| **Premium (money-burners)** | **unlimited AI coach** (Anthropic) + **AI swing analysis** (paid video key; + injury-awareness lens) | variable | core revenue |

> **Governing rule (owner): "para yakan premiumda kalsın" — only what burns money is premium.** The money-burners are the **AI Coach** (Anthropic) and **AI swing analysis** (paid Gemini *video* key). **Match & doubles analysis run on the FREE Gemini key (~$0) → they stay FREE** — and free AI match commentary is the strongest hook to sell the premium Coach ("a coach that remembers all your matches"). Caveat: the free key has a shared quota; if it becomes a constraint at scale, add per-user caps or move those to the paid key (then they become premium).
| **Pro (later, separate tier)** | AI Drill Coach (wall/court drills, session score, Apple Watch) | +Gemini | higher ARPU upsell |

Why this and not a hard paywall: a hard paywall + 0 ratings is a **death spiral**
(nobody experiences value → no ratings → no social proof → no conversion → no
downloads) **and** gives away nothing measurable. Free *content* (which costs ~$0)
breaks the spiral and is the funnel that **sells** the AI. The expensive AI stays
paid. Match logs are the free hook **and** the data moat: the more you log, the
more personal (and sellable) the coach becomes.

## 4. How we sell the AI coach + match logs
- **Match log = free hook + data moat + stickiness.** Logging is cheap → free →
  builds habit and the history that lives in the app. We sell the coach *reading*
  that history, not the logging.
- **AI coach = paid centerpiece.** Pitch: *"a coach in your pocket that knows
  YOUR game"* — reads your logged matches, quiz weaknesses, profile, gear.
- **Funnel:** free quiz exposes a weakness → *"want your AI coach to build a plan
  around this? → upgrade."* Logs accumulate → *"your coach spotted a pattern
  across your last 5 matches — upgrade for the full plan."*

## 5. Feature decisions (market-critiqued — not blanket-accepted)
- ✅ **Pre/post-match log + AI commentary** — keep; strongest asset (the coach's memory).
- ✅ **Tennis IQ + doubles strategy (quizzes/content)** — the moat; **free**.
- 🟡 **Movement** — ship as **content** (tips/quizzes/strategy), **free**. Do **not**
  promise AI video analysis of footwork — a phone can't measure it reliably
  (see AI-DRILL-COACH.md: footwork = Level 2 / camera). Overpromising = bad reviews.
- 🟡 **Injury-awareness** — real gap (no consumer tennis app flags "this swing may
  hurt you"; technique→injury is medically grounded). Ship as an **educational
  lens inside swing analysis**, *never* diagnosis: *"this pattern is associated
  with elbow strain — not medical advice; see a professional if you have pain."*
  Strong **liability / App-Store-health-claim risk** → AI must hedge; reuse the
  existing HealthAcknowledgment gate. Conservative framing only.
- 🔴 **Equipment / string tracking** — the dedicated niche is **solved & crowded**
  (RacquetTune, RacquetTuner, StringTracker, Stringster — some even measure
  tension by sound). Do **not** build a tracker. Ship only a **minimal gear
  profile** (racket / string / last-restring date) as a **coach input**
  (*"your strings are 4 months old — that can cost control and stress your elbow"*).
  Small, in service of the coach.

## 6. Architecture note — the relaunch is mostly *removing* a bolt-on
The codebase was already built for this model:
- Content surfaces gate on `UserSessionManager.isPremiumUnlocked`, which is
  **hardwired `true`** (`UserSession.swift:336`) → content is already "free."
- The **AI Coach already gates** on the real entitlement (`AICoachTabRoot.swift:27`).
- A **root hard-paywall** (`CourtIQApp.swift:234`) was bolted on top and blocks the
  whole app → that single gate is what makes it hard-paywall today.

**So the relaunch = remove the root gate (free entry) + gate the money-burning AI
(swing analysis — paid video key; Coach already gated). Match/doubles use the FREE
Gemini key → they stay free.** Content stays free automatically.

**Status (implemented, build green):** root paywall removed (`CourtIQApp.swift`) →
free entry; swing analysis gated on `entitlementState.isPremium` with a paywall,
**first analysis free** (`FreeTaste.swingUsed`); `RatingPrompt`/`requestReview` wired
to the quiz win; match/doubles free; Coach already gated. (DEBUG auto-grants premium
so dogfooding is unaffected.) Remaining: RevenueCat server enforcement (needs keys),
ASO metadata (after 1.0.1 clears review), Firebase, coach "taste".

## 7. Build sequencing
- **1.0.1** — in App Review (camera-crash + UX fixes). Do not touch.
- **1.0.2 = "relaunch" (highest impact):**
  1. Remove root hard-paywall → **free entry** (`CourtIQApp.swift:234`).
  2. ✅ Gate **swing analysis** on `entitlementState.isPremium` (+ paywall) — paid
     video key. Coach already gated. **Match/doubles stay FREE** (free Gemini key).
  3. RevenueCat server-side entitlement (already coded; needs keys) — verifies premium.
  4. ASO metadata overhaul (subtitle + keyword field — own "Tennis IQ/strategy/doubles").
  5. `requestReview()` at a genuine win moment.
  6. Firebase/Google Analytics.
- **1.1 = coach personalization:** gear-profile input + injury-awareness lens in
  swing analysis + movement *content*.
- **1.2+ = AI Drill Coach** (separate Pro tier — see AI-DRILL-COACH.md).

## 8. Open decisions
- **"Taste" limits:** exact free allowance (proposed: **1 swing analysis + 3 coach
  messages** before the paywall).
- **Premium non-AI perks:** do the existing "premium training tracks" become
  **free content** (thesis-consistent) or stay a **premium perk** to pad the
  subscription's value beyond AI? (Recommend: free, keep premium = AI-only and clean.)
- **Tier model for Drill Coach:** (A) Pro upgrade vs (B) parallel add-on (RevenueCat does both).
