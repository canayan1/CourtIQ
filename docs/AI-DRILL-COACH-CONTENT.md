# AI Drill Coach — drill library, program & scoring (DRAFT v2, for coach vetting)

> **Status: DRAFT v2 for the owner (a tennis coach) to vet.** v2 folds in the
> owner's three calibration decisions + a second verified research pass.
> Decisions locked by the owner (Jun 2026):
> - **Adaptive difficulty:** every scoreable target ships as a **Seviye 1 / 2 / 3
>   ladder** (easy → hard); the user self-selects and the AI scores against the
>   chosen tier. (Replaces the single "adult number" approach.)
> - **Full library:** expand to **~22 drills** across the 7 themes.
> - **Basic equipment:** a hitting partner + a full court with **its own lines**;
>   cones rarely available, so setups use existing court lines and every
>   cone-dependent drill has a **no-cone variant**.
>
> Tags: **[SRC]** = grounded in a verified, cited source · **[COACH VET]** =
> first-principles draft filling a research gap, needs your review · **[RE-SCALE]**
> = re-pitched from youth/junior origin to recreational adults.
> **Important:** all **numeric Seviye targets are coaching defaults** (NTRP and the
> federations publish *no* per-ball counts) — they are defensible starting points
> for you to calibrate, not evidence-based standards.

## 0. Evidence notes & honest caveats (read first) — UPDATED in v2
- **Consistency → direction → depth is a real, sourced ramp.** USTA NTRP
  descriptors (verbatim in §1): 2.5 sustains a short slow rally; 3.0 consistent at
  medium pace, *lacks* directional control/depth/power; 3.5 directional control
  but still lacks depth; 4.0 adds depth + can vary. Our program order is validated.
  [SRC: USTA NTRP] *(a playing-ability rating, not a curriculum — treat as an
  ordered progression.)*
- **Practice-design evidence — corrected & nuanced for ADULTS.** The lab
  "random/variable beats blocked" (contextual-interference) benefit is
  **weak-to-negligible in applied/on-court settings overall** (Ammar 2023: CI
  benefit largely a "myth" in sports practice — ~20% of 183 outcomes agreed; Czyz
  2024 *Scientific Reports*: in applied settings the random-practice retention
  benefit was "almost negligible"). **BUT the adult subgroup is the exception:**
  Czyz 2024 *Frontiers* (transfer) found a medium, significant benefit for
  **adults (SMD ≈ 0.54)** vs negligible for youth (SMD ≈ 0.12). A serve study
  (Buszard 2017, *skilled juniors 11–13*): **blocked** practice won the *closed*
  serve test but the **higher-interference (serial)** group **transferred better**
  to a match-like test. *(Contrast was blocked vs serial — not fully random;
  juniors, not adults — cite for the principle.)*
  → **Design rule (unchanged, now better grounded for adults):** start each set
  *blocked to groove* the pattern, then move to *game-like/variable* reps for
  transfer. Do **not** claim "always randomize," and do **not** say "CI is a myth"
  for our audience — for adults, variable practice *does* help.
- **Stat correction (load-bearing):** the share of points ending within **0–4
  shots is ≈ 65–77%**, *not* "~90%." Peer-reviewed: Prieto-Lage et al. 2023
  (*PLoS ONE*, 4,669 Grand Slam points) — **64.9% clay / 77.4% grass / 68.8%
  hard**, and the server wins **~80%** of first-serve short-rally points. The
  verified O'Shannessy term is **"Serve +1"** (the prior draft's "3-1 pattern" is
  not verifiable — renamed). Do **not** quote the popular "70/20/10" split or the
  "91% of match winners also win the 0–4 battle" line — neither traces to a
  primary source.
- **No validated 0–100 rubric exists** → §4 is **proposed**, built from the
  *objective sub-dimensions the sources give us* (consecutive-ball counts, depth-
  past-service-line gates, narrowing-lane success, sequence completion). Show
  in-app as **"DropVolley Session Score (beta)."**
- **Do NOT assert (refuted in verification):** a fixed session time-template; a
  specific split-step % speed gain (e.g. "13.1% faster"); Spider-Drill reliability
  stats; any clean "random beats blocked" verdict; the unverified O'Shannessy
  numbers above.
- **Biggest remaining gap:** directional **recognition** (deciding *when* to change
  direction) still has **no verified, scored adult drill** — the recognition drills
  in Theme 3 are constraints-led **[COACH VET]** drafts (defensible, not
  "validated"). Don't present them in-app as research-backed.

## 0b. How "adaptive" works — the Seviye ladder (NEW)
Every scoreable target below ships as **Seviye 1 (kolay) / 2 (orta) / 3 (zor)**.
- The user picks a level (or the app suggests one from their Tennis Profile / NTRP).
- The AI scores the filmed set **against the chosen tier**, plus qualitative
  technique. Tier achievement feeds the rubric (§4).
- All ladders are anchored to the NTRP re-scale table (§1) and are **coaching
  defaults** — your numbers override mine.

## 1. Reference data for adult re-scaling (NEW, sourced)
> This is the calibration spine for every numeric target. Court/zone dimensions are
> ITF-exact; the **ball-count ladder is a coaching default** (NTRP publishes none).

**NTRP descriptors (verbatim) — the progression anchor.** [SRC: USTA NTRP]
- **2.5** "learning to judge where the ball is going… can sustain a short rally of
  slow pace."
- **3.0** "fairly consistent when hitting medium-paced shots… lacks execution when
  trying for directional control, depth, or power."
- **3.5** "improved stroke dependability with directional control on moderate
  shots, but still lacks depth and variety."
- **4.0** "dependable strokes, including directional control and depth… plus lobs,
  overheads, approach shots and volleys with some success."

**Consecutive cooperative-ball ladder (coach-calibrated, Jun 2026).** Cooperative
rally, ball kept in play. Anchored to the coach's read of recreational adults
(typical "medium" ≈ 10–12; solid-player ceiling ≈ 20+). Map a drill's Seviye to the
user's band:

| Band | Seviye 1 | Seviye 2 | Seviye 3 |
|---|---|---|---|
| 2.5 | 5–6 | 7–9 | 10–12 |
| 3.0 | 8–10 | 10–12 | 15–18 |
| 3.5 | 12–14 | 15–18 | 20–24 |
| 4.0 | 16–20 | 20–24 | 25+ |

**Court & target dimensions (ITF-exact).** [SRC: ITF]
- Singles width 8.23 m (27 ft); doubles 10.97 m (36 ft); each **alley/tramline
  1.37 m (4.5 ft)**. Net 0.914 m centre / 1.07 m posts. Service line 6.40 m from
  net; baseline 11.89 m; **baseline→service-line corridor 5.49 m**.
- **Depth gate "past the service line"** is a real drill convention; a sourced
  adult depth game scores past-service-line +1, into-net −3, short −1. A
  **"deep third"** = the rear ~1.8 m before the baseline (back third of the 5.49 m
  corridor); 2/1/0 scoring (deep third / past service line / service box).
  [SRC: PlayYourCourt depth game]
  **Coach-calibrated depth % target (Jun 2026):** share of balls landing deep
  (past the gate) — **Seviye 1 / beginner 35% · Seviye 2 / intermediate 60% ·
  Seviye 3 / advanced 85%.** Two-tier (+1 past service line, +2 deep third) is the
  standard depth scoring.
- **Precision-target width ≈ one alley (1.37 m).** Independently validated: the
  Buszard 2017 serve study used a **137 cm** target box — essentially one alley
  width. A defensible deep-corner box for adults ≈ **1.4 m wide × ~1.8 m deep**
  (alley width × deep-third depth; depth pairing is a coaching default).
- **Net-clearance window** ≈ 0.9–1.5 m above the band for safe, deep rally balls
  (more with topspin). *(Only the 0.914 m net height is sourced; the clearance
  window is a coaching default.)*

**Movement timings.** [SRC: USTA PD agility; split-step study PubMed 28210342]
- **Split-step:** take-off ≈ the opponent's contact; land ≈ 130–180 ms after.
  Coaching cue at adult granularity: **"land as they strike the ball."**
- **Recovery:** after a wide ball, recover toward the angle-bisector (≈ centre)
  fast — side-shuffle for short displacements, turn-run→shuffle for the very wide
  ball. *(No federation publishes a "recover within N seconds" number — qualitative.)*
- **Work:rest for movement drills:** in-play tennis ≈ 1:1–1:4; for *developing*
  movement use ~1:3–1:5; USTA PD agility drills run **10–20 s work**, ~30 s rest.
  **Deconditioned adults:** lengthen rest toward 1:5 (e.g. 10 s work : 50–60 s
  rest), shorten bouts (~8–10 s), fewer reps. *(The deconditioned adaptation is a
  coaching default; USTA PD S&C is junior/LTAD-oriented — don't cite it as an
  adult source.)*

## 2. Drill library (by theme)
> Per-drill fields: objective · setup · run · target (Seviye 1/2/3) · scoring ·
> errors · cue · progression · source tag. **Numeric targets = coaching defaults
> unless a [SRC] gives them.**

### Theme 1 — Rally tolerance / consistency
**1. Rally to the Number** [SRC: USTA Net Generation "Budge"] [RE-SCALE]
- **Objective:** build the "miss less" habit. **Setup:** full court, cross-court
  half. **Run:** cooperative rally to a consecutive-ball target; on a miss, reset.
- **Target (S1/S2/S3):** consecutive balls in, per the §1 ladder for the user's
  band. **Scoring:** longest streak + # of target rounds completed in the 5-min set.
- **Errors:** flat/low margin, rushing. **Cue:** add net clearance + spin to raise
  the margin. **Progression:** raise the count → add pace → shrink the box.

**2. Minute Marathon** [COACH VET]
- **Objective:** consistency under mild time pressure. **Setup:** full court,
  down-the-middle or cross. **Run:** in a fixed 2-min block, keep the longest
  unbroken rally; restart instantly on a miss.
- **Target (S1/S2/S3):** longest streak hits §1 ladder (S1/S2/S3). **Scoring:**
  best streak + total balls in. **Cue:** smooth, repeatable, big margin.
  **Progression:** raise pace / narrow the corridor.

### Theme 2 — Cross-court control (FH & BH)
**3. Cross-Court Count** [SRC: USTA Net Generation] [RE-SCALE]
- **Objective:** groove the two diagonals (FH-FH, BH-BH). **Setup:** rally within
  one cross-court box (use the singles sideline + service line as the box edges —
  no cones). **Run:** cross-court only; count consecutive balls in the box.
- **Target (S1/S2/S3):** consecutive in-box from §1 ladder. **Scoring:** count +
  % in. **Cue:** finish toward the target, contact out front. **Progression:** →
  narrow the lane (Squeeze Rally) → add a depth gate (Theme 4).

**4. Two-Wing Switch** [COACH VET]
- **Objective:** hold both diagonals back-to-back. **Setup:** full court. **Run:**
  4 balls FH-cross, then move and rally 4 BH-cross; repeat. **Target (S1/S2/S3):**
  clean switches sustained: 2 / 3 / 4 cycles. **Scoring:** clean cycles in a row.
  **Cue:** recover through the middle between wings. **Progression:** shorten to
  2-and-2 (faster footwork).

### Theme 3 — Direction & change of direction (incl. recognition)
**5. Squeeze Rally** [SRC: USTA Net Generation] [RE-SCALE]
- **Objective:** directional control under a shrinking target. **Setup (no-cone
  variant):** use the **doubles alley** as the starting lane, or two players agree
  a lane "between the singles sideline and one racquet inside it." **Run:** rally
  inside the lane; after **4 successful balls, narrow the lane one racquet-length**;
  continue until too narrow.
- **Target (S1/S2/S3):** narrowest lane sustained for 4 balls: alley width / ¾
  alley / ½ alley. **Scoring:** narrowest lane held. **Cue:** extend the
  follow-through to steer. **Progression:** add change-of-direction (alternate
  DTL/cross).

**6. 2-Cross-1-Line** [SRC: Sportplan "Change of Direction" — execution, not
recognition]
- **Objective:** groove the *mechanics* of redirecting safely. **Setup:** full
  court, existing lines. **Run:** hit 2 balls cross-court then 1 down-the-line,
  repeating; partner sends the line ball back cross to restart.
- **Target (S1/S2/S3):** clean cycles in a row: 3 / 5 / 5-with-every-DTL-deep.
  **Scoring:** longest run of clean cycles. **Errors:** over-rotating the DTL wide;
  losing depth on the change. **Cue:** "cross is the rally; line is on balance,
  through the ball." **Progression:** randomize when the line ball comes → becomes
  the recognition drill below.

**7. Read & Call** (directional **recognition**) — *ship as beta / experimental
in-app* [COACH VET — no verified scored adult drill exists]
- **Objective:** decide *when* to change direction off a live read, not a memorized
  pattern. **Setup:** cross-court rally (no cones). **Trigger = a "step-in" ball:**
  any ball landing inside the court that you can move forward and **step into** →
  go down-the-line; a deep ball that **pushes you back** → stay cross and rebuild.
- **Run:** rally cross; **change down-the-line only off a step-in ball, stay cross
  off a deep ball.** Partner mixes depths naturally. (Scaffold: partner calls
  "step-in!/deep!" at the bounce for early rounds, then goes silent so the player
  reads it.)
- **Target (S1/S2/S3):** correct decisions / 20 balls — **S1** partner calls aloud
  ≥12/20; **S2** silent ≥10/20; **S3** silent and a *wrong-direction* ball costs a
  point even if in. **Scoring:** correct-decision count (S3 net = correct −
  wrong-direction). **Cue:** "Can I step in? → line. Pushed back? → cross."
  **Progression:** add a DTL target zone → play it out live.
- *Coach note (Jun 2026): the full read also weighs the opponent's court position +
  whether you can recover in time — taught as theory; the on-court drill simplifies
  it to the step-in cue. Constraints-led design; show in-app as beta, not "validated."*

**8. Call the Corner** (perception–action cue) — *ship as beta* [COACH VET]
- **Objective:** decouple shot choice from a script — react to a late cue. **Setup:**
  baseline rally; the two singles corners ("line"/"cross") are the targets.
- **Run:** feeder calls **"line!" / "cross!"** *at contact* (or raises a hand); the
  hitter must place the next ball there, in. Late call = a genuine read.
- **Target (S1/S2/S3):** correct-and-in / 20 — **S1** call given early ≥14/20;
  **S2** call at contact ≥11/20; **S3** call at contact + the "line" ball must land
  deep ≥8/20. **Scoring:** correct-direction-and-in count. **Cue:** "eyes up, late
  commit, finish through the target." **Progression:** call later → add a "middle"
  option → live point scores double on a correct call.

### Theme 4 — Depth & margin
**9. Past the Line** [SRC: USTA Net Generation "Grade School"] [RE-SCALE]
- **Objective:** hit deep with margin, two-tier reward. **Setup:** the **deep
  third** = rear ~1.8 m before the baseline (no cones — judge against the distance
  baseline↔service line). **Run:** rally; score each ball **+1 past the service
  line, +2 in the deep third** (short of the service line / into net = 0).
  **Target (S1/S2/S3):** share of balls landing deep (past the gate) — **35% / 60%
  / 85%** (beginner / intermediate / advanced). **Scoring:** % deep + point total.
  **Cue:** aim several feet over the net, heavier topspin. **Progression:** add a
  minimum net-clearance height → Deep-Third Game (race format).

**10. Deep-Third Game** [SRC: PlayYourCourt depth scoring] [RE-SCALE]
- **Objective:** reward *real* depth, penalize the net. **Setup:** the **deep
  third** = rear ~1.8 m before the baseline (no cones — use the distance baseline↔
  service line and aim for the back). **Run:** rally; score each ball **+2 deep
  third / +1 past service line / 0 service box / −3 into net.** **Target
  (S1/S2/S3):** reach 10 / 15 / 20 points before three net errors. **Scoring:**
  running total. **Cue:** net clearance first, depth second. **Progression:** add a
  minimum net-clearance height.

### Theme 5 — Approach & net play  *(gap-fill — now drafted from sourced structures)*
**11. Approach & Recover** [SRC: USTA Net Generation Yellow — structure] [COACH VET:
numbers]
- **Objective:** read the short ball, drive an approach down-the-line, keep moving.
  **Setup:** player at centre; partner drop-feeds a ball landing ~service line; the
  singles sideline is the target reference. **Run:** read it → move up → approach
  DTL (deep, inside the sideline) → continue forward and split-step crossing the
  service line.
- **Target (S1/S2/S3):** approach past service line & inside sideline — back third /
  back quarter / back quarter within a racquet of the line. **Scoring:** /10 feeds
  on target (S1 5, S2 6–7, S3 8). **Errors:** cross-court out of habit; approaching
  off a too-deep ball; admiring the shot; no split. **Cue:** "read it, drive it
  line, keep moving — split as they hit." **Progression:** partner adds a pass →
  player plays the first volley (→ drill 13).

**12. Game of 7** [SRC: WebTennis24 transition drill — structure & 15/30 scoring]
[COACH VET: depth constraints]
- **Objective:** rally → convert one ball to an approach → close and finish 3
  volleys. **Setup:** both at baselines; singles lines = in/out; pattern called each
  round. **Run:** 3 baseline balls cross → 4th ball = approach cross → move up, play
  3 volleys. All 7 = win the point; next round switch to DTL.
- **Target (S1/S2/S3):** complete the 7-shot run — S1 any depth; S2 approach behind
  service line; S3 approach deep + all volleys kept past the partner's service line.
  **Scoring:** tennis scoring (15/30/40/game) per completed run. **Cue:** "three
  steady, one to attack, three to finish." **Progression:** cut to 2 baseline balls;
  live volley-returns after ball 4.

**13. Approach + First Volley** [SRC: LTA Cardio "Approach Volley" + Sportplan —
"1st deep / 2nd angled"] [COACH VET: numbers]
- **Objective:** the two-volley finish — deep controlling first volley, angled
  put-away second. **Setup:** player baseline → partner feeds; service line = the
  transition zone; alley = the angle target. **Run:** approach DTL → split before
  partner's reply → first volley **deep DTL** → close → second volley **angled** to
  finish.
- **Target (S1/S2/S3):** both volleys to target — S1 both in, right general
  direction; S2 first past service line + second in the correct box; S3 first in
  back quarter + second within a racquet of the alley. **Scoring:** /10 sequences
  (S1 5, S2 6–7, S3 8). **Errors:** first volley short/hard; no split; angling the
  first instead of the second. **Cue:** "first deep to set up, second angled to
  finish." **Progression:** real passing attempts; remove the called direction.

**14. Split-Step Volley Ladder** [SRC: split-step/volley standard — PTR/USPTA/ITF]
[COACH VET: streak numbers]
- **Objective:** reliable split + controlled first volley off both wings. **Setup:**
  player between baseline and service line; partner alternates FH/BH feeds; service-
  box corners = references. **Run:** move forward, **split exactly as the partner
  contacts**, punch the volley deep, recover, repeat the other side.
- **Target (S1/S2/S3):** controlled deep volleys in a row alternating FH/BH —
  6 / 8 / 10. **Scoring:** longest unbroken on-target streak in a 2-min block.
  **Errors:** late split (flat-footed); swinging not punching; racquet head
  dropping. **Cue:** "split as they hit, punch and recover." **Progression:** faster
  cadence; body-jam feeds; finish each rep by closing for a put-away.

**15. Fast Hands** [SRC: Athletes Untapped "fast hands" — 10-ball structure] [COACH
VET: pass rates]
- **Objective:** hand speed/control for reaction volleys close in. **Setup:** player
  inside the service box mid-net; partner feeds quick from mid-court. **Run:** 10
  fast feeds — FH / BH / body — reset hands to a "V" between balls.
- **Target (S1/S2/S3):** controlled volleys back — 6/10 any direction / 7/10 / 8/10
  to a **called** side. **Scoring:** clean controlled volleys /10. **Errors:** big
  backswings; not clearing body-jam balls; tight grip; head below wrist. **Cue:**
  "short hands, quick reset, see-block-recover." **Progression:** faster feeds; add
  a low volley; angled put-away on the last ball.

**16. Overhead — Touch-the-Net → Lob & Smash Live** [SRC: Sportplan overhead +
Feel Tennis air/bounce] [COACH VET: numbers]
- **Objective:** recover from the net, turn, and finish the smash deep; then apply
  it live. **Setup:** racquet touches the net to start; partner feeds a lob; back
  quarter = target. **Run:** drop back sideways (off-hand pointing), **S-tiers
  below**; reset to the net each rep.
- **Target (S1/S2/S3):** **S1** let it bounce, smash deep half (5/10); **S2** smash
  out of the air into the back quarter (6/10); **S3 = Lob & Smash Live** — first
  smash in the air + deep, then **play the point out keeping every ball in the air
  on your side** (no bounce), first to 11. **Scoring:** on-target smashes /10 (S1–2)
  or points won off an in-target smash (S3). **Errors:** backpedaling flat; ball
  behind the head; late shoulder turn; crushing instead of placing deep. **Cue:**
  "turn, point, get behind it, drive it deep." **Progression:** start from the
  service line; random lob depths (judge air vs bounce); smash to the open court.

### Theme 6 — Serve & patterns of play
**17. Serve +1 (Wide / T)** [SRC: O'Shannessy "Serve +1"; server-advantage data
Prieto-Lage 2023] [RE-SCALE] *(renamed from "Serve Plus One / 3-1")*
- **Objective:** link the serve to its highest-percentage next ball. **Setup:**
  server + returner, full court; centre service line + sidelines define wide / T /
  open court (no cones). **Run:** serve **wide → +1 into the open court**; serve
  **T → +1 behind the returner**. 3-ball unit, reset, alternate sides.
- **Target (S1/S2/S3):** serve in + +1 to target — S1 +1 in the correct half (6/10);
  S2 +1 in the deeper open-court quadrant (6/10); S3 +1 past service line in the
  correct quadrant **and** server recovers to centre (5/10). **Scoring:** completed
  sequences /10 (+1 bonus if the +1 lands deep). **Cue:** "serve opens the door, +1
  walks through it." **Progression:** returner returns with intent → server reads
  return depth and chooses live → play out from ball 4.

**18. First-Strike 3+2** [SRC: Mattspoint "3+2"; ≤4-shot data Prieto-Lage 2023]
[COACH VET: adult scaling]
- **Objective:** finish *inside* the first-strike window instead of drifting into
  long rallies. **Setup:** server vs returner, play points. **Run:** server must win
  **within 2 shots after the serve** (serve, +1, one more); if the rally goes longer,
  the **returner wins**. Variation: a 3rd post-serve ball only counts if taken at the
  net (volley/swing-volley/overhead).
- **Target (S1/S2/S3):** S1 just try to end early — count points ending ≤4 shots
  /10; S2 score it as stated, game to 7; S3 same + server served to a **called**
  location. **Scoring:** points won under the ≤4-shot rule. **Cue:** "three balls to
  do damage — serve, hurt, finish." **Progression:** serve+1-only finish; net-only
  3rd ball; keep score across service games.

**19. Return +1** [SRC: O'Shannessy "first four shots"; data Prieto-Lage 2023]
[COACH VET: the short/deep read]
- **Objective:** the returner's first-strike combo — a controlled return that sets
  up a planned next ball. **Setup:** play from a second-serve-pace serve (cooperative).
  **Run:** **(a)** land the return deep (past service line, cross by default), **(b)**
  play a planned +1 — short reply → change DTL; deep reply → stay cross, rebuild.
- **Target (S1/S2/S3):** deep return in + +1 — S1 +1 any, in (6/10); S2 +1 to the
  correct direction per the read (6/10); S3 +1 also deep (5/10). **Scoring:**
  completed return+1 units /10. **Cue:** "return deep buys time; then short-goes-
  line, deep-stays-cross." **Progression:** full first-serve pace → choose +1 live →
  play out.

### Theme 7 — Movement & recovery footwork
**20. Recover to Center** [SRC: USTA Player Development agility] [RE-SCALE]
- **Run:** after a wide FH/BH (out to the singles sideline), recover with a
  **crossover then shuffle** toward centre before the next ball. **Target
  (S1/S2/S3):** in-time recoveries / 10 wide balls — 5 / 7 / 9 (partner adds pace by
  tier). **Scoring:** # in-time recoveries. **Cue:** first step is the crossover.

**21. Split-Step on Every Volley** [SRC: USTA PD agility; split-step study]
- **Run:** at net, **split-step on each incoming ball, landing as the partner
  strikes.** **Target (S1/S2/S3):** clean split-then-volley reps in a row —
  5 / 8 / 12. **Scoring:** splits executed on time. **Cue:** "land as they hit."

**22. Movement Benchmarks** (fitness, NOT stroke quality) [SRC: USTA agility; Spider
protocol] [RE-SCALE]
- **17s / Court Widths** (run 17 court widths for time) and the **Spider Drill**
  (5 sprints; 4.11 m & 5.49 m legs; ~30 s rest between reps). **Use as trackable
  movement/fitness metrics only.** Published cutoffs are **junior** → set **adult
  reference times** (coaching default; lengthen rest for deconditioned adults).
  *(Do NOT cite a split-step % gain or Spider reliability stats — both refuted.)*

## 3. How the AI scores a set (maps to §4)
The AI watches the 5-min set (Gemini) and reports against the drill's **scoreable
dimensions** plus which **Seviye** the player sustained: consecutive-ball counts
(consistency), balls past the service line / in the deep third (depth), balls in the
target lane (direction), correct-decision counts (recognition), sequence completion
+ depth bonus (patterns), and qualitative technique/effort. **Precise ball-in-zone
*measurement* = Level 2 CV, out of scope** — the AI gives counts/estimates +
qualitative judgment, scored against the chosen tier.

## 4. 0–100 session score (global weights coach-confirmed Jun 2026; still beta)
No validated rubric exists, so the **overall 0–100 ships as beta** — but the
**global component weights below are coach-confirmed** (balanced). Per-theme
overrides remain proposed. The AI scores each component 0–100 (tier achieved +
qualitative), then weights:
- **Consistency** (streaks / % in) — **30**
- **Execution / technique** (qualitative) — **25**
- **Intent / targeting** (lane + depth-gate + correct-decision success) — **25**
- **Drill success rate** (sequence completion, e.g. Serve +1, Game of 7) — **20**

**Tier→band guide (proposal):** on each component, Seviye 1 achieved ≈ 60–70,
Seviye 2 ≈ 75–85, Seviye 3 ≈ 90–100; missing the chosen tier scales below 60.

**Per-theme weight overrides (proposal — VET):**
| Theme | Consistency | Execution | Intent | Drill success |
|---|---|---|---|---|
| Consistency / cross-court | 45 | 30 | 15 | 10 |
| Direction & **recognition** | 20 | 20 | **45** | 15 |
| Depth | 30 | 25 | 35 | 10 |
| Approach & net | 20 | 35 | 20 | 25 |
| Serve & patterns | 15 | 25 | 25 | **35** |
| Movement | 25 | 40 (mechanics) | 15 | 20 |

> Show in-app as **"DropVolley Session Score (beta)."**

## 5. 8-week progressive program (coach-confirmed Jun 2026)
- **Format:** **8 weeks · 3 sessions/week**; each session = 3–4 × **5-min sets**
  (~20–30 min). [confirmed]
- **Per set (confirmed):** **first ~1–2 min *blocked* grooving → then
  *game-like/variable* reps** (§0 rule; for adults the "then vary" half is
  supported). Movement work 10–20 s on / ~30 s rest × 2–3 [lengthen rest for
  deconditioned adults].
- **Ramp** (validated by NTRP): consistency → direction → depth → patterns → pressure.
  - **Wk 1–2 Consistency:** Rally to the Number, Minute Marathon, Cross-Court Count.
  - **Wk 3 Direction:** Squeeze Rally, 2-Cross-1-Line, then **Read & Call**.
  - **Wk 4 Depth:** Past the Line, Deep-Third Game (+ keep consistency).
  - **Wk 5 Patterns:** Serve +1, Return +1, Approach + First Volley.
  - **Wk 6 Net & movement:** Game of 7, Split-Step Volley Ladder, Recover to Center.
  - **Wk 7–8 Pressure:** First-Strike 3+2, Overhead Live, Call the Corner under
    point-play / streak targets.

**Session-by-session (draft — Jun 2026).** 3 sessions/week (A · B · C); each = 3 ×
5-min sets in order (first set = the short blocked groove). Every set runs the
drill's **Seviye for the player's level**; coach tweaks freely.
- **Wk 1 — Consistency base** · A: Rally to the Number → Minute Marathon → Recover
  to Center · B: Cross-Court Count (FH) → Cross-Court Count (BH) → Rally to the
  Number · C: Minute Marathon → Two-Wing Switch → Split-Step on Every Volley (intro)
- **Wk 2 — Consistency + cross-court** · A: Rally to the Number → Cross-Court Count
  (FH) → Two-Wing Switch · B: Minute Marathon → Cross-Court Count (BH) → Recover to
  Center · C: Two-Wing Switch → Rally to the Number (next tier) → **Movement
  Benchmarks (baseline test)**
- **Wk 3 — Direction** · A: Cross-Court Count (warm) → Squeeze Rally → 2-Cross-1-Line
  · B: Rally to the Number (warm) → 2-Cross-1-Line → Read & Call (scaffolded) · C:
  Squeeze Rally → Read & Call (silent) → Recover to Center
- **Wk 4 — Depth** · A: Cross-Court Count (warm) → Past the Line → Deep-Third Game ·
  B: Rally to the Number (warm) → Past the Line (higher %) → 2-Cross-1-Line (depth on
  the DTL) · C: Deep-Third Game → Squeeze Rally + depth gate → Recover to Center
- **Wk 5 — Patterns** · A: Cross-Court Count (warm) → Serve +1 (Wide) → Serve +1 (T)
  · B: Rally to the Number (warm) → Return +1 → Approach + First Volley · C: Serve +1
  (mixed) → Approach + First Volley → Recover to Center
- **Wk 6 — Net & movement** · A: Cross-Court Count (warm) → Approach & Recover →
  Game of 7 · B: Split-Step Volley Ladder → Fast Hands → Recover to Center · C: Game
  of 7 → Approach + First Volley → Overhead (Touch-the-Net)
- **Wk 7 — Pressure I** · A: Rally to the Number (warm) → First-Strike 3+2 → Serve +1
  (live) · B: Read & Call (live) → Call the Corner → Recover to Center · C: Overhead
  Touch-the-Net → Lob & Smash Live → Game of 7 (live)
- **Wk 8 — Pressure II / test** · A: First-Strike 3+2 → Return +1 (live) → Call the
  Corner · B: Past the Line (test %) → Squeeze Rally (narrow) → Serve +1 (live) · C:
  **Movement Benchmarks (final test)** → Game of 7 (live) → free point-play with
  streak targets
- *Coach: swap/cut any set; weak themes can repeat across weeks.*

## 6. Vetting status (coach, Jun 2026)
**Signed off ✅**
- ✅ **Ball-count ladder** coach-calibrated (§1): typical medium 10–12, solid-player
  ceiling 20+.
- ✅ **Depth:** two-tier gate (+1 past service line / +2 deep third); **% deep by
  level 35 / 60 / 85** (beginner / intermediate / advanced).
- ✅ **Recognition gaps filled:** Read & Call + Call the Corner ship **as beta**,
  trigger = **"step-in ball"** (opponent position + recover-ability noted as theory).
- ✅ **Net-play numbers:** approach/volley **6–7/10** medium; overhead **5–6/10**.
- ✅ **Rubric:** global weights confirmed **balanced 30 · 25 · 25 · 20** (per-theme
  overrides remain a proposal).
- ✅ **Program:** **8 weeks × 3/week**; per-set **~1–2 min blocked → variable**.
- ✅ **Sources named** + corrections applied (≈65–77%, "Serve +1", CI nuance for
  adults, Buszard = serial-vs-blocked / juniors).

- ✅ **Session-by-session set list** for all 8 weeks drafted (§5) — coach to
  red-pen individual sessions.

**Remaining (optional / light):**
1. **Per-theme rubric overrides** (§4) — currently a proposal; tune later if wanted.
2. **Add more drills** to any theme (currently 22) if desired.
3. **Red-pen the 8-week session list** (§5) — swap/cut sets as you see fit.

> All numeric Seviye targets remain coaching defaults — adjust any in the field.

## 7. Sources (verified)
- **USTA Net Generation** practice plan, Yellow Ball / full court (Budge, Squeeze
  Rally, Grade School) — primary.
- **USTA NTRP** characteristics (2.5/3.0/3.5/4.0 descriptors) — primary.
- **USTA Player Development** agility & movement manual (recovery, split-step,
  17s/Court Widths, Spider) — primary; junior cutoffs → set adult references.
- **ITF** court dimensions — primary.
- **Prieto-Lage et al. 2023**, *PLoS ONE* 18(9):e0286076 — ≤4-shot prevalence
  (64.9/77.4/68.8%) + ~80% first-serve short-rally hold — primary/peer-reviewed.
- **Practice design:** Ammar et al. 2023 (*Educ. Res. Rev.* 39:100537); Czyz et al.
  2024 (*Sci. Reports* 14:15974, retention; *Front. Psychol.* 15:1377122, transfer —
  adults SMD ≈ 0.54, youth ≈ 0.12); Buszard et al. 2017 (*Front. Psychol.* 8:1931,
  serial-vs-blocked, juniors 11–13) — primary/peer-reviewed.
- **Net play / patterns (coaching-grade, not peer-reviewed):** O'Shannessy / Brain
  Game Tennis ("Serve +1," first four shots); PTR Adult Development; USPTA "Get to
  the Net"; LTA Cardio Tennis drills; Feel Tennis (ITF L3 / PTR / GPTCA); PlayYourCourt
  depth game; WebTennis24, Sportplan, Athletes Untapped (drill structures).
- **Recognition design:** constraints-led approach — Robbie Joyce; Matt Kuzdub
  (Mattspoint); Rob Gray (Perception & Action). *(No verified scored adult
  recognition drill — drills are first-principles.)*
- **Supporting blogs** for tactical "change direction off the short ball" — secondary,
  treat as conventional wisdom, not data.
