#!/usr/bin/env python3
"""Unregister files from CourtIQ.xcodeproj by basename (inverse of pbx_add.py).

    python3 tools/pbx_remove.py Foo.swift Bar.wav

Drops every PBXFileReference / PBXBuildFile / group child / build-phase line
that names the file. Does not delete the file on disk.
"""
import re, sys
P = "CourtIQ.xcodeproj/project.pbxproj"
s = open(P).read()
for name in sys.argv[1:]:
    n = re.escape(name)
    before = s.count(name)
    s = re.sub(r'^\t+[0-9A-F]{24} /\* %s(?: in [A-Za-z]+)? \*/(?:,| = \{[^\n]*\};)\n' % n, "", s, flags=re.M)
    print(f"{name}: {before} → {s.count(name)} mentions")
open(P, "w").write(s)
