import smtplib
import ssl
import json
import html
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import psycopg2
from datetime import datetime
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from utils.secrets_crypto import decrypt_secret, encrypt_secret
from utils.alert_resultset import fetch_alert_resultset
from email.mime.application import MIMEApplication
from ssrs.ssrs_report_download import ssrs_download_alert_report , ssrs_download_alert_report_with_params
import smtplib
from email.message import EmailMessage
import os
import pandas


import threading
import time

# --- Shared SMTP connection, reused across alerts -------------------------------
# Opening a fresh SMTP connection + login for every alert trips Gmail's
# "454 Too many login attempts". We cache one logged-in connection and reuse it;
# it is re-established only when dead or when the SMTP config changes.
_smtp_lock = threading.Lock()
_smtp_cache = {"conn": None, "key": None}
# Circuit breaker: after an SMTP failure, pause sends until this time so a
# rate-limited/blocked server (e.g. Gmail "454 Too many login attempts") recovers
# instead of being hammered into a permanent block.
_smtp_state = {"cooldown_until": 0.0}
_SMTP_COOLDOWN = 600  # seconds


def _reset_smtp_cache():
    c = _smtp_cache.get("conn")
    _smtp_cache["conn"] = None
    _smtp_cache["key"] = None
    if c is not None:
        try:
            c.quit()
        except Exception:
            try:
                c.close()
            except Exception:
                pass


def _get_smtp_connection(server_host, port, tls, user, password):
    """Return a logged-in SMTP connection, reused across calls. Reconnects only if
    the cached one is dead (NOOP fails) or the config key changed. Caller should
    hold _smtp_lock."""
    key = (server_host, int(port), bool(tls), user)
    c = _smtp_cache.get("conn")
    if c is not None and _smtp_cache.get("key") == key:
        try:
            if c.noop()[0] == 250:
                return c
        except Exception:
            pass
    _reset_smtp_cache()
    s = smtplib.SMTP(server_host, int(port), timeout=15)
    s.ehlo()
    if tls:
        s.starttls()
        s.ehlo()
    if user and str(user).strip():
        s.login(user, decrypt_secret(password))
    _smtp_cache["conn"] = s
    _smtp_cache["key"] = key
    return s


def _metric_metadata_table_html(meta, max_rows=100):
    """Render metric_metadata_json as an HTML table for alert emails.

    Accepts a list-of-dicts (the usual detection result), a single dict, or a JSON
    string of either; columns are the union of keys (first-seen order), one row per
    record. Values are HTML-escaped. Returns '' when there is nothing to show.
    This replaces the old 'Comparison' block (expected / comparison_data) so every
    generic collector's alert email shows the actual result rows as a table."""
    if meta is None:
        return ""
    data = meta
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except Exception:
            return ('<h3 style="margin-top:20px;">📋 Detection Results</h3>'
                    '<pre style="background:#f4f4f4;padding:12px;border-radius:6px;'
                    'font-size:13px;overflow-x:auto;border:1px solid #ddd;">'
                    f'{html.escape(str(meta))}</pre>')
    if isinstance(data, dict):
        rows = [data]
    elif isinstance(data, list):
        rows = [r for r in data if isinstance(r, dict)]
        if not rows and data:                       # list of scalars
            rows = [{"value": v} for v in data]
    else:
        rows = [{"value": data}]
    if not rows:
        return ""

    total = len(rows)
    rows = rows[:max_rows]
    cols = []
    for r in rows:
        for k in r.keys():
            if k not in cols:
                cols.append(k)

    th = "".join(
        '<th style="padding:8px;border:1px solid #ddd;background:#34495e;color:#fff;'
        f'text-align:left;font-size:13px;">{html.escape(str(c))}</th>' for c in cols)
    body_rows = []
    for i, r in enumerate(rows):
        bg = "#ffffff" if i % 2 == 0 else "#f8f9fa"
        tds = "".join(
            '<td style="padding:8px;border:1px solid #ddd;font-size:13px;">'
            f'{html.escape("" if r.get(c) is None else str(r.get(c)))}</td>' for c in cols)
        body_rows.append(f'<tr style="background:{bg};">{tds}</tr>')
    note = (f'<p style="font-size:12px;color:#888;">showing first {max_rows} of {total} rows</p>'
            if total > max_rows else "")
    return (
        '<h3 style="margin-top:20px;">📋 Detection Results</h3>'
        '<div style="overflow-x:auto;">'
        '<table style="border-collapse:collapse;width:100%;font-size:13px;">'
        f'<thead><tr>{th}</tr></thead><tbody>{"".join(body_rows)}</tbody></table></div>'
        f'{note}'
    )


def send_mail_alert_no_attachment(
                        server                  ,
                        domain_name             ,
                        area_name               ,
                        issue_name              ,
                        root_cause_id           ,
                        root_cause_name         ,
                        root_cause_desc         ,
                        detection_name          ,
                        detection_desc          ,
                        step_name               ,
                        risk_level              ,
                        query                   ,
                        expected                =None,
                        comparison_data         =None,
                        metric_metadata_json    =None ,
                        transaction_type='security_alert',
                        alert_id                =None
):
    # Coerce a gate parameter to a plain trimmed str; NaN/None/NA -> "".
    # A float NaN is *truthy*, so `x or ""` does NOT catch it, and psycopg2
    # then renders it as 'NaN'::float8 -> trim() resolves to the non-existent
    # btrim(double precision) and the whole gate query errors out. Upstream
    # collectors occasionally pass a pandas NaN as domain_name/risk_level, so
    # normalise here (pandas.isna covers None, float nan, np.nan, pd.NA, NaT).
    def _gate_str(v):
        if v is None or (pandas.isna(v) if not isinstance(v, str) else False):
            return ""
        return str(v).strip()

    # ========== Area gate: drop only a GARBAGE area, never a merely blank one ==========
    # The original ask was "don't send mail when Area: nan". A pandas float NaN
    # renders as "nan" in the subject; None/NaN/NaT and the literal tokens below
    # are garbage and get suppressed. A genuinely empty area ("") is allowed
    # through — many valid metric alerts have no area, and blocking those wrongly
    # stopped legitimate mail (e.g. Security/critical alerts) from being sent.
    _area_is_nan = (not isinstance(area_name, str)) and (area_name is None or pandas.isna(area_name))
    _area_token  = "" if _area_is_nan else str(area_name).strip().lower()
    if _area_is_nan or _area_token in ("nan", "none", "na", "null"):
        db_write_log(
            f"Alert skipped for {root_cause_id} on {server} - area is NaN ('{area_name}')",
            0, "send_mail_alert_no_attachment", server,
        )
        return

    # ========== Mail-authorisation gate ==========
    # Two checks, BOTH must pass before any email is sent:
    #   1) the risk level is globally active (rootcause.risk_level.is_active), and
    #   2) this (domain, risk_level) combo is explicitly enabled for email in
    #      config.webook_alerts (send_mail_alert = true AND is_active).
    # This is the single authoritative email gate for ALL callers (alert_helper
    # and every vendor collector), so a per-collector auth bug can never leak
    # unwanted mail. Fails open only on an unexpected DB error (logged).
    try:
        gate_conn = psycopg2.connect(get_connection_string())
        gate_cur  = gate_conn.cursor()
        gate_cur.execute(
            "SELECT is_active FROM rootcause.risk_level "
            "WHERE lower(trim(risk_level)) = lower(trim(%s)) LIMIT 1",
            (_gate_str(risk_level),),
        )
        gate_row = gate_cur.fetchone()
        if gate_row is None or not gate_row[0]:
            gate_cur.close(); gate_conn.close()
            db_write_log(
                f"Alert skipped for {root_cause_id} on {server} - risk_level '{risk_level}' is disabled or unknown",
                0, "send_mail_alert_no_attachment", server,
            )
            return
        gate_cur.execute(
            "SELECT 1 FROM config.webook_alerts "
            "WHERE lower(trim(metric_type)) = lower(trim(%s)) "
            "  AND lower(trim(risk_level))  = lower(trim(%s)) "
            "  AND send_mail_alert IS TRUE "
            "  AND COALESCE(is_active, true) IS TRUE LIMIT 1",
            (_gate_str(domain_name), _gate_str(risk_level)),
        )
        wa_ok = gate_cur.fetchone() is not None
        gate_cur.close(); gate_conn.close()
        if not wa_ok:
            db_write_log(
                f"Alert skipped for {root_cause_id} on {server} - mail not enabled in "
                f"webook_alerts (domain '{domain_name}', risk '{risk_level}')",
                0, "send_mail_alert_no_attachment", server,
            )
            return
    except Exception as _gate_ex:
        db_write_log(f"mail-authorisation gate check failed: {_gate_ex}", 0,
                     "send_mail_alert_no_attachment", server)

    # ========== SMTP circuit breaker: skip while cooling down after a failure ====
    if time.time() < _smtp_state.get("cooldown_until", 0):
        db_write_log(
            f"Alert send skipped for {root_cause_id} on {server} - SMTP in cooldown after a recent failure",
            0, "send_mail_alert_no_attachment", server)
        return

    # ========== Dedup: skip if same alert sent within 72 hours ==========
    try:
        pg_connection_string = get_connection_string()
        dedup_conn = psycopg2.connect(pg_connection_string)
        dedup_cur = dedup_conn.cursor()
        if risk_level == 'critical':
            dedup_cur.execute(
                """SELECT COUNT(*) FROM alerts.mail_alert_log
                   WHERE server = %s AND metric_name = %s
                     AND entry_date > NOW() - INTERVAL '1 hour'""",
                (str(server), str(root_cause_id))
            )
        else:
            dedup_cur.execute(
                """SELECT COUNT(*) FROM alerts.mail_alert_log
                   WHERE server = %s AND metric_name = %s
                     AND entry_date > NOW() - INTERVAL '72 hours'""",
                (str(server), str(root_cause_id))
            )
        already_sent = dedup_cur.fetchone()[0] > 0
        dedup_cur.close()
        dedup_conn.close()
        if already_sent:
            db_write_log(
                f"Alert skipped for {root_cause_id} on {server} - already sent within 72 hours",
                0, "send_mail_alert_no_attachment", server
            )
            return
    except Exception as dedup_ex:
        db_write_log(f"Alert dedup check failed: {dedup_ex}", 0, "send_mail_alert_no_attachment", server)
        # Continue sending if dedup check fails

    # Detection results: the canonical rows for this alert are what the Grafana
    # alert-detail panel shows — SELECT * FROM
    # monitoring.get_alert_log_resultset_byid(alert_id) keyed on
    # alerts.alert_log.row_id. Fall back to the raw collector payload only when
    # there is no alert_id or the function returns no rows.
    detection_rows = fetch_alert_resultset(alert_id) if alert_id else []
    display_results = detection_rows or metric_metadata_json

    # Extract login_name from the detection results (list-of-dicts, dict, or JSON string)
    login_name = None
    if display_results:
        try:
            data = display_results
            if isinstance(data, str):
                data = json.loads(data)
            if isinstance(data, list) and data:
                first = data[0]
                if isinstance(first, dict):
                    login_name = first.get('login_name')
            elif isinstance(data, dict):
                login_name = data.get('login_name')
        except Exception:
            pass

    query_html = ""
    if query:
        query_html = f"""
        <h3 style="margin-top:20px;">📊 Detection Query</h3>
        <pre style="background:#f4f4f4; padding:12px; border-radius:6px; font-size:13px; overflow-x:auto; border:1px solid #ddd;">{query}</pre>
        """

    # Comparison block removed: show the alert's detection rows as a table
    # instead. expected / comparison_data are no longer rendered.
    metadata_html = _metric_metadata_table_html(display_results)


    login_suffix = f", login: {login_name}" if login_name else ""
    formated_subject = f"[{transaction_type}] {server} - Risk: {risk_level}, area: {area_name}, domain: {domain_name}, issue: {issue_name}{login_suffix}"
    formatted_description = f"""
    <html>
    <body style="font-family: Arial, sans-serif; background-color:#f4f6f8; padding:20px;">

    <div style="background:white; border-radius:8px; padding:20px; max-width:700px; border-left:6px solid #e74c3c;">

    <h2 style="color:#e74c3c;">🚨 Security Alert Detected</h2>

    <table style="border-collapse: collapse; width:100%; font-size:14px;">
    <tr>
    <td style="padding:8px;"><b>⚠️ Risk Level</b></td>
    <td style="padding:8px; color:#e74c3c;"><b>{risk_level}</b></td>
    </tr>

    <tr style="background:#f8f9fa;">
    <td style="padding:8px;"><b>📂 Area</b></td>
    <td style="padding:8px;">{area_name}</td>
    </tr>

    <tr>
    <td style="padding:8px;"><b>🌐 Domain</b></td>
    <td style="padding:8px;">{domain_name}</td>
    </tr>

    <tr>
    <td style="padding:8px;"><b>🌐 Server</b></td>
    <td style="padding:8px;">{server}</td>
    </tr>

    {'<tr style="background:#f8f9fa;"><td style="padding:8px;"><b>👤 Login Name</b></td><td style="padding:8px;">' + login_name + '</td></tr>' if login_name else ''}

    <tr style="background:#f8f9fa;">
    <td style="padding:8px;"><b>🧾 Transaction</b></td>
    <td style="padding:8px;">{transaction_type}</td>
    </tr>

    <tr>
    <td style="padding:8px;"><b>🔎 Issue</b></td>
    <td style="padding:8px;">{issue_name}</td>
    </tr>

    <tr>
    <td style="padding:8px;"><b>🧩 Root Cause</b></td>
    <td style="padding:8px;">{root_cause_name}</td>
    </tr>
     <tr>
    <td style="padding:8px;"><b>🧩 Root Cause</b></td>
    <td style="padding:8px;">-root cause code:{root_cause_id}</td>
    </tr>

    <tr style="background:#f8f9fa;">
    <td style="padding:8px;"><b>📘 Root Cause Description</b></td>
    <td style="padding:8px;">{root_cause_desc}</td>
    </tr>

    <tr>
    <td style="padding:8px;"><b>🛠 Detection</b></td>
    <td style="padding:8px;">{detection_name}</td>
    </tr>

    <tr style="background:#f8f9fa;">
    <td style="padding:8px;"><b>📄 Detection Details</b></td>
    <td style="padding:8px;">{detection_desc}</td>
    </tr>

    <tr>
    <td style="padding:8px;"><b>✅ Recommended Step</b></td>
    <td style="padding:8px;">{step_name}</td>
    </tr>

    </table>


    <br>

    {query_html}

    {metadata_html}

    <br>

    <div style="background:#f1f8ff; padding:12px; border-radius:6px;">
    💡 <b>Recommendation:</b> Please review the issue and take corrective action as soon as possible.
    </div>

    <br>

    <div style="font-size:12px; color:#888;">
    Generated automatically by the monitoring system.
    </div>

    </div>
    </body>
    </html>
    """

    try:
        pg_connection_string = get_connection_string()
        conn = psycopg2.connect(pg_connection_string)
        cur = conn.cursor()

        p_sqlcmd = """
                SELECT 
                    c_mc.mail_sender,
                    c_mc.smtp_port,
                    c_mc.smtp_user,
                    c_mc.smtp_password,
                    c_mc.tls,
                    c_mc.smtp_server , 
                    mg.recipients
                FROM config.mail_config c_mc
                join config.mail_groups mg on mg.mail_config_id = c_mc.row_id  
            """
        cur.execute(p_sqlcmd)
        row = cur.fetchone()
        conn.commit()   # release the config-read transaction BEFORE the SMTP send,
                        # so the connection is never left "idle in transaction"
                        # while blocked on the (potentially slow) mail server.
        if row:
            mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server, recipients = row
            try:
                msg = EmailMessage()
                msg["Subject"] = f"🚨 Security Alert: {formated_subject}"
                msg["From"] = mail_sender
                msg["To"] = recipients
                msg.set_content(f"🚨 Security alert detected: {formated_subject}. Please view this email in HTML")
                msg.add_alternative(formatted_description, subtype="html")
                with _smtp_lock:
                    try:
                        mail_server = _get_smtp_connection(smtp_server, smtp_port, tls, smtp_user, smtp_password)
                        mail_server.send_message(msg)
                        _smtp_state["cooldown_until"] = 0  # success clears any cooldown
                    except Exception:
                        # login/send failed -> drop the cached connection and start a
                        # cooldown so we stop hammering a rate-limited server (454).
                        _reset_smtp_cache()
                        _smtp_state["cooldown_until"] = time.time() + _SMTP_COOLDOWN
                        raise  # logged by the outer handler
                # connection kept open for reuse (no per-alert quit/login)

                # Log to mail_alert_log for 72-hour dedup
                _meta_json = None
                if display_results is not None:
                    try:
                        _meta_json = json.dumps(display_results) if not isinstance(display_results, str) else display_results
                    except Exception:
                        pass
                cur.execute(
                    """INSERT INTO alerts.mail_alert_log
                       (server, metric_name, transaction_type, body, recipients, subject,
                        login_name, metric_metadata_json)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                    (server, root_cause_id, transaction_type,
                     root_cause_desc, recipients, formated_subject,
                     login_name, _meta_json)
                )
                conn.commit()
                db_write_log(f"send_mail_alert_no_attachment succeeded for {root_cause_id}", 0, "send_mail_alert_no_attachment", server)

            except Exception as e:
                db_write_log(f"send_mail_alert_no_attachment failed with error:{e}", 0, "send_mail_alert_no_attachment", server)

    except Exception as e:
        db_write_log(f"send_mail_alert_no_attachment failed with error:{e}", 0, "send_mail_alert_no_attachment", server)
    finally:
        try:
            cur.close()
            conn.close()
        except Exception:
            pass
            
    
    


def send_alert_email_and_log(
                        smtp_server,
                        smtp_port,
                        smtp_user,
                        smtp_password,
                        recipients,
                        body,
                        subject,    
                        report_url , 
                        report_user , 
                        report_password , 
                        use_tls   ,
                        metric_result_row_id, 
                        server, 
                        transaction_type, 
                        metric_name,  
                        interval_secs, 
                        start_time, 
                        end_time
):
    status = "SUCCESS"
    error_msg = None
    filename = "report_to_send"
    file_path = ssrs_download_alert_report(report_url,report_user , report_password , filename ,  output_dir="." )
    # --- Send Email ---
    try:
        msg = MIMEMultipart()
        msg["From"] = smtp_user
        msg["To"] = recipients
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain"))
        # Attach file
        with open(file_path, "rb") as f:
            part = MIMEApplication(f.read(), Name=file_path)
            part['Content-Disposition'] = f'attachment; filename="{file_path}"'
            msg.attach(part)
        context = ssl.create_default_context()

        if use_tls:
            smtp_port = 587
            server = smtplib.SMTP(smtp_server, smtp_port, timeout=20)
            server.starttls(context=context)
        else:
            server = smtplib.SMTP_SSL(smtp_server, smtp_port, context=context, timeout=10)

        server.login(smtp_user, decrypt_secret(smtp_password))
        server.sendmail(smtp_user, recipients, msg.as_string())
        server.quit()

    except Exception as e:
        status = "FAILED"
        error_msg = str(e)

    # --- Store in DB ---
    db_conn_params = get_connection_string()
    if db_conn_params:
        try:
            conn = psycopg2.connect(get_connection_string())
            cur = conn.cursor()

            cur.execute("""
                INSERT INTO alerts.mail_alert_log (                        
                        metric_result_row_id,  transaction_type, metric_name, body, recipients, report_url, subject, interval_secs, start_time, end_time
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                        metric_result_row_id,  transaction_type, metric_name, body, recipients, report_url, subject, interval_secs, start_time, end_time
            ))

            conn.commit()
            cur.close()
            conn.close()
        except Exception as db_err:
            db_write_log(f"Failure", {db_err} ,"send_alert_email_and_log","mail_server" )

    return status, error_msg

def send_mail_with_pdf_attachment( report_name , recipients , source ,file_name , smtp_user , smtp_server , smtp_port , password ,mail_sender,tls):
    if smtp_user is None : 
        try:    
            msg = EmailMessage()
            msg["Subject"] = f"DBDOME – {report_name}"
            msg["From"] = mail_sender
            msg["To"] = recipients
            msg.set_content(f"{report_name}")

            with open(file_name, "rb") as f:
                msg.add_attachment(
                f.read(),
                maintype="application",
                subtype="pdf",
                filename=file_name
            )

            server = smtplib.SMTP(smtp_server, smtp_port)
            if tls:
                server.starttls()
            server.send_message(msg)
            server.quit()
        except Exception as e:
            status = "FAILED"        
            db_write_log(f"send_mail_with_attachment failed with error:{e}"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment" )  
        finally:
            db_write_log(f"send_mail_with_attachment completed"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment completed" )  
    
    else:
        try:  
            msg = EmailMessage()
            msg["Subject"] = f"DBDOME – {report_name}"
            msg["From"] = mail_sender
            msg["To"] = recipients
            msg.set_content(f"{report_name}")

            with open(file_name, "rb") as f:
                msg.add_attachment(
                f.read(),
                maintype="application",
                subtype="pdf",
                filename=file_name
            )

            server = smtplib.SMTP(smtp_server, smtp_port)
            if tls:
                server.starttls()
            server.login(smtp_user, decrypt_secret(password))
            server.send_message(msg)
            server.quit()
        except Exception as e:
            status = "FAILED"        
            db_write_log(f"send_mail_with_attachment failed with error:{e}"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment" )  
        finally:
            db_write_log(f"send_mail_with_attachment completed"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment completed" )  
      


def send_email_with_attachment(
                          smtp_server,
                        smtp_port,
                        smtp_user,
                        smtp_password,
                        recipients,
                        body,
                        subject,    
                        report_url , 
                        report_user , 
                        report_password , 
                        tls   ,                        
                        start_time, 
                        end_time
                        ):
   status = "SUCCESS"
   error_msg = None
   filename = "report_to_send"
   file_path = ssrs_download_alert_report_with_params(report_url,report_user , report_password , filename ,  start_time , end_time ,  output_dir="." )
    # --- Send Email ---
   try:
        msg = MIMEMultipart()
        msg["From"] = smtp_user
        msg["To"] = recipients
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain"))
        # Attach file
        with open(file_path, "rb") as f:
            part = MIMEApplication(f.read(), Name=file_path)
            part['Content-Disposition'] = f'attachment; filename="{file_path}"'
            msg.attach(part)
        context = ssl.create_default_context()

        if tls:
            smtp_port = 587
            server = smtplib.SMTP(smtp_server, smtp_port, timeout=20)
            server.starttls(context=context)
        else:
            server = smtplib.SMTP_SSL(smtp_server, smtp_port, context=context, timeout=10)

        server.login(smtp_user, decrypt_secret(smtp_password))
        server.sendmail(smtp_user, recipients, msg.as_string())
        server.quit()

   except Exception as e:
        status = "FAILED"
        error_msg = str(e)

   return status, error_msg



def send_mail_with_attachment( pdf_path ,  report_name , recipients , source ,file_name , smtp_user , smtp_server , smtp_port , password ,mail_sender,tls):
    """Send a report PDF by mail. RAISES on failure (and logs it) so callers
    can tell a failed send from a successful one — a swallowed SMTP error here
    previously made scheduled reports report success while nothing arrived."""
    try:
        msg = EmailMessage()
        msg["Subject"] = f"DBDOME – {report_name}"
        msg["From"] = mail_sender
        msg["To"] = recipients
        msg.set_content(f"{report_name}")

        with open(pdf_path, "rb") as f:
            msg.add_attachment(
                f.read(),
                maintype="application",
                subtype="pdf",
                filename=file_name
            )

        server = smtplib.SMTP(smtp_server, smtp_port)
        if tls:
            server.starttls()
        if smtp_user is not None:
            server.login(smtp_user, decrypt_secret(password))
        server.send_message(msg)
        server.quit()
        db_write_log(f"send_mail_with_attachment sent '{report_name}' to {recipients}", 0, "send_mail_with_attachment", "")
    except Exception as e:
        db_write_log(f"send_mail_with_attachment failed with error:{e}", 0, "send_mail_with_attachment", "send_mail_with_attachment")
        raise


def send_mail_with_html_attachment(
                    report , 
                    pdf_file,
                    html_file,
                    recipients,
                    mail_sender,
                    smtp_user,
                    smtp_server,
                    smtp_port,
                    smtp_password,
                    tls , 
                    conn
                    ):

    try:

        cursor = conn.cursor()

        cursor.execute("""
            SELECT
    h.html_content html_data,    
    p.pdf_data
FROM reports.html_reports h
JOIN reports.pdf_reports p
ON p.file_name = %s
WHERE h.file_name = %s
        """, (pdf_file,html_file))

        row = cursor.fetchone()

        if row is None:
            raise Exception("HTML report not found")

        html_data,pdf_data = row


        if isinstance(pdf_data, memoryview):
            pdf_bytes = pdf_data.tobytes()
        else:
            pdf_bytes = pdf_data

        msg = EmailMessage()
        msg["Subject"] = f"🚨 dbdome Report: {report}"
        msg["From"] = mail_sender
        msg["To"] = recipients

        # Plain text fallback
        msg.set_content(f"🚨 Report: {report}. Please view this email in HTML.")

        # HTML body
        msg.add_alternative(html_data, subtype="html")

        # HTML attachment
        msg.add_attachment(
            html_data.encode("utf-8"),
            maintype="text",
            subtype="html",
            filename=html_file
        )

        # PDF attachment
        msg.add_attachment(
            pdf_bytes,
            maintype="application",
            subtype="pdf",
            filename=pdf_file
        )

        server = smtplib.SMTP(smtp_server, smtp_port)

        if tls:
            server.starttls()

        if smtp_user:
            server.login(smtp_user, decrypt_secret(smtp_password))

        server.send_message(msg)
        server.quit()

        db_write_log(
            "send_mail_with_attachment completed",
            0,
            "send_mail_with_attachment",
            "send_mail_with_attachment completed"
        )

    except Exception as e:

        db_write_log(
            f"send_mail_with_attachment failed with error:{e}",
            0,
            "send_mail_with_attachment",
            "send_mail_with_attachment"
        )


def send_report_files_email(subject, recipients, file_paths, mail_sender,
                            smtp_user, smtp_server, smtp_port, smtp_password, tls):
    """Email on-disk report files (html/pdf) as attachments.

    Unlike send_mail_with_html_attachment (which reads the report from the
    reports.* DB tables and needs a live `conn`, and swallows all errors), this
    attaches the files JSONReportGenerator actually writes to disk and RAISES on
    failure so the caller can report it. `recipients` may be a comma-separated
    string. Returns the list of attached file basenames."""
    # Read files first. set_content() must be called BEFORE any add_attachment()
    # (the first attachment converts the message to multipart, after which
    # set_content raises "set_content not valid on multipart").
    atts, html_body = [], None
    for fp in (file_paths or []):
        if not fp or not os.path.isfile(fp):
            continue
        low = fp.lower()
        if low.endswith(".html"):
            with open(fp, "r", encoding="utf-8", errors="ignore") as f:
                data = f.read()
            if html_body is None:
                html_body = data
            atts.append((data.encode("utf-8"), "text", "html", os.path.basename(fp)))
        elif low.endswith(".pdf"):
            with open(fp, "rb") as f:
                atts.append((f.read(), "application", "pdf", os.path.basename(fp)))
        elif low.endswith(".csv"):
            with open(fp, "rb") as f:
                atts.append((f.read(), "text", "csv", os.path.basename(fp)))
    if not atts:
        raise Exception("no report files found to attach")
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = mail_sender
    msg["To"] = recipients
    msg.set_content("Report attached. Please view the HTML or PDF attachment.")
    if html_body is not None:
        msg.add_alternative(html_body, subtype="html")
    for (payload, maintype, subtype, filename) in atts:
        msg.add_attachment(payload, maintype=maintype, subtype=subtype, filename=filename)
    attached = [a[3] for a in atts]
    s = smtplib.SMTP(smtp_server, int(smtp_port), timeout=30)
    try:
        if tls:
            s.starttls()
        if smtp_user and str(smtp_user).strip():
            s.login(smtp_user, decrypt_secret(smtp_password))
        s.send_message(msg)
    finally:
        try:
            s.quit()
        except Exception:
            pass
    return attached



