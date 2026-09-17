# Sensing — what got built, what is proven, what to test next

17 Sep 2026. Covers fifteen commits, `0af0bab` through `f0322d7`.

Two separate machines came out of this session. One measures a court from a
video; the other measures a player from a phone on their body. They share one
rule: a number is only reported when the thing that produced it has been shown
to work, and everything else is declined out loud.

---

## Part 1 — Camera: measuring a court from a clip

### What was wrong before

`tools/duel-eval.swift` had two bugs that corrupted every number it printed.

A clip's rotation lives in `preferredTransform`, not in the pixels, so a
portrait recording arrives as a landscape frame with a turn attached — Vision
was being asked to find sideways people. And Vision normalises x against frame
width and y against frame height, so on a 9:16 frame the two were never the
same unit and every distance that mixed them was wrong.

Fixing both roughly quintupled the usable frames: 15 of 198 to 169 on the
ground-level clip, 146 of 235 to 842 on the wall clip. With clean data
underneath, four of the five metrics stopped depending on the sampling rate.

| metric | 12 fps | 6 fps | drift |
|---|---|---|---|
| width of court used | 2.79 | 2.68 | 4% |
| widest base | 0.86 | 0.82 | 5% |
| time in a wide stance | 51% | 52% | 1% |
| highest wrist | +0.63 | +0.63 | 0% |
| **court coverage** | **5.92** | **15.73** | **166%** |

The earlier conclusion that "the metrics are unreliable" was mostly wrong. Four
were fine; the data feeding them was not. The fifth is genuinely broken by
construction — counting steps answers a question about the sampling rate — and
is printed separately, labelled not reproducible.

### The court as the ruler

Measuring players in body heights always favours whoever stood nearer the
phone, which on a camera behind one baseline is decided by where people
happened to stand. So `CourtCalibration` makes the court itself the ruler.

Depth comes from the lines running across the court, whose real spacing is
fixed, so three of them determine the projective map and the rest test it.
Width comes from the span of the service line, whose ends sit on the singles
sidelines 8.23 m apart. Lines are searched for only where the clip's own motion
landed, so the fence, the clubhouse and the sky never get a vote.

On the ground-level clip: **1.3 cm across and 5.7 cm deep** at the near
baseline, 3.4 cm across at the far one. The sidelines, which are never detected
but derived from the service line, land on the real ones.

### The part that matters more: refusing

The first version fitted a confident court to a clip of somebody hitting
against a wall, and reported a *tighter* residual there than on the real court,
because three roughly parallel edges are easy to find anywhere. So the derived
sidelines became evidence instead of output: if the model is right there is
paint under them, and if it is wrong there is grass.

Nine clips have been through it. **One produced metres. Eight declined.**

| clip | across-line paint | sideline paint | result |
|---|---|---|---|
| court, from behind, ground level | 81% | 63% | full metres |
| wall session on a marked court | 98% | 7% | depth only |
| wall session | 48% | 6% | nothing |
| handheld balcony pan | 46% | 43% | nothing |
| 5 × Davis Cup broadcast (side-on) | — | — | nothing |

`tools/duel-corpus.sh` re-runs the set.

### Tracking, and the correction that mattered

Vision's person detector never once returned a second box on any real clip —
the player across the net is about thirty pixels tall. Background subtraction
put a tight box on the near player in **165 of 165 frames** of the static clip
and produced noise on every frame of the handheld one. So a static camera is
not a preference, it is the precondition.

**I was wrong about the clips.** I reported that both court clips held one
player each. Both contain a rally; the opponent is plainly there when the far
half of the frame is cropped and enlarged. What happened is that the pipeline
could not see her and I wrote its blindness down as a fact about the world.

What actually happens is fragmentation: background subtraction catches only
what differs from the background, so a distant player in pale clothing against
a pale fence arrives as a head here and a leg there — about 19 pixels of a
person the court says should be 68. The pieces are now joined using the court
as the yardstick, and the same prediction grades the result. The near player
measures 125–158 px against a predicted 123–141, which is the best independent
check this geometry has had.

A half-seen player is kept, flagged, and **not measured**. An unguarded version
reported the far player making contact eleven metres in front of her own
baseline, having locked onto the match on the next court — when every candidate
in a half is a fragment, nothing distinguishes the real opponent from anyone
else.

### Per-stroke metrics

Every number is anchored to an audio impact rather than a sampled frame,
because an impact happens the same number of times however often anybody
looked. Smoothing over a span of *time* rather than a count of samples was
required: the bottom edge of a motion blob is the player's feet, and feet move,
so integrating the raw track measured the stride — the first run reported
**9.22 m of travel per stroke** for someone standing almost still. Smoothed, it
reports 2.86 m, and **10 fps and 15 fps now agree to the last printed digit on
all five metrics**. 5 fps does not, so 10 is the floor.

`BallImpactAudio` was split out of `SwingImpactAnalyzer` so the duel gets the
calibrated impact times without the Vision person gate — pose is exactly what
fails for the far player, and gating there would delete one player's strokes.

### Naming players and wings

A player is never just "Player 1": the end of the court is their identity, and
the label says it — "nearest the camera", "across the net".

The wing is the piece most likely to ship backwards. `across` is positive to
the right of the image, always. The near player has their back to the camera,
so a right-hander's forehand side is positive; the far player faces the camera,
so the same patch of court is their backhand and the sign flips.
`tools/duel-report-test.swift` checks all four combinations of end and hand
against a synthetic track whose answer is known by construction.

The hand is asked, never inferred — a wrong guess would not blur the report, it
would mirror it. Two refusals hold the rest: a side needs **eight strokes**
before its difference from the other side means anything, and a difference must
clear the clip's own resolution (a metre is a finding near the camera and noise
at the far baseline, where a pixel is worth forty centimetres).

### Still unbuilt

Deciding **which player hit each impact**. Alternation gives the pattern and
loudness the phase, and `DuelMetrics.pressure` is waiting for the answer. Not
written, because no clip on hand has two measurable players.

---

## Part 2 — Body: measuring a player from a phone they wear

### Why this exists

Propping a phone is the friction that kills the camera features. A phone worn
on the body needs no setup at all, and the strokes it cannot feel it can still
hear.

**The wrist and the waist are not two grades of one thing.** A racket strike
reaches the waist through arm, shoulder and trunk, by which point it is smaller
than the player's own footfalls — a belt phone cannot count strokes. But the
wrist is blind to everything the waist is good at, and human movement lives
below 5 Hz, so the phone's 100 Hz costs nothing for footwork.

### What is built

- `WristSwingDetector` — for a watch, when there is one. `CMBatchedSensorManager`
  gives 800 Hz accelerometer and 200 Hz device motion on watchOS 10 (Series 8
  and Ultra), which is what Apple built it for.
- `MovementDetector` — split steps, efforts, work:rest, from a waist phone.
- `ImpactAttribution` — whose stroke was that.
- `RallyRhythm` — rallies, tempo and steadiness from stroke times alone.
- `BodySessionRecorder` + `BodySessionView` — the runtime, **DEBUG only**.

### Three things the tests caught before any hardware did

**Thresholding raw accelerometer magnitude measures the swing, not the strike.**
A forward swing puts about 1.6 g through the wrist on its own, so a barely
touched ball at the end of a hard swing cleared the floor while a firm block
would not. Contact is now prominence above the load the arm was already
carrying.

**Running has a flight phase too.** "Light then heavy" alone reported a split
step every other stride — five seconds of synthetic running produced five,
which would hand a player 100% readiness for a session in which they never
split stepped once. The fix is physical rather than a threshold: a split step
is made from a set position, so the body must not be driving sideways as it
lands. That took the same five seconds to zero.

**The microphone tap runs on a real-time audio thread.** The first version
handed its buffer to an async Task — a read of memory the callback frees on
return. Samples are now folded into the envelope synchronously inside the
callback, which is also what makes the audio policy true rather than
aspirational.

### The measurement that needs both sensors

The microphone says when the opponent struck; the waist says whether the player
was landing a split step at that moment. Club players are told to split step
constantly and mostly do not, and nobody could previously tell them how often
they actually did.

### The wall case

`WallSwingDetector` records its own measured accuracy: **ten counted out of
about thirteen**, because from behind the player a swing moves mostly toward
the wall, which is depth a single camera cannot see.

A wall rally makes two sounds per cycle. Measured on a wall session filmed from
about twenty metres, the impact strengths form **one continuum** — the widest
gap between neighbours is 1.64×, no gap at all, because from there the racket
and the wall are both twenty metres away. In a pocket the racket is 0.8 m and
the rebound comes from roughly the standing distance, so at four metres that is
about **twenty-five to one in intensity**.

This is a prediction. `separateWallBounces` returning something rather than
`nil` settles it on the first pocket session.

### Audio policy

Audio is reduced to instants and loudnesses as it arrives and discarded in the
same breath. A session is recorded in a public place — the next court, the
conversation behind the fence — so what survives is a few hundred numbers and
never a recording. Nothing written to disk, nothing transmitted, no setting
that changes it.

---

## The bench card, and which devices can feed it

The plan is a data tool that fuses with a device: sit down at the changeover,
open the phone, and read what changed in the games just played. Two pieces
make that possible and both are built and tested (`MatchStints.swift`).

**Stints.** Tennis changes ends after odd games, so what a player sits down
from is usually a pair — "in these two games" is the unit. A stint is cut at a
changeover the player marked (one tap on the wrist, which is what people
already do with a scoring app), or, when nobody tapped, at a quiet gap longer
than 55 s: between-point rests are twenty-odd seconds, changeovers ninety.
Marks always win, so a medical timeout is never mistaken for a changeover.

**The comparison.** The latest stint against the one before: movements per
minute, how sharp the pushes off were, split-step rate, heart rate when a
wearable supplied one. Only differences of 15% or more are mentioned, so two
stints that were the same produce an empty card rather than an invented one.

**What it will never say: why.** A drop between two stints is consistent with
tiredness, heat, dehydration, an opponent who stopped making the player run, a
deliberate change of pace, and fuel — and nothing on a wrist or belt separates
those. "You may need carbohydrate" is both a guess dressed as a reading and a
breach of the app's rule that nutrition content carries no unsourced dietary
advice. The card reports the observation; the Journal already holds what the
player logged eating; the two can sit side by side.

**One event stream, any device.** Everything downstream consumes
`SensorEvent` — contacts, motion, heart rate, changeover marks — and does not
know what produced them. That is what makes "phone and external device" one
product instead of two.

| device | strokes | footwork | heart rate | changeover mark | live to phone | status |
|---|---|---|---|---|---|---|
| iPhone on belt / in pocket | audio | 100 Hz motion | — | rest-gap inference | it *is* the phone | built, DEBUG, needs T1–T3 |
| Apple Watch (S8 / Ultra, watchOS 10+) | 800 Hz accelerometer | 200 Hz motion | yes | one tap | WatchConnectivity | **target built, embedded, UNRUN** — see T0 |
| Garmin | — (Connect IQ accel is ~25 Hz, enough for feet, not for impact) | via a Connect IQ app, separate codebase | via Apple Health sync, after the fact | — | not live | not started |
| Xiaomi / Mi Band | — | — | via Apple Health sync | — | not live | no raw-sensor API; heart rate only |

The honest reading of that table: the phone is the product that exists, the
Apple Watch is the product that would be best, and third-party bands
contribute heart rate after the match and nothing during it.

## Tests to run

Numbered in the order that unblocks the most.

### T0 — The first watch session *(the moment a watch exists)*

**Do:** install the app from Xcode with the watch paired. Open DropVolley on
the wrist, pick `Match`, tap Start, accept the HealthKit and microphone
prompts, hit thirty balls with a partner, tap **Changeover** once, hit thirty
more, tap Stop. Then open the phone: the bench card sits at the bottom of Home
(DEBUG build only).

**Expect — and expect some of this to fail:**
- The workout starts and the screen shows a rising stroke count. If it shows
  "100 Hz fallback" on a Series 8 or later, `CMBatchedSensorManager` did not
  start — the most likely first failure, since it requires an active workout
  session and that ordering has never been exercised.
- "You" roughly equals your count; "Them" roughly equals your partner's.
  Opponent contacts come from the microphone minus whatever the wrist claimed,
  so a wrist that misses strokes shows up here as inflated opponent counts.
- The phone's bench card shows two stints after the changeover, with notes
  only if something moved by more than 15%.
- Heart rate appears on the wrist within the first minute.

**Settles:** whether a single line of `CourtIQWatch/` runs. Everything in that
folder was written without a watch. The detectors under it are tested; the
workout session, the batched sensors, the microphone on watchOS and the link
to the phone have been compiled and never executed. The first session is a
test of the plumbing, not of the player.

**Then:** log the match in the Journal. The AI report's summary now carries a
"Measured session" block (`SensingSummary`) with the rules stated first — no
causes, no dietary advice — and the list of what could not be checked. Read
the report for any sentence that names fatigue, fitness, food or hydration as
a cause. If one appears, the rule in the block was ignored and the block needs
strengthening before this ships.

### T1 — Wall, phone in pocket *(fastest, highest value)*

**Do:** phone in your pocket, `Wall` drill, 30–40 balls against the wall.
Count your strokes yourself. Note roughly how far you stood from the wall.

**Expect:**
- Contacts found within ~10% of your count — better than the camera's 10/13.
- "Rebounds heard" shows a number → the loudness split works in a pocket.
- Longest rally close to your longest unbroken run.
- Tempo spread under ~20% if you struck cleanly.

**Settles:** whether the pocket can replace the Rally Cam's setup entirely.

**If it fails:** "Could not tell your racket from the ball off the wall" means
the two populations did not separate. Tell me your standing distance and
stroke count — the split threshold is one number and the geometry predicts
where it should sit.

### T2 — Rally with a partner, phone on belt

**Do:** phone in a belt strap at your waist, `Free play`, 5+ minutes of
rallying. Count roughly how many balls you hit.

**Expect:**
- Contacts ≈ your count plus your partner's.
- Your strokes and theirs split by loudness (yours louder).
- A readiness percentage. **No expectation on its value** — that number has
  never been measured on anybody, and whatever it says is the first data point,
  not a verdict.
- Split step count in the same ballpark as the readiness denominator.

**Settles:** whether split-step detection survives a real belt strap, where the
phone shifts and the strap adds its own rattle.

### T3 — Deliberate split-step contrast

**Do:** two short sessions, same partner, same tempo. First: split step on
every ball, consciously. Second: stand flat-footed and just swing.

**Expect:** a clear gap between the two readiness numbers. **This is the test
that matters most**, because it checks the metric measures what it claims
rather than something correlated with it.

**If both come out the same,** the detector is measuring footfalls, not
readiness, and nothing built on it should ship.

### T4 — Pocket vs belt

**Do:** repeat T1 with the phone in a belt strap instead of a pocket.

**Expect:** similar contact count, possibly cleaner split steps (less
rotation). Tells us which placement to recommend.

### T5 — Court clip to the camera spec *(needs a helper)*

**Do:** phone clipped to the fence **behind one baseline**, centred on the
centre mark, 2–3 m back, **2.5 m or higher**, landscape, 4K, no zoom, AE/AF
locked, both baselines and both singles sidelines in frame. **Three minutes**
of continuous rallying, nothing holding the phone.

**Expect:** `calibration: full`, both players tracked as *whole* rather than
partial, and per-stroke metrics for both ends.

**Settles:** the last unbuilt piece of the duel — which player hit each impact.

**Why the numbers:** below about 2.3 m the net hides the far player's feet, and
feet are what the measurement needs; standing further back raises that height
rather than lowering it. At 4K the far player is ~183 px, three times the size
of the *near* player in the clip that failed.

### T6 — Doubles, same spec

Same as T5 with four players. Unblocks the near-pair positioning feature, which
needs only the near half — the part of the frame the pipeline is strongest in.

---

## Pain points, honestly

**The readiness number has no baseline.** Nobody knows whether a club player
split steps on 30% or 80% of balls. The first sessions produce a number with
nothing to compare it against, and it will be tempting to coach off it
immediately. T3 exists so the metric earns trust before it earns a sentence.

**A pocket is a loose mount.** The phone rotates and slides; the strap adds
rattle. CoreMotion's gravity vector keeps the vertical/horizontal split honest
regardless of orientation, but extra vibration is not modelled anywhere and may
raise the false-hop rate. T4 is the check.

**Audio detection over-counts by 20–45% on raw audio** — that is the calibrated
figure from the wall sessions. The camera pipeline solved it with a Vision
person gate, which is removed here because it fails for the far player. On the
body, the rejecting is done by loudness clustering and the minimum gap, and
neither has been checked against a hand count.

**No watch.** The watch target now exists, is embedded in the iOS app, and
compiles for watchOS — and not one line of it has run. `WristSwingDetector` is
tested against synthetic signals and none against a wrist; `CourtIQWatch/` has
been tested against nothing. T0 is the first time any of it meets hardware.

**HealthKit is now on the iOS entitlements.** Apple requires it on the
companion whenever the watch app runs a workout session, even though the phone
never reads health data. That changes provisioning (automatic signing should
regenerate the profile) and it changes App Review: the usage strings are in
place, and 1.4's review notes should say the phone reads nothing.

**GPS is recorded but claims nothing yet.** Each fix carries its own
`horizontalAccuracy`. A single-frequency receiver's 3–5 m cannot separate a
baseline from a service line 5.49 m away; the Ultra's dual-frequency L1/L5 is
quoted nearer 1–2 m, which could carry a twelve-metre question like baseline
versus net. What is true on a Dublin court is to be read off recorded fixes.

**`UIBackgroundModes: audio` is now in the Info.plist**, because the phone is in
a strap with the screen off. Legitimate for a workout app, but App Review will
look at it — 1.4's review notes need to say why plainly.

**Battery.** Continuous motion plus microphone plus screen-off for an hour has
not been measured. If a session dies at forty minutes, the three-minute camera
clip is unaffected but a match session is not.

**The duel still cannot say who hit what**, and everything in Part 1 downstream
of that — the pressure metrics, the actual head-to-head verdict — waits on T5.

**Two features now measure strokes** (`SwingImpactAnalyzer` for video,
`BodySessionRecorder` for live). They share `BallImpactAudio`, which is the
point, but if their answers ever disagree on the same session that is a real
bug and worth checking once T1 gives a trusted count.

---

## Where things live

| | |
|---|---|
| Camera pipeline | `CourtIQ/Features/Duel/` |
| Body sensing (shared iOS + watchOS) | `CourtIQ/Features/BodySensing/` |
| Watch app (UNRUN) | `CourtIQWatch/` |
| Shared audio | `CourtIQ/Features/SwingAnalysis/BallImpactAudio.swift` |
| Camera design | `docs/DUEL-BASELINE-CAM.md` |
| Offline tools | `tools/court-calibrate.swift`, `tools/duel-track.swift`, `tools/duel-corpus.sh` |
| Test suites | `tools/{duel-report,wrist-swing,movement,attribution,rhythm,findings,stints,codec}-test.swift` |

The body session screen is reachable only in a DEBUG build, from a plain button
at the bottom of Home. That is deliberate: nothing it reports has been checked
against a hand count, and in this app a measurement earns its place by agreeing
with reality first.
