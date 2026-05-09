from utils.config_dotenv import get_connection_string
import psycopg2
from utils.log4dbexpert import db_write_log
from jobs.job_handler  import job_update_next_run_time
from jobs.job_handler  import job_history_write
from email_utils.smtp_email_sender import send_alert_email_and_log

def email_sender_operation():
    #postgresql connection
    pg_connection_string = get_connection_string()

    # Connect to the PostgreSQL database
    conn = psycopg2.connect(pg_connection_string)

    # Create a cursor
    cur = conn.cursor()

    # Query the view
    p_sqlcmd = f""" 
    select 
    metric_result_row_id , 
    server, 
    transaction_type, 
    metric_name, 
    body, 
    recipients, 
    report_password, 
    report_user, 
    report_url, 
    subject, 
    smtp_server, 
    smtp_password, 
    smtp_user, 
    smtp_port, 
    TLS , 
    interval_secs, 
    start_time, 
    end_time,
    next_time from 
	(
select 
  row_number() over (partition by server, transaction_type, metric_name )seq ,  	
   metric_result_row_id,
    server, 
    transaction_type, 
    metric_name, 
    body, 
    recipients, 
    report_password, 
    report_user, 
    report_url, 
    subject, 
    smtp_server, 
    smtp_password, 
    smtp_user, 
    smtp_port, 
    TLS , 
    interval_secs, 
    start_time, 
    end_time,
    next_time 
from config.v_mail_alert_schedule
) where seq=1
"""
    try:
        cur.execute(p_sqlcmd)

        # Fetch and print rows
        rows = cur.fetchall()
        for row in rows:
            metric_result_row_id    = row[0] 
            server                  = row[1]
            transaction_type        = row[2]
            metric_name             = row[3]
            body                    = row[4]
            recipients              = row[5]
            report_password         = row[6]
            report_user             = row[7]
            report_url              = row[8]    
            subject                 = row[9]
            smtp_server             =row[10]
            smtp_password           =row[11]
            smtp_user               = row[12]        
            smtp_port               = row[13]        
            tls                     = row[14]
            interval_secs           = row[15]
            start_time              = row[16]
            end_time                = row[17]
        
            _body = body.replace("{transaction_type}", transaction_type).replace("{server}", server)
            result = send_alert_email_and_log(                       
                        smtp_server,
                        smtp_port,
                        smtp_user,
                        smtp_password,
                        recipients,
                        _body,
                        _body,    
                        report_url , 
                        report_user , 
                        report_password , 
                        tls   ,
                        metric_result_row_id, 
                        server, 
                        transaction_type, 
                        metric_name,  
                        interval_secs, 
                        start_time, 
                        end_time
            )
            db_write_log(f"send_alert_email_and_log succeeded", result ,"collect_metric_active_transactions",smtp_server , port=smtp_port)                        
    except Exception as e:                 
                    db_write_log(f"send_alert_email_and_log failed with error:{e}"   , result ,"send_alert_email_and_log" ,smtp_server, port=smtp_port)
                    result = "default"
    finally:
                    db_write_log(f"send_alert_email_and_log succeeded", result ,"send_alert_email_and_log" ,"")
                    result = "default"
               
    # Clean up
    cur.close()
    conn.close()

    







