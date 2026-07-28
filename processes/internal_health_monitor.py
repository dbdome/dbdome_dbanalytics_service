"""Internal (self-monitoring) health alerts for the DBDOME appliance.

Checks the LOCAL server every 5 minutes and emails the alert recipients when:
  * free disk on the system drive drops below a threshold (default 10%),
  * CPU utilisation exceeds a threshold (default 90%),
  * memory utilisation exceeds a threshold (default 90%),
  * a watched service is not running
    (DBDOME_scheduler, DBDOME_Grafana, DBDOME_web, postgresql-x64-18).

Thresholds / enable / dedup window live in config.internal_health_checks; the
watched services in config.internal_monitored_services (migration 6560).

These are OPERATIONAL alerts about the appliance itself, so they are emailed
directly to the alert recipients — NOT run through the database-security mail gate
(config.webook_alerts), which only knows the Security/Health/Performance domains.
Each breach is also written to alerts.alert_log so it appears in the alert-incident
lifecycle (open→resolved) alongside database alerts.

A per-check recurrency window (alerts.mail_alert_log) prevents re-mailing the same
condition every cycle.
"""
import os
import json
import socket
import shutil
import smtplib
from email.message import EmailMessage

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret


def _recipients(cur):
    cur.execute(r"""
        SELECT string_agg(DISTINCT trim(r.v), ',')
        FROM config.mail_groups mg
        CROSS JOIN LATERAL regexp_split_to_table(mg.recipients, '[,;\s]+') AS r(v)
        WHERE mg.is_active IS TRUE AND length(trim(r.v)) > 0
    """)
    row = cur.fetchone()
    return [x for x in ((row[0] or "").split(",")) if x]


def _send_mail(cur, subject, body):
    cur.execute("""SELECT mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server
                   FROM config.mail_config LIMIT 1""")
    mc = cur.fetchone()
    if not mc:
        raise RuntimeError("config.mail_config is empty")
    sender, port, user, pw, tls, server = mc
    rcpts = _recipients(cur)
    if not rcpts:
        raise RuntimeError("no active recipients in config.mail_groups")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = ", ".join(rcpts)
    msg.set_content(body)

    s = smtplib.SMTP(server, int(port), timeout=30)
    try:
        s.ehlo()
        if tls:
            s.starttls()
            s.ehlo()
        if user and str(user).strip():
            s.login(user, decrypt_secret(pw))
        s.send_message(msg, to_addrs=rcpts)
    finally:
        try:
            s.quit()
        except Exception:
            pass
    return rcpts


def _already_alerted(cur, metric_name, hours):
    """True if this check already mailed within its recurrency window."""
    if not hours or hours <= 0:
        return False
    cur.execute(
        "SELECT count(*) FROM alerts.mail_alert_log "
        "WHERE metric_name = %s AND entry_date > NOW() - (%s || ' hours')::interval",
        (metric_name, hours))
    return cur.fetchone()[0] > 0


def _fire(conn, host, metric_name, subject, body, hours):
    """Mail + log a breach, unless it is within the recurrency window."""
    cur = conn.cursor()
    if _already_alerted(cur, metric_name, hours):
        return False
    rcpts = _send_mail(cur, subject, body)
    cur.execute(
        """INSERT INTO alerts.mail_alert_log (server, metric_name, subject, body,
                                              recipients, transaction_type)
           VALUES (%s, %s, %s, %s, %s, 'internal_alert')""",
        (host, metric_name, subject, body, ",".join(rcpts)))
    # feed the incident lifecycle (open→resolved) like a database alert
    cur.execute(
        """INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata)
           VALUES (%s, %s, 'critical', CAST(%s AS jsonb))""",
        (host, metric_name, json.dumps({"internal": True, "detail": body})))
    conn.commit()
    db_write_log(f"internal alert emailed: {metric_name} -> {len(rcpts)} recipient(s)",
                 0, "internal_health_monitor", host)
    return True


def _service_status(name):
    """Return a service's status string: 'running', 'stopped', etc."""
    try:
        import psutil
        if hasattr(psutil, "win_service_get"):
            return str(psutil.win_service_get(name).status())
    except Exception as e:
        # service missing / not Windows -> fall through
        if "no service" in str(e).lower():
            return "not-installed"
    # Linux fallback
    try:
        import subprocess
        out = subprocess.run(["systemctl", "is-active", name],
                             capture_output=True, text=True, timeout=10)
        val = (out.stdout or "").strip()
        return "running" if val == "active" else (val or "unknown")
    except Exception:
        return "unknown"


def run_internal_health_monitor():
    import psutil
    host = socket.gethostname()
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = False
        cur = conn.cursor()
        cur.execute("""SELECT check_key, threshold, enabled, recurrency_hours
                       FROM config.internal_health_checks""")
        checks = {r[0]: {"threshold": r[1], "enabled": r[2], "hours": r[3]}
                  for r in cur.fetchall()}
        conn.commit()

        # --- keep config.global_params.disk_size (total capacity in MB) accurate ---
        # This is the authoritative source for disk_size: SQL can't read OS disk
        # size, so the value shipped as a placeholder (10000) that broke the
        # disk-space alert math. Refresh it from the real data-drive capacity on
        # every run so the alert/free-% calculations are correct on any install.
        try:
            drive = "C:\\" if os.name == "nt" else "/"
            total_mb = shutil.disk_usage(drive).total // (1024 * 1024)
            gp = conn.cursor()
            # config.global_params has no unique constraint on `key`, so no
            # ON CONFLICT — update in place, insert only when absent.
            gp.execute("UPDATE config.global_params SET value = %s WHERE key = 'disk_size'",
                       (str(total_mb),))
            if gp.rowcount == 0:
                gp.execute("INSERT INTO config.global_params (key, value) VALUES ('disk_size', %s)",
                           (str(total_mb),))
            conn.commit()
            gp.close()
        except Exception as _ds_ex:
            conn.rollback()
            db_write_log(f"disk_size refresh failed: {_ds_ex}", 0,
                         "internal_health_monitor", host)

        # --- free disk on the local system drive ---
        c = checks.get("disk_free_pct")
        if c and c["enabled"] and c["threshold"] is not None:
            drive = "C:\\" if os.name == "nt" else "/"
            total, _used, free = shutil.disk_usage(drive)
            free_pct = round(100.0 * free / total, 1)
            if free_pct < float(c["threshold"]):
                _fire(conn, host, "INTERNAL-DISK-LOW",
                      f"[DBDOME] Low disk on {host}: {free_pct}% free",
                      f"Free disk on {drive} is {free_pct}% (threshold {c['threshold']}%).\n"
                      f"{round(free/1e9, 1)} GB free of {round(total/1e9, 1)} GB.",
                      c["hours"])

        # --- CPU ---
        c = checks.get("cpu_pct")
        if c and c["enabled"] and c["threshold"] is not None:
            cpu = psutil.cpu_percent(interval=1.0)
            if cpu > float(c["threshold"]):
                _fire(conn, host, "INTERNAL-CPU-HIGH",
                      f"[DBDOME] High CPU on {host}: {cpu}%",
                      f"CPU utilisation is {cpu}% (threshold {c['threshold']}%).",
                      c["hours"])

        # --- memory ---
        c = checks.get("mem_pct")
        if c and c["enabled"] and c["threshold"] is not None:
            mem = psutil.virtual_memory().percent
            if mem > float(c["threshold"]):
                _fire(conn, host, "INTERNAL-MEM-HIGH",
                      f"[DBDOME] High memory on {host}: {mem}%",
                      f"Memory utilisation is {mem}% (threshold {c['threshold']}%).",
                      c["hours"])

        # --- watched services ---
        c = checks.get("service_down")
        if c and c["enabled"]:
            cur = conn.cursor()
            cur.execute("SELECT service_name FROM config.internal_monitored_services WHERE enabled IS TRUE")
            services = [r[0] for r in cur.fetchall()]
            conn.commit()
            for svc in services:
                status = _service_status(svc)
                if status not in ("running",):
                    _fire(conn, host, f"INTERNAL-SERVICE-DOWN-{svc}",
                          f"[DBDOME] Service not running on {host}: {svc} ({status})",
                          f"Watched service '{svc}' is '{status}' (expected 'running').",
                          c["hours"])
        return 1
    except Exception as e:
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                pass
        db_write_log(f"internal_health_monitor failed: {e}", 0, "internal_health_monitor", "")
        return 0
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
