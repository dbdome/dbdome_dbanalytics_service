# -*- coding: utf-8 -*-
"""Reflow the 6 full-width GRC dashboards so they gain the standard nav column:
every panel is scaled from the 24-col grid into the 20-col area starting at x4,
then the two canonical nav panels (Dashboards + GRC) are added at x0.

Usage:  python reflow_grc_nav.py --dry     (preview grc-masking only)
        python reflow_grc_nav.py           (apply to all 6)
"""
import sqlite3, json, sys

DB = r"C:\ProgramData\DBDOME\data\grafana.db"
TARGETS = ["grc-masking", "grc-policy-exceptions", "grc-workflow-sod",
           "grc-risk-register", "grc-incidents", "grc-cross-border"]
NAV1, NAV2 = "dbdome - Dashboards", "dbdome - GRC"
NAV_W = 4
NEWGRID = 24 - NAV_W  # 20


def walk(ps):
    for p in ps or []:
        yield p
        for s in p.get("panels", []):
            yield s


def reflow_pos(g):
    ox, ow = g.get("x", 0), g.get("w", 24)
    nx = NAV_W + round(ox * NEWGRID / 24)
    nw = max(1, round(ow * NEWGRID / 24))
    if nx + nw > 24:
        nw = 24 - nx
    if nx < NAV_W:
        nx = NAV_W
    g["x"], g["w"] = nx, nw
    return g


def canonical(con):
    cdash = json.loads(con.execute("SELECT data FROM dashboard WHERE uid='ad7kkx7'").fetchone()[0])
    c1 = c2 = None
    for p in walk(cdash.get("panels", [])):
        if p.get("type") == "text":
            if (p.get("title") or "") == NAV1:
                c1 = p
            elif (p.get("title") or "") == NAV2:
                c2 = p
    return c1, c2


def main():
    dry = "--dry" in sys.argv
    con = sqlite3.connect(DB)
    CP1, CP2 = canonical(con)
    targets = ["grc-masking"] if dry else TARGETS
    for uid in targets:
        row = con.execute("SELECT id, data, version FROM dashboard WHERE uid=?", (uid,)).fetchone()
        if not row:
            print("  MISSING:", uid); continue
        did, data, ver = row
        dash = json.loads(data)
        panels = dash.get("panels", [])
        if dry:
            print(f"\n=== {uid} reflow preview ===")
        for p in walk(panels):
            g = p.get("gridPos", {})
            before = (g.get("x"), g.get("y"), g.get("w"), g.get("h"))
            reflow_pos(g)
            after = (g.get("x"), g.get("y"), g.get("w"), g.get("h"))
            if dry:
                print(f"  id={p.get('id')!s:>4} {p.get('type'):11} {before} -> {after}  ok={g['x']+g['w']<=24}")
        # add the two nav panels at x0
        nav1 = json.loads(json.dumps(CP1)); nav1["id"] = max([p.get("id", 0) for p in panels] + [0]) + 1
        nav1["gridPos"] = {"x": 0, "y": 0, "w": NAV_W, "h": 29}
        nav1["options"]["mode"] = "markdown"
        nav2 = json.loads(json.dumps(CP2)); nav2["id"] = nav1["id"] + 1
        nav2["gridPos"] = {"x": 0, "y": 29, "w": NAV_W, "h": 18}
        nav2["options"]["mode"] = "markdown"
        if dry:
            print(f"  + nav1 id={nav1['id']} x0 y0 w4 h29 ; nav2 id={nav2['id']} x0 y29 w4 h18")
            continue
        panels.append(nav1); panels.append(nav2)
        dash["version"] = ver + 1
        con.execute("UPDATE dashboard SET data=?, version=?, updated=datetime('now') WHERE id=?",
                    (json.dumps(dash), ver + 1, did))
        print(f"  reflowed + nav added: {uid}")
    if not dry:
        con.commit()
    con.close()


if __name__ == "__main__":
    main()
