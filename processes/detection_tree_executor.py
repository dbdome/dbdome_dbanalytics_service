"""
Detection Tree Executor

Executes detection paths per vendor/server and posts results to
POST /detection-trees/{vendor_slug}/executions

Data contract: detection-trees-data-contract.md
"""

import json
import re
import psycopg2
import requests
from datetime import datetime, timezone
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from alerts.metrics_api_sender import send_results, server_upsert
from processes.vendor_connection import get_target_connection
from processes.detection_tree_builder import (
    fetch_detection_paths, _get_api_config, ACTIVE_VENDORS
)

# ---------------------------------------------------------------------------
# Condition evaluation
# ---------------------------------------------------------------------------

_CONDITION_RE = re.compile(
    r"^\s*row_count\s*([><=!]+)\s*(\d+)\s*$", re.IGNORECASE
)


def evaluate_condition(expected, row_count):
    """Evaluate the expected condition against actual row count."""
    if not expected:
        return row_count > 0

    condition = expected.get("condition", "")
    m = _CONDITION_RE.match(condition)
    if m:
        op, val = m.group(1), int(m.group(2))
        match op:
            case ">":  return row_count > val
            case ">=": return row_count >= val
            case "<":  return row_count < val
            case "<=": return row_count <= val
            case "=" | "==": return row_count == val
            case "!=" | "<>": return row_count != val

    return row_count > 0


def _safe_serialize(val):
    """Convert a DB value to something JSON-safe."""
    if val is None:
        return None
    if isinstance(val, str):
        # Strip null bytes — PostgreSQL text/jsonb cannot store \x00
        return val.replace('\x00', '')
    if isinstance(val, (int, float, bool)):
        return val
    if isinstance(val, (datetime,)):
        return val.isoformat()
    if isinstance(val, bytes):
        return val.hex()
    return str(val).replace('\x00', '')


# ---------------------------------------------------------------------------
# Step execution
# ---------------------------------------------------------------------------

def _substitute_parameters(sql, parameters):
    """Replace :param_name placeholders with literal values from parameters dict."""
    if not parameters or not isinstance(parameters, dict):
        return sql
    for key, value in parameters.items():
        if isinstance(value, str):
            sql = sql.replace(f":{key}", f"'{value}'")
        else:
            sql = sql.replace(f":{key}", str(value))
    return sql


def execute_step(sql, expected, target_conn, parameters=None):
    """
    Execute a single detection step's SQL query.
    Returns (status, matched, duration_ms, actual, error_message).
    """
    started_at = datetime.now(timezone.utc)

    if not sql:
        return "completed", False, 0, {"row_count": 0, "sample_rows": []}, None

    # Substitute :param placeholders with literal values
    sql = _substitute_parameters(sql, parameters)

    try:
        cursor = target_conn.cursor()
        # psycopg2 treats % as parameter placeholder — escape %% for literal LIKE patterns
        if type(target_conn).__module__.startswith('psycopg2') and '%' in sql:
            sql = sql.replace('%', '%%')
        cursor.execute(sql)

        try:
            rows = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description] if cursor.description else []
        except Exception:
            rows = []
            columns = []

        duration_ms = int((datetime.now(timezone.utc) - started_at).total_seconds() * 1000)
        row_count = len(rows)
        matched = evaluate_condition(expected, row_count)

        sample_rows = []
        for r in rows[:5]:
            sample_rows.append(dict(zip(columns, [_safe_serialize(v) for v in r])))

        cursor.close()

        actual = {"row_count": row_count, "sample_rows": sample_rows}
        return "completed", matched, duration_ms, actual, None

    except Exception as e:
        duration_ms = int((datetime.now(timezone.utc) - started_at).total_seconds() * 1000)
        return "failed", None, duration_ms, None, str(e)[:500]


# ---------------------------------------------------------------------------
# Path execution
# ---------------------------------------------------------------------------

def execute_path(path, target_conn):
    """
    Execute all steps in a detection path, following branching logic.

    Returns a path_result dict matching the data contract:
    {
        "detection_path_id": 123,
        "root_cause_id": "SEC-SQL-AUTH-001-RC01",
        "outcome": "confirmed" | "ruled_out" | "failed" | "skipped",
        "severity": "high" | None,
        "steps": [ { sequence, status, matched, duration_ms, actual, error_message }, ... ]
    }
    """
    steps_def = path["steps"]
    step_results = []
    outcome = "ruled_out"  # default if we run out of steps without a terminal action

    i = 0
    while i < len(steps_def):
        step = steps_def[i]
        seq = step["sequence"]

        status, matched, duration_ms, actual, error_msg = execute_step(
            step["sql"], step["expected"], target_conn, step.get("parameters")
        )

        step_results.append({
            "sequence": seq,
            "status": status,
            "matched": matched,
            "duration_ms": duration_ms,
            "actual": actual,
            "error_message": error_msg,
        })

        # If step failed, the whole path fails — mark remaining as skipped
        if status == "failed":
            outcome = "failed"
            for remaining in steps_def[i + 1:]:
                step_results.append({
                    "sequence": remaining["sequence"],
                    "status": "skipped",
                    "matched": None,
                    "duration_ms": None,
                    "actual": None,
                    "error_message": None,
                })
            break

        # Follow branching action
        action = step["on_match_action"] if matched else step["on_no_match_action"]

        if action == "confirmed":
            outcome = "confirmed"
            # Mark remaining steps as not_reached
            for remaining in steps_def[i + 1:]:
                step_results.append({
                    "sequence": remaining["sequence"],
                    "status": "not_reached",
                    "matched": None,
                    "duration_ms": None,
                    "actual": None,
                    "error_message": None,
                })
            break
        elif action == "ruled_out":
            outcome = "ruled_out"
            for remaining in steps_def[i + 1:]:
                step_results.append({
                    "sequence": remaining["sequence"],
                    "status": "not_reached",
                    "matched": None,
                    "duration_ms": None,
                    "actual": None,
                    "error_message": None,
                })
            break
        elif action == "next":
            i += 1
        else:
            # Unknown action — move to next step
            i += 1

    # If we exhausted all steps without a terminal action, last step determines outcome
    if outcome not in ("confirmed", "failed") and step_results:
        last = step_results[-1]
        if last["status"] == "completed" and last["matched"]:
            outcome = "confirmed"

    severity = None
    if outcome == "confirmed":
        # Try to get severity from the last matched step's expected config
        for s in reversed(steps_def):
            sev = s["expected"].get("severity") if s["expected"] else None
            if sev:
                severity = sev
                break
        if not severity:
            severity = "medium"

    return {
        "detection_path_id": path["detection_path_id"],
        "root_cause_id": path["root_cause_id"],
        "outcome": outcome,
        "severity": severity,
        "steps": step_results,
    }


# ---------------------------------------------------------------------------
# Results posting
# ---------------------------------------------------------------------------

def post_execution_to_api(ingest_url, api_key , vendor, server_id, execution_key, status,
                          started_at, completed_at, summary, path_results):
    """POST execution results to /detection-trees/{vendor}/executions."""
    if not ingest_url or not api_key:
        return None

    payload = {
        "server_id": str(server_id),
        "execution_key": execution_key,
        "status": status,
        "started_at": started_at.isoformat(),
        "completed_at": completed_at.isoformat(),
        "summary": summary,
        "path_results": path_results,
    }

    headers = {
        "accept": "application/json",
        "X-Ingest-API-Key": api_key,
        "Content-Type": "application/json",
    }

    try:
        resp = requests.post(
            f"{ingest_url}/detection-trees/{vendor}/executions",
            headers=headers,
            json=payload,
            timeout=120,
        )
        resp.raise_for_status()
        result = resp.json()
        accepted = result.get("accepted", False)
        db_write_log(
            f"Execution posted for {vendor}/{execution_key}: accepted={accepted}, "
            f"paths={summary.get('executed', 0)}",
            0, "detection_tree_executor", ""
        )
        return result
    except Exception as e:
        db_write_log(
            f"Failed to post execution for {vendor}/{execution_key}: {e}",
            0, "detection_tree_executor", ""
        )
        return None


def post_rc_outcomes_to_results_api(_api_url , _api_key , server_name, path_results,server_id):
    """Post each confirmed/ruled_out root cause via the existing send_results() API."""
    for pr in path_results:
        if pr["outcome"] not in ("confirmed", "ruled_out"):
            continue
        status = "finding" if pr["outcome"] == "confirmed" else "clear"
        try:
            send_results(
                _api_url , 
                _api_key ,
                server_id , 
                _server=server_name,
                _root_cause_id=pr["root_cause_id"],
                _status=status,
                _result_count=1 if status == "finding" else 0,
                _evidence=json.dumps({"outcome": pr["outcome"]}),
                _severity=pr.get("severity") or ("high" if status == "finding" else "low"),
                impact_score=1 if status == "finding" else 0,             
            )
        except Exception as e:
            db_write_log(
                f"Failed to post result for {pr['root_cause_id']}: {e}",
                0, "detection_tree_executor", ""
            )


# ---------------------------------------------------------------------------
# Server discovery
# ---------------------------------------------------------------------------

def _get_servers_for_vendor(vendor_slug):
    """Get all active servers for a vendor from metrics.servers and upsert each to the frontend API."""
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        vendor_map = {
            "sqlserver": ("SQL Server", "mssql", "sqlserver"),
            "oracle": ("Oracle", "oracle", "oracle-19c", "oracle-21c", "oracle-23ai"),
            "postgresql": ("PostgreSQL", "postgresql", "postgres"),
            "mysql": ("MySQL", "mysql"),
            "mariadb": ("MariaDB", "mariadb"),
        }
        vendors = vendor_map.get(vendor_slug, (vendor_slug,))
        placeholders = ",".join(["%s"] * len(vendors))
        cur.execute(
            f"""		SELECT o.api_url , o.api_key, server_id , server, database db_name, username, password, port, auth_type,
                       service_name, db_vendor, server_id
                FROM metrics.servers s
				join processes.organizations_servers  os on os.server_row_id = s.row_id				
				join processes.organization o on o.row_id = os.organization_id
                WHERE is_active = true AND LOWER(db_vendor) IN ({placeholders})""",
            tuple(v.lower() for v in vendors)
        )
        columns = [desc[0] for desc in cur.description]
        servers = [dict(zip(columns, row)) for row in cur.fetchall()]
    finally:
        conn.close()

    # Upsert each server to the frontend API so it's registered before posting results
    for srv in servers:
        try:
            server_upsert(
                _api_url =srv["api_url"], 
                _api_key =srv["api_key"],  
                _server=srv["server"],
                _server_id=srv.get("server_id"),
                _vendor_slug=vendor_slug,
                _port=srv.get("port"),
            )
        except Exception as e:
            db_write_log(
                f"Server upsert failed for {srv['server']}: {e}",
                0, "detection_tree_executor", srv["server"],
                port=srv.get("port")
            )

    return servers


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def execute_vendor_detection_allservers():
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute("select slug from rootcause.vendors")
        rows = cur.fetchall()
        for row in rows:
            slug      = row[0]
            execute_vendor_detection_tree(slug)

    except Exception as e:
            db_write_log(f"Failed to fetch paths for {slug}: {e}", 0, "execute_vendor_detection_allservers", slug)

    finally:
        conn.close()

    

    
def execute_vendor_detection_tree(vendor_slug):
    """
    Main entry: fetch detection paths, execute against every server
    of the matching vendor, post results per the data contract.
    """
    db_write_log(
        f"Starting detection tree execution for {vendor_slug}",
        0, "detection_tree_executor", ""
    )

    # Fetch detection paths from rootcause taxonomy
    paths = fetch_detection_paths(vendor_slug)
    if not paths:
        db_write_log(f"No detection paths for {vendor_slug}", 0, "detection_tree_executor", "")
        return

    total_steps = sum(len(p["steps"]) for p in paths)
    db_write_log(
        f"Loaded {len(paths)} detection paths ({total_steps} steps) for {vendor_slug}",
        0, "detection_tree_executor", ""
    )

    # Get target servers
    servers = _get_servers_for_vendor(vendor_slug)
    if not servers:
        db_write_log(f"No active servers for {vendor_slug}", 0, "detection_tree_executor", "")
        return

    db_write_log(
        f"Executing against {len(servers)} servers",
        0, "detection_tree_executor", ""
    )

    for srv in servers:
        server_name = srv["server"]
        server_port = srv.get("port", "")
        server_label = f"{server_name}:{server_port}" if server_port else server_name
        server_id = srv.get("server_id")
        api_url =srv.get("api_url") 
        api_key =srv.get("api_key")  

        try:
            started_at = datetime.now(timezone.utc)

            target_conn = get_target_connection(
                vendor=vendor_slug,
                server=srv["server"],
                database=srv.get("db_name", ""),
                username=srv.get("username", ""),
                password=srv.get("password", ""),
                port=srv.get("port", ""),
                auth_type=srv.get("auth_type", ""),
                service_name=srv.get("service_name"),
            )

            try:
                # Execute all detection paths
                path_results = []
                for path in paths:
                    pr = execute_path(path, target_conn)
                    path_results.append(pr)

                completed_at = datetime.now(timezone.utc)

                # Build summary
                confirmed = sum(1 for pr in path_results if pr["outcome"] == "confirmed")
                ruled_out = sum(1 for pr in path_results if pr["outcome"] == "ruled_out")
                failed = sum(1 for pr in path_results if pr["outcome"] == "failed")
                skipped = sum(1 for pr in path_results if pr["outcome"] == "skipped")
                executed = len(path_results) - skipped

                summary = {
                    "total_paths": len(path_results),
                    "executed": executed,
                    "skipped": skipped,
                    "confirmed": confirmed,
                    "ruled_out": ruled_out,
                    "failed": failed,
                }

                execution_key = (
                    f"detection-{vendor_slug}-{server_name}-"
                    f"{started_at.strftime('%Y%m%d-%H%M')}"
                )

                db_write_log(
                    f"Tree walk done for {server_label}: "
                    f"confirmed={confirmed}, ruled_out={ruled_out}, failed={failed}",
                    0, "detection_tree_executor", server_name, port=server_port
                )

                # Post execution to detection-trees API
                post_execution_to_api(
                    api_url , 
                    api_key,
                    vendor_slug, server_id, execution_key,
                    "completed", started_at, completed_at,
                    summary, path_results
                )

                # Post per-root-cause results via existing results API
                post_rc_outcomes_to_results_api(api_url , api_key , server_name, path_results,server_id)

            finally:
                target_conn.close()

        except Exception as e:
            db_write_log(
                f"Failed to execute tree for {server_label}: {e}",
                0, "detection_tree_executor", server_name, port=server_port
            )
