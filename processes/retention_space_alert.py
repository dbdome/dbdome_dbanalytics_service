"""
Retention low-free-space alert.

Once a day, checks metrics.disk_free_pct() against the threshold in
config.global_params 'retention_free_space_alert_pct' (default 10). If free space
is below the threshold, emails the alert recipients (via the standard alert
pipeline, which handles recipients + the SMTP connection/circuit-breaker).

A 24h guard (alerts.mail_alert_log) ensures at most one mail per day even if the
scheduler runs the job more frequently.

Registered as the 'retention_space_alert' process (metrics.registered_processes).
"""
import socket

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_RC_ID = "RETENTION-DISK-LOW"


def run_retention_space_alert():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        with conn.cursor() as cur:
            # threshold
            cur.execute("SELECT value FROM config.global_params "
                        "WHERE key = 'retention_free_space_alert_pct' ORDER BY row_id DESC LIMIT 1")
            row = cur.fetchone()
            try:
                threshold = float(row[0]) if row and row[0] not in (None, "") else 10.0
            except (TypeError, ValueError):
                threshold = 10.0

            # current free %, free + total bytes
            cur.execute("SELECT metrics.disk_free_pct(), metrics.disk_free_bytes(), metrics.disk_total_bytes()")
            pct, free_b, total_b = cur.fetchone()

            if pct is None:
                db_write_log("retention_space_alert: disk metrics unavailable - skipping",
                             0, "run_retention_space_alert", "")
                return

            pct = float(pct)
            if pct >= threshold:
                db_write_log(f"retention_space_alert: free {pct}% >= {threshold}% (ok)",
                             0, "run_retention_space_alert", "")
                return

            # 24h guard: at most one disk alert per day
            cur.execute(
                "SELECT count(*) FROM alerts.mail_alert_log "
                "WHERE metric_name = %s AND entry_date > NOW() - INTERVAL '24 hours'",
                (_RC_ID,))
            if cur.fetchone()[0] > 0:
                db_write_log(f"retention_space_alert: free {pct}% < {threshold}% but already alerted in last 24h",
                             0, "run_retention_space_alert", "")
                return

        host = socket.gethostname()
        free_gb = round((free_b or 0) / 1073741824.0, 1)
        total_gb = round((total_b or 0) / 1073741824.0, 1)
        desc = (f"Free disk space is {pct}% (threshold {threshold}%). "
                f"{free_gb} GB free of {total_gb} GB on the data disk.")

        # Send via the standard alert pipeline (recipients + SMTP reuse/backoff).
        from email_utils.smtp_email_sender import send_mail_alert_no_attachment
        send_mail_alert_no_attachment(
            server=host,
            domain_name="Retention",
            area_name="Disk Capacity",
            issue_name="Low free disk space",
            root_cause_id=_RC_ID,
            root_cause_name="Free disk space below threshold",
            root_cause_desc=desc,
            detection_name="Disk free-space check",
            detection_desc="metrics.disk_free_pct()",
            step_name="retention_space_alert",
            risk_level="critical",
            query=None,
        )
        db_write_log(f"retention_space_alert: free {pct}% < {threshold}% -> alert emailed",
                     0, "run_retention_space_alert", host)
    except Exception as e:
        db_write_log(f"retention_space_alert failed: {e}", 0, "run_retention_space_alert", "")
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
