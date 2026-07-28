# -*- coding: utf-8 -*-
"""Ensure every nav-column dashboard carries TWO nav panels, matching the
Alerts dashboard (/d/ad7kkx7/alerts):
    1. "dbdome - Dashboards"  (main list)
    2. "dbdome - GRC"         (GRC list, stacked directly below)

Canonical content is read from ad7kkx7. Only dashboards that already have the
"dbdome - Dashboards" nav (i.e. the reserved x0 nav-column layout) are touched;
full-width dashboards without a nav column are left alone. Idempotent.
"""
import sqlite3, json, sys

DB = r"C:\ProgramData\DBDOME\data\grafana.db"
NAV1 = "dbdome - Dashboards"
NAV2 = "dbdome - GRC"


def walk(ps):
    for p in ps or []:
        yield p
        for s in p.get("panels", []):
            yield s


def is_nav1(p):
    if p.get("type") != "text":
        return False
    if (p.get("title") or "") == NAV1:
        return True
    c = (p.get("options", {}) or {}).get("content", "") or ""
    return "/d/ad7kkx7/alerts" in c and "Dashboards" in c


def main():
    con = sqlite3.connect(DB)
    cdash = json.loads(con.execute("SELECT data FROM dashboard WHERE uid='ad7kkx7'").fetchone()[0])
    CP1 = CP2 = None
    for p in walk(cdash.get("panels", [])):
        if p.get("type") == "text":
            if (p.get("title") or "") == NAV1:
                CP1 = p
            elif (p.get("title") or "") == NAV2:
                CP2 = p
    if not CP1 or not CP2:
        print("ERROR: canonical nav panels not found on ad7kkx7"); sys.exit(1)
    C1 = CP1["options"]["content"]
    C2 = CP2["options"]["content"]

    updated = added = 0
    for did, uid, data, ver in con.execute("SELECT id, uid, data, version FROM dashboard").fetchall():
        try:
            dash = json.loads(data)
        except (TypeError, ValueError):
            continue
        panels = dash.get("panels")
        if panels is None:
            continue
        nav1 = next((p for p in panels if is_nav1(p)), None)
        if nav1 is None:
            continue  # not a nav-column dashboard -> leave alone

        nx = nav1.get("gridPos", {}).get("x", 0)
        ny = nav1.get("gridPos", {}).get("y", 0)
        # refresh panel 1
        nav1["title"] = NAV1
        nav1.setdefault("options", {})["content"] = C1
        nav1["options"]["mode"] = "markdown"
        nav1["gridPos"] = {"x": nx, "y": ny, "w": 4, "h": 29}

        # find or create panel 2 (GRC), stacked directly below
        nav2 = next((p for p in panels if p.get("type") == "text" and (p.get("title") or "") == NAV2), None)
        if nav2 is None:
            nav2 = json.loads(json.dumps(CP2))  # deep copy canonical
            nav2["id"] = max([p.get("id", 0) for p in panels] + [0]) + 1
            panels.append(nav2)
            added += 1
        nav2["title"] = NAV2
        nav2.setdefault("options", {})["content"] = C2
        nav2["options"]["mode"] = "markdown"
        nav2["gridPos"] = {"x": nx, "y": ny + 29, "w": 4, "h": 18}

        dash["version"] = ver + 1
        con.execute("UPDATE dashboard SET data=?, version=?, updated=datetime('now') WHERE id=?",
                    (json.dumps(dash), ver + 1, did))
        updated += 1

    con.commit(); con.close()
    print(f"updated {updated} dashboards ({added} new GRC nav panels added)")


if __name__ == "__main__":
    main()
