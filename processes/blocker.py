"""
Blocker: kill the running session behind a root cause when its webook_alert rule
has blocker = true.

Flow (per scheduler tick):
  1. read the global safety switch config.global_params 'blocker_dry_run'
     (default 'true' = log only, do not kill);
  2. for every config.webook_alerts row with blocker=true AND is_active=true,
     find recent (last 10 min) detection results for root causes matching that
     rule's (metric_type -> domain, risk_level);
  3. extract the offending session id(s) from each result's metric_metadata;
  4. on the target server, VERIFY the session is a user session with an OPEN
     transaction, then KILL it (unless dry-run); log every action to
     alerts.blocker_log.

Safety: two gates (per-rule blocker=true AND blocker_dry_run='false'); only user
sessions (SQL Server spid > 50) with an open transaction are killed; recent kills
are de-duped; every decision is audited. SQL Server is supported; other vendors
are logged as unsupported (no kill).
"""
import os
import json

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_SESSION_KEYS = ("session_id", "spid", "pid", "sid", "process_id")


def _truthy(v):
    return str(v).strip().lower() in ("true", "t", "1", "yes", "on")


def _extract_sessions(meta):
    """From a metric_metadata value, yield dicts {sid, schema, table, column} for
    each element that carries a session id (and, where present, the accessed
    sensitive column)."""
    out = []
    data = meta
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except Exception:
            return out
    rows = data if isinstance(data, list) else ([data] if isinstance(data, dict) else [])
    for r in rows:
        if not isinstance(r, dict):
            continue
        sid = None
        for k in _SESSION_KEYS:
            if r.get(k) is not None:
                try:
                    sid = int(str(r[k]).strip())
                    break
                except (TypeError, ValueError):
                    pass
        if sid is None:
            continue
        out.append({
            "sid": sid,
            "schema": (str(r.get("schema_name") or "")).strip().lower(),
            "table":  (str(r.get("table_name")  or "")).strip().lower(),
            "column": (str(r.get("column_name") or "")).strip().lower(),
        })
    return out


def _blog(cur, server, vendor, rc_id, sid, action, detail):
    try:
        cur.execute(
            "INSERT INTO alerts.blocker_log (server, db_vendor, root_cause_id, session_id, action, detail) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            (server, vendor, rc_id, str(sid) if sid is not None else None, action, detail))
    except Exception:
        pass


def _record_block(cur, server, rc, sid):
    """One row per executed block in alerts.blocks (same shape as mail_alert_log)."""
    try:
        cur.execute(
            "INSERT INTO alerts.blocks (server, transaction_type, metric_name, body, subject, metric_metadata_json) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            (server, "blocker_kill", str(rc),
             f"Killed session {sid} for root cause {rc} on {server}",
             f"Blocker: session {sid} killed on {server}",
             json.dumps({"session_id": sid, "root_cause_id": rc, "action": "kill"})))
    except Exception:
        pass


def _recently_killed(cur, server, sid):
    cur.execute(
        "SELECT 1 FROM alerts.blocker_log WHERE server=%s AND session_id=%s "
        "AND action='killed' AND entry_date > now() - interval '2 minutes' LIMIT 1",
        (server, str(sid)))
    return cur.fetchone() is not None


def _mssql_connect(server, port, database, username, password):
    import pyodbc
    drivers = pyodbc.drivers()
    drv = next((d for d in ("ODBC Driver 18 for SQL Server",
                            "ODBC Driver 17 for SQL Server", "SQL Server") if d in drivers), None)
    if not drv:
        raise RuntimeError("no suitable ODBC driver")
    server_str = f"{server},{port}" if port else server
    enc = os.environ.get("DBEXPERT_MSSQL_ENCRYPT", "yes")
    cs = (f"DRIVER={{{drv}}};SERVER={server_str};DATABASE={database or 'master'};"
          f"UID={username};PWD={password};Encrypt={enc};TrustServerCertificate=yes;Connection Timeout=10;")
    c = pyodbc.connect(cs, timeout=10)
    c.autocommit = True   # KILL must run outside a transaction
    return c


def _kill_mssql(pgcur, server, port, database, username, password, sid_to_rc, dry_run):
    try:
        tc = _mssql_connect(server, port, database, username, password)
    except Exception as e:
        for sid, rc in sid_to_rc.items():
            _blog(pgcur, server, "mssql", rc, sid, "error", f"connect failed: {str(e)[:200]}")
        return
    try:
        tcur = tc.cursor()
        for sid, rc in sid_to_rc.items():
            try:
                isid = int(sid)
            except (TypeError, ValueError):
                _blog(pgcur, server, "mssql", rc, sid, "skipped", "non-numeric session id")
                continue
            if isid <= 50:
                _blog(pgcur, server, "mssql", rc, sid, "skipped", "system spid (<=50)")
                continue
            if _recently_killed(pgcur, server, sid):
                _blog(pgcur, server, "mssql", rc, sid, "skipped", "already killed in last 2 min")
                continue
            # verify: user session with an open transaction
            tcur.execute(
                "SELECT s.is_user_process, "
                "(SELECT COUNT(*) FROM sys.dm_tran_session_transactions st WHERE st.session_id=s.session_id) "
                "FROM sys.dm_exec_sessions s WHERE s.session_id = ?", isid)
            row = tcur.fetchone()
            if not row or not row[0] or (row[1] or 0) == 0:
                _blog(pgcur, server, "mssql", rc, sid, "not-running",
                      "no active user transaction for this session")
                continue
            if dry_run:
                _blog(pgcur, server, "mssql", rc, sid, "dry-run",
                      f"would KILL {isid} (rule root cause {rc})")
                continue
            try:
                tcur.execute(f"KILL {isid}")
                _blog(pgcur, server, "mssql", rc, sid, "killed", f"KILL {isid} for root cause {rc}")
                _record_block(pgcur, server, rc, isid)   # row in alerts.blocks
                db_write_log(f"blocker: killed session {isid} on {server} (root cause {rc})",
                             0, "run_blocker", server)
            except Exception as e:
                _blog(pgcur, server, "mssql", rc, sid, "error", f"KILL failed: {str(e)[:200]}")
    finally:
        try:
            tc.close()
        except Exception:
            pass


def run_blocker():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute("SELECT value FROM config.global_params WHERE key='blocker_dry_run' "
                    "ORDER BY row_id DESC LIMIT 1")
        r = cur.fetchone()
        dry_run = True if (not r or r[0] is None) else _truthy(r[0])

        cur.execute("SELECT metric_type, trim(risk_level) FROM config.webook_alerts "
                    "WHERE blocker = true AND is_active = true")
        rules = cur.fetchall()
        if not rules:
            return

        # server -> { session_id : {"rc": root_cause_id, "cols": {(schema,table,column)}} }
        targets = {}
        for metric_type, risk_level in rules:
            cur.execute(
                """SELECT g.server, g.metric_name, g.metric_metadata
                   FROM monitoring.general_metric_metadata_results g
                   JOIN (SELECT DISTINCT root_cause_id, domain_name, risk_level
                         FROM rootcause.v_rootcauses) rc ON rc.root_cause_id = g.metric_name
                   WHERE lower(rc.domain_name) = lower(%s)
                     AND lower(trim(rc.risk_level)) = lower(%s)
                     AND g.entry_date > now() - interval '10 minutes'
                     AND g.metric_metadata::text ILIKE '%%session%%'""",
                (metric_type, risk_level))
            for server, rc_id, meta in cur.fetchall():
                for s in _extract_sessions(meta):
                    info = targets.setdefault(server, {}).setdefault(s["sid"], {"rc": rc_id, "cols": set()})
                    if s["table"] and s["column"]:
                        info["cols"].add((s["schema"], s["table"], s["column"]))

        if not targets:
            return

        # feed metrics.sensitive_columns: when the curated list has entries, only
        # kill sessions that are touching a tracked column (server + schema/table/column).
        cur.execute("SELECT lower(coalesce(server,'')), lower(coalesce(schema_name,'')), "
                    "lower(coalesce(table_name,'')), lower(coalesce(column_name,'')) "
                    "FROM metrics.sensitive_columns")
        sens = {}
        for sv, sc, tb, col in cur.fetchall():
            sens.setdefault(sv, set()).add((sc, tb, col))
        have_list = any(sens.values())

        def _tracked(server, cols):
            sset = sens.get(server.lower(), set()) | sens.get("", set())
            for (sc, tb, col) in cols:
                if (sc, tb, col) in sset or ("", tb, col) in sset:
                    return True
            return False

        for server, sid_map in targets.items():
            # apply the sensitive-column gate
            keep = {}
            for sid, info in sid_map.items():
                if have_list and not _tracked(server, info["cols"]):
                    _blog(cur, server, None, info["rc"], sid, "skipped",
                          "accessed column not in metrics.sensitive_columns")
                    continue
                keep[sid] = info["rc"]
            if not keep:
                continue

            cur.execute("SELECT db_vendor, port, database, username, password "
                        "FROM metrics.servers WHERE server=%s AND is_active=true LIMIT 1", (server,))
            srow = cur.fetchone()
            if not srow:
                _blog(cur, server, None, None, None, "skipped", "server not active/found in metrics.servers")
                continue
            vendor, port, database, username, password = srow
            v = (vendor or "").strip().lower()
            if v in ("mssql", "sqlserver"):
                _kill_mssql(cur, server, port, database, username, password, keep, dry_run)
            else:
                for sid, rc in keep.items():
                    _blog(cur, server, vendor, rc, sid, "skipped", f"vendor '{vendor}' not yet supported by blocker")
    except Exception as e:
        db_write_log(f"blocker failed: {e}", 0, "run_blocker", "")
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
