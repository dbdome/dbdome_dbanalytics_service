"""GRC Phase 9: Access Review / Recertification Scheduler"""
import os
import smtplib
from datetime import date, timedelta
from email.mime.text import MIMEText
import psycopg2
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _send_email(to_addrs: list, subject: str, body: str):
    host = os.getenv('SMTP_HOST', 'localhost')
    port = int(os.getenv('SMTP_PORT', '25'))
    user = os.getenv('SMTP_USER', '')
    pwd  = os.getenv('SMTP_PASS', '')
    msg  = MIMEText(body)
    msg['Subject'] = subject
    msg['From']    = user or 'grc@dbdome.local'
    msg['To']      = ', '.join(to_addrs)
    with smtplib.SMTP(host, port, timeout=10) as s:
        if user and pwd:
            s.login(user, pwd)
        s.sendmail(msg['From'], to_addrs, msg.as_string())


def _compute_next_due(frequency: str, from_date: date) -> date:
    if frequency == 'MONTHLY':
        m = from_date.month % 12 + 1
        y = from_date.year + (1 if from_date.month == 12 else 0)
        return date(y, m, 1)
    elif frequency == 'ANNUAL':
        return date(from_date.year + 1, 1, 1)
    else:  # QUARTERLY default
        q = (from_date.month - 1) // 3
        nq = (q + 1) % 4
        ny = from_date.year + (1 if nq == 0 else 0)
        nm = nq * 3 + 1
        return date(ny, nm, 1)


def _compute_period(frequency: str, today: date):
    if frequency == 'MONTHLY':
        first = date(today.year, today.month, 1)
        end   = today - timedelta(days=1)
        start = date(end.year, end.month, 1)
    elif frequency == 'ANNUAL':
        start = date(today.year - 1, 1, 1)
        end   = date(today.year - 1, 12, 31)
    else:  # QUARTERLY
        q = (today.month - 1) // 3
        pq = (q - 1) % 4
        py = today.year - (1 if pq == 3 else 0)
        start = date(py, pq * 3 + 1, 1)
        end_m = pq * 3 + 3
        end   = date(py, end_m, [31,28,31,30,31,30,31,31,30,31,30,31][end_m-1])
    return start, end


def _already_reminded(conn, instance_id: int) -> bool:
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT 1 FROM log.grc_alert_delivery_log
            WHERE source_feature='access_review'
              AND event_summary LIKE %s
              AND delivered_at >= NOW()-INTERVAL '23 hours'
            LIMIT 1
        """, (f'%instance_id={instance_id}%',))
        found = cur.fetchone() is not None
        cur.close()
        return found
    except Exception:
        return False


def run_access_review_cycle_check():
    today = date.today()
    try:
        conn = _get_conn()
        try:
            cur = conn.cursor()
            cur.execute("SELECT * FROM config.access_review_cycles WHERE is_active=TRUE")
            cols  = [d[0] for d in cur.description]
            cycles = [dict(zip(cols, r)) for r in cur.fetchall()]
            cur.close()

            for cycle in cycles:
                next_due = cycle.get('next_cycle_due_at')
                due = next_due.date() if next_due else None
                if due is None or due <= today:
                    period_start, period_end = _compute_period(cycle['frequency'], today)
                    ic = conn.cursor()
                    ic.execute("""
                        INSERT INTO log.access_review_instances
                            (cycle_id, cycle_name, period_start, period_end, status)
                        VALUES (%s,%s,%s,%s,'OPEN') RETURNING instance_id
                    """, (cycle['cycle_id'], cycle['cycle_name'], period_start, period_end))
                    instance_id = ic.fetchone()[0]

                    # Count pending items
                    ic.execute("""
                        SELECT COUNT(*) FROM log.v_access_review_pending
                        WHERE instance_id=%s
                    """, (instance_id,))
                    total_items = ic.fetchone()[0]
                    ic.execute("UPDATE log.access_review_instances SET total_items=%s WHERE instance_id=%s",
                               (total_items, instance_id))

                    next_due_new = _compute_next_due(cycle['frequency'], today)
                    ic.execute("""
                        UPDATE config.access_review_cycles
                           SET last_cycle_started_at=NOW(), next_cycle_due_at=%s
                         WHERE cycle_id=%s
                    """, (next_due_new, cycle['cycle_id']))
                    conn.commit()
                    ic.close()

                    recipients = [r.strip() for r in (cycle.get('reviewer_email') or '').split(',') if '@' in r]
                    if recipients:
                        body = (
                            f"Access Review Kickoff: {cycle['cycle_name']}\n\n"
                            f"Instance ID: {instance_id}\n"
                            f"Period: {period_start} to {period_end}\n"
                            f"Items to review: {total_items}\n\n"
                            f"Please review at: /grc/access-review"
                        )
                        try:
                            _send_email(recipients,
                                        f"[GRC] Access Review Due: {cycle['cycle_name']}", body)
                        except Exception as e:
                            db_write_log(f"access_review kickoff email: {e}", 0, "access_review_scheduler", "")

                # Send reminders for open instances approaching period_end
                cur2 = conn.cursor()
                cur2.execute("""
                    SELECT instance_id, cycle_name, period_end, total_items, reviewed_items
                    FROM   log.access_review_instances
                    WHERE  cycle_id=%s AND status IN ('OPEN','IN_PROGRESS')
                      AND  period_end - %s::date <= %s
                """, (cycle['cycle_id'], today, cycle.get('reminder_days_before', 7)))
                open_instances = cur2.fetchall()
                cur2.close()

                for inst in open_instances:
                    inst_id, cycle_name, period_end, total_items, reviewed_items = inst
                    if _already_reminded(conn, inst_id):
                        continue
                    recipients = [r.strip() for r in (cycle.get('reviewer_email') or '').split(',') if '@' in r]
                    if recipients:
                        try:
                            _send_email(recipients,
                                        f"[GRC] REMINDER: Access Review Due {period_end}",
                                        f"Access review '{cycle_name}' closes {period_end}.\n"
                                        f"Progress: {reviewed_items}/{total_items} reviewed.\n"
                                        f"Review at: /grc/access-review")
                            lc = conn.cursor()
                            lc.execute("""
                                INSERT INTO log.grc_alert_delivery_log
                                    (channel_type, source_feature, severity, event_summary, success)
                                VALUES ('EMAIL','access_review','MEDIUM',%s,TRUE)
                            """, (f"Reminder for instance_id={inst_id} cycle={cycle_name}",))
                            conn.commit()
                            lc.close()
                        except Exception as e:
                            db_write_log(f"access_review reminder email: {e}", 0, "access_review_scheduler", "")
        finally:
            conn.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"run_access_review_cycle_check: {e}", 0, "access_review_scheduler", "")
