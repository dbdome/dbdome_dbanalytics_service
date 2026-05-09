"""
GRC Firewall Scanner (Phase 1)

Runs as a scheduled job every 60 seconds.
Reads recent active sessions and SQL injection events from the monitoring DB,
evaluates each row through the firewall policy engine, and writes results
to log.firewall_audit_log.

Designed as a non-invasive scanner — does not touch the collection pipeline.
All collector data is already in the DB; this job audits it after the fact.
"""

import psycopg2
from datetime import datetime, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from processes.firewall_policy_engine import evaluate_query

# Only evaluate rows newer than this many seconds on each run
_LOOKBACK_SECONDS = 70


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _scan_active_sessions(conn, since: datetime):
    """Evaluate recent active sessions captured by all vendor collectors."""
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT  s.server_name,
                    s.vendor,
                    s.db_user,
                    s.client_ip,
                    s.db_name,
                    s.sql_text,
                    s.session_id,
                    s.collected_at
            FROM    monitoring.v_recent_active_sessions s
            WHERE   s.collected_at >= %s
            """,
            (since,),
        )
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            server_name, vendor, db_user, client_ip, db_name, \
                sql_text, session_id, _ = row

            result = evaluate_query(
                server_name=server_name or "",
                vendor=vendor or "",
                db_user=db_user or "",
                client_ip=client_ip or "",
                db_name=db_name or "",
                sql_statement=sql_text or "",
                session_id=str(session_id) if session_id else None,
            )

            if result["action"] in ("BLOCK", "ALERT"):
                db_write_log(
                    f"GRC firewall [{result['action']}] user={db_user} "
                    f"server={server_name} policy='{result['policy_name']}' "
                    f"regulation={result['regulation']} risk={result['risk_score']}",
                    result["risk_score"],
                    "grc_firewall_scanner",
                    server_name or "",
                )

    except psycopg2.errors.UndefinedTable:
        pass  # view not yet created — schema migration not run
    except Exception as e:
        db_write_log(f"_scan_active_sessions error: {e}", 0, "grc_firewall_scanner", "")


def _scan_sql_injection_events(conn, since: datetime):
    """Evaluate SQL injection events already flagged by the collection pipeline."""
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT  mr.server_name,
                    mr.vendor,
                    mr.db_user,
                    mr.client_ip,
                    mr.db_name,
                    mr.sql_text,
                    mr.collected_at
            FROM    monitoring.v_recent_sql_injection mr
            WHERE   mr.collected_at >= %s
            """,
            (since,),
        )
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            server_name, vendor, db_user, client_ip, db_name, sql_text, _ = row

            evaluate_query(
                server_name=server_name or "",
                vendor=vendor or "",
                db_user=db_user or "",
                client_ip=client_ip or "",
                db_name=db_name or "",
                sql_statement=sql_text or "",
            )

    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"_scan_sql_injection_events error: {e}", 0, "grc_firewall_scanner", "")


def _scan_privileged_logins(conn, since: datetime):
    """Evaluate recent privileged login events."""
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT  server_name,
                    vendor,
                    db_user,
                    client_ip,
                    db_name,
                    role_name,
                    collected_at
            FROM    monitoring.v_recent_privileged_logins
            WHERE   collected_at >= %s
            """,
            (since,),
        )
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            server_name, vendor, db_user, client_ip, db_name, role_name, _ = row

            evaluate_query(
                server_name=server_name or "",
                vendor=vendor or "",
                db_user=db_user or "",
                client_ip=client_ip or "",
                db_name=db_name or "",
                sql_statement="",
                roles=[role_name] if role_name else [],
            )

    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"_scan_privileged_logins error: {e}", 0, "grc_firewall_scanner", "")


def run_grc_firewall_scan():
    """Entry point registered with APScheduler. Runs every 60 seconds."""
    since = datetime.utcnow() - timedelta(seconds=_LOOKBACK_SECONDS)
    try:
        conn = _get_conn()
        try:
            _scan_active_sessions(conn, since)
            _scan_sql_injection_events(conn, since)
            _scan_privileged_logins(conn, since)
        finally:
            conn.close()
    except Exception as e:
        db_write_log(f"run_grc_firewall_scan failed: {e}", 0, "grc_firewall_scanner", "")
