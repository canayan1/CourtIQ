# Swing analysis — which method, and why

*Research pass, 27 Aug 2026. Answers: is the "coach checkpoint + VLM yes/no"
spec (`~/Downloads/dropvolley-checkpoint-analysis-prompt.md`) the right
method? Short answer: its diagnosis is right, its remedy is not supported by
the evidence, and two of its ideas are worth keeping anyway.*

---

## 1. What the spec bets on

> Open-ended visual judgement is unreliable → narrow the model to ONE yes/no
> question about ONE still frame, and it becomes reliable.

The first half is well supported. The second half is the part I went looking
for evidence on, because the whole design rests on it.

---

## 2. What the literature actually says

### 2a. VLMs on fine-grained motion — confirmed bad

**MotionBench** (CVPR 2025) tests exactly this: fine-grained motion questions
over video. Best model ~57–58%; **Gemini 1.5 Pro 50–51%**; random guessing
25%. Models "lack inter-frame differencing and tend to average or ignore
subtle visual cues." Repetition-counting sits near random.

This vindicates the project's earlier finding and the decision to stop
sending video for judgement.

### 2b. VLMs on pose from *stills* — also bad. This is the problem.

The spec's escape is to switch from video to still frames. The evidence does
not support that rescue:

- **Spatial457** (CVPR 2025), pose-focused tasks: best model **Gemini Pro
  1.5 at 40.5%**.
- **MMSI-Bench**: best open-source ~30%, OpenAI o3 40%, **humans 97%**.
- GPT-4o answering questions about a person's viewpoint in an image: 27.5%.

So a VLM judging *body configuration in an image* is roughly as unreliable as
one judging motion in video. Narrowing the question does not fix a model that
cannot see limb geometry precisely.

**Why this matters more than the video version failing:** a checkpoint
returns `pass`/`fail` with a cited frame and a confident evidence sentence. It
*looks like a measurement*. Fluent wrong prose is detectable by a reader who
knows tennis; a fluent wrong checkbox is not. The spec would move the failure
somewhere harder to catch.

### 2c. Pose estimation — good, but weakest exactly where tennis lives

Single-camera markerless 3D pose, validated against VICON
([PMC10951609](https://pmc.ncbi.nlm.nih.gov/articles/PMC10951609/)):

| Variable | RMSE |
|---|---|
| knee, hip, trunk, pelvis, spine | **≤10°** |
| **shoulder flexion** | **11–15°** |

Their "good" bar is 12°, chosen because that is roughly a physiotherapist's
visual accuracy. So legs and trunk are measurable; the shoulder — the joint
every forehand cue is about — sits at the edge of usable. Caveats: 8 athletes,
and accuracy "reduces quickly for non-validated movements." Tennis strokes are
not among the validated movements.

Apple's own `VNDetectHumanBodyPose3DRequest` gives 17 joints in 3D on-device
(iPhone 12 Pro+, iOS 17) and Apple states the obvious constraint plainly:
phone cameras see in 2D, so **anything out of the camera plane suffers
projection error**. Camera angle is the dominant error source, not the model.

### 2d. The racket is not reliably measurable at all

**RacketVision** (2025), the benchmark built for this: tennis racket keypoints
PCK@0.2 **89.6%**, detection mAP@50 78–79% — but **side keypoints only
64.8–80%**, because they are "occluded by hand grip, subject to motion blur
during rapid movements, and highly sensitive to viewing angles." The paper
claims **no 3D racket pose recovery** from monocular video.

Racket-face angle at contact — the thing coaches actually talk about — is not
available from a phone clip. Any checkpoint phrased around it is unanswerable
by any method we can ship, model or not.

### 2e. The one sensor with high, reproducible accuracy: the wrist

- Wrist IMU + decision tree: **98.1%** for forehand / backhand / serve.
- Commercial smartwatches: **>95%**. Volleys stay hard.
- Skill-level discrimination from IMU is an active, working research area.

And **SwingVision**, the market leader in this exact niche, does on-device
vision for ball and court but classifies **shot type from Apple Watch wrist
motion**. The strongest player in the category already concluded that vision
alone doesn't do this job.

### 2f. Honest limits of this research

The benchmark numbers above test **Gemini 1.5 Pro-era models** (early–mid
2025). Frontier models have moved since. Nothing here proves today's models
score 40%; it proves the capability was weak recently enough that assuming it
is now fine would be a guess. That is an argument for measuring, not for
either optimism or despair.

---

## 3. What to build

### Layer 1 — ship what is genuinely measurable, claim nothing more

Deterministic, on-device, no model judgement anywhere:

1. **Camera-angle gate first.** Projection error dominates everything. Detect
   side-on vs. behind-baseline from pose geometry and refuse to analyse the
   wrong angle. This alone removes most of the garbage.
2. Metrics from the ≤10° group, anchored on the existing audio impact time:
   - contact point relative to the body — early / in front / late
   - follow-through height, split-step presence and timing
   - recovery toward centre, footwork between strikes
3. **Consistency across reps** — variance of these across the clip's strikes.
   A phone genuinely beats the human eye at this, and it is honest.

Nothing shoulder-rotation. Nothing racket-face.

### Layer 2 — the coach reviews are the dataset. This is the real asset.

Every real coach review is a **human label on a real user clip at a real
phone angle**. Nobody else building this has that. The spec's `Checkpoint`
type is exactly the right label schema — so keep it, but have the **coach**
fill it during delivery, as part of the panel work they already do.

After N labelled clips you can *measure* rather than guess whether any
automated method beats chance on your own data and your own users' camera
angles.

### Layer 3 — automate only what the numbers earn

In descending order of evidence:
1. **Apple Watch IMU** — strongest evidence, and the one the market leader
   picked. Fits the AI Drill Coach plan already on file.
2. **Small classifier on pose features** — trained on Layer 2's labels.
3. **VLM checkpoint** — only if the spike below says so.

---

## 4. The spike to run before any feature code

Cheap, and it settles the argument:

1. Take 20–30 clips already collected.
2. You label every checkpoint `pass` / `fail` / `unclear`. You are the coach;
   this is ground truth.
3. Run the spec's §5 checkpoint prompt over the same extracted frames on a
   current model.
4. Score with **Cohen's kappa, not raw accuracy.** With three verdicts and
   imbalanced classes, raw accuracy flatters a model that always says the
   majority answer.

**Decide the rule before seeing results:** kappa < 0.4 → do not ship it, at
any prompt. 0.4–0.6 → usable only as a hint behind an `unclear`-heavy gate.
> 0.6 → the spec's architecture is vindicated and worth building properly.

Frame extraction (`SwingFrameExtractor`, 768px/0.7) and impact detection
(`SwingImpactAnalyzer`) already exist, so the spike is one edge function and
an afternoon of labelling.

---

## 5. What to keep from the spec regardless

- **`unclear` as a first-class verdict**, never coerced to `fail`.
- **The usability gate** — >40% unclear suppresses the result screen. A
  mostly-blind analysis must not be presented as a result. This is the single
  best idea in the document and it applies to Layer 1 too.
- **Coach-authored, prioritised checkpoints** as the unit of feedback.
- **Never send coach prose to the model.** It would anchor and confirm.

## 6. What to drop

- SwiftData (§2) — the project has none; everything is UserDefaults + Codable.
- An in-app Anthropic client (§5) — the key is server-side only; this has to
  be an edge function, and it has to sit behind the spend breaker.
- A parallel `CoachReport` with `coachName`/`coachCredential` (§2) — reviewers
  are anonymous by product decision, and `coach_review_deliverables` already
  carries a structured report. Extend it; don't build a second one.

---

## Sources

- MotionBench — https://arxiv.org/abs/2501.02955
- Spatial457 (CVPR 2025) — https://openaccess.thecvf.com/content/CVPR2025/papers/Wang_Spatial457_A_Diagnostic_Benchmark_for_6D_Spatial_Reasoning_of_Large_CVPR_2025_paper.pdf
- MMSI-Bench — https://www.researchgate.net/publication/392204678_MMSI-Bench_A_Benchmark_for_Multi-Image_Spatial_Intelligence
- Exercise quantification from single-camera markerless 3D pose — https://pmc.ncbi.nlm.nih.gov/articles/PMC10951609/
- RacketVision — https://arxiv.org/html/2511.17045v1
- Tennis stroke classification from wrist IMU — https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9699098/
- Apple `VNDetectHumanBodyPose3DRequest` — https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest
- SwingVision — https://swing.vision/home/
