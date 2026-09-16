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

# Per-locale copy. The device captures are per-locale too: shipping English
# frames onto the Turkish storefront was the old behaviour and it advertised
# an app that does not look like the one a Turkish player downloads.
COPY = {
    "en-US": {
        "01-journal":   ("TENNIS JOURNAL", "Write the\nseason down.",
            "Your matches and what you ate, in one calendar. Tap any day — today or three weeks back — and fill it in.",
            [("Any day", "BACKDATED"), ("Both", "IN ONE PLACE"), ("Free", "MATCHES + FUEL")]),
        "02-fuel":      ("WHAT YOU ATE, AND HOW YOU PLAYED", "Your legs,\nexplained.",
            "Log the meal before you play, rate how you felt after. Your own averages do the talking — plus a guide where every claim is sourced.",
            [("{sources}", "SOURCES CITED"), ("{sections}", "GUIDE SECTIONS"), ("On device", "ONLY")]),
        "03-tactics":   ("TACTICS, TAUGHT", "Learn tactics\nlike a language.",
            "{lessons} lessons, one decision at a time, each with its own court diagram. Chapter 1 is free.",
            [("{lessons}", "LESSONS"), ("Ch. 1", "FREE"), ("Daily", "FREE LESSON")]),
        "04-wall":      ("WALL PRACTICE", "The wall never misses.\nNow it counts.",
            "Prop your phone behind you. It watches you turn and swing, counts every rep on-device, and grades the rung.",
            [("{wall}", "LEVELS"), ("Counts", "BY CAMERA"), ("No", "TRIPOD")]),
        "05-coach":     ("YOUR SWING, REVIEWED", "Film one swing.\nGet coached.",
            "AI reads your swing frame by frame — preparation, contact point, finish, balance — and tells you what to fix first.",
            [("AI", "READS IT"), ("Frame", "BY FRAME"), ("Free", "TO START")]),
        "06-decisions": ("FOUR WAYS TO GET BETTER", "Tennis is decisions,\nnot strokes.",
            "{scenarios} real match scenarios written by certified coaches, and four things to work on — all from one screen.",
            [("{scenarios}", "SCENARIOS"), ("4", "WAYS IN"), ("Free", "TO START")]),
    },
    "fr-FR": {
        "01-journal":   ("JOURNAL DE TENNIS", "Écris\nta saison.",
            "Tes matchs et ce que tu as mangé, dans un seul calendrier. Touche n'importe quel jour, même d'il y a trois semaines, et remplis-le.",
            [("Tout jour", "RÉTROACTIF"), ("Les deux", "AU MÊME ENDROIT"), ("Gratuit", "MATCHS + NUTRITION")]),
        "02-fuel":      ("CE QUE TU AS MANGÉ, COMMENT TU AS JOUÉ", "Tes jambes,\nexpliquées.",
            "Note le repas d'avant match, puis évalue tes sensations après. Ce sont tes propres moyennes qui parlent — plus un guide dont chaque affirmation est sourcée.",
            [("{sources}", "SOURCES CITÉES"), ("{sections}", "CHAPITRES DU GUIDE"), ("Sur l'appareil", "UNIQUEMENT")]),
        "03-tactics":   ("LA TACTIQUE, ENSEIGNÉE", "Apprends la tactique\ncomme une langue.",
            "{lessons} leçons, une décision à la fois, chacune avec son schéma de terrain. Le chapitre 1 est gratuit.",
            [("{lessons}", "LEÇONS"), ("Chap. 1", "GRATUIT"), ("Chaque jour", "UNE LEÇON OFFERTE")]),
        "04-wall":      ("ENTRAÎNEMENT AU MUR", "Le mur ne rate jamais.\nMaintenant il compte.",
            "Pose ton téléphone derrière toi. Il te regarde frapper, compte chaque répétition sur l'appareil et note le palier.",
            [("{wall}", "NIVEAUX"), ("Compté", "PAR LA CAMÉRA"), ("Sans", "TRÉPIED")]),
        "05-coach":     ("TON GESTE, ANALYSÉ", "Filme un geste.\nFais-toi coacher.",
            "L'IA lit ton geste image par image — préparation, point d'impact, finition, équilibre — et te dit quoi corriger en premier.",
            [("L'IA", "LE LIT"), ("Image", "PAR IMAGE"), ("Gratuit", "POUR COMMENCER")]),
        "06-decisions": ("QUATRE FAÇONS DE PROGRESSER", "Le tennis, ce sont\ndes décisions.",
            "{scenarios} situations de match réelles écrites par des entraîneurs diplômés, et quatre choses à travailler — depuis un seul écran.",
            [("{scenarios}", "SITUATIONS"), ("4", "PORTES D'ENTRÉE"), ("Gratuit", "POUR COMMENCER")]),
    },
    "tr": {
        "01-journal":   ("TENİS GÜNLÜĞÜ", "Sezonu yaz,\ngün gün.",
            "Maçların ve ne yediğin tek takvimde. İstediğin güne dokun — bugüne ya da üç hafta öncesine — ve doldur.",
            [("Her gün", "GERİYE DÖNÜK"), ("İkisi", "TEK YERDE"), ("Ücretsiz", "MAÇ + BESLENME")]),
        "02-fuel":      ("NE YEDİN, NASIL OYNADIN", "Bacakların\nneden bitiyor?",
            "Oynamadan önceki öğününü kaydet, sonrasında nasıl hissettiğini puanla. Konuşan kendi ortalamaların — üstelik her iddiası kaynaklı bir kılavuz.",
            [("{sources}", "KAYNAK"), ("{sections}", "KILAVUZ BÖLÜMÜ"), ("Cihazda", "SADECE")]),
        "03-tactics":   ("TAKTİK, ÖĞRETİLİR", "Taktiği bir dil\ngibi öğren.",
            "{lessons} ders, her seferinde tek bir karar, her biri kendi kort şemasıyla. 1. bölüm ücretsiz.",
            [("{lessons}", "DERS"), ("1. bölüm", "ÜCRETSİZ"), ("Her gün", "BEDAVA DERS")]),
        "04-wall":      ("DUVAR ANTRENMANI", "Duvar asla kaçırmaz.\nArtık sayıyor.",
            "Telefonu arkana koy. Dönüşünü ve vuruşunu izler, her tekrarı cihazda sayar ve basamağı notlar.",
            [("{wall}", "SEVİYE"), ("Kamerayla", "SAYAR"), ("Tripod", "YOK")]),
        "05-coach":     ("VURUŞUN, İNCELENMİŞ", "Bir vuruş çek.\nKoçluk al.",
            "AI vuruşunu kare kare okur — hazırlık, temas noktası, bitiş, denge — ve önce neyi düzelteceğini söyler.",
            [("AI", "OKUR"), ("Kare", "KARE"), ("Ücretsiz", "BAŞLA")]),
        "06-decisions": ("GELİŞMENİN DÖRT YOLU", "Tenis karardır,\nvuruş değil.",
            "Sertifikalı koçların yazdığı {scenarios} gerçek maç senaryosu ve üzerinde çalışılacak dört şey — hepsi tek ekrandan.",
            [("{scenarios}", "SENARYO"), ("4", "GİRİŞ YOLU"), ("Ücretsiz", "BAŞLA")]),
    },
}

SHOTS = [
    {
        "id": "01-journal",
        "shot": "02_journal.png",
        "dark": True,
    },
    {
        "id": "02-fuel",
        "shot": "07_fuel.png",
        "dark": False,
    },
    {
        "id": "03-tactics",
        "shot": "05_tactics.png",
        "dark": True,
    },
    {
        "id": "04-wall",
        "shot": "04_wall.png",
        "dark": False,
    },
    {
        "id": "05-coach",
        "shot": "06_coach.png",
        "dark": False,
    },
    {
        "id": "06-decisions",
        "shot": "01_home.png",
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


def build(locale: str) -> None:
    """Render one locale's frames from that locale's device captures."""
    shots_dir = HERE / "assets/shots" / locale
    out_dir = HERE / "out" / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    (HERE / "build").mkdir(exist_ok=True)
    fill = {"scenarios": N_SCENARIOS, "lessons": N_LESSONS, "wall": N_WALL,
            "sections": N_SECTIONS, "sources": N_SOURCES, "recipes": N_RECIPES}

    for s in SHOTS:
        shot = shots_dir / s["shot"]
        assert shot.exists(), f"missing capture: {shot}"
        eyebrow, head, sub, badges_raw = COPY[locale][s["id"]]
        badges = "\n".join(
            f'<div class="badge"><div class="v">{v.format(**fill)}</div>'
            f'<div class="k">{k}</div></div>' for v, k in badges_raw)
        tone = "d dark" if s["dark"] else "l light"
        html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head>
<body><div class="frame {tone}">
  <div class="eyebrow">{eyebrow}</div>
  <div class="head">{head}</div>
  <div class="sub">{sub.format(**fill)}</div>
  <div class="badges">{badges}</div>
  <div class="device"><img src="{data_uri(shot)}" alt=""></div>
</div></body></html>"""
        page = HERE / "build" / f"{locale}-{s['id']}.html"
        page.write_text(html)
        out = out_dir / f"{s['id']}.png"
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                        f"--screenshot={out}", f"--window-size={W},{H}",
                        "--force-device-scale-factor=1", page.as_uri()],
                       check=True, capture_output=True)
        print(f"  {locale}/{out.name}")


def main() -> None:
    locales = sys.argv[1:] or sorted(COPY)
    for locale in locales:
        build(locale)
    print(f"scenarios {N_SCENARIOS} · lessons {N_LESSONS} · wall {N_WALL} · "
          f"guide sections {N_SECTIONS} · recipes {N_RECIPES} · sources {N_SOURCES}")


if __name__ == "__main__":
    main()
