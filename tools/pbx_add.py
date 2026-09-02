#!/usr/bin/env python3
"""Register files in CourtIQ.xcodeproj without Xcode.

    python3 tools/pbx_add.py CourtIQ/Features/X/Foo.swift CourtIQ/Resources/Content/bar.json ...

Mirrors the flat pattern the project already uses for hand-added files
(fileRef with a full path, listed in the main group, and in the Sources or
Resources build phase by extension). Idempotent: a path already present is
skipped. Test-target files are not handled here.
"""
import re, sys, uuid
P = "CourtIQ.xcodeproj/project.pbxproj"
s = open(P).read()
SRC_EXT = {".swift"}
def nid(): return uuid.uuid4().hex[:24].upper()

# anchors: the WallSwingDetector entries mark the main group and the Sources phase
grp_anchor = re.search(r'^(\t+)B400000000000000000001 /\* WallSwingDetector\.swift \*/,$', s, re.M)
src_anchor = re.search(r'^(\t+)B400000000000000000002 /\* WallSwingDetector\.swift in Sources \*/,$', s, re.M)
res_phase  = re.search(r'isa = PBXResourcesBuildPhase;.*?files = \(\n', s, re.S)
assert grp_anchor and src_anchor and res_phase, "anchors missing"

added = []
for path in sys.argv[1:]:
    name = path.rsplit("/", 1)[-1]
    if f"path = {path};" in s:
        print("skip (present)", path); continue
    ext = "." + name.rsplit(".", 1)[-1] if "." in name else ""
    is_src = ext in SRC_EXT
    ftype = {"swift": "sourcecode.swift", "json": "text.json", "wav": "audio.wav"}.get(ext[1:], "file")
    rid, bid = nid(), nid()
    phase = "Sources" if is_src else "Resources"
    s = s.replace(
        "/* End PBXFileReference section */",
        f"\t\t{rid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = {name}; path = {path}; sourceTree = \"<group>\"; }};\n/* End PBXFileReference section */", 1)
    s = s.replace(
        "/* End PBXBuildFile section */",
        f"\t\t{bid} /* {name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {rid} /* {name} */; }};\n/* End PBXBuildFile section */", 1)
    # main group children (after the wall detector entry)
    g = re.search(r'^(\t+)B400000000000000000001 /\* WallSwingDetector\.swift \*/,$', s, re.M)
    s = s[:g.end()] + f"\n{g.group(1)}{rid} /* {name} */," + s[g.end():]
    if is_src:
        a = re.search(r'^(\t+)B400000000000000000002 /\* WallSwingDetector\.swift in Sources \*/,$', s, re.M)
        s = s[:a.end()] + f"\n{a.group(1)}{bid} /* {name} in Sources */," + s[a.end():]
    else:
        r = re.search(r'isa = PBXResourcesBuildPhase;.*?files = \(\n', s, re.S)
        s = s[:r.end()] + f"\t\t\t\t{bid} /* {name} in Resources */,\n" + s[r.end():]
    added.append(path)
open(P, "w").write(s)
print("added", len(added), "file(s)")
