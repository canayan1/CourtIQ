#!/usr/bin/env python3
"""Fill the French arm of the inline bilingual `t(en, tr)` helpers.

    from fr_inline import apply
    apply("path/to/File.swift", {"English source": "Texte français", ...})

Matches `t("<en>", <tr literal>)` — across line breaks — and rewrites it to
`t("<en>", <tr literal>, "<fr>")`. Keyed on the English string so the map
reads like a translation memory and stays verifiable. Reports anything it
could not place instead of failing silently.
"""
import re, sys

def apply(path, mapping):
    s = open(path).read()
    placed, missed = 0, []
    for en, fr in mapping.items():
        pat = re.compile(
            r't\(\s*"' + re.escape(en) + r'"\s*,\s*("(?:[^"\\]|\\.)*")\s*\)', re.S)
        new, n = pat.subn(lambda m: 't("%s", %s, "%s")' % (en, m.group(1), fr.replace('"', '\\"')), s)
        if n: s, placed = new, placed + n
        else: missed.append(en)
    open(path, "w").write(s)
    print(f"{path.split('/')[-1]}: placed {placed}" + (f" · MISSED {len(missed)}" if missed else ""))
    for m in missed: print("   miss:", m[:70])
    return placed

if __name__ == "__main__":
    print(__doc__)
