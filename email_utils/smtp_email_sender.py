import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import psycopg2
from datetime import datetime
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from email.mime.application import MIMEApplication
from ssrs.ssrs_report_download import ssrs_download_alert_report , ssrs_download_alert_report_with_params
import smtplib
from email.message import EmailMessage
import os
import pandas 


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
                        transaction_type='security_alert'
):
    # ========== Risk-level gate: skip if risk_level is disabled ==========
    try:
        gate_conn = psycopg2.connect(get_connection_string())
        gate_cur  = gate_conn.cursor()
        gate_cur.execute(
            "SELECT is_active FROM rootcause.risk_level "
            "WHERE lower(trim(risk_level)) = lower(trim(%s)) LIMIT 1",
            (risk_level or "",),
        )
        gate_row = gate_cur.fetchone()
        gate_cur.close()
        gate_conn.close()
        if gate_row is None or not gate_row[0]:
            db_write_log(
                f"Alert skipped for {root_cause_id} on {server} - risk_level '{risk_level}' is disabled or unknown",
                0, "send_mail_alert_no_attachment", server,
            )
            return
    except Exception as _gate_ex:
        db_write_log(f"risk_level gate check failed: {_gate_ex}", 0,
                     "send_mail_alert_no_attachment", server)

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
            (server, root_cause_id)
        )
        #else:
        #    dedup_cur.execute(
        #    """SELECT COUNT(*) FROM alerts.mail_alert_log
        #       WHERE server = %s AND metric_name = %s
        #         AND entry_date > NOW() - INTERVAL '72 hours'""",
        #    (server, root_cause_id)
        #)
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

    query_html = ""
    if query:
        query_html = f"""
        <h3 style="margin-top:20px;">📊 Detection Query</h3>
        <pre style="background:#f4f4f4; padding:12px; border-radius:6px; font-size:13px; overflow-x:auto; border:1px solid #ddd;">{query}</pre>
        """

    comparison_html = ""
    if expected is not None or comparison_data is not None:
        comparison_html = '<h3 style="margin-top:20px;">📈 Comparison</h3>'
        comparison_html += '<table style="border-collapse: collapse; width:100%; font-size:14px;">'
        if expected is not None:
            comparison_html += f"""
            <tr style="background:#f8f9fa;">
            <td style="padding:8px; border:1px solid #ddd;"><b>Expected</b></td>
            <td style="padding:8px; border:1px solid #ddd;">{expected}</td>
            </tr>"""
        if comparison_data is not None:
            comparison_html += f"""
            <tr>
            <td style="padding:8px; border:1px solid #ddd;"><b>Actual</b></td>
            <td style="padding:8px; border:1px solid #ddd;">{comparison_data}</td>
            </tr>"""
        if metric_metadata_json is not None:
            comparison_html += f"""
            <tr>
            <td style="padding:8px; border:1px solid #ddd;"><b>Actual</b></td>
            <td style="padding:8px; border:1px solid #ddd;">{metric_metadata_json}</td>
            </tr>"""
        comparison_html += '</table>'


    formated_subject = f"[{transaction_type}] {server} - Risk: {risk_level}, area: {area_name}, domain: {domain_name}, issue: {issue_name}"
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

    {comparison_html}

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
        if row:
            mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server, recipients = row
            try:
                msg = EmailMessage()
                msg["Subject"] = f"🚨 Security Alert: {formated_subject}"
                msg["From"] = mail_sender
                msg["To"] = recipients
                msg.set_content(f"🚨 Security alert detected: {formated_subject}. Please view this email in HTML")
                msg.add_alternative(formatted_description, subtype="html")
                mail_server = smtplib.SMTP(smtp_server, smtp_port, timeout=30)
                mail_server.ehlo()
                if tls:
                    mail_server.starttls()
                    mail_server.ehlo()
                if smtp_user and smtp_user.strip():
                    mail_server.login(smtp_user, smtp_password)
                mail_server.send_message(msg)
                mail_server.quit()

                # Log to mail_alert_log for 72-hour dedup
                cur.execute(
                    """INSERT INTO alerts.mail_alert_log
                       (server, metric_name, transaction_type, body, recipients, subject)
                       VALUES (%s, %s, %s, %s, %s, %s)""",
                    (server, root_cause_id, transaction_type,
                     root_cause_desc, recipients, formated_subject)
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

        server.login(smtp_user, smtp_password)
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
            server.login(smtp_user, password)
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

        server.login(smtp_user, smtp_password)
        server.sendmail(smtp_user, recipients, msg.as_string())
        server.quit()

   except Exception as e:
        status = "FAILED"
        error_msg = str(e)

   return status, error_msg



def send_mail_with_attachment( pdf_path ,  report_name , recipients , source ,file_name , smtp_user , smtp_server , smtp_port , password ,mail_sender,tls):
    if smtp_user is None : 
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
            server.login(smtp_user, password)
            server.send_message(msg)
            server.quit()
        except Exception as e:
            status = "FAILED"        
            db_write_log(f"send_mail_with_attachment failed with error:{e}"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment" )  
        finally:
            db_write_log(f"send_mail_with_attachment completed"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment completed" )  
      

def send_mail_with_attachment( pdf_path ,  report_name , recipients , source ,file_name , smtp_user , smtp_server , smtp_port , password ,mail_sender,tls):
    if smtp_user is None : 
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
            server.login(smtp_user, password)
            server.send_message(msg)
            server.quit()
        except Exception as e:
            status = "FAILED"        
            db_write_log(f"send_mail_with_attachment failed with error:{e}"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment" )  
        finally:
            db_write_log(f"send_mail_with_attachment completed"   ,0,"send_mail_with_attachment" , "send_mail_with_attachment completed" )  
      
    

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
            server.login(smtp_user, smtp_password)

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



