#!/usr/bin/env python3
"""capture — reel HTML animasyonunu MP4'e çevirir (headless Chrome + CDP + ffmpeg).
Tek Chrome oturumu; her kare için Web Animations API'yle zamanı ilerletip
Page.captureScreenshot alır → ffmpeg h264/yuv420p 1080x1920 @30fps.

Kullanım:
  python3 capture.py serve_022                 # tek reel → mp4/serve_022.mp4
  python3 capture.py serve_022 rally_022 ...    # birkaçı
  python3 capture.py --all                      # out/*.html hepsi
  python3 capture.py --all serve                # sadece bu kategori öneki
Önkoşul: `python3 -m http.server 8736` reels-iq/ dizininde (yoksa kendi başlatır).
"""
import asyncio, base64, glob, json, os, subprocess, sys, time, urllib.request
import websockets

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_HTML = os.path.join(HERE, "out")
OUT_MP4 = os.path.join(HERE, "mp4")
PORT = 8736
FPS, DUR = 30, 11.5         # full story: reveal → setup rally → gold answer (~8s) → settle
HOLD_MS = 10200             # bu ms'den sonrası donmuş son-kare (animasyon biter)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def ensure_server():
    try:
        urllib.request.urlopen(f"http://localhost:{PORT}/reel.html", timeout=1); return None
    except Exception:
        p = subprocess.Popen(["python3","-m","http.server",str(PORT)], cwd=HERE,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.5); return p

def start_chrome():
    prof = os.path.join(HERE, ".chrome-cap")
    proc = subprocess.Popen([CHROME,"--headless=new","--remote-debugging-port=9222",
        "--window-size=1080,1920","--force-device-scale-factor=1","--hide-scrollbars",
        f"--user-data-dir={prof}","--no-first-run","--no-default-browser-check","about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):
        try:
            tabs = json.load(urllib.request.urlopen("http://localhost:9222/json"))
            page = next((t for t in tabs if t["type"]=="page"), None)
            if page: return proc, page["webSocketDebuggerUrl"]
        except Exception: pass
        time.sleep(0.25)
    raise RuntimeError("Chrome CDP başlamadı")

class CDP:
    def __init__(self, ws): self.ws=ws; self.i=0
    async def cmd(self, method, **params):
        self.i+=1; mid=self.i
        await self.ws.send(json.dumps({"id":mid,"method":method,"params":params}))
        while True:
            msg=json.loads(await self.ws.recv())
            if msg.get("id")==mid:
                if "error" in msg: raise RuntimeError(msg["error"])
                return msg.get("result",{})

async def capture_one(cdp, rid):
    frames_dir=os.path.join(OUT_MP4, f".frames_{rid}")
    os.makedirs(frames_dir, exist_ok=True)
    url=f"http://localhost:{PORT}/out/{rid}.html?capture=1"
    await cdp.cmd("Page.navigate", url=url)
    await asyncio.sleep(1.2)  # load + fonts + first paint
    n=int(FPS*DUR)
    for f in range(n):
        ms=min(int(f/FPS*1000), HOLD_MS)
        await cdp.cmd("Runtime.evaluate", expression=
            f"document.getAnimations().forEach(a=>{{try{{a.currentTime={ms};a.pause();}}catch(e){{}}}});")
        res=await cdp.cmd("Page.captureScreenshot", format="png",
            clip={"x":0,"y":0,"width":1080,"height":1920,"scale":1}, captureBeyondViewport=True)
        with open(os.path.join(frames_dir, f"f{f:04d}.png"),"wb") as fh:
            fh.write(base64.b64decode(res["data"]))
    os.makedirs(OUT_MP4, exist_ok=True)
    mp4=os.path.join(OUT_MP4, f"{rid}.mp4")
    subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate",str(FPS),
        "-i",os.path.join(frames_dir,"f%04d.png"),"-c:v","libx264","-pix_fmt","yuv420p",
        "-movflags","+faststart",mp4], check=True)
    subprocess.run(["rm","-rf",frames_dir])
    print(f"  ✓ {rid}.mp4")

async def run(ids):
    proc,wsurl=start_chrome()
    try:
        async with websockets.connect(wsurl, max_size=None) as ws:
            cdp=CDP(ws)
            await cdp.cmd("Page.enable")
            for rid in ids:
                await capture_one(cdp, rid)
    finally:
        proc.terminate()

def main():
    args=sys.argv[1:]
    srv=ensure_server()
    try:
        if "--all" in args:
            pref=[a for a in args if a!="--all"]
            ids=sorted(os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(OUT_HTML,"*.html")))
            if pref: ids=[i for i in ids if any(i.startswith(p) for p in pref)]
        else:
            ids=args
        if not ids: print("kullanım: capture.py <id...> | --all [önek]"); return
        print(f"{len(ids)} reel → mp4/ ({FPS}fps, {DUR}s)")
        asyncio.run(run(ids))
    finally:
        if srv: srv.terminate()

if __name__=="__main__":
    main()
