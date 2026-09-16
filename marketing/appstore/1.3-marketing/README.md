# App Store screenshots — 1.3

Six frames, 1320×2868 (6.9"), built by `build.py` from real device captures.

```bash
python3 build.py        # writes out/*.png
```

## Where the pictures come from

`assets/shots/*.png` are `xcrun simctl io screenshot` captures from a booted
**iPhone 17 Pro Max**, which reports exactly 1320×2868, so nothing is scaled.
The simulator was seeded with a plausible season — six matches and ten fuel
entries across seven weeks — so the calendar and the averages show a used app
rather than empty state. The UI in every frame is the real UI; nothing is
painted over the top.

## What each frame claims, and where the number comes from

| Frame | Claim | Source, counted at build time |
|---|---|---|
| 01 journal | "Any day · backdated" | the feature itself |
| 02 fuel | 52 sources cited | `nutrition_guide.en.json` |
| 02 fuel | 9 guide sections | same file |
| 03 tactics | 30 lessons, chapter 1 free | `tactics_curriculum.json` (`isFree` asserted) |
| 04 wall | 8 levels | `WallDrill.all` in the Swift source |
| 06 decisions | 156 scenarios | `quiz_questions.json` |

`build.py` reads each file and fails the build if `isFree` ever stops being
true for exactly one chapter. A frame cannot outlive the fact it states.

## What is deliberately absent

- **No ratings, no award, no download count, no testimonial.** The 1.1 set
  opened on two verbatim App Store reviews pulled from the ASC API. They are
  not carried over: they were verified on a date that has passed, and an
  unverified quote is worse than no quote. Re-verify against ASC before
  putting a review back on a frame.
- **No claim about the recipe set being free.** It is Premium, so the fuel
  frame badges the guide instead, which is free.
- **No coach review.** The in-app purchase is off sale, and the store must
  not advertise something a player cannot buy.

## Rendering

Headless Chrome, `--window-size=1320,2868 --force-device-scale-factor=1`.
The device capture is embedded as a data URI so the page has no external
dependency and renders identically on any machine.
