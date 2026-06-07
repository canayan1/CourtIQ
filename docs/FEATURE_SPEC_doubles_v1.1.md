# CourtIQ v1.1 — Doubles Compatibility (detailed spec)

Status: **design locked, pre-implementation.** Ships as v1.1 AFTER 1.0
clears review. Build on a fresh branch; do not touch the in-review 1.0.

## Locked decisions
- **Vision:** personal trainer + strong doubles tool (NOT a social platform).
- **Pairing model: A.5** — on-court QR pairing (reuse Coach Mode /
  MultipeerConnectivity) **plus** a remote invite link (light backend),
  for async fill. No social graph (no accounts-add-each-other, no
  Guideline 1.2 UGC surface).
- **Placement:** a new top-level **Doubles** section/tab.
- **Persistence:** partnerships saved to the user's own account (synced)
  + local cache. Multiple partners supported; re-testable.
- **Monetization:** test + deterministic score + static prep sheet =
  FREE. AI doubles game-plan = PREMIUM (the one paid feature, same as the
  AI Coach gate).

---

## 1. User experience

### Entry: Doubles tab
- Empty state: "Test how you and your partner play together." → CTA "New
  partnership."
- Populated: list of saved **Partnerships** (partner name, compatibility
  score, last tested date). Tap → partnership detail (score, breakdown,
  team setup, prep sheet, AI plan if premium). "Re-test" button.

### New partnership — two ways
1. **On-court (QR):** "My partner is here" → host, show QR. Partner: "Join
   a test" → scan. Both phones connect over MultipeerConnectivity (works
   offline). Each fills the 8-question survey in parallel. On `bothSubmitted`,
   **both devices compute the same deterministic result** and show the reveal.
2. **Remote (invite link):** "Send an invite" → generates a code/link.
   Partner opens it → fills their half → it syncs back to the host's
   pending partnership. Host gets notified, result computes. (Backend: a
   short-lived `doubles_sessions` row keyed by code.)
- **Single-device fallback:** "Fill both myself" — one person answers both
  halves (their perception of the partner). Lowest friction for first try.

### Reveal / result
- **Compatibility score 0–100** + band: Strong fit (80+) / Workable
  (60–79) / Needs a plan (<60).
- **Per-dimension breakdown:** each dimension green (synergy) / yellow
  (manageable) / red (clash) + one-line why.
- **Team setup card:** who serves first, who returns deuce vs ad, starting
  formation.
- **Strengths (top 2)** and **Watch-outs (1–2)**.
- **Free:** static prep checklist mapped to weak dimensions (links to real
  in-app drills where relevant).
- **Premium:** "Get the AI game-plan" → personalized plan.

---

## 2. Data models (client)

```
DoublesProfile (Codable)   // the 8 answers, exchanged peer-to-peer or via link
  preferredSide: deuce | ad | either
  netComfort: net | mixed | baseline
  poach: aggressive | selective | holds
  comms: vocal | some | quiet
  pressure: goForIt | percentage | defend
  formation: flexible | standardOnly   // I-formation/Australian comfort
  handedness: right | left
  serveStrength: 1...5
  returnStrength: 1...5

DoublesResult (Codable)    // pure function of (profileA, profileB)
  score: Int               // 0..100
  band: strong | workable | needsPlan
  dimensions: [ {key, rating: green|yellow|red, note} ]
  serveFirst: A | B
  deuceReturner / adReturner: A | B
  startingFormation: String
  strengths: [String]
  watchOuts: [String]

Partnership (Codable, persisted to account)
  id, partnerName, createdAt, updatedAt
  myProfile: DoublesProfile
  partnerProfile: DoublesProfile
  result: DoublesResult
  aiPlan: String?          // cached premium output, optional
```

---

## 3. Deterministic scoring engine (FREE) — the heart

`DoublesCompatibility.score(_ a: DoublesProfile, _ b: DoublesProfile) -> DoublesResult`
Pure, unit-tested, identical output on both devices. Real doubles logic:

| Dimension | Weight | Rule |
|---|---|---|
| **Court-side fit** | 25 | complementary (one deuce/one ad) or an "either" → green; both same fixed side → red (one must play their weak side); both "either" → yellow-green |
| **Net/baseline balance** | 20 | net-lover + all-court/baseline → green (someone owns net); both baseline-only → red (weak at net — say so); both net-lovers → yellow (aggressive but lob-vulnerable) |
| **Comms alignment** | 15 | both vocal / compatible → green; vocal + quiet → yellow ("vocal one calls the middle"); both quiet → red ("agree who takes the middle ball") |
| **Risk/pressure** | 15 | matched → green; opposite → yellow (can complement, name it) |
| **Formation range** | 10 | both flexible (I-formation/Australian) → green; standard-only → yellow |
| **Handedness synergy** | 10 | lefty + righty → green bonus (two forehands meet in the middle / both cover alleys with forehands); same → neutral |
| **Serve cohesion** | 5 | minor; mostly feeds serve order, small bonus if both serveStrength ≥ 3 |

Score = weighted sum normalized to 0–100. Band by thresholds above.

**Recommendations (derived, not scored):**
- **Serve first:** higher `serveStrength` (ties → either). Rationale shown.
- **Return sides:** honor preferences; on clash, the higher-`returnStrength`
  / more clutch player takes **ad** (more game-deciding points: deuce, ad).
- **Starting formation:** both net → both-up; balanced → one-up-one-back
  with poaching; both baseline → start back, look to approach together.

---

## 4. Static prep sheet (FREE)
Map each red/yellow dimension → a concrete fix + (where possible) an existing
CourtIQ drill. Examples:
- both baseline-only → "Own the net as a team: approach together on short
  balls." → drill pointer.
- comms red → "Pre-agree: middle ball belongs to the forehand / the player
  moving toward it."
- side clash → "Practice the I-formation so the server's partner doesn't
  telegraph the side."

---

## 5. Premium AI game-plan
Reuse the existing premium AI gate + `ai-chat` edge function. Add a doubles
context block (both `DoublesProfile`s + `DoublesResult` + each player's
singles tactical/play-style + the local user's match memory) and a doubles
section in `tennis_manual.ts`. AI returns: a personalized plan, how to cover
the team's weakest dimension, optional opponent-team adaptation, and follow-up
Q&A. Partner's singles history is NOT pulled (no social graph) — the partner's
8 answers + the result are the cross-player signal; the local user's full
profile still feeds it.

---

## 6. Backend (Supabase) — minimal
- `doubles_sessions` (for the remote invite only): `code` (short, unique),
  `host_user_id`, `host_profile` (jsonb), `guest_profile` (jsonb, null
  until filled), `status`, `created_at`, short TTL. RLS: host reads own;
  guest writes their half via the code (function or scoped policy). No
  persistent cross-user link.
- `doubles_partnerships` (saved partnerships): `id`, `user_id`,
  `partner_name`, `my_profile`, `partner_profile`, `result` (jsonb),
  `ai_plan` (text, null), timestamps. RLS: owner-only (`auth.uid()`).
- On-court (QR) path needs **no** backend — MC exchanges profiles
  peer-to-peer; the result is computed locally and saved to
  `doubles_partnerships`.

---

## 7. App Store / privacy
- A.5 shares two consenting parties' 8 answers via a code or peer-to-peer —
  not public UGC, no persistent social connection → **no Guideline 1.2
  (UGC) obligations** (no block/report/moderation needed).
- Privacy nutrition label: the invite path stores questionnaire answers
  (User Content) tied to the account — already covered by the existing
  "User Content / linked to identity" declaration; re-confirm at submit.

---

## 8. Implementation sequence (when we build)
1. Models + **deterministic scorer with unit tests** (pure, no UI) — lock
   the logic first.
2. Doubles tab + questionnaire UI + reveal/result + static prep sheet
   (single-device fallback first — testable without two phones).
3. On-court QR pairing (generalize `CoachSession`).
4. Remote invite link + `doubles_sessions` backend.
5. Persistence (`doubles_partnerships` + local cache + sync).
6. Premium AI game-plan (extend `ai-chat` context + `tennis_manual`).
7. Optional: seed doubles drills/quizzes (fills the audit's doubles gap).
- Branch: `feat/doubles-v1.1` off main (after 1.0 is approved/merged).
