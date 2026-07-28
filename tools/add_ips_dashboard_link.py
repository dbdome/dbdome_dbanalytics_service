#!/usr/bin/env python3
"""Add an "IPS Dashboard" link to every panel named "Dashboards" in every
Grafana dashboard stored in grafana.db.

Handles three panel types:
  - text   : injects an HTML <a> link into the panel content
  - links  : appends an entry to panel.options.links
  - any    : appends an entry to panel.links (panel-level link)

Idempotent: skips panels that already contain the link URL.

Usage:
    python tools/add_ips_dashboard_link.py [path/to/grafana.db]

Environment overrides:
    GRAFANA_DB      — path to grafana.db when no positional arg given
    DBDOME_BASE_URL — base URL of the dbdome service
                      (default: http://localhost:8080)
"""

import json
import os
import sqlite3
import sys

LINK_TITLE   = "IPS Dashboard"
LINK_PATH    = "/siem/ips-dashboard"
# Exact panel title (matched case-insensitively after strip)
PANEL_TITLE  = "dbdome - dashboards"

DBDOME_BASE  = os.getenv("DBDOME_BASE_URL", "http://localhost:8080")
LINK_URL     = DBDOME_BASE.rstrip("/") + LINK_PATH
# Markdown line inserted into the Grafana text-panel content
MARKDOWN_LINK = f"- [{LINK_TITLE}]({LINK_URL})"


def _default_grafana_db():
    if os.name == "nt":
        dev_path = r"c:\dev\dbdome\data\grafana.db"
        if os.path.exists(dev_path):
            return dev_path
        return r"C:\ProgramData\DBDOME\data\grafana.db"
    return "/var/lib/grafana/grafana.db"


def _walk_panels(panels):
    for panel in panels or []:
        yield panel
        for sub in panel.get("panels", []):
            yield sub


def _already_has_link(panel, url):
    """Return True if any existing link in this panel already points to url."""
    for link in panel.get("links") or []:
        if url in (link.get("url") or ""):
            return True
    opts_links = (panel.get("options") or {}).get("links") or []
    for link in opts_links:
        if url in (link.get("url") or ""):
            return True
    content = (panel.get("options") or {}).get("content") or panel.get("content") or ""
    if url in content:
        return True
    return False


def _add_link_to_text_panel(panel, url, title):
    """Inject a Markdown link line into a Grafana text panel's content."""
    # Grafana 9+: options.content; older: panel.content
    opts = panel.setdefault("options", {})
    key  = "content"
    src  = opts.get(key) or panel.get(key) or ""

    md_link = f"- [{title}]({url})"

    # Append inside the **Other** section if present, else at end
    if "\n**Other**" in src:
        # Insert as first item under **Other**
        new_src = src.replace("\n**Other**\n", f"\n**Other**\n{md_link}\n", 1)
    elif src.strip():
        new_src = src.rstrip() + "\n" + md_link
    else:
        new_src = md_link

    opts[key] = new_src
    if key in panel:
        panel[key] = new_src


def _add_panel_link(panel, url, title):
    """Add a panel-level link (panel.links array)."""
    links = panel.setdefault("links", [])
    links.append({
        "title":       title,
        "url":         url,
        "targetBlank": True,
    })


def _add_options_link(panel, url, title):
    """Add to panel.options.links (used by some panel types)."""
    opts  = panel.setdefault("options", {})
    links = opts.setdefault("links", [])
    links.append({
        "title":       title,
        "url":         url,
        "targetBlank": True,
    })


def main(db_path):
    if not os.path.exists(db_path):
        print(f"ERROR: grafana.db not found at {db_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Opening {db_path}")
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT id, uid, title, data, version FROM dashboard")
    dashboards = cur.fetchall()
    print(f"Scanning {len(dashboards)} dashboard(s)…\n")

    updated = 0
    patched = 0

    for d in dashboards:
        try:
            dash = json.loads(d["data"])
        except (TypeError, ValueError):
            continue

        modified = False
        for panel in _walk_panels(dash.get("panels", [])):
            if (panel.get("title") or "").strip().lower() != PANEL_TITLE:
                continue

            if _already_has_link(panel, LINK_URL):
                print(f"  [=] {d['title']} / \"{panel['title']}\" — already has link, skipping")
                continue

            ptype = panel.get("type", "")
            if ptype == "text":
                _add_link_to_text_panel(panel, LINK_URL, LINK_TITLE)
                print(f"  [+] {d['title']} / \"{panel['title']}\" (text) — injected HTML link")
            else:
                # For stat, table, timeseries, etc. — use panel-level links
                _add_panel_link(panel, LINK_URL, LINK_TITLE)
                print(f"  [+] {d['title']} / \"{panel['title']}\" ({ptype}) — added panel link")

            modified = True
            patched += 1

        if modified:
            version = d["version"] + 1
            cur.execute(
                "UPDATE dashboard SET data=?, version=?, updated=datetime('now') WHERE id=?",
                (json.dumps(dash), version, d["id"]),
            )
            updated += 1

    conn.commit()
    conn.close()

    if patched == 0:
        print(
            f'\nNo panels with title "{PANEL_TITLE}" found.\n'
            "Either the panel title differs — edit PANEL_TITLE in this script —\n"
            "or no dashboard has a 'Dashboards' panel yet."
        )
    else:
        print(
            f"\nDone — added IPS Dashboard link to {patched} panel(s) across "
            f"{updated} dashboard(s).\n"
            "Refresh the Grafana page (Ctrl+F5) to see the updated panel."
        )


if __name__ == "__main__":
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        path = os.getenv("GRAFANA_DB", _default_grafana_db())
    main(path)
