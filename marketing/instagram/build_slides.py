#!/usr/bin/env python3
"""Render DropVolley Instagram carousel slides (1080x1350 PNG).

Brand: clay/cream from AppPalette. Screenshots: real 1.0.2 simulator captures
in shots/. Honest copy only — no invented users/ratings/awards (App Review
2.3.1 discipline carries over to marketing).

Usage: python3 build_slides.py  (renders into out/<carousel>/<nn>.png)
"""
import os
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, "shots")
OUT = os.path.join(HERE, "out")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# AppPalette
CLAY = "#C65C31"
CLAY_BRIGHT = "#E4894F"
CLAY_TEXT = "#964626"
CREAM = "#E9DECB"
PARCHMENT = "#FCF7EE"
SAND = "#E1D1B8"
INK = "#1E2938"
INK_SOFT = "#4A4640"
MOSS = "#6C8366"

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:1080px; height:1350px; }}
body {{
  font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
  background:{CREAM}; color:{INK}; overflow:hidden; position:relative;
}}
.slide {{ width:1080px; height:1350px; padding:88px 84px; display:flex;
  flex-direction:column; position:relative; }}
.eyebrow {{ font-size:30px; font-weight:800; letter-spacing:4px;
  text-transform:uppercase; color:{CLAY_TEXT}; margin-bottom:28px; }}
h1 {{ font-size:92px; line-height:1.04; font-weight:800;
  letter-spacing:-2px; }}
h1 .accent {{ color:{CLAY}; }}
.sub {{ font-size:42px; line-height:1.3; color:{INK_SOFT}; margin-top:36px;
  font-weight:500; }}
.footer {{ position:absolute; left:84px; right:84px; bottom:64px;
  display:flex; justify-content:space-between; align-items:center; }}
.wordmark {{ font-size:34px; font-weight:800; color:{INK}; }}
.wordmark .ball {{ color:{CLAY}; }}
.pager {{ font-size:28px; font-weight:700; color:{INK_SOFT}; opacity:.7; }}
.card {{ background:{PARCHMENT}; border:3px solid {SAND};
  border-radius:36px; }}
.rows {{ display:flex; flex-direction:column; gap:30px; margin-top:56px; }}
.row {{ display:flex; gap:30px; align-items:flex-start; padding:38px 40px; }}
.row .ic {{ width:76px; height:76px; border-radius:22px; background:{CLAY};
  color:#fff; display:flex; align-items:center; justify-content:center;
  font-size:40px; flex:none; }}
.row .t {{ font-size:40px; font-weight:750; }}
.row .d {{ font-size:32px; color:{INK_SOFT}; margin-top:8px;
  line-height:1.35; }}
.shot-wrap {{ flex:1; display:flex; align-items:flex-start;
  justify-content:center; margin-top:52px; min-height:0;
  overflow:hidden; }}
.shot {{ border-radius:56px 56px 0 0; border:12px solid {INK};
  border-bottom:none; box-shadow:0 30px 80px rgba(30,41,56,.28);
  width:560px; display:block; flex:none; }}
.topbar {{ display:flex; justify-content:space-between;
  align-items:baseline; margin-bottom:28px; }}
.topbar .eyebrow {{ margin-bottom:0; }}
.chip {{ display:inline-flex; align-items:center; padding:18px 34px;
  border-radius:999px; background:{PARCHMENT}; border:3px solid {SAND};
  font-size:34px; font-weight:700; color:{INK}; margin:0 18px 18px 0; }}
.chip.clay {{ background:{CLAY}; border-color:{CLAY}; color:#fff; }}
.chip.grow {{ border-style:dashed; border-color:{CLAY_BRIGHT}; color:{CLAY_TEXT}; }}
.bubble {{ max-width:760px; padding:34px 40px; border-radius:40px;
  font-size:36px; line-height:1.38; font-weight:550; }}
.bubble.q {{ background:{CLAY}; color:#fff; align-self:flex-end;
  border-bottom-right-radius:10px; }}
.bubble.a {{ background:{PARCHMENT}; border:3px solid {SAND}; color:{INK};
  align-self:flex-start; border-bottom-left-radius:10px; }}
.tag {{ font-size:26px; font-weight:800; letter-spacing:3px; color:{INK_SOFT};
  text-transform:uppercase; opacity:.8; }}
.bigscore {{ font-size:300px; font-weight:800; color:{CLAY};
  letter-spacing:-10px; line-height:1; }}
.dot {{ position:absolute; border-radius:50%; background:{SAND};
  opacity:.55; }}
"""

FOOTER = ('<div class="footer"><div class="wordmark"><span class="ball">●'
          '</span> DropVolley</div><div class="pager">{pager}</div></div>')

DOTS = ('<div class="dot" style="width:220px;height:220px;right:-70px;'
        'top:-70px;"></div>'
        '<div class="dot" style="width:120px;height:120px;left:-40px;'
        'bottom:220px;"></div>')


def page(body: str) -> str:
    return (f"<!doctype html><html><head><meta charset='utf-8'>"
            f"<style>{BASE_CSS}</style></head><body>{body}</body></html>")


def hook(eyebrow, title, sub, pager):
    return page(
        f'<div class="slide">{DOTS}'
        f'<div class="eyebrow">{eyebrow}</div>'
        f'<div style="flex:1;display:flex;flex-direction:column;'
        f'justify-content:center;">'
        f'<h1>{title}</h1><div class="sub">{sub}</div></div>'
        + FOOTER.format(pager=pager) + "</div>")


def rows(eyebrow, title, items, pager):
    rows_html = "".join(
        f'<div class="row card"><div class="ic">{ic}</div><div>'
        f'<div class="t">{t}</div><div class="d">{d}</div></div></div>'
        for ic, t, d in items)
    return page(
        f'<div class="slide">'
        f'<div class="eyebrow">{eyebrow}</div>'
        f'<h1 style="font-size:76px;">{title}</h1>'
        f'<div class="rows">{rows_html}</div>'
        + FOOTER.format(pager=pager) + "</div>")


def phone(eyebrow, title, shot, pager, sub=""):
    sub_html = (f'<div class="sub" style="margin-top:20px;font-size:36px;">'
                f'{sub}</div>') if sub else ""
    return page(
        f'<div class="slide" style="padding-bottom:0;">'
        f'<div class="topbar"><div class="eyebrow">{eyebrow}</div>'
        f'<div class="pager">{pager}</div></div>'
        f'<h1 style="font-size:68px;">{title}</h1>{sub_html}'
        f'<div class="shot-wrap"><img class="shot" src="{SHOTS}/{shot}">'
        f'</div>'
        "</div>")


def chat(eyebrow, title, pager):
    return page(
        f'<div class="slide">'
        f'<div class="eyebrow">{eyebrow}</div>'
        f'<h1 style="font-size:68px;">{title}</h1>'
        f'<div style="flex:1;display:flex;flex-direction:column;gap:34px;'
        f'justify-content:center;">'
        f'<div class="tag">AI Coach · example</div>'
        f'<div class="bubble q">Why do I keep losing to Alex?</div>'
        f'<div class="bubble a">You\'ve logged 2 losses to Alex — same '
        f'pattern both times: your serve rating drops in set 2 and you stop '
        f'going wide. Keep the wide serve in play, and slow things down '
        f'between points — he wins when he rushes you.</div>'
        f'<div class="tag" style="opacity:.55;">A generic chatbot can\'t '
        f'answer this. Your journal can.</div></div>'
        + FOOTER.format(pager=pager) + "</div>")


def cta(title, sub, pager):
    return page(
        f'<div class="slide">{DOTS}'
        f'<div style="flex:1;display:flex;flex-direction:column;'
        f'justify-content:center;align-items:flex-start;">'
        f'<div class="eyebrow">Free to start</div>'
        f'<h1>{title}</h1><div class="sub">{sub}</div>'
        f'<div style="margin-top:70px;display:flex;align-items:center;'
        f'gap:26px;background:{INK};color:#fff;border-radius:28px;'
        f'padding:30px 48px;font-size:40px;font-weight:750;">'
        f'&#63743; Download on the App Store</div></div>'
        + FOOTER.format(pager=pager) + "</div>")


def profile_slide(pager):
    chips1 = "".join(f'<span class="chip clay">{c}</span>'
                     for c in ["Intermediate · NTRP ~3.0", "Counterpuncher"])
    chips2 = "".join(f'<span class="chip">{c}</span>'
                     for c in ["Forehand", "Backhand"])
    return page(
        f'<div class="slide">'
        f'<div class="eyebrow">Step 1 · one minute</div>'
        f'<h1 style="font-size:72px;">4 taps build your <span class="accent">'
        f'Tennis Profile</span></h1>'
        f'<div class="sub">Level, play style, strengths and growth areas — '
        f'the profile every AI feature reads.</div>'
        f'<div style="margin-top:64px;" class="card"><div style="padding:'
        f'56px 52px;"><div class="tag" style="margin-bottom:30px;">Your '
        f'result · example</div><div>{chips1}</div>'
        f'<div style="margin-top:26px;">{chips2}<span class="chip grow">Serve · next</span><span class="chip grow">Net play · next</span></div>'
        f'<div style="margin-top:40px;font-size:34px;color:{INK_SOFT};'
        f'line-height:1.4;">“You rally with medium pace fairly consistently '
        f'— now it\'s about control and depth.”</div></div></div>'
        + FOOTER.format(pager=pager) + "</div>")


def score_slide(pager):
    return page(
        f'<div class="slide">'
        f'<div class="eyebrow">Doubles fit</div>'
        f'<div style="flex:1;display:flex;flex-direction:column;'
        f'justify-content:center;">'
        f'<div class="bigscore">0–100</div>'
        f'<h1 style="font-size:64px;margin-top:30px;">One score for how '
        f'your games interlock.</h1>'
        f'<div class="sub">Plus a game plan: who covers the middle, who '
        f'serves first, when to poach — written for your two games.</div>'
        f'</div>' + FOOTER.format(pager=pager) + "</div>")


CAROUSELS = {
    "carousel-1-intro": [
        hook("DropVolley · Tennis IQ",
             'You don\'t lose because of your <span class="accent">forehand'
             '</span>.',
             "You lose because of decisions. The good news: decisions are "
             "trainable.", "1/7"),
        rows("Meet DropVolley", 'A coach for the part of tennis '
             '<span class="accent">no one teaches</span>',
             [("🧠", "Daily court scenarios",
               "20-second decisions that build real court sense."),
              ("📓", "A match journal that talks back",
               "Log by voice — AI finds the patterns in your matches."),
              ("🎥", "Swing analysis, 0–100",
               "Film one swing, get a score and exact fixes.")],
             "2/7"),
        phone("Your game", "Everything in one place.", "home.png", "3/7"),
        phone("Daily scenario", "Would you make the right call?",
              "quiz-daily.png", "4/7",
              "One tap. Instant why. Court sense, compounding daily."),
        phone("Match journal", "Log it once. Learn from it forever.",
              "matches.png", "5/7"),
        chat("AI Coach", "Ask anything — it already knows your game.",
             "6/7"),
        cta('Train your <span class="accent">Tennis IQ</span>.',
            "Scenarios, drills and the match journal are free. "
            "AI Coach &amp; swing analysis when you\'re ready.", "7/7"),
    ],
    "carousel-2-how": [
        hook("How it works",
             'A tennis coach in your pocket — in <span class="accent">1 '
             'minute</span>.',
             "No forms. No manuals. Four taps and you're training.", "1/7"),
        profile_slide("2/7"),
        phone("Step 2 · daily", "One scenario a day.", "quiz.png", "3/7",
              "Read the court, make the call, learn the why — in 20 "
              "seconds."),
        phone("Step 3 · after you play", "Log matches — talk, don\'t type.",
              "matches.png", "4/7",
              "🎤 Speak your notes; on-device transcription writes them "
              "down."),
        chat("Step 4 · the payoff",
             "Your AI Coach reads your history — not generic advice.",
             "5/7"),
        phone("Step 5 · premium", "Film one swing. Get the truth.",
              "swing.png", "6/7",
              "A 0–100 score, what\'s working, and exact fixes."),
        cta("Start free today.",
            "Setup truly takes a minute — your first scenario is waiting.",
            "7/7"),
    ],
    "carousel-3-doubles": [
        hook("New · Doubles",
             'Your doubles team has a <span class="accent">blind spot</span>.',
             "You know your game. Do you know how it fits your partner's?",
             "1/6"),
        phone("Pair up", "Send a code. That\'s the whole setup.",
              "invite.png", "2/6",
              "Your Tennis Profiles are shared both ways — with consent."),
        phone("Side by side", "See both games in one report.",
              "doubles-report.png", "3/6"),
        score_slide("4/6"),
        phone("Then train it", "Doubles scenarios, built in.", "quiz.png",
              "5/6",
              "Both-up, one-back, poach or stay — drill the calls together."),
        cta("Find your fit. Free.",
            "In the latest update — pair up with your partner today.",
            "6/6"),
    ],
}


def render() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, slides in CAROUSELS.items():
        cdir = os.path.join(OUT, name)
        os.makedirs(cdir, exist_ok=True)
        for i, html in enumerate(slides, 1):
            with tempfile.NamedTemporaryFile(
                    "w", suffix=".html", delete=False) as fh:
                fh.write(html)
                tmp = fh.name
            out = os.path.join(cdir, f"{i:02d}.png")
            subprocess.run(
                [CHROME, "--headless", "--disable-gpu",
                 "--force-device-scale-factor=1",
                 "--window-size=1080,1350", "--hide-scrollbars",
                 f"--screenshot={out}", f"file://{tmp}"],
                check=True, capture_output=True)
            os.unlink(tmp)
            print("rendered", name, os.path.basename(out))


if __name__ == "__main__":
    render()
