"""
GRC Phase 6: Automated Threat Response Engine

Runs every 60 seconds, scans the firewall audit log and user risk profiles
for threats, and executes responses defined in config.threat_response_playbooks.

Response types
──────────────
NOTIFY       → email security team via config.mail_config / SMTP
BLOCK_IP     → insert into config.blocked_ips (policy engine checks this)
SUSPEND_USER → insert into config.suspended_users (policy engine checks this)
ESCALATE     → create incident in log.security_incidents
WEBHOOK      → POST JSON payload to a webhook URL (Slack, PagerDuty, Teams…)

Deduplication
─────────────
Each playbook has a cooldown_mins. The engine checks log.threat_response_log
to skip subjects that were already actioned within the cooldown window.
"""

import json
import time
import socket
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# ── Blocked-entity cache (shared with policy engine) ─────────────────────────

_blocked_ip_cache: set = set()
_suspended_user_cache: set = set()   # (server_name.lower(), login_name.lower())
_entity_cache_loaded_at: float = 0.0
_ENTITY_CACHE_TTL = 30  # seconds


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _load_entity_cache():
    global _blocked_ip_cache, _suspended_user_cache, _entity_cache_loaded_at
    try:
        conn = _get_conn()
        cur  = conn.cursor()

        cur.execute(
            """SELECT ip_address::text FROM config.blocked_ips
               WHERE is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())"""
        )
        _blocked_ip_cache = {row[0] for row in cur.fetchall()}

        cur.execute(
            """SELECT server_name, login_name FROM config.suspended_users
               WHERE is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())"""
        )
        _suspended_user_cache = {(r[0].lower(), r[1].lower()) for r in cur.fetchall()}

        cur.close()
        conn.close()
        _entity_cache_loaded_at = time.time()
    except Exception as e:
        db_write_log(f"threat_response_engine: _load_entity_cache failed: {e}", 0, "threat_response_engine", "")


def get_blocked_ips() -> set:
    if time.time() - _entity_cache_loaded_at > _ENTITY_CACHE_TTL:
        _load_entity_cache()
    return _blocked_ip_cache


def is_user_suspended(server_name: str, login_name: str) -> bool:
    if time.time() - _entity_cache_loaded_at > _ENTITY_CACHE_TTL:
        _load_entity_cache()
    return (server_name.lower(), login_name.lower()) in _suspended_user_cache


def reload_entity_cache():
    global _entity_cache_loaded_at
    _entity_cache_loaded_at = 0.0
    _load_entity_cache()


# ── Playbook cache ────────────────────────────────────────────────────────────

_playbook_cache: list = []
_playbook_cache_loaded_at: float = 0.0
_PLAYBOOK_TTL = 120  # seconds


def _load_playbooks() -> list:
    global _playbook_cache, _playbook_cache_loaded_at
    try:
        conn = _get_conn()
        cur  = conn.cursor()
        cur.execute(
            """SELECT playbook_id, playbook_name, trigger_type, trigger_threshold,
                      trigger_regulation, trigger_severity, response_type, response_params, cooldown_mins
               FROM config.threat_response_playbooks
               WHERE is_active = TRUE
               ORDER BY playbook_id"""
        )
        cols = [d[0] for d in cur.description]
        _playbook_cache = [dict(zip(cols, row)) for row in cur.fetchall()]
        cur.close()
        conn.close()
        _playbook_cache_loaded_at = time.time()
    except Exception as e:
        db_write_log(f"threat_response_engine: _load_playbooks failed: {e}", 0, "threat_response_engine", "")
    return _playbook_cache


def _get_playbooks() -> list:
    if time.time() - _playbook_cache_loaded_at > _PLAYBOOK_TTL:
        _load_playbooks()
    return _playbook_cache


# ── Deduplication ────────────────────────────────────────────────────────────

def _in_cooldown(conn, playbook_id: int, subject: str, cooldown_mins: int) -> bool:
    cur = conn.cursor()
    try:
        cur.execute(
            """SELECT 1 FROM log.threat_response_log
               WHERE playbook_id = %s AND subject = %s
                 AND triggered_at >= NOW() - INTERVAL '%s minutes'
               LIMIT 1""",
            (playbook_id, subject, cooldown_mins),
        )
        return cur.fetchone() is not None
    finally:
        cur.close()


# ── Response executors ────────────────────────────────────────────────────────

def _exec_notify(conn, params: dict, subject: str, context: dict) -> str:
    """Send email via config.mail_config. Returns detail string."""
    try:
        from email_utils.smtp_email_sender import send_mail_with_attachment
        cur = conn.cursor()
        cur.execute(
            "SELECT smtp_server, smtp_port, smtp_user, smtp_password, tls, mail_sender "
            "FROM config.mail_config LIMIT 1"
        )
        row = cur.fetchone()
        cur.close()
        if not row:
            raise RuntimeError("No SMTP config found in config.mail_config")

        smtp_server, smtp_port, smtp_user, smtp_password, tls, mail_sender = row
        prefix   = params.get("subject_prefix", "[DBDOME-THREAT]")
        subject_line = f"{prefix} {subject}"
        recipients_raw = params.get("recipients", "")
        if not recipients_raw:
            cur2 = conn.cursor()
            cur2.execute("SELECT value FROM config.global_params WHERE key='security_email' LIMIT 1")
            r2 = cur2.fetchone()
            cur2.close()
            recipients_raw = r2[0] if r2 else ""
        if not recipients_raw:
            return "skipped: no recipients configured"

        recipients = [r.strip() for r in recipients_raw.split(",") if r.strip()]
        body = (
            f"DBDOME GRC Automated Threat Alert\n\n"
            f"Subject:  {subject}\n"
            f"Trigger:  {context.get('trigger_type','')}\n"
            f"Severity: {context.get('severity','')}\n"
            f"Server:   {context.get('server_name','')}\n"
            f"User:     {context.get('db_user','')}\n"
            f"IP:       {context.get('client_ip','')}\n"
            f"Detail:   {context.get('detail','')}\n\n"
            f"Logged at {datetime.now(timezone.utc).isoformat()}\n"
        )
        send_mail_with_attachment(
            smtp_server, smtp_port, smtp_user, smtp_password, tls,
            mail_sender, recipients, subject_line, body, attachment_path=None,
        )
        return f"notified {recipients}"
    except Exception as e:
        raise RuntimeError(f"NOTIFY failed: {e}")


def _exec_block_ip(conn, params: dict, client_ip: str, context: dict) -> str:
    if not client_ip:
        return "skipped: no IP in context"
    duration = params.get("duration_mins")
    reason   = params.get("reason", "Automated: threat response")
    cur = conn.cursor()
    try:
        expires = None
        if duration:
            expires = f"NOW() + INTERVAL '{int(duration)} minutes'"

        cur.execute(
            f"""INSERT INTO config.blocked_ips (ip_address, reason, blocked_by, expires_at)
                VALUES (%s, %s, 'threat_response', {expires if expires else 'NULL'})
                ON CONFLICT (ip_address) DO UPDATE
                  SET reason=EXCLUDED.reason, blocked_at=NOW(), is_active=TRUE,
                      expires_at={'EXCLUDED.expires_at' if expires else 'NULL'}""",
            (client_ip, reason),
        )
        conn.commit()
        reload_entity_cache()
        return f"IP {client_ip} blocked" + (f" for {duration} min" if duration else " permanently")
    finally:
        cur.close()


def _exec_suspend_user(conn, params: dict, server_name: str, login_name: str, context: dict) -> str:
    if not server_name or not login_name:
        return "skipped: no server/user in context"
    duration = params.get("duration_mins")
    reason   = params.get("reason", "Automated: threat response")
    cur = conn.cursor()
    try:
        expires = None
        if duration:
            expires = f"NOW() + INTERVAL '{int(duration)} minutes'"

        cur.execute(
            f"""INSERT INTO config.suspended_users (server_name, login_name, reason, suspended_by, expires_at)
                VALUES (%s, %s, %s, 'threat_response', {expires if expires else 'NULL'})
                ON CONFLICT (server_name, login_name) DO UPDATE
                  SET reason=EXCLUDED.reason, suspended_at=NOW(), is_active=TRUE,
                      expires_at={'EXCLUDED.expires_at' if expires else 'NULL'}""",
            (server_name, login_name, reason),
        )
        conn.commit()
        reload_entity_cache()
        return f"user {login_name}@{server_name} suspended" + (f" for {duration} min" if duration else " permanently")
    finally:
        cur.close()


def _exec_escalate(conn, params: dict, subject: str, context: dict) -> str:
    severity = params.get("severity", context.get("severity", "HIGH"))
    title    = f"[{severity}] {subject}"
    cur = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO log.security_incidents
                (title, severity, regulation, server_name, db_user, client_ip, description)
               VALUES (%s,%s,%s,%s,%s,%s,%s)
               RETURNING incident_id""",
            (
                title, severity,
                context.get("regulation"), context.get("server_name"),
                context.get("db_user"), context.get("client_ip"),
                context.get("detail", ""),
            ),
        )
        incident_id = cur.fetchone()[0]
        conn.commit()
        return f"incident #{incident_id} created"
    finally:
        cur.close()


def _exec_webhook(conn, params: dict, subject: str, context: dict) -> str:
    url = params.get("url", "")
    if not url:
        return "skipped: no webhook URL"
    payload = json.dumps({
        "source":      "DBDOME-GRC",
        "subject":     subject,
        "trigger":     context.get("trigger_type", ""),
        "severity":    context.get("severity", ""),
        "server":      context.get("server_name", ""),
        "db_user":     context.get("db_user", ""),
        "client_ip":   context.get("client_ip", ""),
        "detail":      context.get("detail", ""),
        "timestamp":   datetime.now(timezone.utc).isoformat(),
    }).encode("utf-8")
    try:
        req = urllib.request.Request(
            url, data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "DBDOME-GRC/1.0"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
        return f"webhook POST → {url} (HTTP {status})"
    except Exception as e:
        raise RuntimeError(f"WEBHOOK failed: {e}")


_RESPONSE_FN = {
    "NOTIFY":       _exec_notify,
    "ESCALATE":     _exec_escalate,
    "WEBHOOK":      _exec_webhook,
}


def _execute_playbook(conn, playbook: dict, subject: str, context: dict):
    """Execute one playbook response and write a log entry."""
    rtype  = playbook["response_type"]
    params = playbook.get("response_params") or {}
    if isinstance(params, str):
        try:
            params = json.loads(params)
        except Exception:
            params = {}

    detail_str = ""
    success    = True
    error_msg  = None
    try:
        if rtype == "BLOCK_IP":
            detail_str = _exec_block_ip(conn, params, context.get("client_ip", ""), context)
        elif rtype == "SUSPEND_USER":
            detail_str = _exec_suspend_user(
                conn, params,
                context.get("server_name", ""), context.get("db_user", ""),
                context,
            )
        elif rtype in _RESPONSE_FN:
            detail_str = _RESPONSE_FN[rtype](conn, params, subject, context)
        else:
            detail_str = f"unknown response_type: {rtype}"
    except Exception as e:
        success   = False
        error_msg = str(e)
        detail_str = str(e)

    # Write log entry
    log_cur = conn.cursor()
    try:
        log_cur.execute(
            """INSERT INTO log.threat_response_log
                (playbook_id, playbook_name, trigger_type, subject, response_type, response_detail, success, error_message)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
            (
                playbook["playbook_id"], playbook["playbook_name"],
                playbook["trigger_type"], subject, rtype,
                json.dumps({"detail": detail_str, **context}),
                success, error_msg,
            ),
        )
        conn.commit()
    finally:
        log_cur.close()

    level = "INFO" if success else "ERROR"
    db_write_log(
        f"[{rtype}] {playbook['playbook_name']}: {detail_str}",
        level, "threat_response_engine", "",
    )


# ── Threat scanners ───────────────────────────────────────────────────────────

_last_audit_scan_at: datetime = datetime.now(timezone.utc) - timedelta(seconds=120)


def _scan_blocked_events(conn, playbooks: list):
    """Handle 'blocked_event' and 'regulation_breach' playbooks."""
    global _last_audit_scan_at
    since = _last_audit_scan_at

    cur = conn.cursor()
    try:
        cur.execute(
            """SELECT audit_id, server_name, db_user, client_ip, db_name,
                      action_taken, regulation, risk_score, event_time
               FROM log.firewall_audit_log
               WHERE event_time > %s
                 AND action_taken IN ('BLOCKED', 'ALERTED')
               ORDER BY event_time""",
            (since,),
        )
        events = cur.fetchall()
    finally:
        cur.close()

    _last_audit_scan_at = datetime.now(timezone.utc)

    for row in events:
        _, server, db_user, client_ip, db_name, action, regulation, risk_score, event_time = row
        context = {
            "server_name": server, "db_user": db_user, "client_ip": client_ip,
            "regulation": regulation, "severity": "CRITICAL" if risk_score >= 90 else "HIGH",
            "detail": f"{action} event (risk={risk_score})",
        }

        for pb in playbooks:
            tt = pb["trigger_type"]
            if tt not in ("blocked_event", "regulation_breach", "ip_attack"):
                continue

            if tt == "regulation_breach":
                pb_reg = (pb.get("response_params") or {})
                if isinstance(pb_reg, str):
                    try: pb_reg = json.loads(pb_reg)
                    except: pb_reg = {}
                req_reg = pb_reg.get("regulation") or pb.get("trigger_regulation")
                if req_reg and regulation != req_reg:
                    continue
            elif tt == "ip_attack":
                # ip_attack is handled separately (requires counting per-IP events)
                continue

            if pb.get("trigger_severity") and context["severity"] != pb["trigger_severity"]:
                continue

            subject = f"{action}@{server}/{db_user} from {client_ip}"
            context["trigger_type"] = tt
            if not _in_cooldown(conn, pb["playbook_id"], subject, pb["cooldown_mins"]):
                _execute_playbook(conn, pb, subject, context)


def _scan_ip_attacks(conn, playbooks: list):
    """Handle 'ip_attack' playbooks — IP with N+ BLOCKED events in the last 10 min."""
    ip_playbooks = [pb for pb in playbooks if pb["trigger_type"] == "ip_attack"]
    if not ip_playbooks:
        return

    cur = conn.cursor()
    try:
        cur.execute(
            """SELECT client_ip, COUNT(*) AS cnt, MIN(server_name), MIN(db_user)
               FROM log.firewall_audit_log
               WHERE event_time >= NOW() - INTERVAL '10 minutes'
                 AND action_taken = 'BLOCKED'
                 AND client_ip IS NOT NULL
               GROUP BY client_ip
               HAVING COUNT(*) >= 2"""
        )
        rows = cur.fetchall()
    finally:
        cur.close()

    for row in rows:
        client_ip, cnt, server, db_user = row
        if client_ip in get_blocked_ips():
            continue  # already blocked

        context = {
            "client_ip": client_ip, "server_name": server, "db_user": db_user,
            "trigger_type": "ip_attack", "severity": "HIGH",
            "detail": f"{cnt} BLOCKED events in 10 min",
        }
        for pb in ip_playbooks:
            if cnt < pb["trigger_threshold"]:
                continue
            subject = f"ip_attack:{client_ip}"
            if not _in_cooldown(conn, pb["playbook_id"], subject, pb["cooldown_mins"]):
                _execute_playbook(conn, pb, subject, context)


def _scan_high_risk_users(conn, playbooks: list):
    """Handle 'high_risk_user' playbooks from monitoring.user_risk_profiles."""
    user_playbooks = [pb for pb in playbooks if pb["trigger_type"] == "high_risk_user"]
    if not user_playbooks:
        return

    min_thresh = min(pb["trigger_threshold"] for pb in user_playbooks)
    cur = conn.cursor()
    try:
        cur.execute(
            """SELECT server_name, login_name, risk_score, consecutive_high_risk,
                      avg_queries_per_hour, typical_tables
               FROM monitoring.user_risk_profiles
               WHERE risk_score >= %s
               ORDER BY risk_score DESC""",
            (min_thresh,),
        )
        users = cur.fetchall()
    except Exception:
        return  # table may not exist yet
    finally:
        cur.close()

    for row in users:
        server, login, score, consec, avg_q, tables = row
        if is_user_suspended(server, login):
            continue

        context = {
            "server_name": server, "db_user": login,
            "trigger_type": "high_risk_user",
            "severity": "CRITICAL" if score >= 90 else "HIGH",
            "detail": f"risk_score={score}, consecutive_high_risk={consec}",
        }
        for pb in user_playbooks:
            if score < pb["trigger_threshold"]:
                continue

            # SUSPEND_USER: only trigger when consecutive_high_risk >= 5
            if pb["response_type"] == "SUSPEND_USER" and (consec or 0) < 5:
                continue

            subject = f"user:{server}/{login}"
            if not _in_cooldown(conn, pb["playbook_id"], subject, pb["cooldown_mins"]):
                _execute_playbook(conn, pb, subject, context)


# ── Expiry janitor ────────────────────────────────────────────────────────────

def _expire_blocks(conn):
    """Deactivate IPs and users whose block/suspension has expired."""
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE config.blocked_ips SET is_active=FALSE WHERE is_active=TRUE AND expires_at <= NOW()"
        )
        cur.execute(
            "UPDATE config.suspended_users SET is_active=FALSE WHERE is_active=TRUE AND expires_at <= NOW()"
        )
        conn.commit()
    finally:
        cur.close()


# ── Main entry point ─────────────────────────────────────────────────────────

def run_threat_response():
    """Scheduled job: scan for threats and execute playbook responses."""
    try:
        conn = _get_conn()
        playbooks = _get_playbooks()
        if not playbooks:
            conn.close()
            return

        _expire_blocks(conn)
        reload_entity_cache()

        _scan_blocked_events(conn, playbooks)
        _scan_ip_attacks(conn, playbooks)
        _scan_high_risk_users(conn, playbooks)

        conn.close()
    except psycopg2.errors.UndefinedTable:
        pass  # schema not yet migrated
    except Exception as e:
        db_write_log(f"run_threat_response failed: {e}", "ERROR", "threat_response_engine", "")
