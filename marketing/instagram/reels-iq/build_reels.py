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

CAT_TR = {"serve":"SERVİS","returnPlay":"KARŞILAMA","rally":"RALLY",
          "net":"FİLE","mental":"ZİHİN","doubles":"ÇİFTLER"}
CAT_EN = {"serve":"SERVE","returnPlay":"RETURN","rally":"RALLY",
          "net":"NET","mental":"MENTAL","doubles":"DOUBLES"}
CAT_TAGS = {
    "serve":"#servis #serve","returnPlay":"#karsilama #return","rally":"#rally #baseline",
    "net":"#voleybol #netgame","mental":"#tenniszihni #mentalgame","doubles":"#ciftler #doubles",
}
BASE_TAGS_TR = "#tenis #tennisiq #tenisdersi #kortiq #tenistaktik #tennistips"
BASE_TAGS_EN = "#tennis #tennisiq #tennistips #tennisstrategy #tenniscoach #kortiq"

def split_hook(scenario_tr):
    """Setup cümlesi = subhead; son (soru) cümlesi = başlık."""
    parts = [p.strip() for p in re.split(r"(?<=[.!?])\s+", scenario_tr.strip()) if p.strip()]
    if len(parts) >= 2:
        return " ".join(parts[:-1]), parts[-1]     # (subhead, headline)
    return "", scenario_tr.strip()

def tr_upper(text):
    """Türkçe-duyarlı büyük harf: i→İ, ı→I (Python .upper() bunu yanlış yapar)."""
    return text.replace("ı", "I").replace("i", "İ").upper()

def two_lines(text):
    """Başlığı ~ortadan iki satıra böl (Türkçe büyük harf)."""
    words = tr_upper(text).split()
    if len(words) <= 1: return text.upper(), ""
    target = len(text) / 2; acc = 0; cut = 1
    for i, w in enumerate(words):
        acc += len(w) + 1
        if acc >= target: cut = i + 1; break
    return " ".join(words[:cut]), " ".join(words[cut:])

def default_diagram(q):
    """~29 senaryonun (çoğu ZİHİN) diagram alanı yok → nötr bir kort görseli."""
    return {"surface":"hard","youX":0.5,"youY":0.94,"opponentX":0.5,"opponentY":0.06,
            "ballOriginX":0.5,"ballOriginY":0.2,"ballTargetX":0.5,"ballTargetY":0.5,
            "scoreChip":CAT_TR.get(q["category"], q["category"].upper())}

def build_reel_obj(q):
    sub, head = split_hook(q["scenarioTr"])
    h1, h2 = two_lines(head)
    return {
        "eyebrow":"TENNIS IQ", "cat":CAT_TR.get(q["category"], q["category"].upper()),
        "headline1":h1, "headline2":h2, "sub":sub,
        "ctaBig":"CEVAP AÇIKLAMADA", "ctaSmall":"Kaydet, o maçtan önce aç",
        "diagram":q.get("diagram") or default_diagram(q),
    }

def render_html(template, obj):
    inject = "<script>window.__REEL__ = " + json.dumps(obj, ensure_ascii=False) + ";</script>\n"
    # __REEL__'i ana script'ten ÖNCE tanımla (charset meta'dan hemen sonra).
    return template.replace('<meta charset="utf-8">',
                            '<meta charset="utf-8">\n' + inject, 1)

def caption_block(q):
    cat_tr, cat_en = CAT_TR[q["category"]], CAT_EN[q["category"]]
    ans_tr = q["optionsTr"][q["correctAnswerIndex"]]
    ans_en = q["options"][q["correctAnswerIndex"]]
    tags = f"{BASE_TAGS_TR} {CAT_TAGS.get(q['category'],'')}"
    tags_en = f"{BASE_TAGS_EN} {CAT_TAGS.get(q['category'],'')}"
    return f"""### `{q['id']}` · {cat_tr} · {q['focusTag']}

**Reel hook (video):** {q['scenarioTr']}

**Caption — TR**
> {q['scenarioTr']} 🎾
>
> Cevap: **{ans_tr}**.
> Neden: {q['explanationTr']}
> 👉 {q.get('takeawayTr','')}
>
> Kaydet + @kortiq.tennis takip et — her gün bir kort kararı.
> {tags}

**Caption — EN**
> {q['scenario']} 🎾
>
> The play: **{ans_en}**.
> Why: {q['explanation']}
> 👉 {q.get('takeaway','')}
>
> Save it + follow @kortiq.tennis — one court decision a day.
> {tags_en}
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
    lines = ["# KORT IQ — Tennis IQ Reels: caption & description bankası",
             "",
             f"Kaynak: `quiz_questions.json` ({len(data)} senaryo). Her senaryonun animasyonlu "
             "reel'i `out/<id>.html` (9:16, ekran-kaydı al). Reel HOOK'lar; **cevap + neden caption'da** "
             "(referans mock'taki 'cevap açıklamada' mantığı → kaydet/takip'i tetikler).",
             "",
             "Dürüstlük: videoya sahte beğeni/yorum sayısı BASMA (o IG'nin kendi arayüzü). "
             "Handle mock'tan: **@kortiq.tennis** — app adı DropVolley; içerik-brand handle'ını teyit et.",
             ""]
    order = ["serve","returnPlay","rally","net","mental","doubles"]
    for cat in [c for c in order if c in by_cat]:
        lines.append(f"\n## {CAT_TR[cat]} ({len(by_cat[cat])})\n")
        for q in by_cat[cat]:
            lines.append(caption_block(q))
    with open(os.path.join(HERE, "captions-iq.md"), "w") as f:
        f.write("\n".join(lines))

    print(f"{len(data)} reel → out/  ·  captions-iq.md ({sum(len(v) for v in by_cat.values())} blok)")
    for cat in order:
        if cat in by_cat: print(f"  {CAT_TR[cat]}: {len(by_cat[cat])}")

if __name__ == "__main__":
    main()
