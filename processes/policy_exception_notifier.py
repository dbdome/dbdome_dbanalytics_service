"""GRC Phase 8: Policy Exception Notifier
Marks expired exceptions and sends expiry-warning emails.
"""
import os
import smtplib
from email.mime.text import MIMEText
import psycopg2
import psycopg2.errors  # explicit: psycopg2/__init__ never imports this statically (the binding happens inside the compiled _psycopg), so a frozen build drops it and psycopg2.errors.* raises AttributeError at runtime
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _send_email(to_addr: str, subject: str, body: str):
    host = os.getenv('SMTP_HOST', 'localhost')
    port = int(os.getenv('SMTP_PORT', '25'))
    user = os.getenv('SMTP_USER', '')
    pwd  = os.getenv('SMTP_PASS', '')
    msg  = MIMEText(body)
    msg['Subject'] = subject
    msg['From']    = user or 'grc@dbdome.local'
    msg['To']      = to_addr
    with smtplib.SMTP(host, port, timeout=10) as s:
        if user and pwd:
            s.login(user, pwd)
        s.sendmail(msg['From'], [to_addr], msg.as_string())


def _already_reminded(conn, exception_id: int) -> bool:
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT 1 FROM log.grc_alert_delivery_log
            WHERE source_feature='policy_exception_notifier'
              AND event_summary LIKE %s
              AND delivered_at >= NOW()-INTERVAL '23 hours'
            LIMIT 1
        """, (f'%exception_id={exception_id}%',))
        found = cur.fetchone() is not None
        cur.close()
        return found
    except Exception:
        return False


def _log_reminder(conn, exception_id: int, to_addr: str, success: bool, error: str = None):
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO log.grc_alert_delivery_log
                (channel_name, channel_type, source_feature, severity,
                 server_name, event_summary, success, error_message)
            VALUES ('email','EMAIL','policy_exception_notifier','MEDIUM',
                    '', %s, %s, %s)
        """, (f"Expiry warning for exception_id={exception_id} to {to_addr}",
              success, str(error)[:500] if error else None))
        conn.commit()
        cur.close()
    except Exception as e:
        db_write_log(f"_log_reminder: {e}", 0, "policy_exception_notifier", "")


def run_exception_expiry_check():
    try:
        conn = _get_conn()
        try:
            # 1. Expire approved exceptions past their expiry date
            cur = conn.cursor()
            cur.execute("""
                UPDATE config.policy_exceptions
                   SET approval_status='EXPIRED', updated_at=NOW()
                 WHERE approval_status='APPROVED'
                   AND expires_at <= NOW()
            """)
            expired_count = cur.rowcount
            conn.commit()
            cur.close()
            if expired_count:
                db_write_log(f"Expired {expired_count} policy exceptions", "INFO",
                             "policy_exception_notifier", "")
                try:
                    from processes.firewall_policy_engine import reload_policy_cache
                    reload_policy_cache()
                except Exception:
                    pass

            # 2. Send expiry-warning emails for exceptions expiring within 7 days
            cur = conn.cursor()
            cur.execute("""
                SELECT pe.exception_id, pe.exception_name, pe.reason,
                       pe.expires_at, pe.approved_by, pe.requested_by,
                       pe.regulation, fp.policy_name
                FROM   config.v_expiring_exceptions ve
                JOIN   config.policy_exceptions pe ON pe.exception_id = ve.exception_id
                JOIN   config.firewall_policies  fp ON fp.policy_id   = pe.policy_id
            """)
            rows = cur.fetchall()
            cur.close()

            for row in rows:
                (exc_id, exc_name, reason, expires_at, approved_by,
                 requested_by, regulation, policy_name) = row
                if _already_reminded(conn, exc_id):
                    continue
                to_addr = (requested_by or '').strip()
                if '@' not in to_addr:
                    continue
                body = (
                    f"Policy Exception Expiry Warning\n\n"
                    f"Exception:  {exc_name}\n"
                    f"Policy:     {policy_name}\n"
                    f"Reason:     {reason}\n"
                    f"Expires:    {expires_at}\n"
                    f"Approved by:{approved_by or 'N/A'}\n"
                    f"Regulation: {regulation or 'N/A'}\n\n"
                    f"Please review and renew or let the exception expire.\n"
                    f"GRC Portal: /grc/policy-exceptions"
                )
                success, error = True, None
                try:
                    _send_email(to_addr,
                                f"[GRC] Policy exception expiring: {exc_name}",
                                body)
                except Exception as e:
                    success, error = False, str(e)
                    db_write_log(f"expiry email to {to_addr}: {e}", 0,
                                 "policy_exception_notifier", "")
                _log_reminder(conn, exc_id, to_addr, success, error)
        finally:
            conn.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"run_exception_expiry_check: {e}", 0, "policy_exception_notifier", "")
