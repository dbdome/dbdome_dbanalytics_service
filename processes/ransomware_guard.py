"""
ransomware_guard: detect ransomware behaviour in SQL Server active transactions and
alert + kill the offending session.

Reads the last ~10 min of SEC-SQL-ACC-011-RC02 active transactions (sql_text) and flags:
  RC01  mass in-place encryption  -- UPDATE + ENCRYPTBY* / large 0x blob
  RC02  modification velocity      -- a login issuing >= config.global_params
                                      'ransomware_mod_velocity' (default 50) modification
                                      statements in the window
  RC03  ransom-note artifacts      -- ransom keywords / readme-recover object names in sql_text

Per fresh hit (deduped per root-cause + server + session for 1h): raise an alert
(alerts.alert_log -> incident on Open Alerts + mail + SIEM) and kill the session
reusing processes.blocker -- gated by the global blocker_dry_run switch (default dry-run).
"""
import json
import re

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

SOURCE_ROOT_CAUSE_ID = "SEC-SQL-ACC-011-RC02"
RC_ENCRYPT  = "SEC-SQL-AUD-031-RC01"
RC_VELOCITY = "SEC-SQL-AUD-031-RC02"
RC_ARTIFACT = "SEC-SQL-AUD-031-RC03"
RC_EXFIL_DEL = "SEC-SQL-AUD-031-RC04"   # bulk export -> mass delete (double extortion)
RC_SYSCMD    = "SEC-SQL-AUD-031-RC05"   # system command / OLE automation
RISK = "critical"
_MON_USERS = ("dbdome_mon_usr", "dbd_mon_usr")

_UPDATE_RE   = re.compile(r"\bupdate\b", re.I)
_ENCRYPT_RE  = re.compile(r"(encryptby(key|passphrase|cert|asymkey)|0x[0-9a-f]{40,})", re.I)
_ARTIFACT_RE = re.compile(
    r"(your files.{0,20}encrypt|files? (are|have been) encrypted|how[_ ]?to[_ ]?decrypt|"
    r"decrypt.{0,20}(instruction|your files|to recover)|bitcoin|\.onion|\bransom|"
    r"recover.{0,15}files|restore.{0,15}files|readme.{0,20}(decrypt|recover)|"
    r"contact.{0,25}(decrypt|unlock|restore))", re.I)
_MODIFY_RE   = re.compile(r"\b(update|delete|truncate\s+table|drop\s+table)\b", re.I)
_SYSCMD_RE   = re.compile(
    r"(xp_cmdshell|sp_oacreate|sp_oamethod|sp_oageterrorinfo|xp_dirtree|xp_fileexist|"
    r"sp_execute_external_script|\bbulk\s+insert\b|openrowset\s*\(\s*bulk|xp_regwrite|xp_regread)", re.I)
_EXPORT_RE   = re.compile(r"(select\s+[^;]*\binto\b|\bbcp\b|openrowset|select\s+\*\s+from|for\s+xml\b)", re.I)
_MASSDEL_RE  = re.compile(r"(truncate\s+table|drop\s+table|delete\s+from\s+[\[\]\w\.]+\s*(;|--|$))", re.I)

# Read straight from general_metric_metadata_results so we can carry r.id through to
# alerts.alert_log.metric_result_row_id (jsonb_lower_keys mirrors get_root_cause_resultset).
_FEED_SQL = """
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
       result->>'sql_text'      AS sql_text,
       result                   AS result
FROM feed
WHERE result->>'session_id' IS NOT NULL
"""


def _dry_run(cur):
    cur.execute("SELECT value FROM config.global_params WHERE key='blocker_dry_run' "
                "ORDER BY row_id DESC LIMIT 1")
    r = cur.fetchone()
    if not r or r[0] is None:
        return True
    return str(r[0]).strip().lower() in ("true", "t", "1", "yes", "on")


def _velocity_threshold(cur):
    cur.execute("SELECT value FROM config.global_params WHERE key='ransomware_mod_velocity' "
                "ORDER BY row_id DESC LIMIT 1")
    r = cur.fetchone()
    try:
        return int(str(r[0]).strip()) if r and r[0] is not None else 50
    except (TypeError, ValueError):
        return 50


def _already_alerted(cur, rc, server, sid):
    cur.execute(
        "SELECT 1 FROM alerts.alert_log WHERE root_cause_id=%s AND server=%s "
        "AND metadata::text LIKE %s AND entry_date > now() - interval '1 hour' LIMIT 1",
        (rc, server, f'%"session_id": {sid}%'))
    return cur.fetchone() is not None


def _sid(v):
    try:
        return int(float(str(v).strip()))
    except (TypeError, ValueError):
        return None


def run_ransomware_guard():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        cur = conn.cursor()

        cur.execute(_FEED_SQL, (SOURCE_ROOT_CAUSE_ID,))
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, row)) for row in cur.fetchall()]
        if not rows:
            return
        dry_run = _dry_run(cur)
        vth = _velocity_threshold(cur)

        # (rc_id) -> list of matched transaction rows
        hits = []                       # (rc_id, row)
        modcount = {}                   # (server, login) -> count
        export_logins = set()           # (server, login) that did a bulk export
        massdel_logins = set()          # (server, login) that did a mass delete
        for m in rows:
            login = (m["login_name"] or "").strip()
            if login.lower() in _MON_USERS:
                continue
            text = m["sql_text"] or ""
            key = (m["server"], login)
            if _UPDATE_RE.search(text) and _ENCRYPT_RE.search(text):
                hits.append((RC_ENCRYPT, m))
            if _ARTIFACT_RE.search(text):
                hits.append((RC_ARTIFACT, m))
            if _SYSCMD_RE.search(text):
                hits.append((RC_SYSCMD, m))
            if _MODIFY_RE.search(text):
                modcount[key] = modcount.get(key, 0) + 1
            if _EXPORT_RE.search(text):
                export_logins.add(key)
            if _MASSDEL_RE.search(text):
                massdel_logins.add(key)

        # velocity: a login above the modification threshold -> flag its active sessions
        for (server, login), n in modcount.items():
            if n >= vth:
                for m in rows:
                    if m["server"] == server and (m["login_name"] or "").strip() == login:
                        hits.append((RC_VELOCITY, m))

        # double-extortion: same login both exported AND mass-deleted in the window
        for (server, login) in (export_logins & massdel_logins):
            for m in rows:
                if m["server"] == server and (m["login_name"] or "").strip() == login:
                    hits.append((RC_EXFIL_DEL, m))

        if not hits:
            return

        # rc -> {sid: rc}, server -> {sid: rc} for kill; also raise alert rows
        servers_hit = {}                # server -> {sid: rc_id}
        raised = set()                  # (rc, server, sid) to avoid dup in this run
        for rc, m in hits:
            server = m["server"]
            sid = _sid(m["session_id"])
            if sid is None or (rc, server, sid) in raised:
                continue
            if _already_alerted(cur, rc, server, sid):
                continue
            raised.add((rc, server, sid))
            meta = dict(m["result"]) if isinstance(m["result"], dict) else {}
            meta["session_id"] = sid
            cur.execute(
                "INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name, metric_result_row_id) "
                "VALUES (%s,%s,%s,%s::jsonb,%s,%s)",
                (server, rc, RISK, json.dumps([meta], default=str), m["login_name"], m.get("metric_result_row_id")))
            servers_hit.setdefault(server, {})[sid] = rc
            db_write_log(f"ransomware_guard {rc}: login={m['login_name']} session={sid} server={server}",
                         0, "run_ransomware_guard", server)

        if not servers_hit:
            return

        # mail + SIEM per (server, rc)
        try:
            from email_utils.smtp_email_sender import send_mail_alert_no_attachment
            from alerts.alert_dispatcher import dispatch
            from siem.generic.syslog_sender import siem_send_all
            seen_rc = {}
            for rc, m in hits:
                seen_rc.setdefault((m["server"], rc), m)
            for (server, rc), m in seen_rc.items():
                cur.execute("""SELECT domain_name, area_name, issue_name, root_cause_name, root_cause_desc,
                                      detection_name, detection_desc, step_name
                               FROM rootcause.v_rootcauses WHERE root_cause_id=%s AND vendor_name='sqlserver' LIMIT 1""", (rc,))
                fr = cur.fetchone() or ("Security", "AUD", "Ransomware Activity", rc, "", "", "", "")
                desc = f"area:{fr[1]}, domain:{fr[0]}, issue:{fr[2]}, root:{fr[3]}, login:{m['login_name']}"
                try:
                    send_mail_alert_no_attachment(server, fr[0], fr[1], fr[2], rc, fr[3], fr[4],
                                                  fr[5] or "ransomware_guard", fr[6] or desc,
                                                  fr[7] or "ransomware_guard", RISK, desc)
                except Exception as me:
                    db_write_log(f"ransomware_guard mail failed: {me}", 0, "run_ransomware_guard", server)
                try:
                    dispatch(siem_send_all, label=f"siem_generic:{rc}", event_type=rc, severity=RISK,
                             server=server, root_cause_id=rc, description=desc)
                except Exception:
                    pass
        except Exception as e:
            db_write_log(f"ransomware_guard alert dispatch failed: {e}", 0, "run_ransomware_guard", "")

        # kill sessions (dry-run by default) -- reuse the blocker kill path
        from processes.blocker import _kill_mssql, _blog
        from utils.secrets_crypto import decrypt_secret
        for server, sidmap in servers_hit.items():
            cur.execute("SELECT db_vendor, port, database, username, password "
                        "FROM metrics.servers WHERE server=%s AND is_active=true "
                        "AND lower(db_vendor) IN ('mssql','sqlserver') LIMIT 1", (server,))
            srow = cur.fetchone()
            if not srow:
                _blog(cur, server, None, RC_VELOCITY, None, "skipped", "no active mssql registration")
                continue
            vendor, port, database, username, password = srow
            try:
                pwd = decrypt_secret(password)
            except Exception:
                pwd = password
            _kill_mssql(cur, server, port, database, username, pwd, sidmap, dry_run)
    except Exception as e:
        db_write_log(f"ransomware_guard failed: {e}", 0, "run_ransomware_guard", "")
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
