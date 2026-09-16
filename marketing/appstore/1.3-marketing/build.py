#!/usr/bin/env python3
"""App Store screenshots for 1.3 — a marketing layer over real captures.

Every number on these frames is counted from the shipping content at build
time, so a frame cannot outlive the fact it states:

  · 156 scenarios   — len(quiz_questions.json)
  · 30 lessons      — chapters[].lessons in tactics_curriculum.json
  · chapter 1 free  — the `isFree` flag, asserted below
  · 8 wall levels   — WallDrill.all, counted in the Swift source
  · 9 guide sections — nutrition_guide.en.json (the guide is free; the
                       recipe set is Premium, so it is not badged here)
  · 52 sources      — the source links in nutrition_guide.en.json

Nothing about ratings, awards, download counts or roster size appears here.
The 1.1 set opened on two verbatim App Store reviews; they are not carried
over, because they were verified against the ASC API on a date that has
passed and an unverified quote is worse than no quote.

The device captures come from a booted iPhone 17 Pro Max (1320x2868), taken
with the app seeded with a plausible season — real UI, real layout, no
mock-ups painted over the top.

Render: python3 build.py   (writes out/*.png via headless Chrome)
"""
import base64, json, os, pathlib, re, subprocess, sys

ROOT = pathlib.Path("/Users/can/Projects/CourtIQ")
HERE = pathlib.Path(__file__).parent
CONTENT = ROOT / "CourtIQ/Resources/Content"

N_SCENARIOS = len(json.loads((CONTENT / "quiz_questions.json").read_text()))
CURRICULUM = json.loads((CONTENT / "tactics_curriculum.json").read_text())
N_LESSONS = sum(len(c["lessons"]) for c in CURRICULUM["chapters"])
FREE_CHAPTERS = sum(1 for c in CURRICULUM["chapters"] if c.get("isFree"))
assert FREE_CHAPTERS == 1, "copy says chapter 1 is free — the JSON must agree"

GUIDE = json.loads((CONTENT / "nutrition_guide.en.json").read_text())
N_SOURCES = sum(len(s["sources"]) for s in GUIDE["sections"])
N_SECTIONS = len(GUIDE["sections"])
N_RECIPES = len(json.loads((CONTENT / "nutrition_recipes.en.json").read_text())["recipes"])

# The wall ladder is a Swift literal, not JSON; count its entries rather than
# typing the number into the copy.
N_WALL = len(re.findall(r"\bWallDrill\(", (ROOT / "CourtIQ/Core/Models/WallDrill.swift").read_text()))
assert N_WALL >= 4, "wall level count looks wrong"

W, H = 1320, 2868

SHOTS = [
    {
        "id": "01-journal",
        "shot": "02_journal.png",
        "eyebrow": "TENNIS JOURNAL",
        "head": "Write the\nseason down.",
        "sub": "Your matches and what you ate, in one calendar. Tap any day — today or three weeks back — and fill it in.",
        "badges": [("Any day", "BACKDATED"), ("Both", "IN ONE PLACE"), ("Free", "MATCHES + FUEL")],
        "dark": True,
    },
    {
        "id": "02-fuel",
        "shot": "07_fuel.png",
        "eyebrow": "WHAT YOU ATE, AND HOW YOU PLAYED",
        "head": "Your legs,\nexplained.",
        "sub": f"Log the meal before you play, rate how you felt after. Your own averages do the talking — plus a guide where every claim is sourced.",
        "badges": [(f"{N_SOURCES}", "SOURCES CITED"), (f"{N_SECTIONS}", "GUIDE SECTIONS"), ("On device", "ONLY")],
        "dark": False,
    },
    {
        "id": "03-tactics",
        "shot": "05_tactics.png",
        "eyebrow": "TACTICS, TAUGHT",
        "head": "Learn tactics\nlike a language.",
        "sub": f"{N_LESSONS} lessons, one decision at a time, each with its own court diagram. Chapter 1 is free.",
        "badges": [(f"{N_LESSONS}", "LESSONS"), ("Ch. 1", "FREE"), ("Daily", "FREE LESSON")],
        "dark": True,
    },
    {
        "id": "04-wall",
        "shot": "04_wall.png",
        "eyebrow": "WALL PRACTICE",
        "head": "The wall never misses.\nNow it counts.",
        "sub": "Prop your phone behind you. It watches you turn and swing, counts every rep on-device, and grades the rung.",
        "badges": [(f"{N_WALL}", "LEVELS"), ("Counts", "BY CAMERA"), ("No", "TRIPOD")],
        "dark": False,
    },
    {
        "id": "05-coach",
        "shot": "06_coach.png",
        "eyebrow": "YOUR SWING, REVIEWED",
        "head": "Film one swing.\nGet coached.",
        "sub": "AI reads your swing frame by frame — preparation, contact point, finish, balance — and tells you what to fix first.",
        "badges": [("AI", "READS IT"), ("Frame", "BY FRAME"), ("Free", "TO START")],
        "dark": False,
    },
    {
        "id": "06-decisions",
        "shot": "01_home.png",
        "eyebrow": "FOUR WAYS TO GET BETTER",
        "head": "Tennis is decisions,\nnot strokes.",
        "sub": f"{N_SCENARIOS} real match scenarios written by certified coaches, and four things to work on — all from one screen.",
        "badges": [(f"{N_SCENARIOS}", "SCENARIOS"), ("4", "WAYS IN"), ("Free", "TO START")],
        "dark": True,
    },
]

CSS = """
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:%(W)dpx;height:%(H)dpx;overflow:hidden}
  .frame{position:relative;width:%(W)dpx;height:%(H)dpx;overflow:hidden;
    font-family:"SF Pro Rounded","SF Pro Display",-apple-system,system-ui,sans-serif;
    -webkit-font-smoothing:antialiased}
  .dark{background:
    radial-gradient(900px 900px at 82%% 6%%, rgba(198,92,49,.16), rgba(198,92,49,0) 70%%),
    radial-gradient(980px 980px at 8%% 94%%, rgba(230,177,156,.09), rgba(230,177,156,0) 70%%),
    #1E2938}
  .light{background:
    radial-gradient(900px 900px at 84%% 8%%, rgba(198,92,49,.12), rgba(198,92,49,0) 70%%),
    #E9DECB}
  .eyebrow{position:absolute;left:70px;right:70px;top:126px;text-align:center;
    font-size:31px;font-weight:800;letter-spacing:.28em}
  .head{position:absolute;left:0;right:0;top:184px;text-align:center;
    font-size:104px;font-weight:800;letter-spacing:-.025em;line-height:1.06;
    white-space:pre-line}
  .sub{position:absolute;left:110px;width:%(subw)dpx;top:430px;text-align:center;
    font-size:35px;font-weight:500;line-height:1.40}
  .badges{position:absolute;left:0;right:0;top:600px;
    display:flex;justify-content:center;gap:26px}
  .badge{min-width:236px;padding:20px 14px 18px;border-radius:26px;text-align:center}
  .badge .v{font-size:52px;font-weight:800;letter-spacing:-.02em;line-height:1.05}
  .badge .k{font-size:22px;font-weight:700;letter-spacing:.14em;margin-top:6px}
  .device{position:absolute;left:180px;top:800px;width:960px;height:2086px;
    border-radius:64px;overflow:hidden;box-shadow:0 40px 90px rgba(0,0,0,.42);
    border:3px solid rgba(30,41,56,.28)}
  .device img{display:block;width:100%%;height:auto}
  .d .eyebrow{color:#E8B6A2}
  .d .head{color:#FCF7EE}
  .d .sub{color:rgba(252,247,238,.82)}
  .d .badge{background:rgba(252,247,238,.10);border:2px solid rgba(252,247,238,.22)}
  .d .badge .v{color:#FCF7EE}
  .d .badge .k{color:rgba(252,247,238,.62)}
  .l .eyebrow{color:#C65C31}
  .l .head{color:#1E2938}
  .l .sub{color:rgba(30,41,56,.78)}
  .l .badge{background:rgba(252,247,238,.88);border:2px solid rgba(30,41,56,.14)}
  .l .badge .v{color:#C65C31}
  .l .badge .k{color:rgba(30,41,56,.60)}
""" % {"W": W, "H": H, "subw": W - 220}

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def data_uri(path: pathlib.Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def main() -> None:
    (HERE / "out").mkdir(exist_ok=True)
    (HERE / "build").mkdir(exist_ok=True)
    for s in SHOTS:
        shot = HERE / "assets/shots" / s["shot"]
        assert shot.exists(), f"missing capture: {shot}"
        badges = "\n".join(
            f'<div class="badge"><div class="v">{v}</div><div class="k">{k}</div></div>'
            for v, k in s["badges"])
        tone = "d dark" if s["dark"] else "l light"
        html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head>
<body><div class="frame {tone}">
  <div class="eyebrow">{s['eyebrow']}</div>
  <div class="head">{s['head']}</div>
  <div class="sub">{s['sub']}</div>
  <div class="badges">{badges}</div>
  <div class="device"><img src="{data_uri(shot)}" alt=""></div>
</div></body></html>"""
        page = HERE / "build" / f"{s['id']}.html"
        page.write_text(html)
        out = HERE / "out" / f"{s['id']}.png"
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                        f"--screenshot={out}", f"--window-size={W},{H}",
                        "--force-device-scale-factor=1", page.as_uri()],
                       check=True, capture_output=True)
        print(f"  {out.name}")
    print(f"scenarios {N_SCENARIOS} · lessons {N_LESSONS} · wall {N_WALL} · "
          f"guide sections {N_SECTIONS} · recipes {N_RECIPES} · sources {N_SOURCES}")


if __name__ == "__main__":
    main()
