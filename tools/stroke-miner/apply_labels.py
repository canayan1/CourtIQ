#!/usr/bin/env python3
"""apply_labels — labelcheck çıktısını (relabels.json) eğitim setine uygular.

forehand/backhand/smash → ilgili sınıf klasörüne taşır;
tweener/cop → _rejected/<etiket>/ altına alır (eğitime girmez).

Kullanım: python3 apply_labels.py ~/TennisVideos/_training/v0 relabels.json
"""
import json, shutil, sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1]).expanduser()
relabels = json.loads(Path(sys.argv[2]).expanduser().read_text())["relabels"]

TRAIN = {"forehand", "backhand", "smash"}
moves = Counter()
for rel, new in relabels.items():
    src = root / rel
    if not src.exists():
        print(f"  atla (yok): {rel}")
        continue
    dst = (root / new if new in TRAIN else root / "_rejected" / new) / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dst))
    moves[f"{rel.split('/')[0]} → {new}"] += 1

for k, v in sorted(moves.items()):
    print(f"  {k}: {v}")
print("--- yeni sayılar:")
for d in ("forehand", "backhand", "smash"):
    print(f"  {d}: {len(list((root / d).glob('*.mp4')))} klip")
