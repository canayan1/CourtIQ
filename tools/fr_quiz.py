#!/usr/bin/env python3
"""Write French fields into quiz_questions.json, keyed by question id.

    from fr_quiz import write
    write({"serve_021": {"s": "...", "o": ["…","…","…"], "e": "…", "t": "…"}, ...})

Fills scenarioFr / optionsFr / explanationFr / takeawayFr. Refuses an option
list whose length differs from the English one — the shuffler reorders both
together and a mismatched list would silently fall back to English.
"""
import json
P = "CourtIQ/Resources/Content/quiz_questions.json"

def write(mapping):
    data = json.load(open(P))
    by_id = {q["id"]: q for q in data}
    done, missing = 0, []
    for qid, fr in mapping.items():
        q = by_id.get(qid)
        if q is None: missing.append(qid); continue
        assert len(fr["o"]) == len(q["options"]), f"{qid}: {len(fr['o'])} options vs {len(q['options'])}"
        q["scenarioFr"], q["optionsFr"] = fr["s"], fr["o"]
        q["explanationFr"], q["takeawayFr"] = fr["e"], fr["t"]
        done += 1
    json.dump(data, open(P, "w"), ensure_ascii=False, indent=2)
    total = sum(1 for q in data if q.get("scenarioFr"))
    print(f"wrote {done}" + (f" · MISSING ids {missing}" if missing else "") + f" · french coverage {total}/{len(data)}")
