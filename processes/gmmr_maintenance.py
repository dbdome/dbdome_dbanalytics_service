"""
Scheduled maintenance for monitoring.general_metric_metadata_results.

Calls monitoring.gmmr_maintain(), which:
  * creates upcoming monthly partitions,
  * drops partitions past the retention window,
  * collapses duplicate snapshots (keeps the newest row per
    server + metric_name + identical metric_metadata).

Registered as the 'gmmr_maintain' process (metrics.registered_processes) so the
scheduler runs it on an interval.
"""
import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# Session advisory lock so two maintains can never run concurrently — a second
# concurrent gmmr_maintain doubles the I/O load and has twice starved the whole
# DB (2026-07-11/12 incidents). Distinct from sql_script_runner's 727274.
_ADVISORY_LOCK_KEY = 727275


def run_gmmr_maintain():
    conn = None
    try:
        # keepalives: if this client dies mid-run (service restart), Postgres
        # notices within ~1 min and aborts the server-side run instead of
        # leaving an orphaned gmmr_maintain() grinding for hours.
        conn = psycopg2.connect(
            get_connection_string(),
            keepalives=1, keepalives_idle=30,
            keepalives_interval=10, keepalives_count=3,
        )
        conn.autocommit = True          # the function does DDL (partition create/drop)
        with conn.cursor() as cur:
            cur.execute("SELECT pg_try_advisory_lock(%s)", (_ADVISORY_LOCK_KEY,))
            if not cur.fetchone()[0]:
                db_write_log("gmmr_maintain skipped: previous run still active",
                             0, "run_gmmr_maintain", "")
                return
            # Hard cap below the hourly cadence so a runaway maintain is killed
            # server-side instead of piling up behind the next tick.
            cur.execute("SET statement_timeout = '45min'")
            cur.execute("SELECT monitoring.gmmr_maintain()")
        db_write_log("gmmr_maintain completed (partitions + dedup)", 0, "run_gmmr_maintain", "")
    except Exception as e:
        db_write_log(f"gmmr_maintain failed: {e}", 0, "run_gmmr_maintain", "")
    finally:
        if conn is not None:
            try:
                conn.close()   # releases the advisory lock with the session
            except Exception:
                pass
