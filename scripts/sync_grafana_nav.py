#!/usr/bin/env python3
r"""
Sync the "dbdome - Dashboards" navigation panel across every Grafana dashboard.

Grafana stores each dashboard as JSON in grafana.db (SQLite). Each dashboard has
a text panel titled "dbdome - Dashboards" whose markdown is the shared nav menu.
When a new dashboard is added (or one is hand-edited), its nav can drift. This
tool copies one canonical nav into all of them so the menu stays identical.

Canonical source:
  * default: the nav content that the most dashboards already share (majority);
  * or pass --source-uid <uid> to use a specific dashboard's nav as the source.

It only rewrites dashboards whose nav differs (version bumped only on change), so
re-running when everything is in sync is a no-op.

The dashboard table is locked while Grafana runs, so by default this stops the
DBDOME_Grafana service, edits, then restarts it. Use --no-service to skip that
(you must stop Grafana yourself first).

Usage:
    python scripts/sync_grafana_nav.py
    python scripts/sync_grafana_nav.py --source-uid ad7kkx7
    python scripts/sync_grafana_nav.py --db "C:\ProgramData\DBDOME\data\grafana.db"
    python scripts/sync_grafana_nav.py --no-service        # Grafana already stopped
    python scripts/sync_grafana_nav.py --dry-run           # report only
"""
import argparse
import json
import os
import subprocess
import sys
import time
from collections import Counter

try:
    import sqlite3
except ImportError:  # pragma: no cover
    sys.exit("sqlite3 module unavailable")

DEFAULT_DB = r"C:\ProgramData\DBDOME\data\grafana.db"
SERVICE = "DBDOME_Grafana"
NAV_TITLE = "dbdome - dashboards"          # matched case-insensitively


def nav_panel(dash):
    for p in dash.get("panels", []):
        if p.get("type") == "text" and (p.get("title") or "").strip().lower() == NAV_TITLE:
            return p
    return None


def _svc(action):
    subprocess.run(["sc.exe", action, SERVICE], capture_output=True, text=True)


def _svc_status():
    r = subprocess.run(["sc.exe", "query", SERVICE], capture_output=True, text=True)
    return "RUNNING" if "RUNNING" in r.stdout else ("STOPPED" if "STOPPED" in r.stdout else "?")


def stop_service(db_path):
    _svc("stop")
    for _ in range(25):
        if _svc_status() == "STOPPED":
            break
        time.sleep(1)
    # clear the read-only attribute Windows sometimes leaves on the db file
    try:
        os.chmod(db_path, 0o666)
    except OSError:
        pass


def start_service():
    _svc("start")


def sync(db_path, source_uid=None, dry_run=False):
    con = sqlite3.connect(db_path)
    rows = con.execute("SELECT uid, slug, data, version FROM dashboard WHERE is_folder=0").fetchall()

    parsed, counts, source_content = {}, Counter(), None
    for uid, slug, data, ver in rows:
        try:
            d = json.loads(data)
        except Exception:
            continue
        parsed[uid] = (slug, d, ver)
        p = nav_panel(d)
        if p is not None:
            content = (p.get("options", {}) or {}).get("content", "")
            counts[content] += 1
            if source_uid and uid == source_uid:
                source_content = content

    if not counts:
        con.close()
        print("no 'dbdome - Dashboards' nav panels found")
        return 0

    if source_uid:
        if source_content is None:
            con.close()
            sys.exit(f"--source-uid {source_uid} has no nav panel")
        canonical = source_content
        print(f"canonical nav: from dashboard {source_uid} (len {len(canonical)})")
    else:
        canonical, n = counts.most_common(1)[0]
        print(f"canonical nav: majority of {n} dashboards (len {len(canonical)})")

    changed = []
    for uid, (slug, d, ver) in parsed.items():
        p = nav_panel(d)
        if p is None:
            continue
        if (p.get("options", {}) or {}).get("content", "") != canonical:
            changed.append(slug)
            if not dry_run:
                p.setdefault("options", {})["content"] = canonical
                d["version"] = ver + 1
                con.execute(
                    "UPDATE dashboard SET data=?, version=?, updated=datetime('now') WHERE uid=?",
                    (json.dumps(d), ver + 1, uid))
    if not dry_run:
        con.commit()
    con.close()

    verb = "would update" if dry_run else "updated"
    print(f"{verb} {len(changed)} dashboard(s): {changed}" if changed
          else "all nav panels already in sync")
    return len(changed)


def main():
    ap = argparse.ArgumentParser(description="Sync the dbdome nav panel across all Grafana dashboards.")
    ap.add_argument("--db", default=DEFAULT_DB, help=f"path to grafana.db (default {DEFAULT_DB})")
    ap.add_argument("--source-uid", default=None, help="use this dashboard's nav as canonical (default: majority)")
    ap.add_argument("--no-service", action="store_true", help="do not stop/start DBDOME_Grafana (already stopped)")
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    args = ap.parse_args()

    if not os.path.isfile(args.db):
        sys.exit(f"grafana.db not found: {args.db}")

    manage = not args.no_service and not args.dry_run
    if manage:
        print(f"stopping {SERVICE} ...")
        stop_service(args.db)
    try:
        changed = sync(args.db, source_uid=args.source_uid, dry_run=args.dry_run)
    finally:
        if manage:
            print(f"starting {SERVICE} ...")
            start_service()
    sys.exit(0 if changed >= 0 else 1)


if __name__ == "__main__":
    main()
