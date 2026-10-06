"""Diagnostics for outgoing mail: why an alert or report did not arrive.

Every send path calls through here, so a failure produces (a) a structured row in
alerts.mail_send_log and (b) a one-line, level-2 entry in log.operation_log that
names the host, port, auth mode, recipients and the SMTP code. Before this, a
failed send left either a level-0 line reading "failed with error:<repr>" - the
same severity as routine chatter, with none of the context needed to act on it -
or, when there was no mail config or no recipient, nothing at all.

Deliberately light on imports (psycopg2 + config_dotenv + log4dbexpert) so the
scheduler processes and job_handler can use it without pulling the SSRS/alert
stack that email_utils.smtp_email_sender drags in.

Nothing in here may raise: a logging problem must never be the reason a mail
fails, so every path is wrapped and falls back to the operation log alone.

Typical use:

    from email_utils.mail_log import mail_attempt

    with mail_attempt(channel="report", routine="send_report_files_email",
                      smtp_server=host, smtp_port=port, tls=tls, user=smtp_user,
                      mail_sender=sender, recipients=rcpts, subject=subject,
                      attachments=files) as att:
        att.stage("connect")
        s = smtp_connect(...)
        att.stage("send")
        s.send_message(msg)

The stage() calls are what turn "it failed" into "the login was rejected" vs
"the server never answered" vs "the recipient was refused".
"""
import os
import re
import smtplib
import socket
import ssl
import time

try:
    import psycopg2
except Exception:                                       # pragma: no cover
    psycopg2 = None

from utils.config_dotenv import get_connection_string

try:
    from utils.log4dbexpert import db_write_log
except Exception:                                       # pragma: no cover
    def db_write_log(*_a, **_k):
        return None


TABLE = "alerts.mail_send_log"

# Level used for failed/skipped sends in log.operation_log. The old code logged
# mail failures at level 0, which is why they never stood out from normal traffic.
LEVEL_ERROR = 2
LEVEL_INFO = 0

_MAX_TEXT = 2000


def auth_mode(user):
    """How the send authenticated, for the log. Never records the password, and
    never its length - only whether a user is configured, and which."""
    u = (user or "").strip() if isinstance(user, str) else (user or "")
    return f"user:{u}" if u else "anonymous"


def _trim(v, n=_MAX_TEXT):
    if v is None:
        return None
    s = v if isinstance(v, str) else str(v)
    s = s.strip()
    return s if len(s) <= n else s[: n - 3] + "..."


def _join(v):
    """Recipients/attachments may arrive as a list or a comma-separated string."""
    if v is None:
        return None
    if isinstance(v, (list, tuple, set)):
        return ", ".join(str(x) for x in v if x)
    return str(v)


def classify(exc):
    """Map an exception to (stage, error_class, error_code).

    The stage matters more than the message: a 535 at `auth` means the stored
    credentials are wrong, while the same send failing at `connect` means the
    relay is unreachable and the credentials are irrelevant. smtplib carries the
    numeric code on most of its exceptions; socket/ssl errors carry none.
    """
    cls = type(exc).__name__
    code = None
    for attr in ("smtp_code", "errno"):
        v = getattr(exc, attr, None)
        if isinstance(v, int):
            code = str(v)
            break
    if code is None:
        m = re.search(r"\b([2345]\d\d)\b", str(exc))
        if m:
            code = m.group(1)

    if isinstance(exc, (smtplib.SMTPAuthenticationError, smtplib.SMTPNotSupportedError)):
        return "auth", cls, code
    if isinstance(exc, (smtplib.SMTPConnectError, smtplib.SMTPServerDisconnected,
                        socket.timeout, socket.gaierror, ConnectionError, ssl.SSLError)):
        return "connect", cls, code
    if isinstance(exc, (smtplib.SMTPRecipientsRefused, smtplib.SMTPSenderRefused,
                        smtplib.SMTPDataError)):
        return "send", cls, code
    if isinstance(exc, (FileNotFoundError, PermissionError, IsADirectoryError)):
        return "attach", cls, code
    if isinstance(exc, OSError):
        return "connect", cls, code
    return None, cls, code          # unrecognised: let the caller's stage stand


def _insert(row):
    """Write one row. Silent no-op when the table is absent (an install that has
    not run 7670 yet) or the DB is unreachable - the operation-log line still
    carries the same information."""
    if psycopg2 is None:
        return False
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(
                f"""INSERT INTO {TABLE}
                    (channel, routine, status, stage, smtp_server, smtp_port, tls,
                     auth_mode, mail_sender, recipients, subject, attachments,
                     server_name, root_cause_id, duration_ms,
                     error_class, error_code, error_text)
                    VALUES (%(channel)s, %(routine)s, %(status)s, %(stage)s,
                            %(smtp_server)s, %(smtp_port)s, %(tls)s, %(auth_mode)s,
                            %(mail_sender)s, %(recipients)s, %(subject)s, %(attachments)s,
                            %(server_name)s, %(root_cause_id)s, %(duration_ms)s,
                            %(error_class)s, %(error_code)s, %(error_text)s)""",
                row,
            )
        return True
    except Exception as e:
        # Do not recurse through db_write_log's own failure path; print is enough.
        print(f"[mail_log] could not write {TABLE}: {str(e).splitlines()[0][:200]}")
        return False
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


def _summary_line(row):
    """The one-liner that lands in log.operation_log. Everything needed to act on
    the failure has to be IN this line - it is what an operator greps."""
    bits = [
        f"MAIL {row['status'].upper()}",
        f"[{row.get('channel') or '?'}/{row.get('routine') or '?'}]",
    ]
    if row.get("stage"):
        bits.append(f"stage={row['stage']}")
    if row.get("smtp_server"):
        bits.append(f"host={row['smtp_server']}:{row.get('smtp_port')}")
    if row.get("tls") is not None:
        bits.append(f"tls={row['tls']}")
    if row.get("auth_mode"):
        bits.append(f"auth={row['auth_mode']}")
    if row.get("recipients"):
        bits.append(f"to={_trim(row['recipients'], 200)}")
    if row.get("subject"):
        bits.append(f"subject='{_trim(row['subject'], 120)}'")
    if row.get("root_cause_id"):
        bits.append(f"rc={row['root_cause_id']}")
    if row.get("duration_ms") is not None:
        bits.append(f"{row['duration_ms']}ms")
    if row.get("error_code"):
        bits.append(f"smtp_code={row['error_code']}")
    if row.get("error_class"):
        bits.append(f"error={row['error_class']}")
    if row.get("error_text"):
        bits.append(f"detail={_trim(row['error_text'], 400)}")
    return " ".join(bits)


def log_mail(status, channel=None, routine=None, stage=None, smtp_server=None,
             smtp_port=None, tls=None, user=None, mail_sender=None, recipients=None,
             subject=None, attachments=None, server_name=None, root_cause_id=None,
             duration_ms=None, error=None, detail=None):
    """Record one outcome ('sent' | 'failed' | 'skipped'). Never raises."""
    try:
        err_class = err_code = None
        err_text = detail
        if error is not None:
            st, err_class, err_code = classify(error)
            stage = st or stage
            err_text = detail or str(error)
        row = {
            "channel": _trim(channel, 40),
            "routine": _trim(routine, 80),
            "status": status,
            "stage": _trim(stage, 40),
            "smtp_server": _trim(smtp_server, 200),
            "smtp_port": int(smtp_port) if str(smtp_port or "").strip().isdigit() else None,
            "tls": None if tls is None else bool(tls),
            "auth_mode": auth_mode(user) if user is not None or status != "skipped" else None,
            "mail_sender": _trim(mail_sender, 200),
            "recipients": _trim(_join(recipients)),
            "subject": _trim(subject, 500),
            "attachments": _trim(_join(attachments)),
            "server_name": _trim(server_name, 200),
            "root_cause_id": _trim(root_cause_id, 80),
            "duration_ms": None if duration_ms is None else round(float(duration_ms), 1),
            "error_class": _trim(err_class, 80),
            "error_code": _trim(err_code, 20),
            "error_text": _trim(err_text),
        }
        _insert(row)
        db_write_log(_summary_line(row),
                     LEVEL_INFO if status == "sent" else LEVEL_ERROR,
                     routine or "mail_log",
                     server_name or (smtp_server or ""))
    except Exception as e:                                # pragma: no cover
        print(f"[mail_log] log_mail failed: {e}")


def log_mail_skipped(reason, **kw):
    """A send that never happened: no SMTP config, no recipients, SMTP cooldown,
    dedup window, authorisation gate. These used to be completely silent, which
    is why 'the alert never arrived' had no trail at all."""
    kw.setdefault("stage", "config")
    log_mail("skipped", detail=reason, **kw)


class mail_attempt:
    """Context manager that times a send and logs its outcome exactly once.

    Re-raises whatever the body raised - callers keep their own error handling;
    this only guarantees the attempt is recorded. Call .stage() as the send
    progresses so a failure is attributed to connect / auth / send rather than
    guessed from the message.
    """

    def __init__(self, channel=None, routine=None, smtp_server=None, smtp_port=None,
                 tls=None, user=None, mail_sender=None, recipients=None, subject=None,
                 attachments=None, server_name=None, root_cause_id=None):
        self.ctx = dict(channel=channel, routine=routine, smtp_server=smtp_server,
                        smtp_port=smtp_port, tls=tls, user=user, mail_sender=mail_sender,
                        recipients=recipients, subject=subject, attachments=attachments,
                        server_name=server_name, root_cause_id=root_cause_id)
        self._stage = None
        self._t0 = None
        self.logged = False

    def stage(self, name):
        self._stage = name
        return self

    def update(self, **kw):
        """Fill in context discovered after the attempt started (recipients read
        from the DB, the subject built mid-way, and so on)."""
        self.ctx.update({k: v for k, v in kw.items() if v is not None})
        return self

    def skip(self, reason, stage="config"):
        """Abandon the attempt and record why. Use for 'nothing to send with'."""
        if not self.logged:
            self.logged = True
            log_mail("skipped", stage=stage, detail=reason, **self.ctx)

    def __enter__(self):
        self._t0 = time.time()
        return self

    def __exit__(self, exc_type, exc, tb):
        if self.logged:
            return False
        ms = (time.time() - self._t0) * 1000.0 if self._t0 else None
        self.logged = True
        if exc is None:
            log_mail("sent", stage=None, duration_ms=ms, **self.ctx)
        else:
            log_mail("failed", stage=self._stage, duration_ms=ms, error=exc, **self.ctx)
        return False        # never swallow the caller's exception
