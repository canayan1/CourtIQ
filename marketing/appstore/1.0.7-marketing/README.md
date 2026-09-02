# App Store screenshots — 1.0.7

Six frames at 1320×2868 (6.9"), marketing layer over real simulator captures
of build 36 (the four-tab app: Home · Coach · Wall · Tactics).
Regenerate: `python3 build.py && npx --yes hyperframes@0.8.20 snapshot --at 0.5,1.5,2.5,3.5,4.5,5.5`,
then copy `snapshots/frame-0N` → `out/` in the order below.

| File | Headline | Badges |
|---|---|---|
| `01_reviews` | Like having a coach with you. | two verbatim App Store reviews, no rating |
| `02_tactics` | Learn tactics like a language. | 30 lessons · Ch. 1 free · Daily free lesson |
| `03_wall` | The wall never misses. Now it counts. | 8 levels · Counts by camera · No tripod |
| `04_decisions` | Tennis is decisions, not strokes. | 10+ certified coaches · 15+ yrs · 1000s taught |
| `05_swing` | Film one swing. Get coached. | AI today · Real coach waitlist · Free to start |
| `06_the_club` | A club's playbook, in your pocket. | 10+ coaches behind it · 15+ yrs · 156 hand-written |

## What changed from 1.0.6

- **Tactics frame is new** — the ported lesson rail. Lesson count and the
  "chapter 1 free" flag are read from `tactics_curriculum.json` at build
  time; the script asserts exactly one free chapter.
- **Wall** badge says *counts by camera*, and the sub-line says what the
  camera actually watches (you turn and swing). The sound counter is gone.
- **Coach review frame is honest about the waitlist.** 1.0.6's "A person
  watches it. Not an algorithm." described a feature that is a waitlist in
  the build; 1.0.7 sells what ships (AI today) and names the real-coach
  review as coming. No "72h · Human" badges until a coach actually reviews.
- Dropped the second Home frame ("Your whole game") — Home appeared twice.
- All captures retaken: the old ones showed the five-tab bar.

## The claims, and exactly what they mean

Same rules as 1.0.6: DropVolley is the app, **the DropVolley project** is
the club behind it. "10+ certified coaches", "15+ years", "thousands of
students" describe the club's coaches who shaped the content — never who
reviews your swing in the app. No rating, download count or roster size
appears anywhere (two reviews is not a rating). "Free" is true: the app is
free, the AI coach chat and Wall grading are the paid parts.
