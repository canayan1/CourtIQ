# Teaching — a plan for an app that shapes a stroke

21 Sep 2026. A plan, not a commitment: each step ends with the decisions it
needs, and those are the discussion.

## The premise, stated so it can be disagreed with

An app cannot teach the stroke. It cannot see contact, it cannot feel weight
transfer, and it has no idea which of fifteen deviations is the cause and
which are compensations. Every attempt this project made to have software
judge technique either failed or had to be refused, and the things that
worked were all measurements of position, timing and repetition.

What an app can do is the other two-thirds of learning: teach the game
(knowledge), and show a player what they cannot see about themselves
(self-knowledge). And there is one route to shaping the stroke itself that
does not require diagnosing it — **design the task so that only good
technique succeeds, and count the outcome.** That is the spine of this plan.

The order is the reverse of the tempting one. Tempting: solve vision, then
diagnosis, then teaching. This plan: teach without diagnosing first, collect
the data that diagnosis would need second, build diagnosis last — and only if
the data says it works.

Three findings from the motor-learning literature are treated as constraints
throughout, because an app's natural instincts violate all three:

- **External focus beats internal focus.** "Send the ball past the service
  line" produces better learning than "extend your elbow". An app's native
  vocabulary — angles, joints, pose — is internal. Every cue this app ever
  utters is written externally.
- **More feedback is worse feedback.** Constant feedback raises performance
  in the moment and lowers retention (the guidance hypothesis); the learner
  becomes dependent on it. Feedback here is after the set, never during the
  stroke. The haptic-nudge-per-stroke idea in `AI-DRILL-COACH.md` is retired.
- **Variable practice beats blocked practice for retention** (contextual
  interference). Twenty identical feeds feel productive and transfer badly.
  Task libraries interleave.

## Step 0 — what already exists, so the plan builds on real things

| capability | state | where |
|---|---|---|
| Count strokes from audio | calibrated on hand-counted wall sessions | `BallImpactAudio` |
| Rally structure: longest rally, tempo, steadiness | tested, unrun on device | `RallyRhythm` |
| Split step, recovery, lateness, fading | tested, unrun on device | `SessionFindings` |
| Court as a ruler (cm from a clip) | works on one real clip, refuses on eight | `CourtCalibration` |
| Pose from a static camera | works close and side-on; fails far and from behind | `tools/duel-eval.swift` |
| Tennis IQ: 156 scenarios, tactics lessons | shipped | Tactics tab |
| Journal + AI report | shipped | Journal tab |
| The rule that a number is reported only when earned | everywhere | — |

Nothing here needs to be rebuilt. The plan reuses it.

---

## Step 1 — teach without diagnosing: constraint tasks

**What.** A library of tasks, each with a measurable outcome and a success
threshold, arranged in progressions. The app defines the task, counts the
outcome, and says whether the threshold was met. It never looks at the stroke.

**Why this shapes technique.** A short, flat, arm-only forehand cannot land
twenty consecutive balls past the service line. The task fails, and the player
finds a solution that works — which is the one with the longer swing and the
weight going forward. Nobody told them to change their swing. This is the
constraints-led approach and it is how a great deal of good coaching already
works; the app is just the referee.

**Where first: the wall.** The wall is a constraint machine that gives its own
feedback and needs no partner, and the app can already count on it. Tasks:

- consecutive strokes without a miss (rally length — measurable today)
- strokes at a held tempo (tempo steadiness — measurable today)
- alternating forehand / backhand (needs the wing; wrist or feeder-declared)
- above the line / below the line (needs a target — not measurable today)

**Then: the court with a feeder.** "Past the service line", "inside the
singles line", "cross-court" — these need to know where the ball landed, which
the app cannot see. Two honest options: the feeder marks it (a tap per ball —
what coaches already do with a bucket and a clicker), or ball tracking is
built (a project of its own; SwingVision's core, years of work). The plan
starts with the tap.

**What the app says afterwards.** The outcome, the threshold, the progression:
"14 of 20 past the line; threshold is 16; same task next time." Nothing about
the stroke. The player is not told what to change; the task tells them.

**Test.** Two groups of a coach's students, same weeks: one practises with the
task library, one with the coach's usual feeding. Measured on the same
constraint tasks at the start and end. If the library group does not move,
the tasks are wrong or the theory is — either is worth knowing.

**Decisions for discussion**
1. Which tasks go in the first library, and what does each one shape? (This
   is coaching knowledge. It is yours.)
2. Thresholds and progressions — fixed numbers, or relative to the player's
   own first attempt?
3. Feeder-tap for landing zones, or wait for ball tracking? (The plan says tap.)
4. Interleaving rule: how many tasks per session, in what order?

---

## Step 2 — the swing lab: canonical capture

**What.** One stroke, one setup, every time: tripod at a marked spot, side-on,
about three metres, 240 fps, the player hits ten balls from a feed. Not a
match, not a rally, not behind the baseline. Every serious product in the
research doc does this and none of them apologise for it.

**Why the constraint is the feature.** Same framing session to session means
today's ten forehands are comparable with the ten from two weeks ago at the
same scale. That comparability is what makes "changed" a measurement rather
than an impression, and it is what Step 3 needs.

**What it measures.** Not correctness — *variability and change*. Across ten
reps: where contact happened relative to the body (from pose at the audio
impact), how consistent that was, the time from the start of the forward
swing to contact, the finish height, and the spread of all of those. A stroke
that is the same ten times in a row is a learned stroke, whatever it looks
like; a stroke that is different every time is not yet learned.

**What it must refuse.** A clip from the wrong angle, a moving camera, a rally.
The calibration and refusal machinery from the duel work transfers directly:
the app says "not the lab setup" rather than measuring something else.

**Tooling.** An on-screen alignment guide so the phone is placed the same way
each time (a court line and a cone in the frame at fixed positions), the
240 fps capture, the audio impact, the pose at impact, the ten-rep summary.

**Decisions for discussion**
5. Forehand first? (Most repetitions, easiest to feed, best pose from the side.)
6. Which measurements — the five above, or fewer? Each one has to be
   explainable to the player in a sentence.
7. Does the lab live in the app now, or in `tools/` until the numbers are
   trusted? (Same rule as the sensing work: behind DEBUG until calibrated.)

---

## Step 3 — the teaching dataset: only a coach can make it

**What is missing from the world.** Stroke data exists in quantity. What does
not exist anywhere is *teaching* data: this player did X, the coach said Y,
and two weeks later Z changed. Without it no system can learn to diagnose or
prescribe, and no amount of model capability substitutes for it.

**The protocol, per lesson, one stroke:**
1. Lab capture before (Step 2).
2. The coach gives **one** cue — one, so the effect is attributable.
3. Lab capture after, same session.
4. Lab capture again at the next lesson (retention, not just performance).
5. The coach records: which deviation they saw, which cue they gave.

**Two fixed vocabularies, authored by the coach.** Without them the data does
not aggregate, it piles up.

- A **deviation taxonomy**: the twenty or so things that are actually wrong
  with club forehands, named consistently ("late preparation", "contact
  behind the hip", "arm-only, no rotation"…).
- A **cue library**: the fifty or so things the coach actually says, each one
  written in external-focus language.

**Tooling.** A lesson-capture mode in the app: pick the student, pick the
stroke, capture, pick the deviation from the taxonomy, pick the cue from the
library, capture again. Thirty seconds of overhead per lesson. Behind DEBUG.

**Consent and storage.** Students are filmed. Written consent, parental
consent for minors, the footage stays on the coach's device, deletion on
request, and none of it leaves the phone until there is a reason and a
policy. This is decided before the first capture, not after.

**Volume.** A hundred lesson-triples is more than exists anywhere. A thousand
is a research asset. Neither happens without the coach doing it every lesson.

**Decisions for discussion**
8. Do you have enough students, and enough lessons, for this to accumulate?
   Honestly — how many forehand lessons a week?
9. The taxonomy and the cue library: will you write them? They are the
   plan's real intellectual property and nobody else can.
10. One cue per lesson is a constraint on how you coach. Acceptable?
11. Consent wording, and where the footage lives.

---

## Step 4 — the decision tree, and only then a model

**First, no model.** When data starts arriving, the first thing built is the
coach's own diagnostic logic written down: "when I see this deviation and the
player is at this level, I give this cue; if that did not work last time, I
give this one." A tree, over the deviations Step 2 can measure. This is how
the rest of the app already works — rules decide, a model only phrases — and
it is testable against every lesson in Step 3: did the tree pick what the
coach picked, and did the coach's pick produce measured change?

**Then, maybe, a model.** Only when the tree is wrong often enough and the
data is deep enough to say why. And note what the model would be: a
*recommender* over (measured deviations, history) → cue. Not a vision model.
The vision is done deterministically in Step 2 and stays that way.

**What decides whether any of this works.** In Step 3, does the cue produce
measurable change on the Step 1 tasks and the Step 2 measurements? If yes,
the loop closes. If no, one of two things is true: the measurement is wrong,
or coaching is less deterministic than believed. Both are findings. The
second would mean the diagnosis layer should not be built — and that Step 1
alone is the product.

**Decisions for discussion**
12. Will you sit down and externalise the tree? (A few hours, once, then
    revisions as data disagrees with it.)
13. Kill criterion: after N lessons with no measurable effect, we stop
    building Steps 3–4 and ship Step 1 as the product. Pick N.

---

## Step 5 — closing the loop for a player who is not your student

This is what the product becomes if Steps 1–4 hold.

1. The player runs the swing lab (Step 2) and gets their ten-rep picture.
2. The tree (Step 4) reads the measured deviations and picks **one** thing
   and **one** cue, in external-focus words.
3. The app assigns the constraint task (Step 1) that targets that thing.
4. The player practises it for a week, the app counts.
5. They run the lab again. The app says what changed — and only what
   changed; never why.

**Cadence.** The cue is given once, at the start of the week. The counting
happens every session. The comparison happens at the next lab. Nothing speaks
mid-stroke.

**What it may claim.** "Your contact point moved 12 cm forward since last
month and your ten reps are half as spread." What it may not claim: that the
stroke is correct, that the player will win, or that the app taught them.
The player taught themselves; the app set the task and kept the score.

---

## Sequencing

| when | what | needs |
|---|---|---|
| now | Step 1 on the wall — task library, counting, thresholds, progression | nothing new; buildable this week |
| now | Step 3 vocabularies — taxonomy and cue library | you, a few hours |
| month 1–2 | Step 2 — the lab, in `tools/` then behind DEBUG | a tripod, a court, ten forehands |
| month 1–2 | Step 1 on court — feeder tap for landing zones | a feeder |
| month 2+ | Step 3 — lesson capture, every lesson | you, thirty seconds per lesson, consent in place |
| month 6+ | Step 4 — the tree, validated against the first hundred triples | the data |
| month 9+ | Step 5 — the loop, for players who are not your students | Steps 1–4 holding |

Step 1 and the vocabularies do not wait for anything. Everything else waits
on the lab and on lessons.

## Risks, honestly

- **The data does not accumulate.** The most likely failure. It depends on a
  human doing a small thing every lesson for months. Mitigation: make the
  capture thirty seconds, not five minutes, and show the coach their own
  data growing.
- **The cues do not move the numbers.** Possible, and a finding. Then Step 1
  is the product and the plan stops there — still a real product.
- **The lab is not repeatable in practice.** Different courts, light, phone
  placement. Mitigation: the alignment guide, and the refusal — measure only
  when the setup matches.
- **Landing zones without ball tracking.** The feeder tap is honest but adds
  friction. If it is not tolerated, only the wall and the audio-measurable
  tasks survive, which is still Step 1.
- **The obvious one.** Everything in Steps 2–5 sits on measurements that,
  as of this document, have not met a court. T1 and T3 in
  `SENSING-TEST-PLAN.md` come before any of this.

## What the app is at each stage

- After Step 1: a practice partner that sets tasks and keeps score, and
  shapes technique without ever mentioning it. Sellable on its own.
- After Steps 2–3: the same, plus a lab that shows a player their own stroke
  changing over months — the thing no memory can do.
- After Steps 4–5: a coach's judgement, distilled into rules, applied on the
  six days the coach is not there.

The ceiling stays where it was: not "learn tennis from an app", but "practise
better on the days nobody is watching, and see whether it worked".
