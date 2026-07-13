#!/usr/bin/env python3
"""build_reels — Tennis IQ senaryolarını (quiz_questions.json) animasyonlu Reel
HTML'lerine + caption/description dokümanına çevirir. Her senaryo → out/<id>.html
(9:16, ekran-kaydına hazır) + captions-iq.md içine EN/TR caption bloğu.

Kullanım: python3 build_reels.py            (hepsi)
          python3 build_reels.py serve rally (sadece bu kategoriler)
Kayıt→MP4: out/<id>.html'i telefonda/QuickTime ile ekran-kaydı al (9:16), ya da
headless Chrome frame-capture + ffmpeg (README).
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "../../..", "CourtIQ/Resources/Content/quiz_questions.json")
TEMPLATE = os.path.join(HERE, "reel.html")
OUT = os.path.join(HERE, "out")

# English-first DropVolley "Court IQ" marketing (app is EN-first). Every reel → app.
CAT_EN = {"serve":"SERVE","returnPlay":"RETURN","rally":"RALLY",
          "net":"NET","mental":"MENTAL","doubles":"DOUBLES"}
CAT_TAGS = {
    "serve":"#tennisserve #serve","returnPlay":"#tennisreturn #returngame","rally":"#baseline #rally",
    "net":"#netgame #volley","mental":"#tennismental #matchtoughness","doubles":"#doubles #doublestennis",
}
BASE_TAGS = "#tennis #tennisiq #tennistips #tennisstrategy #tenniscoach #dropvolley #tennislesson #playsmarter"

def split_hook(scenario_en):
    """Setup sentence(s) = subhead; final (question) sentence = headline."""
    parts = [p.strip() for p in re.split(r"(?<=[.!?])\s+", scenario_en.strip()) if p.strip()]
    if len(parts) >= 2:
        return " ".join(parts[:-1]), parts[-1]     # (subhead, headline)
    return "", scenario_en.strip()

def two_lines(text):
    """Split the headline into ~two even lines (uppercase)."""
    words = text.upper().split()
    if len(words) <= 1: return text.upper(), ""
    target = len(text) / 2; acc = 0; cut = 1
    for i, w in enumerate(words):
        acc += len(w) + 1
        if acc >= target: cut = i + 1; break
    return " ".join(words[:cut]), " ".join(words[cut:])

def default_diagram(q):
    """~29 scenarios (mostly MENTAL) have no diagram → a neutral court visual."""
    return {"surface":"clay","youX":0.5,"youY":0.94,"opponentX":0.5,"opponentY":0.06,
            "ballOriginX":0.5,"ballOriginY":0.2,"ballTargetX":0.5,"ballTargetY":0.5,
            "scoreChip":CAT_EN.get(q["category"], q["category"].upper())}

def build_reel_obj(q):
    sub, head = split_hook(q["scenario"])
    h1, h2 = two_lines(head)
    return {
        "eyebrow":"DROPVOLLEY", "cat":"COURT IQ · " + CAT_EN.get(q["category"], q["category"].upper()),
        "headline1":h1, "headline2":h2, "sub":sub,
        "ctaBig":"ANSWER IN THE CAPTION",
        "ctaSmall":"Save it — then train your Tennis IQ free in DropVolley",
        "diagram":q.get("diagram") or default_diagram(q),
    }

def render_html(template, obj):
    inject = "<script>window.__REEL__ = " + json.dumps(obj, ensure_ascii=False) + ";</script>\n"
    # __REEL__'i ana script'ten ÖNCE tanımla (charset meta'dan hemen sonra).
    return template.replace('<meta charset="utf-8">',
                            '<meta charset="utf-8">\n' + inject, 1)

def caption_block(q):
    cat_en = CAT_EN[q["category"]]
    ans_en = q["options"][q["correctAnswerIndex"]]
    tags = f"{BASE_TAGS} {CAT_TAGS.get(q['category'],'')}"
    return f"""### `{q['id']}` · {cat_en} · {q['focusTag']}

**Reel hook (on-screen):** {q['scenario']}

**Caption (EN)**
> {q['scenario']} 🎾
>
> The play: **{ans_en}**.
> Why: {q['explanation']}
> 👉 {q.get('takeaway','')}
>
> This is Court IQ — the part no one teaches. Get 150+ scenarios like this, free, in DropVolley. 🎾 Link in bio → train your Tennis IQ.
> {tags}
"""

def main():
    only = set(sys.argv[1:])
    data = json.load(open(SRC))
    if only: data = [q for q in data if q["category"] in only]
    template = open(TEMPLATE).read()
    os.makedirs(OUT, exist_ok=True)

    by_cat = {}
    for q in data:
        with open(os.path.join(OUT, f"{q['id']}.html"), "w") as f:
            f.write(render_html(template, build_reel_obj(q)))
        by_cat.setdefault(q["category"], []).append(q)

    # captions doc, grouped by category
    lines = ["# DropVolley — Court IQ Reels: caption & description bank (EN)",
             "",
             f"Source: `quiz_questions.json` ({len(data)} scenarios). Each scenario's animated "
             "reel is `out/<id>.html` (9:16, screen-record it). The reel HOOKS; **the answer + why "
             "live in the caption** (borrowed from the reference mechanic), and every post drives to "
             "the DropVolley app (link in bio).",
             "",
             "Honesty: never bake fake like/comment counts into the video (that's IG's own UI). "
             "Brand: DropVolley / Court IQ, @dropvolley.",
             ""]
    order = ["serve","returnPlay","rally","net","mental","doubles"]
    for cat in [c for c in order if c in by_cat]:
        lines.append(f"\n## {CAT_EN[cat]} ({len(by_cat[cat])})\n")
        for q in by_cat[cat]:
            lines.append(caption_block(q))
    with open(os.path.join(HERE, "captions-iq.md"), "w") as f:
        f.write("\n".join(lines))

    print(f"{len(data)} reel → out/  ·  captions-iq.md ({sum(len(v) for v in by_cat.values())} blok)")
    for cat in order:
        if cat in by_cat: print(f"  {CAT_EN[cat]}: {len(by_cat[cat])}")

if __name__ == "__main__":
    main()
