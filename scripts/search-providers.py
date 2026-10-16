#!/usr/bin/env python3
"""GNOME Shell SearchProvider2 client for the overview search.

    search-providers.py search <query> [max-per-provider]
        Prints a JSON array of results from every installed provider.
    search-providers.py activate <bus> <object-path> <result-id> <query>
        Opens a result.

Every D-Bus call goes through `busctl --json=short` with its own timeout:
some providers activate and never answer, and the overview must not wait on
them.
"""

import configparser
import glob
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

IFACE = "org.gnome.Shell.SearchProvider2"
TIMEOUT = "2"


def provider_dirs():
    dirs = []
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    dirs.append(data_home)
    dirs.extend((os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":"))
    seen = []
    for d in dirs:
        path = os.path.join(d, "gnome-shell", "search-providers")
        if path not in seen and os.path.isdir(path):
            seen.append(path)
    return seen


def providers():
    found = {}
    for directory in provider_dirs():
        for ini in sorted(glob.glob(os.path.join(directory, "*.ini"))):
            parser = configparser.ConfigParser(interpolation=None)
            try:
                parser.read(ini)
                section = parser["Shell Search Provider"]
            except Exception:
                continue
            if section.get("DefaultDisabled", "false").lower() == "true":
                continue
            bus = section.get("BusName")
            path = section.get("ObjectPath")
            if not bus or not path:
                continue
            desktop = section.get("DesktopId", "")
            found.setdefault(bus + path, {"bus": bus, "path": path, "desktopId": desktop})
    return list(found.values())


def busctl(provider, method, signature, *args):
    command = ["busctl", "--user", "--json=short", f"--timeout={TIMEOUT}", "call",
               provider["bus"], provider["path"], IFACE, method, signature, *args]
    out = subprocess.run(command, capture_output=True, text=True, timeout=float(TIMEOUT) + 1)
    if out.returncode != 0:
        return None
    return json.loads(out.stdout).get("data", [None])[0]


def icon_name(meta):
    icon = meta.get("icon", {}).get("data")
    # (sv): ["themed", {"type": "as", "data": [...]}] or ["file", {...}]
    if isinstance(icon, list) and len(icon) == 2:
        kind, value = icon
        data = value.get("data") if isinstance(value, dict) else None
        if kind == "themed" and isinstance(data, list) and data:
            return data[0]
        if kind == "file" and isinstance(data, str):
            return data
    gicon = meta.get("gicon", {}).get("data")
    if isinstance(gicon, str):
        return gicon.split(" ")[0]
    return ""


def search_one(provider, terms, limit):
    try:
        ids = busctl(provider, "GetInitialResultSet", "as", str(len(terms)), *terms) or []
        ids = ids[:limit]
        if not ids:
            return []
        metas = busctl(provider, "GetResultMetas", "as", str(len(ids)), *ids) or []
    except Exception:
        return []
    results = []
    for meta in metas:
        def text(key):
            value = meta.get(key, {}).get("data")
            return value if isinstance(value, str) else ""
        results.append({
            "bus": provider["bus"],
            "path": provider["path"],
            "desktopId": provider["desktopId"],
            "id": text("id"),
            "name": text("name"),
            "description": text("description"),
            "clipboardText": text("clipboardText"),
            "icon": icon_name(meta),
        })
    return results


def search(query, limit):
    terms = [t for t in query.split() if t]
    if not terms:
        print("[]")
        return
    found = providers()
    out = []
    with ThreadPoolExecutor(max_workers=max(1, len(found))) as pool:
        for chunk in pool.map(lambda p: search_one(p, terms, limit), found):
            out.extend(chunk)
    print(json.dumps(out))


def activate(bus, path, result_id, query):
    provider = {"bus": bus, "path": path}
    terms = [t for t in query.split() if t]
    busctl(provider, "ActivateResult", "sasu", result_id, str(len(terms)), *terms,
           str(int(time.time()) & 0xFFFFFFFF))


def main(argv):
    if len(argv) >= 3 and argv[1] == "search":
        limit = int(argv[3]) if len(argv) > 3 else 5
        search(argv[2], limit)
    elif len(argv) == 6 and argv[1] == "activate":
        activate(argv[2], argv[3], argv[4], argv[5])
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
