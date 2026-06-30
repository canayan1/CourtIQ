# DropVolley — Content Review (Jun 2026)

Full review of the in-app tennis content. **Headline: content is a genuine strength** — substantial, well-structured, tennis-accurate, and largely bilingual. Issues are *gaps*, not quality.

## Inventory
| Content | Size | Bilingual |
|---|---|---|
| Quiz scenarios | **66** (was 60) | ✅ 100% (TR parity perfect) |
| AI Coach manual (`tennis_manual.ts`) | 572 lines, 11 sections, v1.2.0 | n/a (prompt) |
| Daily tips | 50 | ✅ |
| Training programs | 222 items | 🟡 partial (titles yes; overviews/guidance EN) |
| Court-tap drills | 75 | 🟡 partial (~2 TR fields/item) |
| Mobility flows | 90 | 🟡 partial |
| Pro-shot patterns | 16 | ✅ better-translated (~5 TR/item) |
| FAQ | — | 🟡 **absent** (in CLAUDE.md, no content/view found) |

## Quality (verified by sampling)
- **Quizzes:** sampled serve + doubles — tennis-accurate, sound explanations, good takeaways. Perfect category balance (now 11 per category × 6).
- **Coach manual:** SECTION 1 spot-read — court dimensions + percentage rules all correct. Comprehensive coverage.
- **Manual full-accuracy pass** by the owner (a coach) recommended — I verified structure + a sample, not every claim.

## Gaps + status
- [x] **No "hard" quiz difficulty** → **DONE:** added `QuizDifficulty.hard` + **6 hard scenarios** (1 per category, bilingual, varied surfaces); advanced/coach players now *prefer* hard (`Quiz.swift` `levelBiasedBank`). Build green.
- [ ] **(c) Diagram coverage** — only 30/66 quizzes have a diagram (doubles + others lack them); all original diagrams are **clay** (the 6 new hard ones vary: hard/grass/clay). → backfill diagrams on the gap set + vary surfaces.
- [ ] **(b) Deep bilingual gap** — training program overviews/day-guidance, drill coaching cues, mobility detail are **English-only** at the data layer (titles are translated). This is the **biggest TR-experience gap** — bigger than the view chrome already localized. A large, multi-pass translation effort.
- [ ] **FAQ** — reconcile: it's in CLAUDE.md but not in the app (likely superseded by the AI Coach / Community). Update docs or build it.
- [ ] Minor: quiz difficulty titles (`Foundation`/`Match Pressure`/`Advanced Tactics`) are English-only (enum-level, hard to localize without moving to the view).

## Recommended order
1. ✅ Hard scenarios (done) — deepens the Tennis-IQ moat.
2. (b) Deep-TR of the big content — biggest TR-user gap. Multi-pass (start with training overviews, then drill cues, then mobility).
3. (c) Backfill quiz diagrams + vary surfaces.
4. Reconcile FAQ in docs/positioning.
