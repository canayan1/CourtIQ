# Wall section — "Duolingo for wall tennis" gamification design

Research-backed design for the premium Wall section (see [[wall-duolingo-vision]]).
Goal: a level-by-level, challenge-driven, competitive wall-practice loop where the
audio Rally Cam counter is the **referee**. Built honestly (no fake social proof),
tuned so we don't over-gamify.

---

## 1. What the research says (and the hard numbers)

**Streaks are the single biggest retention lever.** Users with a 7+ day streak
retain at ~2.4× the rate of users who never build one; a streak wager gave +14%
D14 retention. Streaks work via **loss aversion** — a 180-day user is motivated by
*not losing 180*, not by reaching 181. Keep the streak count **visible on first
open** (fire icon), and convert effort → identity. ([Duolingo case study, trophy.so](https://trophy.so/blog/duolingo-gamification-case-study); [Yu-kai Chou streak design](https://yukaichou.com/gamification-study/master-the-art-of-streak-design-for-short-term-engagement-and-long-term-success/); [Duolingo streak habit research](https://blog.duolingo.com/how-duolingo-streak-builds-habit/))

**Mercy infrastructure is mandatory, not optional.** "A streak that can never be
repaired is a bomb set for a bad day." Duolingo moved from *buying* streak freezes
to **Earn Back** (redo a session within a window to reclaim the streak) because it
preserves the streak's earned value. Repair options retain users "through illness,
travel, and grief." ([Apptitude teardown](https://apptitude.io/blog/how-duolingos-streak-mechanic-actually-works/); trophy.so)

**Leagues drove +25% lesson completion.** Design: **30 users per cohort, one week**,
top ~7 promote, bottom ~5 relegate, **reset every Monday**. Cohorts matched by
similar activity + timezone. Psychology: weekly reset = urgency without permanent
hierarchy; a 30-person cohort makes winning feel *attainable*; fear of relegation
(asymmetric loss aversion) drives more than hope of promotion. ([Duolingo leagues, deconstructoroffun](https://duolingo.deconstructoroffun.com/mechanics/leagues); [How leagues work, Duolingo blog](https://blog.duolingo.com/duolingo-leagues-leaderboards/))

**XP + weekly leaderboards** ≈ +40% engagement; each mechanic is **calibrated to a
point in the journey** (day-1 achievable goals → day-7 streak → first league → months-in
badges/friend-streaks). Don't ship one mechanic; ship a *ladder* of them. ([StriveCloud](https://www.strivecloud.io/blog/gamification-examples-boost-user-retention-duolingo); [thepmrepo](https://www.thepmrepo.com/articles/how-duolingo-gamified-monthly-active-users-lessons-in-habit-formation))

**Flow / difficulty:** engagement peaks when **challenge matches skill** (Csíkszentmihályi).
Give clear goals, **immediate feedback**, and ramp difficulty as skill grows — the
"just-manageable challenge" / Goldilocks band. ([Flow in game design, gamedeveloper.com](https://www.gamedeveloper.com/design/the-flow-applied-to-game-design); [skill-challenge balance & flow, PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC8943660/))

**Pitfalls (fitness/sports-specific):**
- **Over-reliance on extrinsic rewards erodes intrinsic motivation** — when the
  points stop mattering, so does the activity. Anchor to real improvement, not
  points-for-points. ([Frontiers motivation-crowding](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1286463/full))
- **Streak/again pressure causes stress + overtraining** in fitness contexts —
  worse than in a knowledge app because the activity is physical. ([ResearchGate fitness gamification](https://www.researchgate.net/publication/388104203_Role_of_Gamification_in_Enhancing_Learning_and_Participation_in_Fitness_Apps))
- **Data overload:** numbers motivate only when they drive a decision or show
  progress toward something the user cares about. Don't dump metrics. ([Glofox](https://www.glofox.com/blog/fitness-gamification/))

**Leaderboard cold-start:** with few users a board is **empty and demotivating**.
Fixes: **layered boards** (weekly / monthly / all-time — different users chase
different timescales); a fresh user can "crush it weekly" while ignoring all-time.
Choose a metric that reflects the behavior you want (not one that's trivially
gamed). ([Yu-kai Chou leaderboard guide](https://yukaichou.com/gamification-analysis/leaderboard-design-definitive-guide-octalysis/); [gamified e-learning leaderboard study](https://www.sciencedirect.com/org/science/article/pii/S1062737524000672))

---

## 2. What's DIFFERENT for us (physical skill, not knowledge)

Duolingo teaches knowledge: a "lesson" is cheap, repeatable dozens of times/day.
**Wall tennis is physical effort** — needs a wall, ball, space, energy. So:

- **Cadence is lower** (maybe 1 session/day or a few/week). The daily streak must
  count **"practiced today" = any session**, never "did N reps." We already have
  this via `ActivityManager` (unified active-day streak).
- **Mercy matters MORE than Duolingo** — you can't always practice daily (no wall,
  rain, injury). Ship **streak freeze + earn-back from day one**, or the streak
  becomes a punishment that drives churn.
- **Immediate feedback is already native** — the live Rally Cam count + per-hit
  haptic IS the flow-theory "immediate feedback." This is our unfair advantage
  over a quiz app; lean into it (big live number, haptic, sound-off to avoid mic
  feedback).
- **Challenge = skill-tuned targets.** Beginner "5 in a row" vs advanced "40 in a
  row." Tie targets to `TennisPlayerLevel` so the first challenge is winnable and
  they ramp — the Goldilocks band.
- **Reward effort + improvement, not just completion** (intrinsic anchor): "new
  personal best," "+3 vs last week," "longest rally yet" — not just "+10 XP."

---

## 3. The design (tailored)

**The counter's job (answers "sayaç ne işe yarıyor"):** it's the **referee** — it
measures whether you cleared a level's challenge (e.g. "20 in a row"), auto-clears
the level, awards XP, updates your PB, and (later) posts your best to the board.

**A) Levels + path (the spine).** Each level = one wall drill + a concrete,
skill-tuned **challenge target**. Clearing unlocks the next (we already have the
ladder + unlock in `WallHubView`/`WallProgressManager`). Add a Duolingo-style
**path/map** UI: units → level nodes → progress. Each node shows target + PB +
cleared state.

**B) Challenge targets (flow-tuned).** Per level, a target the counter judges:
"X hits in a row" / "keep a rally Y seconds" / (v2, needs vision) "Z in the target
zone." Targets scale by player level. Auto-clear the moment the live count hits the
target — instant win moment (haptic + celebration + XP).

**C) XP + progression.** XP per level cleared + per PB beaten; a visible level/rank.
Keep it a *secondary* signal to the real metric (rally length / PB), to avoid the
extrinsic-only trap.

**D) Streak (with mercy).** Reuse the unified daily streak; surface it prominently
in the Wall hub. Add **streak freeze + earn-back** (redo a session within 24–48h to
reclaim). Gentle, encouraging notification copy — never shaming.

**E) Competition — HONEST cold-start (critical).** We have ~0 users and a hard rule:
**no fake players, no seeded bots, no fabricated numbers** ([[dropvolley-en-first]]).
So stage it:
  1. **Now (1 user works):** compete against **yourself** — beat your PB, race a
     **"ghost" of your previous best**, weekly personal goal. This is honest and
     motivating with zero other users.
  2. **Friends:** invite real people (we already have doubles invite links) → a
     small real friends board.
  3. **Real global leagues later:** once there are enough real users, add the
     Duolingo 30-cohort weekly league (task #40, needs Supabase `deploy et`).
     **Never** show an empty or faked global board before then.

---

## 4. Build order (given ~0 users + no backend deploy yet)

1. **Per-level challenge targets + counter auto-clear + XP** — makes the Wall a
   game *today*, no backend, and makes the counter meaningful. **← start here.**
2. **Path/map UI** (Duolingo spine) + prominent streak surface in the Wall hub.
3. **Streak freeze + earn-back** (mercy) — cheap, high retention, honest.
4. **Self-competition:** PB + "ghost"/previous-best race + weekly personal goal.
5. **Real leagues/leaderboard** — only with `deploy et` + when real users exist;
   layered (weekly/monthly/all-time); honest, no bots.

**Guardrails:** anchor every mechanic to real improvement; keep targets in the
winnable Goldilocks band; make streaks forgiving; never fake competition.
