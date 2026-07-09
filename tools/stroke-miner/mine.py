#!/usr/bin/env python3
"""stroke-miner — ses-impact tespitiyle uzun tenis videosunu etiketli eğitim
kliplerine böler (Create ML Action Classifier için).

Yaklaşım: raket teması geniş-bantlı, keskin bir darbe ve mikrofon oyuncunun
arkasında olduğu için duvar sekmesinden belirgin daha yüksek gelir. Yüksek-geçiren
farklayıcı + kısa-pencere RMS zarfı + adaptif eşik (medyan + k·MAD) + min-aralıklı
tepe seçimi (aralık içinde en güçlü tepe kazanır → raket vuruşu duvar sesini eler).

Kullanım:
  python3 mine.py --video <dosya> --label forehand --out ~/TennisVideos/_training/v0
Çıktı: <out>/<label>/<video-adı>_NN.mp4 (2.2 sn, 30fps, h264, sessiz)
       + <out>/manifest.json'a ekleme. --dry-run yalnızca zamanları basar.
"""
import argparse, json, math, os, subprocess, sys, tempfile, wave
from pathlib import Path

import numpy as np

SR = 16_000
ENV_WIN_S = 0.010      # RMS zarf penceresi
MIN_GAP_S = 1.4        # iki vuruş arası minimum süre (duvar sekmesini eler)
PRE_S, POST_S = 1.3, 0.9   # klip: temastan önce/sonra (toplam 2.2 sn ≈ 66 kare @30fps)
MAD_K = 6.0            # eşik = medyan + K·MAD
OTHER_GAP_S = 5.0      # bu kadar sessiz aralıkların ortası = "other" (negatif) adayı


def extract_envelope(video: Path) -> tuple[np.ndarray, float]:
    """Videonun ses izi → yüksek-geçirenli RMS zarfı (env, saniye/örnek)."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wav_path = tf.name
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(video),
             "-ac", "1", "-ar", str(SR), "-vn", wav_path],
            check=True,
        )
        with wave.open(wav_path, "rb") as w:
            raw = w.readframes(w.getnframes())
            x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    finally:
        os.unlink(wav_path)
    hp = np.diff(x, prepend=x[:1])              # farklayıcı ≈ yüksek-geçiren (adım/rüzgâr gürültüsünü kırpar)
    win = max(1, int(ENV_WIN_S * SR))
    n = len(hp) // win
    env = np.sqrt((hp[: n * win].reshape(n, win) ** 2).mean(axis=1))
    return env, ENV_WIN_S


def detect_impacts(env: np.ndarray, dt: float) -> list[float]:
    med = float(np.median(env))
    mad = float(np.median(np.abs(env - med))) or 1e-6
    thr = med + MAD_K * mad
    idx = np.where(env > thr)[0]
    if len(idx) == 0:
        return []
    # adaylar amplitüde göre; min-aralık içinde en güçlü tepe kazanır
    order = idx[np.argsort(env[idx])[::-1]]
    kept: list[int] = []
    min_gap = int(MIN_GAP_S / dt)
    for i in order:
        if all(abs(i - j) >= min_gap for j in kept):
            kept.append(int(i))
    return sorted(i * dt for i in kept)


def other_windows(impacts: list[float], duration: float) -> list[float]:
    """Vuruşsuz uzun aralıkların ortaları — 'other' (hareket yok/yürüme) örnekleri."""
    bounds = [0.0, *impacts, duration]
    outs = []
    for a, b in zip(bounds, bounds[1:]):
        if b - a >= OTHER_GAP_S:
            outs.append((a + b) / 2)
    return outs


def cut(video: Path, t: float, dst: Path) -> None:
    start = max(0.0, t - PRE_S)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{start:.3f}", "-i", str(video),
         "-t", f"{PRE_S + POST_S:.3f}", "-an", "-r", "30",
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
         "-pix_fmt", "yuv420p", str(dst)],
        check=True,
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", required=True)
    ap.add_argument("--label", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-other", action="store_true", help="'other' negatifleri üretme")
    args = ap.parse_args()

    video = Path(os.path.expanduser(args.video))
    out = Path(os.path.expanduser(args.out))
    dur = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(video)],
        capture_output=True, text=True, check=True).stdout.strip())

    env, dt = extract_envelope(video)
    impacts = [t for t in detect_impacts(env, dt) if PRE_S <= t <= dur - POST_S]
    others = [] if args.no_other else [t for t in other_windows(impacts, dur) if PRE_S <= t <= dur - POST_S]

    print(f"{video.name}: {dur:.0f} sn → {len(impacts)} vuruş, {len(others)} 'other' adayı")
    if args.dry_run:
        print("  vuruş anları:", " ".join(f"{t:.1f}" for t in impacts))
        return

    manifest_path = out / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"clips": []}
    for label, times in ((args.label, impacts), ("other", others)):
        d = out / label
        d.mkdir(parents=True, exist_ok=True)
        for k, t in enumerate(times, 1):
            dst = d / f"{video.stem}_{k:02d}.mp4"
            cut(video, t, dst)
            manifest["clips"].append({"src": video.name, "label": label, "t": round(t, 2), "clip": str(dst.relative_to(out))})
        if times:
            print(f"  {label}: {len(times)} klip → {d}")
    manifest_path.write_text(json.dumps(manifest, indent=1))


if __name__ == "__main__":
    sys.exit(main())
