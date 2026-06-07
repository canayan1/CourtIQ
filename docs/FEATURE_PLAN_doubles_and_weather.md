# CourtIQ — Feature Plan: Doubles Compatibility + Weather Advice

Status: **planning only — not for the 1.0 resubmission.** Build 13 (the
rejection fix) ships first. These land in later versions.

- **1.1 → Doubles Compatibility** (free hard-coded test + score + prep
  sheet; AI doubles game-plan is premium). Two-device via the existing
  Coach Mode pairing.
- **1.2 → Weather-aware pre-match advice** (free conditions + static tips;
  AI personalized advice is premium). WeatherKit.

---

## Decisions locked with the owner

| Question | Decision |
|---|---|
| Timing | Ship 1.0 first; Doubles = 1.1; Weather = 1.2 |
| Doubles scope | **Two-device** (reuse Coach Mode MultipeerConnectivity pairing) |
| Premium split | AI parts = premium; deterministic/hard-coded parts = free |
| Weather | Deferred to 1.2 (entitlement + location + privacy-label cost) |

---

## FEATURE 1 — Doubles Compatibility (1.1)

### Why this feature
- The pre-submission tennis-coach audit explicitly flagged **doubles as a
  near-total content gap** (only 1 of 75 drills touches it). This fills a
  real hole, not a vanity add.
- It is inherently **social/viral**: you need a partner, so the natural
  next action is "invite/scan your partner" — a built-in growth loop.
- Strong free→premium ladder: the test + score + a static prep sheet are
  free and genuinely useful; the AI game-plan is the paid upgrade.

### Reuse: Coach Mode already gives us the hard part
`CourtIQ/Features/CoachMode/CoachSession.swift` already implements, over
MultipeerConnectivity:
- `MCSession` with `.required` encryption, host/guest **roles**, QR-based
  pairing via `discoveryInfo["session"] == sessionID`
  (`CoachPairView.swift`).
- A `Submission: Codable` payload exchanged both ways, with a
  `bothSubmitted` state and a reveal screen (`CoachReveal.swift`).

Doubles is the **same choreography** with a different payload + a scoring
step. We fork/generalize CoachSession rather than writing MC from scratch.

### Data model — the compatibility questionnaire (each player answers)
Plain enums, no free text (so scoring is deterministic). Proposed
`DoublesProfile: Codable`:

| Field | Values | Drives |
|---|---|---|
| preferredSide | deuce / ad / either | side assignment + conflict detection |
| netComfort | loves net / mixed / baseline | net coverage balance |
| poachTendency | aggressive / selective / holds | who hunts the middle |
| communication | very vocal / moderate / quiet | comms-style match |
| pressureShot | goes for it / percentage / defensive | risk-style match |
| formationComfort | standard only / I-formation & Australian ok | tactical range |
| handedness | right / left | lefty+righty = two forehands in the middle |
| serveStrength | 1–5 | serve order |
| returnStrength | 1–5 | return-side assignment |

(8–9 quick taps per player — keep it ≤60s.)

### Scoring engine — FREE, hard-coded (`DoublesCompatibility.score(a:b:)`)
Pure function over the two profiles. Real doubles principles:
- **Side fit**: both want the same side → conflict (−); complementary or
  one "either" → (+). Surface "who takes which side."
- **Handedness**: lefty + righty → classic advantage, two forehands meet
  in the middle (+). Two of the same → note backhand-middle vulnerability.
- **Net coverage**: net-lover + all-court = balanced (+); two
  baseline-only = weak at net (−, and say so honestly).
- **Risk/comms alignment**: matched risk appetite and comms style (+);
  mismatch flagged as "agree on who calls the middle ball."
- **Serve order / return sides**: from serve/return strength.
Output: `DoublesResult` →
- `score` 0–100 + a short band label ("Strong fit" / "Workable" / "Needs
  a plan").
- per-dimension breakdown (green/yellow/red + one-line why).
- **Hard-coded prep sheet**: who serves first, who returns which side,
  starting formation, the team's 2 biggest strengths and 1–2 watch-outs.
All of this is free and works with zero network/AI.

### Premium layer — AI doubles game-plan
When a premium user taps "Get the AI game-plan," send to the `ai-chat`
edge function a new context block:
- both `DoublesProfile`s + the deterministic `DoublesResult`
- each player's existing singles play-style + tactical profile + recent
  match context (already in the AI context for the local user; the
  partner sends a compact snapshot over MC).
AI returns: a personalized doubles game-plan, how to cover the team's weak
dimension, optional opponent-specific adjustments ("vs a lobbing team…"),
and a follow-up Q&A. This rides the existing premium AI-Coach gate and
the existing serialization (extend the context payload + tennis_manual
with a doubles section).

### Two-device flow (reusing Coach Mode)
1. Player A opens Doubles → "Test with a partner" → hosts, shows QR
   (CoachPairView pattern).
2. Player B scans → joins the session.
3. Each fills their `DoublesProfile` on their own phone.
4. On `bothSubmitted`, **both** devices compute the same deterministic
   `DoublesResult` (pure function → identical on both) and show the
   reveal. No server needed for the free result.
5. Premium user can then request the AI game-plan (their device calls
   ai-chat; partner snapshot already exchanged over MC).
   - Single-device fallback: also allow one person to fill both profiles
     (so a solo user can still try it). Cheap to add, removes the
     "needs two phones right now" friction for first use.

### New work (1.1)
- `DoublesProfile`, `DoublesResult`, `DoublesCompatibility` (pure scorer) — unit-testable.
- Generalize `CoachSession` to carry a `DoublesProfile` payload (or a
  sibling `DoublesSession` reusing the same MC plumbing).
- UI: entry card, questionnaire, QR pair screen (reuse), reveal/score
  screen, prep sheet, AI game-plan screen (premium-gated).
- AI: extend `AIChatContextPayload` with a doubles block; add a doubles
  section to `tennis_manual.ts`; deploy edge function.
- Content: a doubles section is also a chance to add the missing doubles
  drills/quizzes the audit flagged (separate, optional).
- **Tests**: the scorer must have unit tests (the AI-serialization bug we
  just fixed shows why — verify the payload round-trips).

### Risks / watch-outs
- App Review: new IAP-gated AI surface — keep the free test genuinely
  usable so it's not a paywall-only feature.
- MC reliability: Coach Mode already handles disconnect states; reuse them.
- Keep the questionnaire short or completion drops.

---

## FEATURE 2 — Weather-aware pre-match advice (1.2)

### Concept
When a user logs a pre-match entry for an **outdoor** match, fetch the
forecast for the match location + time and surface tennis-relevant advice.

### Real tennis↔weather basis (sound)
- Wind → toss adjustment, which end to attack, higher margin into wind.
- Sun → which end to serve from, watch lobs/high balls.
- Heat → hydration, shorter points, grip sweat.
- Cold → longer warm-up, lower bounce/flight, injury risk.
- Humidity → heavier ball, slower court.

### Free vs Premium
- **Free (hard-coded)**: show conditions for match time (temp, wind, sun)
  + a static lookup-table tip ("Windy — add margin, attack with the wind").
- **Premium (AI)**: blend the user's game + weaknesses + the specific
  conditions into personalized advice via ai-chat.

### Real costs (the reason it's 1.2, not 1.1)
- **WeatherKit entitlement**: enable in Developer portal + Xcode
  capability (free tier 500k calls/mo). Client fetches (entitlement is
  app-side), then passes structured weather into the ai-chat context.
- **Apple legal attribution**: must show "Apple Weather™" + the required
  data-source link in the UI (non-negotiable).
- **Location**: either CoreLocation (permission prompt → **must update
  the App Privacy nutrition label**, which we just published) OR let the
  user type the court/venue and geocode it. Because a match may be
  elsewhere/later, a **location field + match-time forecast** is actually
  more accurate than current-location.
- **Privacy label update + new permission string** → another review
  touch-point.

### Why later
Medium value (a "delight"/demo feature, not a retention driver) but high
plumbing cost (entitlement + location + privacy-label change). Ship after
Doubles proves out.

---

## Sequencing summary
1. **1.0** — in review now (rejection fix: Apple sign-in, IAP, AI-Coach
   pricing model, content/UX audit fixes). Build 13.
2. **1.1** — Doubles Compatibility (this plan).
3. **1.2** — Weather-aware advice (this plan), + optional two-device
   doubles polish and the doubles drills/quizzes the audit wanted.
