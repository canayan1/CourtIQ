# Wall mechanism — audit (28 Aug 2026)

*The question asked: does the mechanism cohere, can the tech actually detect
wall drills, is the ladder educational and achievable, does it adjust to the
player? Findings first, verdicts second, what was fixed and what only a real
wall can answer, last.*

---

## 1. Findings

### CRITICAL — a rung that could never be cleared (FIXED)

**First Strike** is a sequence drill: feed hard, hit one aggressive ball,
fetch, re-feed. The fetch takes longer than the 3-second rally-gap rule, so
the streak reset on every sequence — `maxStreak` could reach 2–3 against a
goal of 15. **The rung was mathematically impossible** with the paid referee;
a player who bought premium would meet an unwinnable red screen. Same class
of problem, milder: **Reset Ball**'s slow high arcs have a >3s cycle, so even
honest play couldn't hold a streak.

Fix shipped: drills now declare how they are graded. Continuous-rally drills
(Steady, FH↔BH, Volley, Depth, Approach, Figure-8) demand the goal **in a
row** — the streak is the exercise. Sequence drills (First Strike, Reset)
grade **total hits this session**. The HUD, the gate and the "verified" line
all follow the drill's own grading.

### CRITICAL — duration rungs were invisible to the referee (FIXED)

Volley (45s) and Reset (60s) had duration targets; the gate only graded rep
goals, so `goal = nil` → no verdict → **the premium referee could never clear
those two rungs** and the honour button remained the only path. Both are now
rep-based (volley 20 in a row, reset 12 total), one mechanism everywhere.

### HIGH — one rep is up to three sounds (MITIGATED, needs the wall)

A wall cycle produces up to three impulsive sounds — racquet contact, wall
thud, floor bounce — typically 0.1–0.3s apart, all inside the mic's band.
At `refractory = 0.14s` the detector could count each separately, **silently
inflating every goal ~2–3×** (and polluting the zone tally: a floor bounce
reads LOW, logging phantom NETs). Raised to **0.45s**, which merges
racquet+wall while staying under the fastest realistic close-range volley
cadence (~0.6s). The floor bounce can still fall outside the window; whether
it crosses the adaptive threshold in practice is **the single most important
thing to verify on a real wall.** If field sessions overcount, the next step
is cadence clustering (group sounds within ~0.5s as one rep), not more
threshold guessing.

### MEDIUM — the player occludes the wall (COPY MITIGATION)

The phone sits behind the player; the ball strikes the wall roughly in front
of them — often exactly where their body blocks the camera. Expect
`unknown`-heavy sessions and therefore gold-heavy seals. The gate absorbs
this by design (gold clears; unknown never punishes). Setup copy now says to
place the phone **a step to the side, so it sees past you** — the cheapest
real improvement. Watch `unread` in analytics.

### MEDIUM — which sound anchors the camera read (OPEN)

The locator looks ±50ms around the counted sound. If the counted sound is
the racquet contact (loudest, nearest the phone), the ball at that moment is
at the PLAYER, not the wall — reads would come back unknown or wrong. If the
wall thud dominates, reads are anchored right. Which one wins is acoustics,
unknowable from a desk. If field zone-splits look nonsensical, widen the
locator's search asymmetrically forward (+0.35s after the counted sound, when
a racquet-anchored ball is arriving at the wall).

### The rest of the coherence sweep — clean

- Placement can upgrade or hold a verdict, never fail one; `unknown` never
  shows as failure; the streak belongs to the mic alone. Consistent
  throughout.
- Seals only improve; a level change rescales targets but never revokes
  seals or re-locks rungs (`clearedDrills` is id-based).
- Verdict reasons, HUD pill, big counter and the "verified" line all read
  from the same `goalProgress` — no screen disagrees with another.
- Free rally and duration-less sessions produce no verdict and skip the
  gate, as before.

---

## 2. Can the tech detect a wall drill at all?

Honest capability table:

| Claim | Sensor | Status |
|---|---|---|
| A ball was hit (rep) | mic | **yes** — modulo the multi-sound risk above |
| Reps in a row / totals | mic + clock | **yes** |
| Height at impact (net / band / long) | camera at mic's timestamp | **beta** — occlusion + anchor-sound risks, degrades to `unknown` |
| Left/right placement | camera | possible later (locator already returns x) — not graded |
| Which stroke (FH vs BH) | — | **no.** Neither sensor can. Said openly on the level screen; Apple Watch (wrist IMU ~98%) is the planned verifier |
| Footwork quality (Approach drill) | — | **no** — honour |

So: the tech CAN referee "N hits (in a row) with the ball between the
lines," which is exactly what the ladder now asks of it. Everything beyond
that is labelled honour, not silently pretended.

---

## 3. Is the ladder educational and achievable?

Mapping against the motor-learning evidence (blocked → variable,
`WALL-PRACTICE-PLAN.md` §3):

| # | Drill | Grading | Club target | What it adds |
|---|---|---|---|---|
| 1 | Steady Rally | streak | 10 | blocked baseline — right |
| 2 | FH↔BH | streak | **14** (was 20) | first variability step |
| 3 | Quick-Hands Volley | streak | 20 | tempo/hands |
| 4 | Depth High↔Low | streak | 20 | self-called variability (CI) |
| 5 | Reset Ball | **total** | 12 | pressure habit |
| 6 | First Strike | **total** | 15 | decision before contact |
| 7 | Approach & Recover | streak | 18 | movement under time |
| 8 | Figure-8 | streak | 24 | fine control |

Changes made for achievability: rung 2 was a cliff (10 blocked → 20
alternating; alternation roughly halves control, so it was ~4× harder than
rung 1) — now 14. Rungs 5–6 became winnable at all (grading fix). The red
screen stays kind by design: "The wall is patient," retry right there, and a
gold pass can never be taken away by the beta camera. Discouragement risk
now sits mainly in field miscounting, not in the ladder's shape.

---

## 4. Does it adjust to the player's level?

Now, yes — two dials:

1. **Targets scale to the self-rated onboarding level** (beginner ×0.7,
   club ×1.0, advanced/coach ×1.3, floor 5). Beginner's rung 1 is 7 in a
   row; advanced faces 13. The self-rating is the honest source — the in-app
   TennisPlayerLevel is quiz-derived and says nothing about a forehand.
   Displayed target, HUD and gate all use the scaled number.
2. **The band itself is a difficulty dial** — dragging the lines wider is
   easier, tighter is harder, and it's per-wall persistent.

Not done, deliberately: auto-adjusting targets from results (needs field
data first) and per-drill band presets (wait for `unread` rates).

---

## 5. What only a real wall can answer

1. Does one rep count once? (multi-sound; watch the counter vs. reality)
2. Zone split sanity — all-unknown means occlusion/anchor; all-NET means
   floor bounces are being read.
3. Net-line measurement vs. a tape measure.
4. Whether 0.45s eats any legitimate quick-volley reps.

Session analytics carry `hits`, `total`, `in_band/net/long/unread` — the
tuning loop is wired.
