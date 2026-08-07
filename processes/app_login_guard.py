"""
app_login_guard: alert + kill sessions on a WATCHED program that are NOT run by a
WHITELISTED applicative login.

Per scheduler tick:
  1. No-op unless enforcement is enabled: the whitelist (metrics.app_logins where
     white=true) and watched-program list (metrics.programs) are both non-empty AND
     the Security/critical 'blocker' switch is ON in config.webook_alerts.
  2. Read the last ~10 min of SEC-SQL-ACC-011-RC02 active transactions
     (monitoring.get_root_cause_resultset) and find rows where program_name matches
     a programs pattern for that server AND login_name is NOT in the app_logins
     whitelist (white=true) for that server (case-insensitive SQL LIKE; server
     '%'/blank = all servers).
  3. For each fresh match (deduped per server+session for 1h): raise an alert
     (alerts.alert_log -> incident on the Open Alerts dashboard, plus mail + SIEM
     via the standard pipeline) under root cause SEC-SQL-ACC-030-RC01.
  4. Kill the offending session (session_id on that server) reusing processes.blocker
     -- gated by the global blocker_dry_run switch (default: dry-run, log only).
"""
import json

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

ROOT_CAUSE_ID = "SEC-SQL-ACC-030-RC01"          # the alert we raise
SOURCE_ROOT_CAUSE_ID = "SEC-SQL-ACC-011-RC02"   # the active-transactions feed we read

# Read the active-transactions feed straight from general_metric_metadata_results
# (rather than monitoring.get_root_cause_resultset) so we can carry r.id through to
# alerts.alert_log.metric_result_row_id. jsonb_lower_keys mirrors the function's
# key-normalisation; server is taken from the gmmr row.
_MATCH_SQL = """
WITH feed AS (
    SELECT r.id AS metric_result_row_id,
           (monitoring.jsonb_lower_keys(elem) || jsonb_build_object('server', r.server)) AS result
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) elem
    WHERE r.metric_name = %s AND r.entry_date > now() - interval '10 minutes'
)
SELECT metric_result_row_id,
       result->>'server'        AS server,
       result->>'login_name'    AS login_name,
       result->>'program_name'  AS program_name,
       result->>'session_id'    AS session_id,
       result->>'database_name' AS database_name,
       result                   AS result
FROM feed
WHERE result->>'session_id' IS NOT NULL
  -- login_name is NOT one of the whitelisted (white=true) applicative logins
  AND NOT EXISTS (SELECT 1 FROM metrics.app_logins a
                  WHERE a.is_active AND a.white IS TRUE
                    AND (a.server IS NULL OR a.server IN ('', '%%')
                         OR COALESCE(feed.result->>'server','') ILIKE a.server)
                    AND COALESCE(feed.result->>'login_name','') ILIKE a.applicative_login)
  AND EXISTS (SELECT 1 FROM metrics.programs p
              WHERE p.is_active
                AND (p.server IS NULL OR p.server IN ('', '%%')
                     OR COALESCE(feed.result->>'server','') ILIKE p.server)
                AND COALESCE(feed.result->>'program_name','') ILIKE p.program_name)
"""


def _dry_run(cur):
    cur.execute("SELECT value FROM config.global_params WHERE key='blocker_dry_run' "
                "ORDER BY row_id DESC LIMIT 1")
    r = cur.fetchone()
    if not r or r[0] is None:
        return True
    return str(r[0]).strip().lower() in ("true", "t", "1", "yes", "on")


def _security_critical_blocker_on(cur):
    """The SEC-SQL-ACC-030 guard only fires when the Security / critical 'blocker'
    switch is enabled in config.webook_alerts. risk_level is fixed-width CHAR
    (padded), so btrim before comparing; match case-insensitively."""
    cur.execute("""SELECT 1 FROM config.webook_alerts
                   WHERE lower(btrim(metric_type)) = 'security'
                     AND lower(btrim(risk_level))  = 'critical'
                     AND blocker IS TRUE
                     AND is_active IS TRUE
                   LIMIT 1""")
    return cur.fetchone() is not None


def _already_alerted(cur, server, sid):
    """Dedup: this (server, session) already alerted within the last hour?"""
    cur.execute(
        "SELECT 1 FROM alerts.alert_log WHERE root_cause_id=%s AND server=%s "
        "AND metadata::text LIKE %s AND entry_date > now() - interval '1 hour' LIMIT 1",
        (ROOT_CAUSE_ID, server, f'%"session_id": {sid}%'))
    return cur.fetchone() is not None


def run_app_login_guard():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute("SELECT (SELECT count(*) FROM metrics.app_logins WHERE is_active AND white IS TRUE), "
                    "       (SELECT count(*) FROM metrics.programs   WHERE is_active)")
        n_whitelist, n_progs = cur.fetchone()
        if not n_whitelist or not n_progs:
            return  # no whitelist and/or no watched programs -> nothing to enforce

        # Gate: only enforce when the Security/critical 'blocker' is enabled in
        # config.webook_alerts (turned off -> raise no SEC-SQL-ACC-030-RC01, no kill).
        if not _security_critical_blocker_on(cur):
            return

        cur.execute(_MATCH_SQL, (SOURCE_ROOT_CAUSE_ID,))
        cols = [d[0] for d in cur.description]
        matches = [dict(zip(cols, row)) for row in cur.fetchall()]
        if not matches:
            return

        dry_run = _dry_run(cur)

        # root-cause fields for the mail (query once)
        cur.execute("""SELECT domain_name, area_name, issue_name, root_cause_name, root_cause_desc,
                              detection_name, detection_desc, step_name
                       FROM rootcause.v_rootcauses
                       WHERE root_cause_id=%s AND vendor_name='sqlserver' LIMIT 1""", (ROOT_CAUSE_ID,))
        rc = cur.fetchone() or ("Security", "Access Control", "Applicative Login From Watched Program",
                                "Applicative login used from a watched program", "", "", "", "")

        servers_hit = {}   # server -> {sid: ROOT_CAUSE_ID} for the kill step
        for m in matches:
            server = m["server"]
            # session_id may come through as '101' or '101.0'
            sid_raw = str(m["session_id"]).strip()
            try:
                sid = int(float(sid_raw))
            except (TypeError, ValueError):
                continue
            if _already_alerted(cur, server, sid):
                continue
            # 1) alert -> alert_log (fires the incident on the Open Alerts dashboard)
            meta = dict(m["result"]) if isinstance(m["result"], dict) else {}
            meta["session_id"] = sid   # normalise for dedup matching
            cur.execute(
                "INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name, metric_result_row_id) "
                "VALUES (%s,%s,'high',%s::jsonb,%s,%s)",
                (server, ROOT_CAUSE_ID, json.dumps([meta], default=str), m["login_name"], m.get("metric_result_row_id")))
            servers_hit.setdefault(server, {})[sid] = ROOT_CAUSE_ID
            db_write_log(f"app_login_guard: non-whitelisted login={m['login_name']} on watched program={m['program_name']} "
                         f"session={sid} server={server}", 0, "run_app_login_guard", server)

        if not servers_hit:
            return

        # 2) mail + SIEM per server (both have their own dedup / gate)
        try:
            from email_utils.smtp_email_sender import send_mail_alert_no_attachment
            from alerts.alert_dispatcher import dispatch
            from siem.generic.syslog_sender import siem_send_all
            for server, sidmap in servers_hit.items():
                desc = (f"area:{rc[1]}, domain:{rc[0]}, issue:{rc[2]}, root:{rc[3]}, "
                        f"sessions:{sorted(sidmap)}")
                try:
                    send_mail_alert_no_attachment(server, rc[0], rc[1], rc[2], ROOT_CAUSE_ID, rc[3],
                                                  rc[4], rc[5] or "app_login_guard", rc[6] or desc,
                                                  rc[7] or "app_login_guard", "high", desc)
                except Exception as me:
                    db_write_log(f"app_login_guard mail failed: {me}", 0, "run_app_login_guard", server)
                try:
                    dispatch(siem_send_all, label=f"siem_generic:{ROOT_CAUSE_ID}",
                             event_type=ROOT_CAUSE_ID, severity="high", server=server,
                             root_cause_id=ROOT_CAUSE_ID, description=desc)
                except Exception:
                    pass
        except Exception as e:
            db_write_log(f"app_login_guard alert dispatch import failed: {e}", 0, "run_app_login_guard", "")

        # 3) kill sessions (dry-run by default) -- reuse the blocker kill path
        from processes.blocker import _kill_mssql, _blog
        from utils.secrets_crypto import decrypt_secret
        for server, sidmap in servers_hit.items():
            # A host can have several registrations (pg/mysql/oracle/mssql); the
            # active transactions came from SQL Server, so pick the mssql one.
            cur.execute("SELECT db_vendor, port, database, username, password "
                        "FROM metrics.servers WHERE server=%s AND is_active=true "
                        "AND lower(db_vendor) IN ('mssql','sqlserver') LIMIT 1", (server,))
            srow = cur.fetchone()
            if not srow:
                _blog(cur, server, None, ROOT_CAUSE_ID, None, "skipped", "server not active/found")
                continue
            vendor, port, database, username, password = srow
            v = (vendor or "").strip().lower()
            if v in ("mssql", "sqlserver"):
                try:
                    pwd = decrypt_secret(password)
                except Exception:
                    pwd = password
                _kill_mssql(cur, server, port, database, username, pwd, sidmap, dry_run)
            else:
                for sid, rc_id in sidmap.items():
                    _blog(cur, server, vendor, rc_id, sid, "skipped",
                          f"vendor '{vendor}' not supported by app_login_guard")
    except Exception as e:
        db_write_log(f"app_login_guard failed: {e}", 0, "run_app_login_guard", "")
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
