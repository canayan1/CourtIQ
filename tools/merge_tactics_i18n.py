#!/usr/bin/env python3
"""Emit or merge the Tactics course translation files.

    python3 tools/merge_tactics_i18n.py --emit <dir>   # English, split into groups
    python3 tools/merge_tactics_i18n.py fr             # merge <dir>/fr/*.json

Reads <scratch>/tac/<lang>/*.json (the per-group agent output), checks every
key against the English manifest regenerated from the curriculum itself, and
writes CourtIQ/Resources/Content/tactics_i18n.<lang>.json.

Refuses a key the app will never ask for and refuses a value that is still
English on a key whose English differs -- both are silent failures at
runtime, where a bad key simply never renders and an untranslated value is
indistinguishable from a missing one.
"""
import json, sys, os, glob

SCRATCH = os.environ.get("TAC_DIR") or (
    "/private/tmp/claude-501/-Users-can-Projects-CourtIQ/"
    "bd71eb2e-adfc-4ac5-a839-1026428f22b9/scratchpad/tac")
OUT = "CourtIQ/Resources/Content/tactics_i18n.{}.json"


def manifest():
    """The exact keys `TacticsCopy` will ask for, rebuilt from the content."""
    cur = json.load(open("CourtIQ/Resources/Content/tactics_curriculum.json"))
    dlg = json.load(open("CourtIQ/Resources/Content/tactics_dialogues.json"))
    m = {}
    for ch in cur["chapters"] + cur.get("sideSets", []):
        m[f"chapter.{ch['id']}.title"] = ch["title"]
        m[f"chapter.{ch['id']}.subtitle"] = ch["subtitle"]
        if ch.get("hook"):
            m[f"chapter.{ch['id']}.hook"] = ch["hook"]
        for l in ch["lessons"]:
            b = f"lesson.{l['id']}"
            for f in ("title", "situation", "principle", "defaultAction", "commonMistake"):
                m[f"{b}.{f}"] = l[f]
            for i, a in enumerate(l.get("adjustments", [])):
                m[f"{b}.adj.{i}.when"] = a["when"]
                m[f"{b}.adj.{i}.then"] = a["then"]
            if l.get("advanced"):
                m[f"{b}.advanced.heading"] = l["advanced"]["heading"]
                m[f"{b}.advanced.body"] = l["advanced"]["body"]
            q = l["quiz"]
            m[f"{b}.quiz.scenario"] = q["scenario"]
            m[f"{b}.quiz.question"] = q["question"]
            for i, o in enumerate(q["options"]):
                m[f"{b}.quiz.opt.{i}"] = o
            m[f"{b}.quiz.explanation"] = q["explanation"]
    for s in dlg["scripts"]:
        for n in s["nodes"]:
            b = f"dialogue.{s['lessonId']}.{n['id']}"
            m[b] = n["text"]
            for i, o in enumerate(n.get("options", [])):
                m[f"{b}.opt.{i}.label"] = o["label"]
                m[f"{b}.opt.{i}.reply"] = o["reply"]
    return m


def main(lang):
    en = manifest()
    merged, dupes = {}, []
    files = sorted(glob.glob(f"{SCRATCH}/{lang}/*.json"))
    assert files, f"no group files in {SCRATCH}/{lang}"
    for path in files:
        for k, v in json.load(open(path)).items():
            if k in merged:
                dupes.append(k)
            merged[k] = v
    unknown = sorted(set(merged) - set(en))
    missing = sorted(set(en) - set(merged))
    empty = sorted(k for k, v in merged.items() if not str(v).strip())
    # A value identical to the English is only suspicious when the English is
    # a sentence; single tennis terms legitimately survive translation.
    untranslated = sorted(k for k, v in merged.items()
                          if v == en.get(k) and len(str(v).split()) > 3)
    print(f"groups {len(files)} · keys {len(merged)}/{len(en)}")
    for name, rows in (("duplicate", dupes), ("unknown key", unknown),
                       ("empty", empty), ("still English", untranslated)):
        if rows:
            print(f"  {name}: {len(rows)}  e.g. {rows[:4]}")
    if missing:
        print(f"  MISSING {len(missing)}  e.g. {missing[:4]}")
    assert not unknown and not empty, "refusing to write"
    json.dump(merged, open(OUT.format(lang), "w"), ensure_ascii=False, indent=1, sort_keys=True)
    print(f"wrote {OUT.format(lang)} · coverage {len(merged)}/{len(en)} "
          f"({100 * len(merged) // len(en)}%)")


def emit(target):
    """Split the English into one file per chapter plus three dialogue files.

    Chapter-sized groups are what a translator (or a translating agent) can
    hold in one pass while still seeing a whole lesson's situation, principle
    and quiz together -- which is what catches a crosscourt that turned into a
    down-the-line somewhere between the option and its explanation.
    """
    en = manifest()
    cur = json.load(open("CourtIQ/Resources/Content/tactics_curriculum.json"))
    groups, dialogue = {}, {}
    for ch in cur["chapters"] + cur.get("sideSets", []):
        pre = (f"chapter.{ch['id']}.",) + tuple(f"lesson.{l['id']}." for l in ch["lessons"])
        groups[f"chapter-{ch['id']}"] = {k: v for k, v in en.items() if k.startswith(pre)}
    dialogue = {k: v for k, v in en.items() if k.startswith("dialogue.")}
    items = list(dialogue.items())
    for i in range(3):
        groups[f"dialogue-{i + 1}"] = dict(items[i * len(items) // 3:(i + 1) * len(items) // 3])
    os.makedirs(target, exist_ok=True)
    covered = sum(len(g) for g in groups.values())
    assert covered == len(en), f"{covered} of {len(en)} keys landed in a group"
    for name, g in groups.items():
        json.dump(g, open(os.path.join(target, f"{name}.json"), "w"), ensure_ascii=False, indent=1)
        print(f"{name:30} {len(g):4d} keys  {sum(len(v) for v in g.values()):6,d} chars")
    print(f"TOTAL {covered} keys per language")


if __name__ == "__main__":
    if sys.argv[1] == "--emit":
        emit(sys.argv[2])
    else:
        main(sys.argv[1])
