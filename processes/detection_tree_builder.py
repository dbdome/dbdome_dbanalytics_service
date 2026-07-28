"""
Detection Tree Builder

Queries the rootcause taxonomy to discover detection paths and steps per vendor.
The tree structure itself is NOT pushed to the frontend (it builds from its
knowledge DB).  This module provides:

  - _fetch_tree_rows()   → raw DB rows for a vendor
  - fetch_detection_paths() → grouped detection paths ready for execution
  - _get_api_config()    → INGEST_URL / INGEST_API_KEY from config
"""

import json
import psycopg2
from collections import OrderedDict
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


ACTIVE_VENDORS = ["sqlserver", "oracle", "postgresql", "mysql", "mariadb"]

VENDOR_DISPLAY = {
    "sqlserver": "SQL Server",
    "oracle": "Oracle",
    "postgresql": "PostgreSQL",
    "mysql": "MySQL",
    "mariadb":"MariaDB"
}

# ---------------------------------------------------------------------------
# Tree query
# ---------------------------------------------------------------------------

TREE_SQL = """
SELECT
    d.code       AS domain_code,
    d.name       AS domain_name,
    a.code       AS area_code,
    a.name       AS area_name,
    i.issue_id,
    i.name       AS issue_name,
    rc.root_cause_id,
    rc.name      AS root_cause_name,
    rc.topics,
    rc.vendors_applicable,
    dp.id        AS detection_path_id,
    dps.id       AS path_step_id,
    dps.sequence,
    dps.on_match_action,
    dps.on_no_match_action,
    ds.id        AS detection_step_id,
    ds.step_type,
    ds.name      AS step_name,
    -- detection logic is encrypted at rest (7300_rootcause_content_encryption.sql);
    -- rootcause.dec() returns plaintext because the connection carries the session
    -- key (options=-c rootcause.k=... injected by get_connection_string). Plaintext
    -- rows pass through unchanged, so this is safe before and after the migration.
    rootcause.dec(ds.content)    AS content,
    rootcause.dec(ds.expected)   AS expected,
    rootcause.dec(ds.parameters) AS parameters
FROM rootcause.domains d
JOIN rootcause.issues i ON i.domain_code = d.code
JOIN rootcause.areas a ON a.code = i.area_code
JOIN rootcause.root_causes rc ON rc.issue_id = i.issue_id
JOIN rootcause.detection_paths dp
    ON dp.root_cause_id = rc.root_cause_id
    AND dp.vendor_slug = %s
    AND dp.is_active = true
JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
WHERE d.is_enabled = true AND a.is_enabled = true
ORDER BY d.code, a.code, i.issue_id, rc.root_cause_id, dps.sequence
"""


def _fetch_tree_rows(vendor_slug):
    """Fetch the full detection hierarchy for a vendor in one query."""
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute(TREE_SQL, (vendor_slug,))
        columns = [desc[0] for desc in cur.description]
        rows = [dict(zip(columns, row)) for row in cur.fetchall()]
        return rows
    finally:
        conn.close()


def _ensure_json(val):
    """Return a dict/list from a value that may be a JSON string or already parsed."""
    if val is None:
        return {}
    if isinstance(val, (dict, list)):
        return val
    if isinstance(val, str):
        try:
            return json.loads(val)
        except (json.JSONDecodeError, ValueError):
            return {}
    return {}


# ---------------------------------------------------------------------------
# Group rows into detection paths ready for execution
# ---------------------------------------------------------------------------

def fetch_detection_paths(vendor_slug):
    """
    Query the rootcause taxonomy and return a list of detection paths,
    each with its steps ordered by sequence.

    Returns list of dicts:
    [
        {
            "detection_path_id": 123,
            "root_cause_id": "SEC-SQL-AUTH-001-RC01",
            "root_cause_name": "...",
            "severity": "high",
            "steps": [
                {
                    "sequence": 1,
                    "sql": "SELECT ...",
                    "expected": {"condition": "row_count > 0"},
                    "on_match_action": "next",
                    "on_no_match_action": "ruled_out",
                },
                ...
            ]
        },
        ...
    ]
    """
    rows = _fetch_tree_rows(vendor_slug)
    if not rows:
        return []

    # Group by detection_path_id
    paths = OrderedDict()
    for r in rows:
        pid = r["detection_path_id"]
        if pid not in paths:
            paths[pid] = {
                "detection_path_id": pid,
                "root_cause_id": r["root_cause_id"],
                "root_cause_name": r["root_cause_name"],
                "steps": [],
            }

        content = _ensure_json(r["content"])
        expected = _ensure_json(r["expected"])

        parameters = _ensure_json(r.get("parameters"))

        paths[pid]["steps"].append({
            "sequence": r["sequence"],
            "sql": content.get("sql", ""),
            "expected": expected,
            "parameters": parameters,
            "on_match_action": r["on_match_action"],
            "on_no_match_action": r["on_no_match_action"],
        })

    return list(paths.values())


# ---------------------------------------------------------------------------
# API config
# ---------------------------------------------------------------------------

def _get_api_config():
    """Fetch INGEST_API_KEY and INGEST_URL from config.global_params."""
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute("SELECT key, value FROM config.global_params WHERE key IN ('INGEST_API_KEY', 'INGEST_URL')")
        config = dict(cur.fetchall())
        return config.get("INGEST_URL"), config.get("INGEST_API_KEY")
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Public entry points (kept for scheduler compatibility)
# ---------------------------------------------------------------------------

def build_all_vendor_trees():
    """
    Pre-fetch and validate detection paths for all vendors.
    Logs counts — no longer pushes tree definition to API.
    """
    for vendor in ACTIVE_VENDORS:
        try:
            paths = fetch_detection_paths(vendor)
            total_steps = sum(len(p["steps"]) for p in paths)
            db_write_log(
                f"Detection paths for {vendor}: {len(paths)} paths, {total_steps} steps",
                0, "detection_tree_builder", ""
            )
        except Exception as e:
            db_write_log(f"Failed to fetch paths for {vendor}: {e}", 0, "detection_tree_builder", "")



