#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check nutrition content against what the app's Codable models require.

    python3 tools/validate_nutrition.py guide   path/to/nutrition_guide.xx.json
    python3 tools/validate_nutrition.py recipes path/to/nutrition_recipes.xx.json

Mirrors NutritionContent.swift: a key the decoder needs and cannot find is a
silent failure at runtime (the card simply never appears), so it is caught
here instead. For recipes it also re-checks that tags tell the truth about
ingredients, because a wrong "dairyFree" is not a bug, it is a hazard.
"""
import json, sys, io, re

TODAY_BASE = ["under1", "h1to2", "h2to4", "over4"]
TODAY_MODS = {"intensity": ["light", "normal", "hard"], "heat": ["cool", "warm", "hot"], "lastSession": ["flat", "ok", "great"]}
QUIZ_IDS = ["playTime", "sessionLength", "stomach", "diet", "prepTime", "goal"]
WHEN = {"pre", "post", "tournament", "evening"}
DAIRY  = re.compile(r"\b(milk|yog(h)?urt|cheese|butter|cream|whey|kefir|labneh|ayran|feta|parmesan|mozzarella|ricotta|paneer)\b", re.I)
GLUTEN = re.compile(r"\b(wheat|pasta|bread|couscous|bulgur|noodle|flour|pita|tortilla|barley|rye|semolina|spaghetti|penne|toast|bagel|crackers?)\b", re.I)
ANIMAL = re.compile(r"\b(egg|eggs|milk|yog(h)?urt|cheese|butter|cream|honey|chicken|turkey|beef|lamb|fish|tuna|salmon|meat|whey|kefir|labneh|ayran|feta)\b", re.I)

def fail(msgs):
    for m in msgs: print("  ✗", m)
    sys.exit(1)

def guide(path):
    d = json.load(io.open(path, encoding="utf-8")); errs = []
    for i, s in enumerate(d.get("sections", [])):
        for k in ("id", "title", "summary", "body", "keyPoints", "sources"):
            if k not in s: errs.append(f"section {i} missing {k}")
        if not s.get("sources"): errs.append(f"section {s.get('id', i)} has no source")
        for src in s.get("sources", []):
            if not str(src.get("url", "")).startswith("http"): errs.append(f"section {s.get('id')} source without url")
    t = d.get("today", {})
    for k in TODAY_BASE:
        b = t.get("base", {}).get(k)
        if not b: errs.append(f"today.base.{k} missing")
        else:
            for f in ("headline", "eat", "avoid", "why"):
                if not b.get(f): errs.append(f"today.base.{k}.{f} missing")
    for mod, keys in TODAY_MODS.items():
        for k in keys:
            if not t.get(mod, {}).get(k): errs.append(f"today.{mod}.{k} missing")
    words = sum(len(str(v).split()) for s in d.get("sections", []) for v in [s.get("summary", "")] + s.get("body", []) + s.get("keyPoints", []))
    if errs: fail(errs)
    print(f"  guide ok · {len(d['sections'])} sections · {words} words · {sum(len(s['sources']) for s in d['sections'])} source links")

def recipes(path):
    d = json.load(io.open(path, encoding="utf-8")); errs = []
    ids = [q.get("id") for q in d.get("quiz", [])]
    if ids != QUIZ_IDS: errs.append(f"quiz ids {ids} != {QUIZ_IDS}")
    for q in d.get("quiz", []):
        for o in q.get("options", []):
            for k in ("id", "label", "tags"):
                if k not in o: errs.append(f"quiz {q.get('id')} option missing {k}")
    tag_counts = {}
    for r in d.get("recipes", []):
        for k in ("id", "title", "when", "hoursBefore", "prepMinutes", "tags", "ingredients", "steps", "why", "swap"):
            if k not in r: errs.append(f"recipe {r.get('id')} missing {k}")
        if r.get("when") not in WHEN: errs.append(f"recipe {r.get('id')} bad when {r.get('when')}")
        text = " ".join(i.get("item", "") for i in r.get("ingredients", []))
        tags = set(r.get("tags", []))
        if "dairyFree" in tags and DAIRY.search(text): errs.append(f"recipe {r['id']} tagged dairyFree but lists dairy")
        if "glutenFree" in tags and GLUTEN.search(text): errs.append(f"recipe {r['id']} tagged glutenFree but lists gluten")
        if "vegan" in tags and ANIMAL.search(text): errs.append(f"recipe {r['id']} tagged vegan but lists an animal product")
        for t in tags: tag_counts[t] = tag_counts.get(t, 0) + 1
        # A pro note is a factual report, so it must carry a fetchable source
        # and must never put a person's name in the recipe title.
        pro = r.get("proNote")
        if pro is not None:
            for k in ("text", "sourceLabel", "sourceURL"):
                if not str(pro.get(k, "")).strip(): errs.append(f"recipe {r['id']} proNote missing {k}")
            if not str(pro.get("sourceURL", "")).startswith("http"):
                errs.append(f"recipe {r['id']} proNote source is not a url")
    quiz_tags = {t for q in d.get("quiz", []) for o in q.get("options", []) for t in o.get("tags", [])}
    for t in sorted(quiz_tags):
        if tag_counts.get(t, 0) < 3: errs.append(f"quiz tag '{t}' appears on only {tag_counts.get(t, 0)} recipes (need 3)")
    if errs: fail(errs)
    when_counts = {w: sum(1 for r in d["recipes"] if r["when"] == w) for w in sorted(WHEN)}
    pro = sum(1 for r in d["recipes"] if r.get("proNote"))
    print(f"  recipes ok · {len(d['recipes'])} recipes · when {when_counts} · quiz tags all ≥3 · {pro} pro notes")

if __name__ == "__main__":
    {"guide": guide, "recipes": recipes}[sys.argv[1]](sys.argv[2])
