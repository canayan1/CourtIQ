#!/usr/bin/env python3
"""narrate — animated reel + English voiceover → Desktop MP4 (narrated mini-lesson).

Turns a silent hook reel into a spoken tennis-IQ tip:
  voice reads the scenario → beat → the smart play → why → app CTA.
The reveal animation plays (~5s), then the settled frame HOLDS while the
voiceover finishes, so narration length drives the video length. We only
capture the ~5s reveal (150 frames) regardless of how long the voice talks —
ffmpeg clones the last frame to fill the hold, then muxes the audio.

TTS: macOS `say` (free, offline) — review-quality. Swap to ElevenLabs for
studio/commercial audio (see README).

Usage:
  python3 narrate.py serve_022 doubles_001 ...   # specific reels
  python3 narrate.py --sample                    # one from each category
  python3 narrate.py --all                        # every scenario
Output: ~/Desktop/DropVolley IG Reels/<id>.mp4  (+ <id>.txt script/caption sidecar)
"""
import asyncio, glob, json, os, re, subprocess, sys
from capture import CDP, start_chrome, ensure_server, PORT
from build_reels import build_reel_obj, render_html, caption_block, CAT_EN

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "../../..", "CourtIQ/Resources/Content/quiz_questions.json")
OUT_N = os.path.join(HERE, "out-narrated")          # narrated HTML variants
DESK = os.path.expanduser("~/Desktop/DropVolley IG Reels")
TMP = os.path.join(HERE, ".narrate-tmp")

VOICE, RATE = "Samantha", 170       # macOS say; US female, calm
FPS = 30
ANSWER_LEAD = 1.4                   # s after the scenario line the gold answer fires (≈ "the smart play — …")
SETTLE_MS = 2700                    # answer draw + target-ring settle, captured after the answer
TAIL = 0.9                          # frozen beat after the voice ends

# narrated reels give the answer in the voice → CTA drives to the app, not "caption"
CTA_BIG, CTA_SMALL = "TRAIN YOUR TENNIS IQ", "Free on the App Store · @dropvolley"


def say_markup(text: str) -> str:
    """Make TTS read our tennis shorthand correctly."""
    t = text.replace("+1", "plus-one").replace("&", "and")
    t = re.sub(r"\bIQ\b", "I.Q.", t)
    t = re.sub(r"\b1st\b", "first", t); t = re.sub(r"\b2nd\b", "second", t)
    t = re.sub(r"\b3rd\b", "third", t)
    t = t.replace("crosscourt", "cross-court").replace("mid-court", "mid court")
    return re.sub(r"\s+", " ", t).strip()


def narration(q) -> str:
    scen = say_markup(q["scenario"])
    ans = say_markup(q["options"][q["correctAnswerIndex"]].rstrip("."))
    why = re.split(r"(?<=[.!?])\s+", q["explanation"].strip())
    why = say_markup(" ".join(why[:2]))                     # 1-2 sentences, keep it tight
    return (f"{scen} [[slnc 650]] The smart play — {ans}. [[slnc 300]] "
            f"{why} [[slnc 550]] Train your tennis I.Q., free, in DropVolley. Link in bio.")


def audio_dur(path: str) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "csv=p=0", path], capture_output=True, text=True)
    return float(out.stdout.strip())


def write_narrated_html(q, template, answer_ms):
    obj = build_reel_obj(q)
    obj["ctaBig"], obj["ctaSmall"] = CTA_BIG, CTA_SMALL
    obj["answerAtMs"] = answer_ms                    # sync the on-court answer to the voice
    os.makedirs(OUT_N, exist_ok=True)
    p = os.path.join(OUT_N, f"{q['id']}.html")
    with open(p, "w") as f:
        f.write(render_html(template, obj))


async def capture_story(cdp, rid, frames_dir, anim_end_ms):
    """Capture the FULL animated story (setup rally → gold answer → settle), so
    the tactic plays out on court; the muxed voice runs over it + the frozen tail."""
    os.makedirs(frames_dir, exist_ok=True)
    await cdp.cmd("Page.navigate", url=f"http://localhost:{PORT}/out-narrated/{rid}.html?capture=1")
    await asyncio.sleep(1.2)
    n = int(FPS * anim_end_ms / 1000.0)
    for f in range(n):
        ms = int(f / FPS * 1000)
        await cdp.cmd("Runtime.evaluate", expression=
            f"document.getAnimations().forEach(a=>{{try{{a.currentTime={ms};a.pause();}}catch(e){{}}}});")
        res = await cdp.cmd("Page.captureScreenshot", format="png",
            clip={"x": 0, "y": 0, "width": 1080, "height": 1920, "scale": 1}, captureBeyondViewport=True)
        import base64
        with open(os.path.join(frames_dir, f"f{f:04d}.png"), "wb") as fh:
            fh.write(base64.b64decode(res["data"]))
    return n


def mux(frames_dir, voice_aiff, voice_dur, video_secs, dest):
    hold = max(0.0, voice_dur + TAIL - video_secs)      # freeze the settled frame while the voice finishes
    total = video_secs + hold
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error",
        "-framerate", str(FPS), "-i", os.path.join(frames_dir, "f%04d.png"),
        "-i", voice_aiff,
        "-filter_complex", f"[0:v]tpad=stop_mode=clone:stop_duration={hold:.2f}[v]",
        "-map", "[v]", "-map", "1:a", "-t", f"{total:.2f}",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS),
        "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", dest], check=True)


async def make_one(cdp, q, template):
    rid = q["id"]
    fdir = os.path.join(TMP, f"f_{rid}")
    aiff = os.path.join(TMP, f"{rid}.aiff")
    scen = os.path.join(TMP, f"{rid}_scen.aiff")
    os.makedirs(TMP, exist_ok=True)
    # 1) measure the spoken scenario, so the gold answer fires on the voice's cue
    subprocess.run(["say", "-v", VOICE, "-r", str(RATE), "-o", scen, say_markup(q["scenario"])], check=True)
    answer_ms = int(min(13000, max(3400, (audio_dur(scen) + ANSWER_LEAD) * 1000)))
    os.remove(scen)
    anim_end_ms = answer_ms + SETTLE_MS
    # 2) full narration + synced HTML + full-story capture
    subprocess.run(["say", "-v", VOICE, "-r", str(RATE), "-o", aiff, narration(q)], check=True)
    dur = audio_dur(aiff)
    write_narrated_html(q, template, answer_ms)
    await capture_story(cdp, rid, fdir, anim_end_ms)
    os.makedirs(DESK, exist_ok=True)
    mux(fdir, aiff, dur, anim_end_ms / 1000.0, os.path.join(DESK, f"{rid}.mp4"))
    with open(os.path.join(DESK, f"{rid}.txt"), "w") as f:
        f.write(f"# {rid}  ({CAT_EN.get(q['category'], q['category'])})\n\n"
                f"VOICEOVER (EN):\n{narration(q)}\n\n{'-'*50}\n\nCAPTION:\n{caption_block(q)}")
    subprocess.run(["rm", "-rf", fdir]); os.remove(aiff)
    print(f"  ✓ {rid}.mp4  ({dur+TAIL:.1f}s, answer@{answer_ms/1000:.1f}s)")


async def run(qs):
    template = open(os.path.join(HERE, "reel.html")).read()
    proc, wsurl = start_chrome()
    try:
        import websockets
        async with websockets.connect(wsurl, max_size=None) as ws:
            cdp = CDP(ws)
            await cdp.cmd("Page.enable")
            for q in qs:
                await make_one(cdp, q, template)
    finally:
        proc.terminate()


def main():
    args = sys.argv[1:]
    data = json.load(open(SRC))
    by_id = {q["id"]: q for q in data}
    if "--sample" in args:
        seen, qs = set(), []
        for q in data:
            if q["category"] not in seen:
                seen.add(q["category"]); qs.append(q)
    elif "--all" in args:
        qs = data
    else:
        qs = [by_id[a] for a in args if a in by_id]
    if not qs:
        print("usage: narrate.py <id...> | --sample | --all"); return
    print(f"{len(qs)} narrated reel(s) → {DESK}")
    srv = ensure_server()
    try:
        asyncio.run(run(qs))
    finally:
        if srv: srv.terminate()


if __name__ == "__main__":
    main()
