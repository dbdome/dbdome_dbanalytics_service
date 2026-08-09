#!/usr/bin/env python3
"""Add the Login Authorisation Guard entry point to the Grafana Configuration dashboard.

The /login_authorizations page and its API ship in the service, but nothing in the UI
pointed at them - so the feature was unreachable for anyone who did not already know the
URL. This adds an action panel to the Configuration dashboard, matching the existing
"Mail Configuration Actions" / "Risk Level Actions" panels exactly: same html text-panel
shape, same button styling, same ?sender= round-trip so the page can link back.

Idempotent: keyed on a marker in the panel content, so a re-run replaces rather than
stacks. Grafana MUST be stopped - it holds grafana.db open and caches dashboards, so a
live write can be lost.

Usage:
    python tools/add_login_auth_config_link.py            # dry run
    python tools/add_login_auth_config_link.py --apply
    python tools/add_login_auth_config_link.py --apply path/to/grafana.db
"""

import datetime
import json
import os
import shutil
import sqlite3
import sys

MARKER = "<!--dbdome-login-auth-link-->"
PANEL_TITLE = "Login Authorisation Actions"

# The Configuration dashboards to stamp. dbdome-configuration is the product's config
# screen; adnz9dq is the older Security-folder one that carries the same mail actions.
TARGET_UIDS = ("dbdome-configuration", "adnz9dq")

DEFAULT_DB = os.getenv(
    "GRAFANA_DB",
    r"C:\ProgramData\DBDOME\data\grafana.db" if os.name == "nt"
    else "/var/lib/grafana/grafana.db",
)


def panel_content(uid):
    """Same markup as the neighbouring action panels: an html text panel with a label and
    a button. ${global_ip} is the existing hidden dashboard variable, so the link works
    from any host without hard-coding an address."""
    sender = f"/d/{uid}/configuration"
    return (
        MARKER
        + '<div style="display:flex;gap:12px;align-items:center;padding:8px;">'
        + '<span style="font-weight:600;color:#d8d9da;">Login authorisation:</span>'
        + f'<a href="https://${{global_ip}}:8080/login_authorizations?sender={sender}" '
        + 'style="background:#5794f2;color:#fff;padding:8px 16px;border-radius:4px;'
        + 'text-decoration:none;font-size:13px;">Configure Login Authorisations</a>'
        + '<span style="color:#9aa0a6;font-size:12px;">Which statements each login may '
        + 'run &mdash; unauthorised use raises SEC-SQL-AUD-011-RC06 (critical)</span>'
        + '</div>'
    )


def find_slot(panels):
    """Place the panel directly under the existing action row rather than at the bottom.

    The left nav rail starts at a known y; dropping the panel below everything would put
    it under a 29-row rail where nobody looks. Sitting it immediately beneath the other
    *Actions* panels is where an operator already goes for configuration buttons.
    """
    actions = [p for p in panels
               if isinstance(p.get("title"), str) and p["title"].endswith("Actions")]
    if actions:
        anchor = max(actions, key=lambda p: p.get("gridPos", {}).get("y", 0))
        g = anchor["gridPos"]
        return {"x": g.get("x", 0), "y": g.get("y", 0) + g.get("h", 3),
                "w": g.get("w", 24), "h": 3}
    bottom = max((p.get("gridPos", {}).get("y", 0) + p.get("gridPos", {}).get("h", 0)
                  for p in panels), default=0)
    return {"x": 0, "y": bottom, "w": 24, "h": 3}


def upsert_panel(dash, uid):
    """Returns True if the dashboard changed."""
    panels = dash.setdefault("panels", [])
    content = panel_content(uid)

    for p in panels:
        if MARKER in ((p.get("options") or {}).get("content") or ""):
            if p["options"]["content"] == content and p.get("title") == PANEL_TITLE:
                return False                       # already current
            p["options"]["content"] = content
            p["title"] = PANEL_TITLE
            p["options"]["mode"] = "html"
            return True

    used = {p.get("id") for p in panels if isinstance(p.get("id"), int)}
    panels.append({
        "id": (max(used) + 1) if used else 1,
        "type": "text",
        "title": PANEL_TITLE,
        "gridPos": find_slot(panels),
        "options": {"mode": "html", "content": content},
        "pluginVersion": "12.2.0",
        "transparent": True,
    })
    return True


def main(argv):
    apply = "--apply" in argv
    args = [a for a in argv if not a.startswith("--")]
    db = args[0] if args else DEFAULT_DB
    if not os.path.isfile(db):
        sys.exit(f"grafana.db not found: {db}")

    if apply:
        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = f"{db}.bak.{stamp}"
        shutil.copy2(db, backup)
        print(f"backup: {backup}")

    con = sqlite3.connect(db)
    changed = 0
    for uid in TARGET_UIDS:
        row = con.execute(
            "SELECT id, title, version, data FROM dashboard WHERE uid=? AND is_folder=0",
            (uid,)).fetchone()
        if not row:
            print(f"  SKIP {uid}: not present")
            continue
        did, title, ver, data = row
        dash = json.loads(data)
        if not upsert_panel(dash, uid):
            print(f"  ok   {title!r} ({uid}) already current")
            continue
        changed += 1
        print(f"  {'PATCH' if apply else 'would patch'} {title!r} ({uid})")
        if apply:
            con.execute(
                "UPDATE dashboard SET data=?, version=?, updated=? WHERE id=?",
                (json.dumps(dash), (ver or 0) + 1,
                 datetime.datetime.now(datetime.timezone.utc)
                         .strftime("%Y-%m-%d %H:%M:%S"), did))
    if apply:
        con.commit()
    con.close()
    print(f"\n{'applied' if apply else 'DRY RUN'}: {changed} dashboard(s) changed")
    if not apply:
        print("re-run with --apply to write (stop the Grafana service first)")


if __name__ == "__main__":
    main(sys.argv[1:])
