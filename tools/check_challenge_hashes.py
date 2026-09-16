#!/usr/bin/env python3
"""A challenge link names its five scenarios by a 24-bit hash of the id.

Two scenarios sharing a hash would make one link play the wrong question, so
this asserts the whole bank is collision-free. Run it whenever scenarios are
added — the failure is silent and the link looks fine, which is exactly the
kind of bug nobody finds by using the app.
"""
import json, pathlib, sys

def fnv1a24(s: str) -> int:
    h = 2166136261
    for b in s.encode():
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF
    return h & 0xFFFFFF

bank = json.loads(pathlib.Path("CourtIQ/Resources/Content/quiz_questions.json").read_text())
seen, clashes = {}, []
for q in bank:
    h = fnv1a24(q["id"])
    if h in seen:
        clashes.append((seen[h], q["id"], hex(h)))
    seen[h] = q["id"]

print(f"scenarios: {len(bank)} · distinct 24-bit hashes: {len(seen)}")
if clashes:
    print("COLLISIONS — a challenge link would play the wrong scenario:")
    for a, b, h in clashes:
        print(f"  {a}  ==  {b}   ({h})")
    sys.exit(1)
# Birthday estimate, so the margin is visible rather than assumed.
n = len(bank)
print(f"collision probability at this size ≈ {n*n/2/2**24:.4%} — clear")
