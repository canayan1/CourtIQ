# Tactics tab — port notes (2 Sep 2026)

The Tactics tab is the lessons feature of the separate TennisTactics app
(`/Users/can/Projects/TennisTactics`), ported wholesale into DropVolley as
the third pillar (see `three-pillar-restructure` decision). Nothing was
rewritten; the diffs are seams.

## What came across

`CourtIQ/Features/Tactics/` — 13 files, ~3.5k lines:
models (`Curriculum`, `Dialogue`, `PlayerProgress`, `AccessGate`), services
(`ContentStore`, `DialogueBuilder`, `Sound`), rendering (`CourtDiagram`,
`Mascot` = Rocco), views (`LearnPathView` rail, `DialogueView` player,
`LessonCompleteView`, `LessonView` notes).

Content: `Resources/Content/tactics_curriculum.json` (5 chapters × 6 lessons
+ 1 side set of 5 = 35 lessons) and `tactics_dialogues.json` (35 scripts,
270 nodes). Audio: 9 stings as `Resources/Audio/tactics_*.wav`.

## Seams (the only edits)

| TennisTactics | DropVolley |
|---|---|
| `SubscriptionStore` (StoreKit 2) | `TacticsAccess.isSubscribed` ← `PremiumGate.isPremium(session)` |
| `PaywallView()` | `TacticsPaywallSheet` → `PaywallView(source: "Tactics")` |
| `AppPalette`, `DesignSystem` | reused; missing pieces in `TacticsDesignKit.swift` (`AppPalette.Court`, `premiumGradient`, `CardSurface`, `PrimaryButton`, `QuietButton`, `KineticBar`, `StatPill`, `CenteredScroll`); `Eyebrow` gained a `tint:` |
| `curriculum.json` / `dialogues.json` / `*.wav` | prefixed `tactics_` |
| `TennisTactics.progress.v1`, `TennisTactics.sound.muted` | `DropVolley.tactics.progress.v1`, `DropVolley.tactics.sound.muted` |
| Rally warm-up card (`ExtraRoute.rally`) | Tennis IQ card (`ExtraRoute.tennisIQ` → `DailyIQView`) |

Freemium rule is unchanged and lives only in `AccessGate`: replays free,
sequential unlock, chapter 1 free (`isFree` flag in the JSON), premium = all,
otherwise one free lesson per day, spent at open time.

## Integration hazard (kept)

`LearnPathView` owns its `NavigationStack`; `LessonRouter` and the stores are
injected **outside** it (`TacticsTabRoot`). MainTabView therefore does NOT
wrap this tab in a NavigationStack. Moving the injection inside the stack
traps on the first lesson tap. `SIMCTL_CHILD_QC_TACTICS=lesson` pushes the
first lesson headlessly to prove the push works.

## Known gaps

- **English only.** Views are literal strings and the 290 KB of content is
  EN. Consistent with the EN-first decision; a TR pass is a content project.
- Rocco (the raccoon coach) is kept: the 270 dialogue nodes are written in
  his voice.
- TennisTactics' content tests (`ContentIntegrityTests`, `DialogueGraphTests`)
  are not yet in `CourtIQTests`.
- `TrainView` (the old Train hub) and its `QC_TRAIN` hook are no longer in
  the nav tree; Drills / Recover / Programs are Home shortcuts.
