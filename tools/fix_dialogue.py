#!/usr/bin/env python3
"""Patch tactics_dialogues.json by (script id, node id).

    from fix_dialogue import patch
    patch("dlg-geo-3", "n2", stem="…", options={"old label": ("new label", "new reply")})

`stem` replaces the node's question text; each `options` entry rewrites one
option's label and (optionally) its reply, matched on the CURRENT label.
Every edit must match exactly one target or the run fails — a silent miss
would leave a question the audit says is ambiguous.
"""
import json
P = "CourtIQ/Resources/Content/tactics_dialogues.json"

def _load(): return json.load(open(P))
def _save(d): json.dump(d, open(P, "w"), ensure_ascii=False, indent=2)

def patch(script_id, node_id, stem=None, options=None):
    d = _load()
    script = next(s for s in d["scripts"] if s["id"] == script_id)
    node = next(n for n in script["nodes"] if n["id"] == node_id)
    if stem is not None:
        node["text"] = stem
    for old, new in (options or {}).items():
        label, reply = new if isinstance(new, tuple) else (new, None)
        target = [o for o in node["options"] if o["label"] == old]
        assert len(target) == 1, f"{script_id}/{node_id}: {len(target)} options match {old!r}"
        target[0]["label"] = label
        if reply is not None: target[0]["reply"] = reply
    _save(d)
