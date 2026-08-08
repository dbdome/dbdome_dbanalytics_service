#!/usr/bin/env python3
"""Stamp the DBDOME version onto every Grafana dashboard.

Two edits per dashboard, both idempotent:

  1. a hidden query variable ``dbdome_version`` (refresh-on-load) that reads
     ``config.get_version_label()`` — modelled exactly on the existing
     ``global_ip`` / ``config.get_local_ip()`` variable already on 76 boards;
  2. a dedicated full-width 1-row text panel at the bottom showing
     ``$dbdome_version``.

Because the footer interpolates a variable rather than hard-coding a number,
this only has to run ONCE. Every later build just updates config.app_version
(7440) and all 102 dashboards pick the new number up on next load.

Placement is uniform: its own panel, every board. Appending to the existing
left nav rail was tried first and FAILED — the rail is 4 grid columns (~165px)
wide, so its dashboard links wrap to three or four lines each and the content
overflows the panel. The text panel scrolls and anything appended at the end is
below the fold, which left the version invisible on 101 of 102 boards.

Grafana MUST be stopped before applying: it holds grafana.db open and caches
dashboards, so a live write can be lost or half-applied.

Usage:
    python tools/add_version_footer_to_dashboards.py            # dry run
    python tools/add_version_footer_to_dashboards.py --apply
    python tools/add_version_footer_to_dashboards.py --apply path/to/grafana.db
"""

import collections
import datetime
import json
import os
import shutil
import sqlite3
import sys

VAR_NAME = "dbdome_version"
MARKER = "<!--dbdome-version-->"          # idempotency anchor inside the markdown
VERSION_QUERY = "SELECT config.get_version_label()"

DEFAULT_DB = os.getenv(
    "GRAFANA_DB",
    r"C:\ProgramData\DBDOME\data\grafana.db" if os.name == "nt"
    else "/var/lib/grafana/grafana.db",
)

# The datasource the dashboards already query (607 of ~660 panels).
DATASOURCE = {"type": "grafana-postgresql-datasource", "uid": "dezcmrkd94em8f"}

FOOTER = (
    MARKER + "\n\n---\n\n"
    "<div style=\"font-size:11px;color:#9aa0a6;\">$" + VAR_NAME + "</div>"
)


def version_variable():
    """Same shape as the existing global_ip variable: hidden (2), refresh on
    dashboard load (1). 'current' is left empty so Grafana fills it on first
    query rather than showing a stale cached build number."""
    return {
        "name": VAR_NAME,
        "label": "DBDOME version",
        "type": "query",
        "datasource": dict(DATASOURCE),
        "query": VERSION_QUERY,
        "current": {"text": "", "value": ""},
        "refresh": 1,
        "hide": 2,
    }


def ensure_variable(dash):
    """Add/refresh the hidden version variable. Returns True if changed."""
    templating = dash.setdefault("templating", {})
    lst = templating.setdefault("list", [])
    wanted = version_variable()
    for i, v in enumerate(lst):
        if v.get("name") == VAR_NAME:
            # keep whatever Grafana cached in 'current', refresh the rest
            wanted["current"] = v.get("current", wanted["current"])
            if v == wanted:
                return False
            lst[i] = wanted
            return True
    lst.append(wanted)
    return True


def _bottom(p):
    g = p.get("gridPos", {})
    return g.get("y", 0) + g.get("h", 0)


PAD_KEY = "dbdomeVersionPad"        # rows this tool added to a panel's height
OWN_KEY = "dbdomeVersionPanel"      # marks a footer panel this tool created


def _is_footer_only(panel):
    """Is this panel nothing but a version footer we created?

    Cannot rely on OWN_KEY alone: Grafana runs its dashboard schema migration on
    load and re-saves, which normalises gridPos and DROPS unknown panel keys
    (observed on 'Alerts' - tag gone, y shifted 34 -> 35). Falling back to the
    structural test keeps re-runs from stranding an empty panel and appending a
    second one next to it."""
    if panel.get(OWN_KEY):
        return True
    if panel.get("type") != "text":
        return False
    content = (panel.get("options") or {}).get("content") or ""
    if MARKER not in content:
        return False
    return content.split(MARKER)[0].strip() == ""


def clear_existing_footer(panels):
    """Undo any footer this tool placed before, wherever it went.

    Placement rules change (they did: the first pass put the footer in header
    panels); re-running must be able to MOVE a footer, not just refresh it in
    the wrong place. So every pass strips first, then places fresh. Panels this
    tool created are dropped; panels it only appended to are restored to their
    original height via the pad it recorded."""
    changed = False
    for p in list(panels):
        if _is_footer_only(p):
            panels.remove(p)
            changed = True
            continue
        opts = p.get("options") or {}
        content = opts.get("content") or ""
        if MARKER not in content:
            continue
        opts["content"] = content.split(MARKER)[0].rstrip()
        # pad may be gone if Grafana re-saved the board; leaving two spare rows
        # on a nav rail is invisible, so absence is not worth guessing about
        pad = p.pop(PAD_KEY, 0)
        if pad:
            g = p.setdefault("gridPos", {})
            g["h"] = max(1, g.get("h", 1) - pad)
        changed = True
    return changed


def new_footer_panel(panels):
    """Full-width one-row text panel below everything already on the board."""
    bottom = max(
        (p.get("gridPos", {}).get("y", 0) + p.get("gridPos", {}).get("h", 0)
         for p in panels),
        default=0)
    used_ids = {p.get("id") for p in panels if isinstance(p.get("id"), int)}
    return {
        "type": "text",
        "title": "",
        "id": (max(used_ids) + 1) if used_ids else 1,
        "gridPos": {"x": 0, "y": bottom, "w": 24, "h": 1},
        "transparent": True,
        "options": {"mode": "markdown", "content": FOOTER},
        "fieldConfig": {"defaults": {}, "overrides": []},
        OWN_KEY: True,
    }


def apply_footer(dash):
    """Strip any previous footer, then give the board its own footer panel.

    Appending the footer to the existing left nav rail was tried and does not
    work: the rail is 4 grid columns (~165px) wide, so each of its ~14 dashboard
    links wraps to three or four lines. The content runs roughly 900px inside a
    ~584px panel, the text panel scrolls, and anything appended at the end sits
    below the fold - invisible on 101 of 102 boards. The only one that rendered
    was the board that happened to get its own panel.

    A dedicated full-width row at the bottom is always laid out, never scrolls,
    and is identical everywhere. Returns (changed, where)."""
    panels = dash.setdefault("panels", [])
    before = json.dumps(panels, sort_keys=True)

    clear_existing_footer(panels)
    panels.append(new_footer_panel(panels))

    return json.dumps(panels, sort_keys=True) != before, "own panel"


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
    rows = con.execute(
        "SELECT id, uid, title, version, data FROM dashboard WHERE is_folder=0"
    ).fetchall()

    stats = collections.Counter()
    changed = unchanged = failed = 0

    for did, uid, title, ver, data in rows:
        try:
            dash = json.loads(data)
        except Exception as e:                       # noqa: BLE001
            print(f"  SKIP {title!r}: unreadable JSON ({e})")
            failed += 1
            continue

        var_changed = ensure_variable(dash)
        foot_changed, where = apply_footer(dash)
        if not (var_changed or foot_changed):
            unchanged += 1
            continue

        stats[where] += 1
        changed += 1
        print(f"  {'PATCH' if apply else 'would patch'} {title!r:52} footer->{where}")
        if apply:
            con.execute(
                "UPDATE dashboard SET data=?, version=?, updated=? WHERE id=?",
                (json.dumps(dash), (ver or 0) + 1,
                 datetime.datetime.now(datetime.timezone.utc)
                         .strftime("%Y-%m-%d %H:%M:%S"), did))

    if apply:
        con.commit()
    con.close()

    print(f"\n{'applied' if apply else 'DRY RUN'}: {changed} changed, "
          f"{unchanged} already current, {failed} unreadable, {len(rows)} total")
    print("   footer placement: " + (", ".join(f"{k}={v}" for k, v in stats.items()) or "-"))
    if not apply:
        print("\nre-run with --apply to write (stop the Grafana service first)")


if __name__ == "__main__":
    main(sys.argv[1:])
