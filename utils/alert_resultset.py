"""
Canonical detection-result rows for one alert.

Mail and SIEM alert deliveries must show the SAME detection results the Grafana
alert-detail panel shows, i.e.:

    SELECT * FROM monitoring.get_alert_log_resultset_byid(<alert_log.row_id>)

That function normalises alerts.alert_log.metadata (array / wrapped string /
single object), lower-cases keys, merges server / servername / risk_level /
login_name and filters out the monitoring account — so rendering the raw
collector payload instead can disagree with the UI. Every alert sender goes
through here instead of re-implementing that logic.
"""
import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def fetch_alert_resultset(alert_id, max_rows=100):
    """Return the detection rows for alerts.alert_log.row_id `alert_id` as a
    list of dicts (one per resultset row, newest-normalised by the DB function).

    Never raises; returns [] when alert_id is falsy, the function yields no
    rows, or the lookup fails (callers fall back to the raw collector payload).
    """
    if not alert_id:
        return []
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT result FROM monitoring.get_alert_log_resultset_byid(%s) "
                "LIMIT %s",
                (int(alert_id), int(max_rows)),
            )
            rows = [r[0] for r in cur.fetchall() if r[0] is not None]
            cur.close()
        finally:
            conn.close()
        return rows
    except Exception as e:
        db_write_log(f"fetch_alert_resultset({alert_id}) failed: {e}", 0,
                     "fetch_alert_resultset", "")
        return []
