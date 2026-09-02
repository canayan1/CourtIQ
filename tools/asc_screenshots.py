#!/usr/bin/env python3
"""Replace an App Store version's screenshots through the ASC API.

    python3 tools/asc_screenshots.py <appStoreVersionId> <displayType> <locale>... -- <png>...

For every listed locale of the version: find (or create) the screenshot set
for `displayType`, delete whatever is in it, then upload the PNGs in the
given order (reserve → PUT chunks → commit with md5). Prints one line per
step. Auth comes from ~/.appstore-keys/asc_jwt.py; nothing secret is
printed.
"""
import hashlib, json, os, subprocess, sys, urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
TOKEN = subprocess.check_output(["python3", os.path.expanduser("~/.appstore-keys/asc_jwt.py")]).decode().strip()

def call(method, path, body=None, raw_url=None, headers=None, data=None):
    url = raw_url or (API + path)
    req = urllib.request.Request(url, method=method)
    if raw_url is None:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    if body is not None:
        req.add_header("Content-Type", "application/json")
        data = json.dumps(body).encode()
    with urllib.request.urlopen(req, data=data) as r:
        txt = r.read()
        return json.loads(txt) if txt and r.headers.get("Content-Type", "").startswith("application/json") else None

args = sys.argv[1:]
sep = args.index("--")
version_id, display_type, locales = args[0], args[1], args[2:sep]
files = args[sep + 1:]
assert files, "no files"

locs = call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale")["data"]
by_locale = {l["attributes"]["locale"]: l["id"] for l in locs}

for locale in locales:
    lid = by_locale[locale]
    sets = call("GET", f"/appStoreVersionLocalizations/{lid}/appScreenshotSets?fields[appScreenshotSets]=screenshotDisplayType")["data"]
    sid = next((s["id"] for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
    if sid is None:
        sid = call("POST", "/appScreenshotSets", {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]["id"]
        print(f"[{locale}] created set {display_type}")
    old = call("GET", f"/appScreenshotSets/{sid}/appScreenshots?fields[appScreenshots]=fileName&limit=50")["data"]
    for s in old:
        call("DELETE", f"/appScreenshots/{s['id']}")
    print(f"[{locale}] cleared {len(old)} old screenshot(s)")

    for path in files:
        name = os.path.basename(path)
        blob = open(path, "rb").read()
        res = call("POST", "/appScreenshots", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": name, "fileSize": len(blob)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}})["data"]
        for op in res["attributes"]["uploadOperations"]:
            chunk = blob[op["offset"]: op["offset"] + op["length"]]
            call(op["method"], None, raw_url=op["url"],
                 headers={h["name"]: h["value"] for h in op["requestHeaders"]}, data=chunk)
        call("PATCH", f"/appScreenshots/{res['id']}", {"data": {"type": "appScreenshots", "id": res["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
        print(f"[{locale}] uploaded {name} ({len(blob)//1024} KB)")
print("done")
