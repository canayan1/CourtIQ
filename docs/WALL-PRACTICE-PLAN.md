# Wall practice — where it is, and how to build the target ladder

*27 Aug 2026. Audit of what ships today + research on the foul-line / too-high
idea and on level design.*

---

## 1. What actually exists today

| Piece | State |
|---|---|
| 8 curated drills (`WallDrill.all`), reps- or duration-targeted, with a tempo pacer | shipped |
| `WallProgressManager` — per-drill personal bests, times completed, cleared-drill set | shipped |
| Level ladder plumbing (`clearedDrills`, `markCleared`, `isCleared`) | **plumbing only — no ladder UI** |
| Rally Cam: counts hits, tracks current + best streak, contributes to the activity streak | shipped, works |
| Counting method | **audio (microphone impact peaks)** |
| `VNDetectTrajectoriesRequest` + in-target/out-of-target scoring + `accuracy` % | **written, but disabled in practice** |

Two things in that table matter.

### 1a. Vision was tried and abandoned

The code says so plainly:

> *"A wall impact heard by the mic — the primary, placement-independent hit
> counter (Vision trajectory detection proved too finicky for this setup)."*

So `registerImpact(at:)`, the target square, and the `accuracy` percentage are
all live code fed by a path that doesn't fire reliably. The target is also
**auto-locked to wherever the first ball happens to land** — it isn't a target
the player chose, which is the opposite of what a target is for.

### 1b. A debug HUD is shipping to users

`WallRallyCamView.swift` renders this over the camera, in green monospace, with
**no `#if DEBUG` anywhere in the file**:

```
SOUND hits: 12
peak 0.43   hold 0.61
triggers @ 0.28
```

Its own comment calls it "DEBUG readout (temporary)". It is in the App Store
build. This should come out before anything else here.

---

## 2. Your idea: a foul line and a too-high zone

### 2a. Coaching says you're right

This is standard wall practice, not an invention. Coaching sources recommend
**painting lines on the wall** to mark net height and service-box depth, and
purpose-built practice walls ship with **line markings, target zones and
colour-coded scoring**. Judy Murray's wall progression is literally *"keep
count of how many you can get in a row and aim for a set target which you can
make higher as you progress."*

The motor-learning evidence is even more supportive, and for a specific
reason: **external focus of attention**. Directing a learner's attention to
the *target and the ball* beats directing it to *their own body* — repeatedly,
across studies, including tennis and table-tennis accuracy tasks with
low-skilled players. A band on the wall is an external focus made physical.

Useful check: the existing drill copy is **already** external-focused
("controlled shots to the SAME spot at the same height", "arced well above the
net band", "pick the target BEFORE you hit"). Nothing to fix there — and note
that "net band" is already promised in the copy while nothing measures it.

### 2b. Why the current vision path failed, and the way around it

`VNDetectTrajectoriesRequest` fits **parabolic** trajectories — it is built for
a thrown ball or a fired arrow. A ball rebounding off a wall *toward the
camera* does not trace a clean parabola in the image plane. That is a very
plausible reason it "proved too finicky" here: the drill is being asked of an
API whose core assumption the motion violates.

**The inversion that makes your idea tractable:**

The audio path already gives you the one hard thing — the **exact moment** of
each wall impact — and it works today. What you're asking for is not
continuous ball tracking. It is a **single vertical position at a known
instant**:

> below the line → net · in the band → good · above the top line → sailing

So: **audio triggers, vision answers one narrow question.** At each audio
impact, look at the two or three frames around that timestamp on a stationary
camera and find the ball — the brightest fast-moving blob against a static
background. Frame differencing on a fixed camera at a known moment is a far
smaller problem than fitting trajectories continuously, and it degrades
gracefully: if the ball can't be found in those frames, the rep still counts
(audio heard it) and the placement is simply **unknown**, not wrong.

That "unknown" state is the same idea as the swing spec's `unclear`, and it is
what keeps this honest. A rep with no placement reading is still a rep.

**Don't detect the lines — let the player set them.** Two draggable lines on
the camera preview before the session starts, remembered per wall. Zero CV,
zero error, and it matches how coaches actually do it (tape or paint on the
wall). It also handles the thing automatic detection could never know: the
right height depends on how far back the player is standing.

**Make the zones mean something in tennis**, not arbitrary colours:
- below the line → the ball hit the net
- in the band → a driving ball that clears and lands in
- above the top line → the ball would be sailing long

That is a real translation from wall to court, and it is what makes the red
worth avoiding.

### 2c. Left/right

You said left/right is fine — agreed, and worth keeping it that way. Horizontal
placement is the axis the current auto-target already implies, and it's easier
than height. Height is where the tennis meaning is.

---

## 3. Level design — what the evidence says

Your instinct ("10 reps, 20 reps, record it, level by level") is sound. The
research adds one refinement about *what varies* as levels rise.

**Contextual interference**: blocked practice (same shot, over and over)
produces faster in-session gains but **worse retention**; randomised/variable
practice performs worse during practice but retains and transfers better. The
nuance that matters here: for beginners still "getting the idea of the
movement", blocked practice is the right start — variability too early doesn't
help.

So the ladder should escalate along **two** axes, not one:

| Level | Reps in a row | What varies |
|---|---|---|
| 1 | 10 | nothing — same shot, band only. Blocked. |
| 2 | 20 | same shot, tighter band |
| 3 | 20 | alternate forehand / backhand |
| 4 | 30 | height called on each ball (high / low) |
| 5 | 30 | randomised — the app calls the shot |

Levels 1–2 are blocked because that is what beginners need. Levels 3+ introduce
contextual interference deliberately, which is where retention comes from. The
existing drill set already covers most of these — `Steady Rally`,
`Forehand ↔ Backhand`, `Depth Control` map onto rungs 1, 3 and 4 almost
directly. The ladder is mostly a matter of ordering and gating what exists.

**"In a row" is the right unit.** A streak breaking on a miss is what makes the
target consequential, and `maxStreak` is already tracked and recorded.

---

## 4. Build order

**P0 — take the debug HUD out.** One `#if DEBUG`. It ships today.

**P1 — the line, without any new computer vision.**
1. Two draggable lines on the preview, saved per wall.
2. Keep counting on audio exactly as now.
3. Show the band as an overlay during the rally. Even with no placement
   detection at all, a visible target changes where the player looks — which
   is the whole external-focus benefit, and it costs nothing.

**P2 — placement. DONE (1.0.6), REBUILT (2 Sep) — see WALL-AUDIT.md §6.**
`WallBallLocator` keeps a second of 120×160 luma frames, builds a background
from a per-pixel median of frames from before the ball arrived, thresholds the
difference and flood-fills what survives. Blobs over 5% of frame are the
player; blobs stretched past 5:1 are an arm or a shadow. The largest survivor's
centroid height is classified against the player's lines. Weak or missing
blobs report `unknown`, which never shows as a failure and never touches the
streak — the mic gives the rep, the camera only reports.

**The net line places itself. DONE (1.0.6).**
There is no way to recover metric scale from one photo of a wall — but a
person standing against that wall is a known length in the same plane. Their
feet mark the ground, their head marks their height, and the pixels between
convert metres to screen units where we need it. `WallNetEstimator` runs
Vision body pose on one frame after a five-second countdown and puts the lower
line at 0.914 m — a singles net at the centre strap.

Only that line is physics. The upper line has no physical definition (how high
a good ball strikes depends on how far back you stand), so it is offset a
default metre and presented as a starting point. Dragging always overrides,
and a failed measurement leaves the lines exactly where they were.

**P3 — the ladder.** Surface `clearedDrills` as five rungs on the schedule
above, gate each on a rep-streak target, and keep the personal best per rung.

**Later — Apple Watch.** A wrist IMU classifies forehand / backhand / serve at
~98%, which is the cheapest possible way to verify that a "Forehand ↔ Backhand"
rung is actually being alternated rather than just counted. That is the natural
place for the Watch to enter this feature.

---

## Sources

- External focus of attention, tennis skill acquisition in children — https://pmc.ncbi.nlm.nih.gov/articles/PMC10721975/
- External focus and table-tennis backhand accuracy in low-skilled players — https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9714895/
- Contextual interference, systematic review and meta-analysis — https://pmc.ncbi.nlm.nih.gov/articles/PMC11237090/
- Contextual interference effect review (acquisition vs retention) — https://www.researchgate.net/publication/223220662_A_review_of_the_contextual_interference_effect_in_motor_skill_acquisition
- Judy Murray wall drills and the count-in-a-row progression — https://www.coachweb.com/sport/8611/wall-tennis-practice-drills-from-judy-murray-to-improve-your-game
- Practice walls with line markings and target zones — https://targetboundsports.com/en/tennis-practice-walls-backboards
- `VNDetectTrajectoriesRequest` (parabolic fits) — https://developer.apple.com/documentation/vision/vndetecttrajectoriesrequest
