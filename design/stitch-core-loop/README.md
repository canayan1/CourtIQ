# Stitch — DropVolley Core Loop (direction round)

Status: **direction-finding.** Owner approved the look; these become the
target for a later SwiftUI pass on the real app.

Design system asset: **assets/9912387750154062633** ("DropVolley Clay") —
encodes the exact palette, Plus Jakarta Sans, 12px roundness, AND the product
rules (≤5-word primary lines, one primary action per screen, Home is TODAY
only, honesty rules: no invented ratings/precision, unmeasurable = "—").

## Screens

| # | Screen | Stitch project | Have image? |
|---|---|---|---|
| 01 | Home — IQ hero + Coach + Recent rail | 15483249102910597479 | ✓ `01_home.png` |
| 02 | Tennis IQ session — question + court diagram | 15483249102910597479 | review in Stitch UI |
| 03 | Session summary — IQ delta, XP, streak | 15483249102910597479 | review in Stitch UI |
| 04 | Skill path — one merged court map | 17407665673871936467 | ✓ `04_skill_path.png` |
| 05 | Choose your path — AI vs real coach | 15483249102910597479 | review in Stitch UI |
| 06 | Coach review order — consent + price | 8418416009148772597 | ✓ `06_coach_order.png` |
| 07 | Coach review report — the One Thing | 15283106124373811040 | ✓ `07_coach_report.png` |
| 08 | Coach tab — one-line quota, big CTA | 16049933221628331055 | ✓ `08_coach_tab.png` |

## Two API quirks worth knowing

1. **`list_screens` is unusable here** — returns `{}` and then "invalid
   argument" for the same project. `get_project` only ever returns the FIRST
   screen's thumbnail, so screens 2 and 3 can't be pulled down; they're
   visible in the Stitch web app.
2. **A design system does not travel between projects.** Passing project 01's
   asset id to project 04 was silently ignored and Stitch invented its own
   theme. The fix that works: in every new project call `create_design_system`
   then `update_design_system`, then pass THAT project's asset id. Projects
   06 and 07 were built this way and kept the palette and fonts exactly.
3. **A project can lock itself to DESKTOP.** Project `764185169801179342`
   returned `deviceType: DESKTOP` despite MOBILE being passed, and produced a
   landscape poster of a professional player at a branded tournament instead
   of an app screen — unusable, and a licensing risk if it had been kept. It
   stayed stuck on a retry. Fix: start a fresh project and state "portrait
   iPhone app screen, never a poster" in BOTH the design MD and the prompt.
   The design MD now also forbids identifiable professionals and branded
   venues in imagery.
4. **A project degrades after ~3 generations** — the main project started
   answering "invalid argument" to every call. One project per screen avoids
   it and has the bonus that `get_project`'s thumbnail is that screen, so
   each design can actually be pulled down and reviewed.
