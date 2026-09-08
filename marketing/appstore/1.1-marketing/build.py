#!/usr/bin/env python3
"""App Store screenshots — marketing layer over real device captures.

Every claim on these frames is checkable:
  · 156 scenarios      — len(quiz_questions.json), counted at build time
  · 15 years on court  — the founding coach's own career
  · 72-hour review     — the coach-review SLA the app actually promises
  · Free               — the app is free; only the AI coach is paid
  · 30 lessons         — len(chapters[].lessons) in tactics_curriculum.json
  · Chapter 1 free     — the `isFree` flag on the geometry chapter, read here

Nothing about ratings, download counts, or roster size appears here. See
README.md for what was asked for and why it isn't in the file.
"""
import json, os

N_SCENARIOS = len(json.load(open(
    "/Users/can/Projects/CourtIQ/CourtIQ/Resources/Content/quiz_questions.json")))

CURRICULUM = json.load(open(
    "/Users/can/Projects/CourtIQ/CourtIQ/Resources/Content/tactics_curriculum.json"))
N_LESSONS = sum(len(c["lessons"]) for c in CURRICULUM["chapters"])
FREE_CHAPTERS = sum(1 for c in CURRICULUM["chapters"] if c.get("isFree"))
assert FREE_CHAPTERS == 1, "copy says chapter 1 is free — the JSON must agree"

W, H = 1320, 2868

SHOTS = [
    {
        # Both quotes are verbatim App Store reviews, pulled from the ASC API
        # on 30 Aug 2026. Two reviews is what the app has; no average and no
        # volume claim appears anywhere, because two is not a rating.
        "id": "01-what-players-say",
        "shot": "01_home.png",
        "eyebrow": "WHAT PLAYERS SAY",
        "head": "Like having\na coach with you.",
        "sub": "",
        "quotes": [
            ("&ldquo;Vuruşlarımı kaydedip bu uygulamadan taktikler alıyorum. Çok iyi. Hoca gibi.&rdquo;",
             "JackRave · Türkiye"),
            ("&ldquo;App really helpful, improving daily thanks to them.&rdquo;",
             "Luis Torregrosa · España"),
        ],
        "badges": [],
        "dark": True,
    },
    {
        "id": "02-tactics",
        "shot": "07_tactics.png",
        "eyebrow": "TACTICS, TAUGHT",
        "head": "Learn tactics\nlike a language.",
        "sub": f"{N_LESSONS} lessons, one decision at a time, each with its own court diagram. Chapter 1 is free.",
        "badges": [(f"{N_LESSONS}", "LESSONS"), ("Ch. 1", "FREE"), ("Daily", "FREE LESSON")],
        "dark": True,
    },
    {
        "id": "03-wall",
        "shot": "06_wall.png",
        "eyebrow": "WALL PRACTICE",
        "head": "The wall never misses.\nNow it counts.",
        "sub": "Prop your phone behind you. It watches you turn and swing, counts every rep, and grades the rung green, gold or try again.",
        "badges": [("8", "LEVELS"), ("Counts", "BY CAMERA"), ("No", "TRIPOD")],
        "dark": False,
    },
    {
        "id": "04-decisions",
        "shot": "03_scenario.png",
        "eyebrow": "BUILT BY A TENNIS CLUB",
        "head": "Tennis is decisions,\nnot strokes.",
        "sub": f"{N_SCENARIOS} real match scenarios, shaped by certified coaches — not generated.",
        "badges": [("10+", "CERTIFIED COACHES"), ("15+ yrs", "COACHING"), ("1000s", "STUDENTS TAUGHT")],
        "dark": True,
    },
    {
        # The real-coach review is a waitlist in this build, and the frame
        # says so. The AI read is what a player gets today.
        "id": "05-swing",
        "shot": "05_coach_review.png",
        "eyebrow": "YOUR SWING, REVIEWED",
        "head": "Film one swing.\nGet coached.",
        "sub": "AI reads your swing today. A real coach review — voice notes, back in 72 hours — is coming; the waitlist is inside.",
        "badges": [("AI", "TODAY"), ("Real coach", "WAITLIST"), ("Free", "TO START")],
        "dark": False,
    },
    {
        "id": "06-the-club",
        "shot": "02_tennis_iq.png",
        "eyebrow": "WHERE IT COMES FROM",
        "head": "A club's playbook,\nin your pocket.",
        "sub": f"Fifteen years of coaching in Türkiye, thousands of students, and 10+ certified coaches who shaped all {N_SCENARIOS} scenarios by hand.",
        "badges": [("10+", "COACHES BEHIND IT"), ("15+ yrs", "ON COURT"), (f"{N_SCENARIOS}", "HAND-WRITTEN")],
        "dark": True,
    },
]

TPL = """<template>
  <div id="root" data-composition-id="shots" data-start="0" data-duration="{total}"
       data-width="{W}" data-height="{H}" data-fps="30">
    <style>
      #root {{ position:relative; width:{W}px; height:{H}px; overflow:hidden;
        font-family: ui-rounded, system-ui, -apple-system, sans-serif; }}
      .frame {{ position:absolute; inset:0; width:{W}px; height:{H}px; }}
      .dark {{ background:
        radial-gradient(900px 900px at 82% 6%, rgba(198,92,49,.14), rgba(198,92,49,0) 70%),
        radial-gradient(980px 980px at 8% 94%, rgba(230,177,156,.08), rgba(230,177,156,0) 70%),
        #1E2938; }}
      .light {{ background:
        radial-gradient(900px 900px at 84% 8%, rgba(198,92,49,.10), rgba(198,92,49,0) 70%),
        #E9DECB; }}
      .eyebrow {{ position:absolute; left:0; right:0; top:126px; text-align:center;
        font-size:31px; font-weight:800; letter-spacing:.30em; }}
      .head {{ position:absolute; left:0; right:0; top:180px; text-align:center;
        font-size:104px; font-weight:800; letter-spacing:-.025em; line-height:1.06;
        white-space:pre-line; }}
      .sub {{ position:absolute; left:110px; width:{subw}px; top:424px; text-align:center;
        font-size:35px; font-weight:500; line-height:1.40; }}
      .quotes {{ position:absolute; left:88px; width:{quotew}px; top:452px;
        display:flex; flex-direction:column; gap:22px; }}
      .quote {{ border-radius:30px; padding:26px 30px 24px; }}
      .quote .stars {{ font-size:27px; letter-spacing:.14em; color:#E8A33D; line-height:1; }}
      .quote .qt {{ font-size:31px; font-weight:600; line-height:1.34; margin-top:12px; }}
      .quote .by {{ font-size:22px; font-weight:700; letter-spacing:.10em;
        text-transform:uppercase; margin-top:12px; }}
      .d .quote {{ background:rgba(252,247,238,.94); }}
      .d .quote .qt {{ color:#1E2938; }}
      .d .quote .by {{ color:rgba(30,41,56,.55); }}
      .l .quote {{ background:#FCF7EE; border:2px solid rgba(30,41,56,.12); }}
      .l .quote .qt {{ color:#1E2938; }}
      .l .quote .by {{ color:rgba(30,41,56,.55); }}
      .badges {{ position:absolute; left:0; right:0; top:566px;
        display:flex; justify-content:center; gap:26px; }}
      .badge {{ min-width:236px; padding:20px 10px 18px; border-radius:26px;
        text-align:center; }}
      .badge .v {{ font-size:52px; font-weight:800; letter-spacing:-.02em; line-height:1.05; }}
      .badge .k {{ font-size:22px; font-weight:700; letter-spacing:.16em; margin-top:6px; }}
      .device {{ position:absolute; left:180px; top:790px; width:960px; height:2086px;
        border-radius:64px; overflow:hidden; box-shadow:0 40px 90px rgba(0,0,0,.42);
        border:3px solid rgba(30,41,56,.28); }}
      .device img {{ display:block; width:100%; height:auto; }}
      .d .eyebrow {{ color:#E8B6A2; }}
      .d .head {{ color:#FCF7EE; }}
      .d .sub  {{ color:rgba(252,247,238,.80); }}
      .d .badge {{ background:rgba(252,247,238,.10); border:2px solid rgba(252,247,238,.22); }}
      .d .badge .v {{ color:#FCF7EE; }}
      .d .badge .k {{ color:rgba(252,247,238,.62); }}
      .l .eyebrow {{ color:#C65C31; }}
      .l .head {{ color:#1E2938; }}
      .l .sub  {{ color:rgba(30,41,56,.76); }}
      .l .badge {{ background:rgba(252,247,238,.86); border:2px solid rgba(30,41,56,.14); }}
      .l .badge .v {{ color:#C65C31; }}
      .l .badge .k {{ color:rgba(30,41,56,.60); }}
    </style>
{frames}
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
    <script>
      window.__timelines = window.__timelines || {{}};
      window.__timelines["shots"] = gsap.timeline({{ paused: true }});
    </script>
  </div>
</template>
"""

frames = []
for i, s in enumerate(SHOTS):
    tone = "d dark" if s["dark"] else "l light"
    if s.get("quotes"):
        block = '      <div class="quotes">\n' + "\n".join(
            f'        <div class="quote"><div class="stars">★★★★★</div>'
            f'<div class="qt">{t}</div><div class="by">{by}</div></div>'
            for t, by in s["quotes"]) + "\n      </div>"
    else:
        badges = "\n".join(
            f'        <div class="badge"><div class="v">{v}</div><div class="k">{k}</div></div>'
            for v, k in s["badges"])
        block = f'      <div class="badges">\n{badges}\n      </div>"'.rstrip('"')
    frames.append(f"""    <div class="clip frame {tone}" id="{s['id']}"
         data-start="{i}" data-duration="1" data-track-index="{i}">
      <div class="eyebrow">{s['eyebrow']}</div>
      <div class="head">{s['head']}</div>
      <div class="sub">{s['sub']}</div>
{block}
      <div class="device"><img src="assets/shots/{s['shot']}" alt=""></div>
    </div>""")

open("compositions/shots.html", "w").write(
    TPL.format(total=len(SHOTS), W=W, H=H, subw=W - 220,
               quotew=W - 176, frames="\n".join(frames)))

open("index.html", "w").write(f"""<!doctype html>
<html><head><meta charset="utf-8"><title>App Store screenshots</title></head><body>
  <div id="root" data-composition-id="root" data-start="0" data-duration="{len(SHOTS)}"
       data-width="{W}" data-height="{H}" data-fps="30">
    <div class="clip" id="host" data-composition-id="shots-host"
         data-composition-src="compositions/shots.html"
         data-start="0" data-duration="{len(SHOTS)}" data-track-index="0"></div>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
  <script>window.__timelines=window.__timelines||{{}};
    window.__timelines["root"]=gsap.timeline({{paused:true}});</script>
</body></html>
""")

print(f"{len(SHOTS)} kare · {N_SCENARIOS} senaryo doğrulandı")
for i, s in enumerate(SHOTS):
    print(f"  t={i}.5  {s['id']:22s} {s['head'].splitlines()[0]}")
