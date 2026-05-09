#!/usr/bin/env python3
"""Smoke-test the /api/print-panel endpoint end-to-end.

Picks the first table-type panel in a dashboard (or one you specify),
builds the same URL Grafana would build at click-time using each
dashboard variable's current value, GETs the endpoint, and verifies
the response is a non-trivial PDF. Saves the result so you can open it.

Usage:
    # auto-discover the first table panel in the first dashboard that has one
    python tools/test_print_panel.py

    # target a specific dashboard / panel
    python tools/test_print_panel.py --dashboard ad7kkx7 --panel 2

    # against a non-default service / grafana.db
    python tools/test_print_panel.py \\
        --base-url http://181.214.214.4:8080 \\
        --grafana-db /var/lib/grafana/grafana.db

Exit code 0 = success, non-zero = failure (with diagnostic on stderr).
"""

import argparse
import json
import os
import sqlite3
import sys
import urllib.parse
import urllib.request


def _default_grafana_db():
    if os.name == "nt":
        return r"C:\ProgramData\DBDOME\data\grafana.db"
    return "/var/lib/grafana/grafana.db"


def _walk_panels(panels):
    for p in panels or []:
        yield p
        for sub in p.get("panels", []):
            yield sub


def _pick_table_panel(db_path, dashboard_uid=None, panel_id=None):
    """Return (uid, panel_id, panel_title, var_pairs) for a chosen test target.

    var_pairs is a list of (name, value) pulled from each variable's
    current.value (Grafana's idea of "what's selected right now"); falls
    back to empty string when missing.
    """
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    if dashboard_uid:
        cur.execute(
            "SELECT uid, title, data FROM dashboard WHERE uid = ?",
            (dashboard_uid,),
        )
    else:
        cur.execute("SELECT uid, title, data FROM dashboard")
    dashboards = cur.fetchall()
    conn.close()

    for d in dashboards:
        try:
            dash = json.loads(d["data"])
        except (TypeError, ValueError):
            continue

        var_pairs = []
        for v in (dash.get("templating", {}).get("list") or []):
            name = v.get("name")
            if not name:
                continue
            current = v.get("current") or {}
            val = current.get("value")
            if isinstance(val, list):
                val = val[0] if val else ""
            var_pairs.append((name, str(val) if val is not None else ""))

        for panel in _walk_panels(dash.get("panels", [])):
            if panel.get("type") not in ("table", "table-old"):
                continue
            if panel_id is not None and panel.get("id") != int(panel_id):
                continue
            return d["uid"], panel.get("id"), panel.get("title", ""), var_pairs

    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://localhost:8080",
                    help="dbdome service base URL")
    ap.add_argument("--grafana-db", default=os.getenv("GRAFANA_DB", _default_grafana_db()),
                    help="path to grafana.db")
    ap.add_argument("--dashboard", help="dashboard uid (optional — auto-picks first table panel if omitted)")
    ap.add_argument("--panel", help="panel id (optional)")
    ap.add_argument("--out", default="/tmp/test_print_panel.pdf"
                    if os.name != "nt" else os.path.expandvars(r"%TEMP%\test_print_panel.pdf"),
                    help="where to save the returned PDF")
    args = ap.parse_args()

    if not os.path.exists(args.grafana_db):
        print(f"ERROR: grafana.db not found at {args.grafana_db}", file=sys.stderr)
        return 2

    pick = _pick_table_panel(args.grafana_db, args.dashboard, args.panel)
    if pick is None:
        print("ERROR: no table panel found matching the criteria", file=sys.stderr)
        return 3
    uid, pid, title, var_pairs = pick

    print(f"Testing dashboard={uid!r}  panel={pid}  title={title!r}")
    print(f"Variables: {var_pairs or '(none)'}")

    qs = [("dashboard", uid), ("panel", str(pid))] + var_pairs
    url = f"{args.base_url}/api/print-panel?" + urllib.parse.urlencode(qs)
    print(f"GET {url}")

    req = urllib.request.Request(url, headers={"Accept": "application/pdf"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            ctype = resp.headers.get("Content-Type", "")
            data = resp.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:500]
        print(f"FAIL: HTTP {e.code} from {url}\n{body}", file=sys.stderr)
        return 4
    except Exception as e:
        print(f"FAIL: request error: {e}", file=sys.stderr)
        return 4

    if "pdf" not in ctype.lower():
        print(f"FAIL: response Content-Type is {ctype!r} (expected application/pdf)",
              file=sys.stderr)
        # still save what we got, for inspection
        with open(args.out + ".raw", "wb") as f:
            f.write(data)
        return 5

    if len(data) < 1000 or not data.startswith(b"%PDF-"):
        print(f"FAIL: response is {len(data)} bytes and doesn't look like a PDF "
              f"(magic={data[:8]!r})", file=sys.stderr)
        return 6

    with open(args.out, "wb") as f:
        f.write(data)
    print(f"OK: {len(data):,} bytes saved to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
