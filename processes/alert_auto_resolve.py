"""Auto-resolve stale open alert incidents.

Scheduled process (metrics.registered_processes 'alert_auto_resolve', 5-minutely).
Delegates the whole decision to alerts.auto_resolve_incidents(), which reads the
per-severity timeout from alerts.alert_lifecycle_config and closes open incidents
that have not recurred within their window. Kept thin on purpose: the policy lives
in SQL so it is one place, and the customer's manual-resolve path shares the same
table/rules.
"""
import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def run_alert_auto_resolve():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("SELECT alerts.auto_resolve_incidents()")
        n = cur.fetchone()[0]
        if n:
            db_write_log(f"auto-resolved {n} stale alert incident(s)", 0,
                         "alert_auto_resolve", "")
        return 1
    except Exception as e:
        db_write_log(f"alert_auto_resolve failed: {e}", 0, "alert_auto_resolve", "")
        return 0
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
