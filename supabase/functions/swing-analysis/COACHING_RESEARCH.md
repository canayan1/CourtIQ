# Tennis stroke-coaching research (basis for the swing-analysis prompt)

Deep-research synthesis (USTA, Tennis Australia, peer-reviewed biomechanics —
Elliott 2006 BJSM; Landlinger 2010 JSSM; Frontiers 2024; Giles 2022 IJSPP).
Used to ground the COACHING_REFERENCE + few-shot examples in `index.ts`.
Re-run the deep-research workflow to expand (e.g. per-stroke gold examples).

## Checkpoint frameworks
- **Groundstrokes (FH, 1HBH, 2HBH)** — USTA 7-phase: Preparation → Unit Turn →
  Loading → Hitting → Contact → Extension → Finish. (TA: 4-phase Prep → Swing →
  Impact → Balance/Recovery.)
- **Serve** — Preparation → Toss Release → Loading → Position → Contact → Finish.
- **Volley** — Preparation → Backswing → Contact → Finish.

## Key checkpoints + most common club faults + cue/drill
- **Unit turn first** (shoulders/trunk lead, arm lags ~50% of rotation). Fault:
  "arming the ball"/no turn (#1). Cue: "show your back shoulder to the net."
  Drill: hold the throat with the off-hand until the turn completes.
- **Swing path**: low-to-high loop, racquet drops BELOW the ball, vertical face,
  long hitting zone, high finish. Fault: hitting UP/scooping. Cue: "drop under
  it, finish high over the shoulder."
- **Contact in front of the front hip**. Fault: late contact behind the hip —
  usually a LATE-PREP/footwork root, not a swing fault (diagnose the root).
- **Serve**: stance + Continental → knee bend + LEG DRIVE → racquet drop behind
  back (tip down), elbow leads → full extension contact up & in front →
  PRONATION ("palm in → palm flat → palm out"). Faults: no leg drive; flat
  "frying-pan/waiter's" finish (no pronation). Internal shoulder rotation is the
  single biggest direct speed driver (but invisible side-on).
- **1HBH**: firm, laid-back (hyper-extended) wrist at contact; fault = wristy/
  collapsing wrist.
- **Footwork** (USTA's 4 objectives): split-step AS opponent strikes → explosive
  first step (push off outside foot) → spacing ~an arm's length (small adjust
  steps, don't reach) → recover toward the middle. Faults: no/late split (root
  of most late, off-balance shots); flat-footed; too close; no recovery.

## CRITICAL — what a single side-on phone clip CANNOT show (don't fabricate)
- NOT reliably visible side-on: exact joint angles in degrees, shoulder/hip
  separation angle, internal shoulder rotation, far-hand grip, lateral spacing,
  court positioning/recovery geometry. → Describe DIRECTION, never invent numbers.
- GOOD side-on: swing path, racquet drop, contact vs front hip, leg drive/
  extension, balance, finish height, split-step timing.
- Kinetic chain (legs→hips→trunk→shoulder→arm→racquet) is the teaching lens but
  a heuristic, not a rigid timing law (elite players deviate). Don't be dogmatic.

## Numbers to NOT cite (failed verification or not phone-measurable)
- Separation angles (~20°/30°/20°): conceptual coiling cue only, not measurable.
- Knee ~110°, wrist ~13°: small-sample lab means, observe direction not degrees.
- Refuted correlations: knee-flexion r=0.83, elbow r=-0.93, trunk r=0.76,
  trunk/arm°/s→kph conversions — DO NOT use.

## Sources (primary)
- USTA Grips/Preparation/Swing-Path brochure; USTA Player Development Sport Science.
- Tennis Australia "Stroke & Tactical Fundamentals" (2010).
- Elliott 2006 BJSM; Landlinger 2010 JSSM; Frontiers 2024 (Reveret); Giles 2022 IJSPP.
