#!/usr/bin/env python3
"""Add a 'Print PDF' panel link to every table-type panel in every Grafana
dashboard.

The link points at the dbdome service's /api/print-panel endpoint and
includes the dashboard uid, panel id, and every dashboard variable as
${var} placeholders — Grafana substitutes these at click-time.

Run once after upgrading the dbdome service. Idempotent: skips panels
that already have a link with the same title.

Usage:
    python tools/add_print_links_to_panels.py [path/to/grafana.db]

Environment overrides:
    DBDOME_PRINT_URL  — base URL of the print endpoint
                        (default: http://localhost:8080/api/print-panel)
    GRAFANA_DB        — path to grafana.db when no positional arg given
                        (default: /var/lib/grafana/grafana.db on Linux,
                                 C:\\ProgramData\\DBDOME\\data\\grafana.db on Windows)
"""

import json
import os
import sqlite3
import sys

LINK_TITLE       = "Print PDF"
EMAIL_LINK_TITLE = "Email PDF"
DEFAULT_BASE_URL = os.getenv(
    "DBDOME_PRINT_URL",
    "http://localhost:8080/api/print-panel",
)
DEFAULT_EMAIL_URL = os.getenv(
    "DBDOME_EMAIL_URL",
    "http://localhost:8080/api/email-panel-form",
)


def _walk_panels(panels):
    """Yield every panel including those nested inside row containers."""
    for panel in panels or []:
        yield panel
        for sub in panel.get("panels", []):
            yield sub


def _build_link_url(base_url, dashboard_uid, panel_id, variable_names):
    parts = [
        f"{base_url}?dashboard={dashboard_uid}",
        f"panel={panel_id}",
    ]
    for v in variable_names:
        parts.append(f"{v}=${{{v}}}")
    return "&".join(parts)


def _default_grafana_db():
    if os.name == "nt":
        return r"C:\ProgramData\DBDOME\data\grafana.db"
    return "/var/lib/grafana/grafana.db"


def main(db_path):
    if not os.path.exists(db_path):
        print(f"ERROR: grafana.db not found at {db_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Opening {db_path}")
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute("SELECT id, uid, title, data FROM dashboard")
    dashboards = cur.fetchall()
    print(f"Scanning {len(dashboards)} dashboards…\n")

    updated_dashboards = 0
    inserted_panels = 0
    refreshed_panels = 0
    for d in dashboards:
        try:
            dash = json.loads(d["data"])
        except (TypeError, ValueError):
            continue

        var_names = [
            v.get("name")
            for v in (dash.get("templating", {}).get("list") or [])
            if v.get("name")
        ]

        modified = False
        for panel in _walk_panels(dash.get("panels", [])):
            if panel.get("type") not in ("table", "table-old"):
                continue
            existing = panel.setdefault("links", [])
            for link_title, base_url in (
                (LINK_TITLE,       DEFAULT_BASE_URL),
                (EMAIL_LINK_TITLE, DEFAULT_EMAIL_URL),
            ):
                expected_url = _build_link_url(
                    base_url, d["uid"], panel.get("id"), var_names
                )
                link = next(
                    (l for l in existing if l.get("title") == link_title),
                    None,
                )
                if link is None:
                    existing.append({
                        "title": link_title,
                        "url":   expected_url,
                        "targetBlank": True,
                    })
                    modified = True
                    inserted_panels += 1
                elif link.get("url") != expected_url:
                    link["url"] = expected_url
                    modified = True
                    refreshed_panels += 1

        if modified:
            cur.execute(
                "UPDATE dashboard "
                "   SET data = ?, version = version + 1, updated = datetime('now') "
                " WHERE id = ?",
                (json.dumps(dash), d["id"]),
            )
            updated_dashboards += 1
            print(f"[+] {d['title']}  ({d['uid']})")

    conn.commit()
    conn.close()
    print(
        f"\nDone — inserted {inserted_panels} new link(s), "
        f"refreshed {refreshed_panels} stale link(s) across "
        f"{updated_dashboards} dashboard(s).\n"
        f"Restart Grafana (or wait for cache to refresh) to see the "
        f"updated links on each table panel."
    )


if __name__ == "__main__":
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        path = os.getenv("GRAFANA_DB", _default_grafana_db())
    main(path)
