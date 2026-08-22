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


def fetch_security_agent_verdict(alert_id):
    """The security agent's verdict for alerts.alert_log.row_id `alert_id`.

    Returns a dict of the columns monitoring.get_security_agent_byid() exposes,
    or None when the alert was never triaged, the function is absent (the
    install predates sql_scripts/7630), or the lookup fails.

    Never raises: a mail must still go out if the verdict cannot be read. The
    agent is an annotation on the alert, not the alert itself.
    """
    if not alert_id:
        return None
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT verdict, confidence, decided_by, reason, indicators, "
                "       matched_precedent, exact_matches, distinct_shapes, "
                "       candidates_searched, retrieval_method, model, "
                "       elapsed_ms, triaged "
                "FROM monitoring.get_security_agent_byid(%s)",
                (int(alert_id),),
            )
            row = cur.fetchone()
            cols = [d[0] for d in cur.description]
            cur.close()
        finally:
            conn.close()
        if not row:
            return None
        v = dict(zip(cols, row))
        # triaged=False means the alert predates the agent, or it was disabled
        # or unavailable - there is nothing to show, which is different from a
        # verdict of "nothing found".
        return v if v.get("triaged") else None
    except Exception as e:
        db_write_log(f"fetch_security_agent_verdict({alert_id}) failed: {e}", 0,
                     "fetch_security_agent_verdict", "")
        return None
