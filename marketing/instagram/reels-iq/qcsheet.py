#!/usr/bin/env python3
"""qcsheet — one answer-moment thumbnail per reel → labeled contact sheets.
Lets me eyeball all 156 choreographies at once (story correct? 4 dots on doubles?
answer shot sane?). Downsamples via CDP clip.scale so it's fast.

Usage: python3 qcsheet.py [--cat serve rally ...]   (default: all)
Then open qc/index.html in the preview and screenshot each category grid.
"""
import asyncio, base64, glob, json, os, sys
from capture import CDP, start_chrome, ensure_server, PORT

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out"); QC = os.path.join(HERE, "qc")
SCALE = 0.30          # 1080x1920 → 324x576 thumb
SEEK_MS = 9400        # answer fired + ring pulsing + any player move done (silent build: answer@8000)
ORDER = ["serve", "returnPlay", "rally", "net", "mental", "doubles"]

def ids_for(cats):
    data = json.load(open(os.path.join(HERE, "../../..", "CourtIQ/Resources/Content/quiz_questions.json")))
    return [(q["category"], q["id"]) for q in data if not cats or q["category"] in cats]

async def shot(cdp, rid):
    await cdp.cmd("Page.navigate", url=f"http://localhost:{PORT}/out/{rid}.html?capture=1")
    await asyncio.sleep(1.0)
    await cdp.cmd("Runtime.evaluate", expression=
        f"document.getAnimations().forEach(a=>{{try{{a.currentTime={SEEK_MS};a.pause();}}catch(e){{}}}});")
    res = await cdp.cmd("Page.captureScreenshot", format="png",
        clip={"x": 0, "y": 0, "width": 1080, "height": 1920, "scale": SCALE}, captureBeyondViewport=True)
    with open(os.path.join(QC, f"{rid}.png"), "wb") as fh:
        fh.write(base64.b64decode(res["data"]))

async def run(items):
    proc, wsurl = start_chrome()
    try:
        import websockets
        async with websockets.connect(wsurl, max_size=None) as ws:
            cdp = CDP(ws); await cdp.cmd("Page.enable")
            for i, (_, rid) in enumerate(items):
                await shot(cdp, rid)
                if (i + 1) % 20 == 0: print(f"  {i+1}/{len(items)}")
    finally:
        proc.terminate()

def index_html(items):
    by = {}
    for cat, rid in items: by.setdefault(cat, []).append(rid)
    css = ("body{background:#111;color:#eee;font-family:-apple-system,Arial;margin:0;padding:20px}"
           "h2{margin:26px 0 10px;font-size:22px;color:#E4894F;text-transform:uppercase;letter-spacing:.08em}"
           ".g{display:grid;grid-template-columns:repeat(6,1fr);gap:8px}"
           ".c{background:#000;border-radius:6px;overflow:hidden}"
           ".c img{width:100%;display:block}.c div{font-size:11px;padding:3px 5px;color:#bbb}")
    h = [f"<meta charset=utf-8><style>{css}</style>"]
    for cat in [c for c in ORDER if c in by]:
        h.append(f"<h2>{cat} ({len(by[cat])})</h2><div class=g>")
        for rid in by[cat]:
            h.append(f"<div class=c><img src='{rid}.png'><div>{rid}</div></div>")
        h.append("</div>")
    open(os.path.join(QC, "index.html"), "w").write("\n".join(h))

def main():
    args = sys.argv[1:]
    cats = args[args.index("--cat")+1:] if "--cat" in args else []
    os.makedirs(QC, exist_ok=True)
    items = ids_for(cats)
    print(f"{len(items)} thumbnails → qc/")
    srv = ensure_server()
    try: asyncio.run(run(items))
    finally:
        if srv: srv.terminate()
    index_html(items)
    print("open qc/index.html in the preview")

if __name__ == "__main__":
    main()
