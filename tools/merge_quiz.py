#!/usr/bin/env python3
"""Merge rewritten quiz questions into quiz_questions.json.

    python3 tools/merge_quiz.py rewrites.json

Applies the English fields, then does the two things a rewrite forces:

* **Clears the Turkish and French fields.** They mirror the OLD English, so
  leaving them would show a Turkish reader a different question from the one
  the options answer — worse than falling back to English.
* **Drops the diagram.** The court picture encodes the old ball; a wrong
  diagram teaches the wrong shot. 29 of the 156 questions already ship
  without one, so nil is a supported state.

Both are recorded in `docs/quiz-rewrite-manifest.json` so the translation and
diagram passes know exactly what they owe. Validates every rewrite against the
authoring rules and refuses the whole merge if any fails.
"""
import json, re, sys

BANNED = re.compile(r"\b(hope|hoping|bad luck|complain|argue|ignore|do nothing|give up|apolog|smash|"
                    r"close your eyes|squint|admire|whatever feels|never;|always .*no exceptions)\b", re.I)
P = "CourtIQ/Resources/Content/quiz_questions.json"
MANIFEST = "docs/quiz-rewrite-manifest.json"

def validate(qid, q):
    errs = []
    s = q["scenario"]
    if not (110 <= len(s) <= 240): errs.append(f"scenario {len(s)} chars")
    if len(q["options"]) != 3: errs.append("not 3 options")
    lens = [len(o) for o in q["options"]]
    if max(lens) / min(lens) > 1.55: errs.append(f"option parity {max(lens)/min(lens):.2f} ({lens})")
    if q["correctAnswerIndex"] != 0: errs.append("correctAnswerIndex != 0")
    e = q["explanation"]
    if not (150 <= len(e) <= 280): errs.append(f"explanation {len(e)} chars")
    for o in q["options"]:
        if BANNED.search(o): errs.append(f"banned phrasing in option: {o}")
    return errs

def main(path):
    rewrites = json.load(open(path))
    data = json.load(open(P))
    by_id = {q["id"]: q for q in data}
    problems = {qid: validate(qid, q) for qid, q in rewrites.items()}
    problems = {k: v for k, v in problems.items() if v}
    if problems:
        for k, v in problems.items(): print(f"REJECT {k}: {'; '.join(v)}")
        sys.exit(1)
    try:
        manifest = json.load(open(MANIFEST))
    except FileNotFoundError:
        manifest = {"needsTranslation": [], "needsDiagram": []}
    for qid, fr in rewrites.items():
        q = by_id[qid]
        for field in ("scenario", "options", "correctAnswerIndex", "explanation",
                      "takeaway", "difficulty", "focusTag"):
            if field in fr: q[field] = fr[field]
        for stale in ("scenarioTr", "optionsTr", "explanationTr", "takeawayTr",
                      "scenarioFr", "optionsFr", "explanationFr", "takeawayFr"):
            q.pop(stale, None)
        if q.pop("diagram", None) is not None and qid not in manifest["needsDiagram"]:
            manifest["needsDiagram"].append(qid)
        if qid not in manifest["needsTranslation"]: manifest["needsTranslation"].append(qid)
    json.dump(data, open(P, "w"), ensure_ascii=False, indent=2)
    json.dump(manifest, open(MANIFEST, "w"), ensure_ascii=False, indent=2)
    print(f"merged {len(rewrites)} · awaiting translation {len(manifest['needsTranslation'])}"
          f" · awaiting diagram {len(manifest['needsDiagram'])}")

if __name__ == "__main__":
    main(sys.argv[1])
