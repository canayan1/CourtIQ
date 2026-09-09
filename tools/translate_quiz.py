#!/usr/bin/env python3
"""Write a language's fields into quiz_questions.json, keyed by question id.

    python3 tools/translate_quiz.py Tr translations.json
    python3 tools/translate_quiz.py Fr translations.json

Each entry: {"s": scenario, "o": [3 options], "e": explanation, "t": takeaway}.
Writes scenario<Lang> / options<Lang> / explanation<Lang> / takeaway<Lang>.

Refuses an option list of the wrong length: `shufflingOptions()` permutes
every language by the SAME map, so a short list silently falls back to
English mid-question and the player reads two languages at once. Clears the
id from the manifest's `needsTranslation` only when both languages are in.
"""
import json, sys

P = "CourtIQ/Resources/Content/quiz_questions.json"
MANIFEST = "docs/quiz-rewrite-manifest.json"

def main(lang, path):
    assert lang in ("Tr", "Fr"), "language must be Tr or Fr"
    payload = json.load(open(path))
    data = json.load(open(P))
    by_id = {q["id"]: q for q in data}
    done, missing = 0, []
    for qid, t in payload.items():
        q = by_id.get(qid)
        if q is None: missing.append(qid); continue
        assert len(t["o"]) == len(q["options"]), f"{qid}: {len(t['o'])} options vs {len(q['options'])}"
        q[f"scenario{lang}"], q[f"options{lang}"] = t["s"], t["o"]
        q[f"explanation{lang}"], q[f"takeaway{lang}"] = t["e"], t["t"]
        done += 1
    json.dump(data, open(P, "w"), ensure_ascii=False, indent=2)

    manifest = json.load(open(MANIFEST))
    both = [q["id"] for q in data if q.get("scenarioTr") and q.get("scenarioFr")]
    manifest["needsTranslation"] = [i for i in manifest["needsTranslation"] if i not in both]
    json.dump(manifest, open(MANIFEST, "w"), ensure_ascii=False, indent=2)
    tr = sum(1 for q in data if q.get("scenarioTr")); fr = sum(1 for q in data if q.get("scenarioFr"))
    print(f"{lang}: wrote {done}" + (f" · MISSING {missing}" if missing else ""))
    print(f"bank coverage — tr {tr}/{len(data)} · fr {fr}/{len(data)} · still owed {len(manifest['needsTranslation'])}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
