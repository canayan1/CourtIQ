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

## Two API quirks worth knowing

1. **`list_screens` is unusable here** — returns `{}` and then "invalid
   argument" for the same project. `get_project` only ever returns the FIRST
   screen's thumbnail, so screens 2 and 3 can't be pulled down; they're
   visible in the Stitch web app.
2. **A new project ignores the `designSystem` argument** — project 04 was
   given `assets/9912387750154062633` but Stitch generated its own
   "Courtside Heritage" theme instead (Rubik + Hanken Grotesk, primary
   #1a1a1a, accent #d97241). It landed close to our identity by luck, not by
   instruction. Before the SwiftUI pass, re-apply the real system with
   `update_design_system` on any project used.
