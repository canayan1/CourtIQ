# Baseline Cam — two players, one clip, from behind the court

The head-to-head feature asks one video who the better player is. This is the
design for the shot people will actually take: a phone behind one baseline.

Everything in "What we measured" is a number this machine produced. Everything
in "The arithmetic" is geometry, labelled as prediction, not yet confirmed on a
clip. Nothing here is an estimate dressed up as a finding.

## What we measured

Four clips have gone through `tools/duel-eval.swift`.

Two bugs in that tool were corrupting every number it printed: the clip's
rotation lives in `preferredTransform` rather than in the pixel buffer, so
Vision was being handed sideways people; and Vision normalises x against frame
width and y against frame height, so on a 9:16 frame the two were never the
same unit. Fixing both took usable frames from 15 of 198 to 169 on the
ground-level clip and from 146 of 235 to 842 on the wall clip, and four of the
five metrics stopped depending on the sampling rate — at 12 fps versus 6 fps
they now agree within 5%. The fifth, accumulated court coverage, moved 166% and
is printed separately as not reproducible.

Then a result that was read wrongly the first time, and the correction matters
more than the original claim.

**Not one frame of any clip contained two detectable people** — true of Vision's
person detector, at a confidence floor of 0.05, with the frame tiled and each
tile upscaled 4×. That was reported as "these clips contain one player", which
is false. Both court clips contain a rally. What happened is that the pipeline
could not see the far player and the pipeline's blindness was written down as a
fact about the world; the far player is plainly there when the far half of the
frame is cropped and enlarged.

Once looked for properly, the far player IS found — by motion, not recognition
— but in **fragments**. Background subtraction only catches what differs from
the background, so a distant player in pale clothing against a pale fence
arrives as a head here and a leg there: about 19 pixels of a person the court
says should be 68. Judged one at a time, each piece is too small to be a person
and, worse, its lowest pixel is not a foot.

One technique did work perfectly. On the static ground-level clip, background
subtraction — a temporal median background, then a threshold, then connected
components — put a tight box on the near player in **165 of 165 frames**. On
the handheld balcony clip the same code produces hundreds of false boxes per
frame and misses the player entirely.

So: **a static camera is not a preference, it is the precondition.**

The fragments are joined back together using the court as the yardstick — it
predicts how tall a person standing at a given row should be, so pieces that
overlap horizontally and sit within a body height of each other belong to one
person, and the rule tightens with distance instead of needing a constant tuned
per clip. That same prediction then grades what it found: far too tall is
scenery, and too short is a player only half seen. The near player measures 125
to 158 pixels against a predicted 123 to 141, which is the strongest
independent check the geometry has had.

A half-seen player is kept and flagged, never measured. Their lateral position
holds; their depth is the bottom of whatever registered, which is fiction. An
unguarded version of this reported the far player making contact eleven metres
in front of their own baseline, having quietly locked onto the match being
played on the next court — there is nothing to tell two fragments apart when
both are fragments. Seeing somebody and measuring them are different things,
and the app says which one it did.

## Why the clips failed, and why that is good news

The near player in the ground-level clip is 65 px tall. That is not what a
court does to a player; it is what that particular recording did. The file is
576 px tall — a downscaled re-encode — and the camera was roughly 20 m away,
outside the fence.

An iPhone main camera on 16:9 video has a vertical field of view of 42.6°. A
1.70 m player therefore occupies:

| distance | 1080p | 4K |
|---|---|---|
| 6 m (near player, camera behind the baseline) | 409 px | 819 px |
| 12 m (mid-court) | 206 px | 411 px |
| 27 m (far player, other baseline) | **92 px** | **183 px** |

At 4K the far player is nearly three times the size of the near player in the
clip that failed. The geometry of a tennis court was never the obstacle. The
recording was.

## The arithmetic that sets the camera height

A low camera cannot see the far player's feet, because the net is in the way,
and feet are what the measurement needs. The ray from a camera at height `h` to
a point on the ground at the far baseline passes the net at
`h · (1 − (d+11.885)/(d+23.77))`, where `d` is how far behind the near baseline
the camera stands. That has to clear the net — 0.914 m at the centre, about
1.00 m out at the singles sideline.

| camera stands | must clear centre | must clear sideline |
|---|---|---|
| on the baseline | 1.83 m | 2.00 m |
| 2 m behind | 1.98 m | 2.17 m |
| 3 m behind | 2.06 m | 2.25 m |
| 5 m behind | 2.21 m | 2.42 m |
| 8 m behind | 2.44 m | 2.67 m |

Two things fall out of this. The camera has to be **high** — about 2.3 m to see
the far player's feet across the full width, so 2.5 m with margin, which is
roughly where a court fence is climbable. And it has to be **close to the
baseline**, because standing further back raises the height you need, not
lowers it.

If the phone cannot be got that high, the fallback is to track the far player's
head instead and infer the feet from standing height. That is measurably worse
and the app should say so rather than quietly degrade.

## The shot

- Phone clipped or propped on the fence **behind one baseline**, centred on the
  centre mark, 2–3 m back, **2.5 m or higher**.
- **Nothing holds it.** A handheld clip cannot be measured; the balcony clip is
  the proof.
- **Landscape, 4K, no zoom.** 1080p works; a downscaled export does not.
- Lock exposure and focus — on iPhone, press and hold until AE/AF LOCK.
- Both baselines and both singles sidelines in frame.
- **At least three minutes of continuous rallying**, five is better.

That last one is the answer to "would a longer video help": yes, and it is not a
nicety. Every metric below is per stroke, and a median over a handful of strokes
is a coin toss. Three minutes of rallying is roughly 60–100 strokes each, which
is where per-stroke medians settle down. The 17-second clip would have given
about eight.

## The measurement architecture

The near player will always be several times the size of the far player. Any
comparison built on pose is therefore rigged in favour of whoever stood closer
to the phone. So the head-to-head does not run on pose.

**1. Court homography.** Find the court lines — baseline, service line, singles
sidelines, net line — and solve the image-to-court transform. The court is a
fixed, known rectangle, so this converts any pixel to a position in metres.
Crucially it depends on the lines, not on the players, so it removes the near/far
size asymmetry entirely: the far player's feet land in metres just as the near
player's do.

**2. Two tracks, from motion, not recognition.** A static camera makes
background subtraction reliable, and it does not care how many pixels tall a
person is. Court homography also tells us which half of the court a blob is in,
which is what separates the two players and rejects the neighbouring court —
both failure modes we have already seen in real clips.

**3. Events from audio.** `SwingImpactAnalyzer` already finds ball impacts on
the audio track. Impacts alternate between the players, and the near player's
hit is markedly louder, which fixes the phase. Every metric is then measured
per stroke rather than per sampled frame — which is what makes it reproducible,
and is precisely the fix the coverage metric needs.

**4. The metrics, all of which both players can supply.** Each one is a position
in metres at an instant defined by an impact:

- **Contact depth** — how far behind the baseline each player meets the ball.
- **Recovery** — how close each player gets to the bisector before the opponent
  strikes, in metres of the gap closed.
- **Metres run per stroke** — event-anchored, so it does not grow with the
  sampling rate.
- **Displacement forced on the opponent** — how far the other player has to
  travel to reach your ball. This measures the quality of your ball through its
  effect, without ever seeing the ball.
- **Time taken away** — the interval between your contact and theirs.
- **Set at contact** — speed at the instant of impact; arriving early and
  balanced reads differently from arriving late.

Pose stays in the product, but as a one-sided detail layer for whoever is near
the camera, clearly labelled as such. It never enters the head-to-head.

## What the verdict may claim

It may say who covered more ground per ball, who recovered further, who took the
ball earlier, who forced the other to move more, and who was more often set at
contact. Those are measurements.

It may not say who has better technique, whose ball had more spin, who chose
better, or who would win. Nothing here sees any of that, and the research doc's
§1 finding — that a video model cannot see motion — means no model may be asked
to supply it either.

## Build order

1. ~~Court homography from the lines~~ — done. `CourtCalibration` /
   `CourtLineFinder`, driven by `tools/court-calibrate.swift`. On the
   ground-level clip it resolves a foot position to 1.3 cm across at the near
   baseline and 3.4 cm at the far one, and the sidelines — derived, never
   detected — land on the real ones. It refuses rather than guesses: of four
   clips only the real court keeps full metres.
2. ~~Static-camera tracker~~ — done. `PlayerTracker`. The court does the
   separating (one player per half) and the rejecting (feet inside the lines,
   and person-sized where they stand, which is what throws out the match on
   the next court along).
3. ~~Impact-anchored metrics~~ — done. `DuelMetrics`, on `BallImpactAudio`
   split out of `SwingImpactAnalyzer` so the duel gets the calibrated impact
   times without the Vision person gate. 10 fps and 15 fps now agree to the
   last printed digit on all five metrics.
4. The two-player association, against a clip shot to the spec above. Still
   unwritten, and staying unwritten: every clip on hand holds one player, so
   there is nothing to test it against. What it needs is deciding which player
   hit each impact — alternation fixes the pattern and loudness fixes the
   phase, since the near racket is metres from the microphone and the far one
   is twenty — and `DuelMetrics.pressure` is already waiting for the answer.

## Known costs of the on-device port

The offline tool peaks at 400 MB on a 1080p clip. Most of that is the 48-frame
background sample, and a phone should not copy the approach unchanged: a
running background estimate, or tracking at a reduced resolution while keeping
the calibration at full, would both work. The far player's foot position is the
thing that resolution buys, so whichever is chosen has to be measured against
the far end rather than the near one.
