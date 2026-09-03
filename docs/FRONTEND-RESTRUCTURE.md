# Front-end restructure — the whole app tells the three-pillar story

Status: plan 2 Sep 2026; steps 1–7 landed on `restructure/1.1` on 3 Sep 2026 (see §11). Decision it serves: DropVolley sells exactly three
things — **Coach** (your video, reviewed), **Wall** (camera-judged drills),
**Tactics** (lessons, Duolingo-style). 1.0.7 (build 36, in review) changed
the *tab bar* to say that. Nothing underneath does yet. This document is the
screen-by-screen inventory of what still tells the old story, what each
screen's new job is, and the order to do it in. Target: **1.1**, on a branch,
while 1.0.7 ships the counter fix.

Principle for every screen: **if it isn't one of the three, it is either a
utility (settings, legal) or it is demoted to a shortcut.** No screen gets to
introduce a fourth headline.

---

## 0. What the app says today, screen by screen

| Surface | What it says now | Pillar it serves | Verdict |
|---|---|---|---|
| Onboarding hook (`OnboardingCopy.hookTitle`) | "Train your Tennis IQ." / "AI coaching for … your swing, your decisions, your match craft." | none of the three by name | rewrite |
| Onboarding showcase (7 pages) | Swing two ways · **AI match coaching** · **Doubles compatibility** · daily scenario · **AI coach knows your game (Alex)** · numbers · early-player quotes | 1 of 7 pages is a pillar | rebuild as 3 pages |
| Onboarding questions | goal (win/fix/strategy/NTRP) · experience · level · weaknesses · "building" · result | fine — but the answers only feed IQ difficulty and the Wall band | keep, re-point outputs |
| Activation cover (`ActivationView`) | IQ taste → "Meet your AI Coach" + plan bullets: swing score, daily drill, mental scenarios, 5 daily scenarios, log every match | AI chat + old features | replace |
| Home | IQ hero (number, streak) → coach hero → 5 shortcuts (Drills, Matches, Doubles, Recover, Programs) → Recent | IQ is inside Tactics now; half the screen is old features | rebuild |
| Paywall (`paywall.*`) | title "AI Coach"; benefits: Unlimited AI Coach · swing 0–100 · tactics/opponents/drills; tip copy: "**Only the AI Coach is premium**" | contradicts Wall grading + Tactics being premium | rewrite |
| Profile | greeting · avatar · streak & progress · **quiz history (premium)** · beta feedback · account · legal; "Unlock AI Coach" button; tactical/play-style cards | old stats model | slim to utility + the three pillars' progress |
| Coach tab | swing flow root (title Coach) · AI chat in toolbar · real-coach waitlist card | pillar 1, but three things without one story | one story: film → read → (soon) coach |
| Wall tab | hub "The wall never misses." · rungs · level detail · Rally Cam | pillar 2 | keep; copy pass |
| Tactics tab | ported rail; own design kit; English literals; "Tactics" title; IQ card | pillar 3 | keep; unify kit + localize |
| Drills (`TrainPracticeView`) + Pro shot, Mobility, Programs, Matches, Doubles, Daily IQ | reachable via Home shortcuts / Tactics card | secondary | keep reachable, stop marketing them |
| Notifications, Daily tip, Today, Community, Train hub, old onboarding | strings/files still in the bundle | none | delete |

String weight tells the same story: `matches.` 105 keys, `training.` 71,
`drill.` 70, `today.` 29, `community.` 14 versus `wall.`+`rallycam.` 61,
`coachreview.` 62, and **zero** localized keys for Tactics.

---

## 1. Onboarding — sell the three things, then ask three questions

**Hook (one screen).** "Three ways to get better at tennis." Sub: "Film a
swing and get it read. Hit the wall and get it counted. Learn the tactics
that win points." CTA "Show me". (No superlatives, no user counts — the
2.3.1 rule stays.)

**Showcase — exactly three pages, one per pillar, each a live sample:**
1. *Coach* — the swing sample already built (two annotated frames) + one
   line: "AI reads it today. A real coach review is coming — join the
   waitlist inside." Drop the match-coaching, doubles and "Alex" pages.
2. *Wall* — a 6-second loop of the rung being counted (shoulder-turn count
   ticking, the verdict chip). Copy: "Prop the phone behind you. It counts
   every rep and grades the rung."
3. *Tactics* — the court diagram from lesson 1 + Rocco's first bubble.
   "Thirty lessons, one decision at a time. Chapter 1 is free."
Then the *quotes* page stays (real reviews only) and the *bridge*.

**Questions — keep goal / level / weaknesses, drop experience** (level
already implies it). Each answer must land somewhere visible:
- level → Wall band (already), Tactics starting chapter suggestion, IQ
  difficulty (already)
- goal → which pillar Home leads with for the first week
- weaknesses → the first Tactics chapter recommended + the Coach stroke
  pre-selected

**Result screen** = "Your first week": three cards, one per pillar, each
with the *first action* (film your forehand / clear Steady Rally / lesson 1),
not a "coach-shaped plan" of programs and mobility.

**Activation cover: delete.** It sells the AI chat. The result screen above
is the activation. `ActivationView` (270 lines) and `activation.*` (20 keys)
go.

## 2. Home — today's three moves

Order, top to bottom:
1. **Header** — wordmark, avatar → Profile. Unchanged.
2. **Three pillar cards** (not heroes for one of them): Coach, Wall, Tactics.
   Each shows *state*, not a slogan: Coach = "Last read: forehand, 82 · film
   another"; Wall = current rung + best verdict chip; Tactics = next lesson
   title + streak/XP. Tap = switch tab (they are tabs; no duplicate pushes).
3. **Tennis IQ strip** — one row: number, streak, "today's 5" → pushes
   `DailyIQView` inside Tactics' story (it *is* tactics practice).
4. **"Also"** — a single compact row of small chips: Drills · Matches ·
   Doubles · Recover · Programs. Chips, not photo tiles: they stop competing
   with the pillars.
5. **Recent** — keep, but the feed's `RecentActivity` gets a `pillar`
   field and the strip groups by it.

Goes: `iqHero` as the first thing on screen, the photo shortcut grid, the
"JUMP BACK IN" eyebrow, `linkRow` (dead).

## 3. Coach tab — one story: film → read → coached

Root stays `SwingAnalysisView`, retitled and re-sequenced:
- Step 1 "Film" (stroke + handedness + how-to-film tip) — keep.
- Step 2 "Read" — the AI result; rename "AI analysis" → "Coach's read".
- Step 3 "Get it reviewed by a coach" — the waitlist card, always visible on
  the result, honest "coming soon", with the count of people waiting shown
  only to admins.
- AI chat: **demote from toolbar to "Ask about this read"** on the result
  screen (context = the analysis). The standalone chat landing
  (`AICoachTabRoot.landing`, "Your personal AI tennis coach") goes. Chat
  remains premium.
- History stays in the toolbar.

## 4. Wall tab — keep, tighten copy

- Hub sub-line: drop "the decisions that build Tennis IQ" — that's Tactics'
  line now. New: "Eight rungs. The camera counts and grades every one."
- `wall.rallycam_cta` "Score it with the camera — auto-target + accuracy" →
  "Count my reps" (what the button already says elsewhere).
- Level detail: the premium gate copy says what premium buys *here* (camera
  counting + verdicts), not "AI Coach".
- Verdict overlay: add "Send to Coach" as the bridge to pillar 1 (already
  wired via `preloadedClip`; make it a first-class button).

## 5. Tactics tab — make it native

- Move `TacticsDesignKit` components into `SharedUI/DesignSystem.swift`
  (they are the same studio); delete the kit file.
- Localize: `LearnPathView`, `DialogueView`, `LessonCompleteView`,
  `LessonView` chrome strings → `tactics.*` keys, EN + TR. Content JSON
  stays EN for 1.1 (a TR content pass is its own project; the model already
  supports it per-locale if we ship `tactics_curriculum_tr.json`).
- Tennis IQ card on the rail stays; the IQ *number* moves to the rail
  header pills (streak · XP · IQ) so Tactics owns it.
- Port `ContentIntegrityTests` + `DialogueGraphTests` into a new
  `CourtIQTests` target (there is none today; only UI tests).

## 6. Paywall — one paywall, three reasons

Title "DropVolley Premium". Three benefit rows, one per pillar:
- Coach — unlimited AI reads + the chat about them; first in line for real
  coach reviews.
- Wall — camera counting and verdicts on every rung.
- Tactics — every chapter, every day.
Then plans (unchanged SKUs). Kill `paywall.tip_*` ("only the AI Coach is
premium" is now false) and the "Support DropVolley" tip framing. `source`
values collapse to `coach | wall | tactics | profile`.

## 7. Profile — utility plus progress

Keep: avatar/name, level (editable), handedness, streak, account, legal,
beta feedback. Add: three progress rows (reads done · rungs cleared · lessons
done). Remove: quiz-history archive section and its premium gate,
"Unlock AI Coach" button (paywall is reached from the pillars), tactical /
play-style profile cards (move to Tactics later if ever).

## 8. Delete list (compiled, unreachable, or telling the old story)

Files: `App/TodayView.swift`, `Features/Training/TrainView.swift`,
`TrainingHubView.swift`, `Features/Community/CommunityViews.swift`,
`Features/ProShot/ProShotCard.swift`, `Features/Onboarding/OnboardingView.swift`,
`TourStep.swift`, `SelfAssessmentStep.swift`, `ActivationView` (in
MainTabView). Strings: `onb.*` (93, dead onboarding), `onboarding.*`
paywall/trial keys, `activation.*`, `today.*`, `community.*`, `tab.today/
practice/community/training/profile/train/matches/doubles`. QC hooks:
`QC_TRAIN`. Remove from `project.pbxproj` with `tools/pbx_add.py`'s inverse
(add a `--remove`).

Keep but demote (reachable from Home "Also" chips only): Drills + Pro shot,
Mobility, Programs, Matches, Doubles, Notifications pre-ask.

## 9. Order of work (each step ships green, screenshots via the QC hooks)

1. **Paywall + Profile** (small, unblocks copy everywhere else).
2. **Home** rebuild.
3. **Onboarding** hook/showcase/result + delete Activation.
4. **Coach tab** re-sequence + chat demotion.
5. **Tactics** kit merge + localization + tests target.
6. **Wall** copy pass + "Send to Coach".
7. **Delete list** + strings sweep + TR review of every changed key.
8. Screenshot set 1.1, What's New, submit.

Rough size: ~1.5–2 days of focused work; steps 1–3 are the visible half.

## 10. What this plan does NOT do

- No new features. No fourth pillar. No social/matches investment (see the
  split-social-app idea).
- No TR translation of the 290 KB Tactics content.
- Doesn't touch the wall detector or the swing pipeline.

---

## 11. Status (3 Sep 2026, branch `restructure/1.1`)

| Step | Commit | Notes |
|---|---|---|
| 1 Paywall + Profile | `c6c1902` | three-pillar benefits; quiz archive + tactical cards out; pillar progress rows in; chip says Premium |
| 2 Home | `c6c1902` | three state cards, IQ strip, "Also" chips |
| 3 Onboarding | `054837e` | hook, 3 pillar slides (wall + tactics samples new), first-week card; Activation deleted |
| 4 Coach | `1fe1dd1` | chat demoted to "Ask about this read"; AICoachTabRoot deleted |
| 5 Tactics | (this commit) | `TacticsCopy` EN/TR for all chrome; design kit merged into `DesignSystem.swift`; **tests target not created** (no unit-test target exists; hand-editing pbxproj for a new native target judged too risky — do it in Xcode) |
| 6 Wall | `1fe1dd1` | hub sub-line, "Count my reps", verdict "Send to Coach" |
| 7 Delete list | (this commit) | 8 dead files removed from disk + pbxproj; 195 dead keys dropped (`onb.`, `onboarding.`, `activation.`, `community.`, old tabs, tip jar, quiz archive) |
| 8 Screenshots + submit | pending | after Can's review |

Found on the way: `LanguageManager` is **locked to English** in `init` ("localization not yet shipped"), so the TR strings — including the new `tactics.*` copy — are maintained but never shown. Unlocking it is a one-line change plus a TR review pass of every screen; not done here.
