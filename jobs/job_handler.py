import asyncio
#job_handler.py
import psycopg2
from datetime import datetime
from utils.utils_config_dotenv  import get_connection_string
from utils.log4dbexpert  import db_write_log
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
import pandas as pd
import reportlab
from reportlab.lib.pagesizes import A4,landscape
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
import os
from datetime import datetime
import smtplib
from  email_utils.smtp_email_sender import send_mail_with_attachment , send_mail_with_pdf_attachment
from reportlab.platypus import (
    SimpleDocTemplate, Table, TableStyle,
    Image, Paragraph, Spacer
)
from reportlab.lib.units import cm
from datetime import datetime
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from print_utils.dasboard_capture import capture_grafana_dashboard_pdf
from ReportGenerator.json_report_generator import JSONReportGenerator
cell_style = ParagraphStyle(
    name="CellStyle",
    fontName="Helvetica",
    fontSize=9,
    leading=11,
    alignment=TA_LEFT,
    wordWrap='CJK'  # best wrap behavior
    )
    

def job_update_next_run_time (job_id , duration_secs,next_runtime ):
    pg_connection_string = get_connection_string()
    conn = psycopg2.connect(pg_connection_string)

    cur = conn.cursor()
    cur.execute(f"update jobs.monitoring_jobschdules set next_run_time = NOW() + INTERVAL '{duration_secs} seconds'")
    conn.commit()
    cur.close()
    conn.close()


def job_history_write (job_id ):
    pg_connection_string = get_connection_string()
    conn = psycopg2.connect(pg_connection_string)

    cur = conn.cursor()
    try:
        cur.execute(
            "insert into job.monitoring_job_history (job_id) values ( %s)",
            (job_id )
        )
    except Exception as e:                 
                db_write_log(f"monitoring_job_history failed with error:{e}"   , 0 ,"monitoring_job_history" ,"" )
    finally:
        conn.commit()
        cur.close()
        conn.close()


def job_next_run():
        pg_connection_string = get_connection_string()   
        # ========== 2. Create SQLAlchemy Engines ==========
        # PostgreSQL (target)

    # Connect to the PostgreSQL database
        

    # Create a cursor
        

        raw_conn = psycopg2.connect(pg_connection_string)
        p_sql_cmd = f"""              
        Select  	
  report_id,
    job_id,
    next_run,
    report_name,
    report_query,
    occurance,
    occurs_at,
    schedule_type,
    recipients,
    smtp_password,
    smtp_port,
    smtp_server,
    smtp_user,
    tls,
    mail_sender , 
	alert_id , 
	alert_name , 
	alert_query , 
	value_start , 
	value_end , 
    report_url
	    from monitoring.v_job_scheduler        
        """            
        try:
            cur = raw_conn.cursor()
            cur.execute(p_sql_cmd)
            rows = cur.fetchall()
            
            for row in rows:                                                
                        report_id           = row[0]
                        job_id              = row[1]
                        next_run            = row[2]
                        report_name         = row[3]
                        report_query        = row[4]
                        occurance           = row[5]
                        occurs_at           = row[6]
                        schedule_type       = row[7]
                        recipients          = row[8]
                        smtp_password       = row[9]
                        smtp_port           = row[10]
                        smtp_server         = row[11]
                        smtp_user           = row[12]
                        tls                 = row[13]
                        mail_sender         = row[14] 
                        alert_id            = row[15]
                        alert_name          = row[16]	                    
                        alert_query         = row[17] 	                    
                        value_start         = row[18] 	                    
                        value_end           = row[19]	                    
                        report_url          = row[20]	                    
	                    
                        
                        if not alert_name or not alert_query or not alert_query.strip():
                            alert_triggered = 0
                        else:
                            alert_triggered = is_alert(
                                raw_conn,
                                alert_id,
                                alert_name,
                                alert_query,
                                value_start,
                                value_end
                            )
                        if not alert_triggered and alert_name:
                              continue
                        
                        if report_url is not None:
                            try:        
                                generator = JSONReportGenerator(report_url)
                                pdf_file = generator.generate()  
                                conn = psycopg2.connect(pg_connection_string)
                                cur = conn.cursor()
                                p_sqlcmd = """
                                            SELECT 
                                                c_mc.mail_sender,
                                                c_mc.smtp_port,
                                                c_mc.smtp_user,
                                                c_mc.smtp_password,
                                                c_mc.tls,
                                                c_mc.smtp_server
                                            FROM config.mail_config c_mc
                                        """
                                cur.execute(p_sqlcmd)
                                row = cur.fetchone()
                                if row:
                                            mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server = row
                                            # Call your email function
                                            send_mail_with_pdf_attachment(
                                                report_url,
                                                recipients,
                                                mail_sender,
                                                pdf_file,
                                                smtp_user,
                                                smtp_server,
                                                smtp_port,
                                                smtp_password,
                                                mail_sender,
                                                tls
                                            ) 
                                            db_write_log(f"send_alert_email_and_log succeeded", 0 ,"send_alert_email_and_log" ,"")   
                            except Exception as e:               
                                    db_write_log(f"generate_report failed with error:{e}"   , 0 ,"generate_report" ,"generate_report")
                            finally:                  
                                        
                                            #  Clean up
                                            cur.close()
                                            conn.close()
                                   




                        else:
                            columns , rows = fetch_data_report(raw_conn , report_query) 
                            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

                            # Build PDF path
                            output_dir = os.path.join(os.getcwd(), "reports")

                            # Make sure the folder exists
                            os.makedirs(output_dir, exist_ok=True)

                            # Generate timestamp
                            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

                            # Build PDF path
                            pdf_filename = f"{report_name}_{timestamp}.pdf"
                            pdf_path = os.path.join(output_dir, pdf_filename)
                            try:
                                header = alert_name if alert_triggered else report_name
                                export_to_pdf(
                                            columns,
                                            rows,
                                            pdf_path,
                                            logo_path="./icons/logo.png",
                                            _header=header
                                        )
                                send_mail_with_attachment(pdf_path , report_name , recipients , mail_sender,pdf_filename ,smtp_user, smtp_server , smtp_port , smtp_password,mail_sender,tls)
                            finally:
                                if os.path.exists(pdf_path):
                                    os.remove(pdf_path)
                            # ========== 4. Bulk UPSERT into PostgreSQL ==========
                            raw_conn = psycopg2.connect(pg_connection_string)
                            cur = raw_conn.cursor()

                            cur.execute(
                                "CALL jobs.job_schedule_insert(%s, %s);",
                            (report_id, job_id)
                            )

                            raw_conn.commit()
                            cur.close()
                            raw_conn.close()
            
        except Exception as e:                 
                    db_write_log(f"job_next_run failed with error:{e}"   ,0,"job_next_run" , "job_next_run" )
        finally:
            db_write_log(f"✅ job_next_run  complete."   ,0,"job_next_run" , "job_next_run" )
            raw_conn.close()


def   fetch_data_report_once (_conn , _query , report_name ,start_time , end_time):
            try:
                cur = _conn.cursor()
                cur.execute(_query, (start_time, end_time))
                rows = cur.fetchall()
                columns = [desc[0] for desc in cur.description]

                cur.close()
                _conn.close()                
            except Exception as e:                 
                    db_write_log(f"fetch_data_report failed with error:{e}"   ,0,"fetch_data_report" , "fetch_data_report" )
            finally:
                db_write_log(f"✅ fetch_data_report  complete."   ,0,"fetch_data_report" , "fetch_data_report" )
                _conn.close()
                return columns, rows
         
def   fetch_data_report (_conn , _query ):
            try:
                cur = _conn.cursor()
                cur.execute(_query)
                rows = cur.fetchall()
                columns = [desc[0] for desc in cur.description]

                cur.close()
                _conn.close()                
            except Exception as e:                 
                    db_write_log(f"fetch_data_report failed with error:{e}"   ,0,"fetch_data_report" , "fetch_data_report" )
            finally:
                db_write_log(f"✅ fetch_data_report  complete."   ,0,"fetch_data_report" , "fetch_data_report" )
                _conn.close()
                return columns, rows

_MAX_CELL_CHARS = 2500  # one row with CJK wrap stays under landscape-A4 frame height

def wrap_cell(value):
    import html as _html
    if value is None:
        return ""
    if isinstance(value, (int, float)):
        return str(value)
    s = str(value)
    if len(s) > _MAX_CELL_CHARS:
        s = s[:_MAX_CELL_CHARS] + " …[truncated]"
    return Paragraph(_html.escape(s), cell_style)

def export_to_pdf(columns, rows, pdf_path, logo_path, _header):    
    pagesize = landscape(A4)

  

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=pagesize,
        rightMargin=2*cm,
        leftMargin=2*cm,
        topMargin=2*cm,
        bottomMargin=1.5*cm
    )

    cell_style = ParagraphStyle(
    name="CellStyle",
    fontName="Helvetica",
    fontSize=9,
    leading=11,
    alignment=TA_LEFT,
    wordWrap='CJK'  # best wrap behavior
)
    styles = getSampleStyleSheet()
    elements = []

    # ---------- Header ----------
    header_table_data = []

    if logo_path:
        logo = Image(logo_path, width=4*cm, height=1.5*cm)
        header_table_data.append([
            logo,
            Paragraph(
                f"<b>{_header}</b><br/>"
                f"<font size=9>Generated: {datetime.now():%Y-%m-%d %H:%M}</font>",
                styles["Normal"]
            )
        ])
    else:
        header_table_data.append([
            Paragraph(
                f"<b>{_header}</b><br/>"
                f"<font size=9>Generated: {datetime.now():%Y-%m-%d %H:%M}</font>",
                styles["Normal"]
            )
        ])

    header = Table(
        header_table_data,
        colWidths=[5*cm, None]
    )

    header.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 12),
    ]))

    elements.append(header)
    elements.append(Spacer(1, 12))

    # ---------- Data Table ----------
    table_data = [
    columns
    ] + [
    [wrap_cell(cell) for cell in row]
    for row in rows
    ]
    

    table = Table(table_data, repeatRows=1)

    table.setStyle(TableStyle([
        # Header
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#2F4F4F")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('FONT', (0,0), (-1,0), 'Helvetica-Bold'),

        # Body
        ('FONT', (0,1), (-1,-1), 'Helvetica'),
        ('BACKGROUND', (0,1), (-1,-1), colors.beige),
        ('ROWBACKGROUNDS', (0,1), (-1,-1),
         [colors.whitesmoke, colors.lightgrey]),

        # Grid & alignment
        ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),

        # Padding
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))

    elements.append(table)

    # ---------- Footer with page numbers ----------
    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 9)
        canvas.drawRightString(
            pagesize[0] - 2*cm,
            1*cm,
            f"Page {doc.page}"
        )
        canvas.restoreState()

    doc.build(elements, onLaterPages=footer, onFirstPage=footer)





def export_to_pdf_once(columns, rows, pdf_path,start_time,end_time, logo_path, _header):    
    pagesize = landscape(A4)

  

    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=pagesize,
        rightMargin=2*cm,
        leftMargin=2*cm,
        topMargin=2*cm,
        bottomMargin=1.5*cm
    )

    cell_style = ParagraphStyle(
    name="CellStyle",
    fontName="Helvetica",
    fontSize=9,
    leading=11,
    alignment=TA_LEFT,
    wordWrap='CJK'  # best wrap behavior
)
    styles = getSampleStyleSheet()
    elements = []

    # ---------- Header ----------
    header_table_data = []

    if logo_path:
        logo = Image(logo_path, width=4*cm, height=1.5*cm)
        header_table_data.append([
            logo,
            Paragraph(
                f"<b>{_header}</b><br/>"
                f"<font size=9>Generated: {datetime.now():%Y-%m-%d %H:%M}</font>",
                styles["Normal"]
            )
        ])
    else:
        header_table_data.append([
            Paragraph(
                f"<b>{_header}</b><br/>"
                f"<font size=9>Generated: {datetime.now():%Y-%m-%d %H:%M}</font>",
                styles["Normal"]
            )
        ])

    header = Table(
        header_table_data,
        colWidths=[5*cm, None]
    )

    header.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 12),
    ]))

    elements.append(header)
    elements.append(Spacer(1, 12))

    # ---------- Data Table ----------
    table_data = [
    columns
    ] + [
    [wrap_cell(cell) for cell in row]
    for row in rows
    ]
    

    table = Table(table_data, repeatRows=1)

    table.setStyle(TableStyle([
        # Header
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#2F4F4F")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('FONT', (0,0), (-1,0), 'Helvetica-Bold'),

        # Body
        ('FONT', (0,1), (-1,-1), 'Helvetica'),
        ('BACKGROUND', (0,1), (-1,-1), colors.beige),
        ('ROWBACKGROUNDS', (0,1), (-1,-1),
         [colors.whitesmoke, colors.lightgrey]),

        # Grid & alignment
        ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),

        # Padding
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))

    elements.append(table)

    # ---------- Footer with page numbers ----------
    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 9)
        canvas.drawRightString(
            pagesize[0] - 2*cm,
            1*cm,
            f"Page {doc.page}"
        )
        canvas.restoreState()

    doc.build(elements, onLaterPages=footer, onFirstPage=footer)




def is_alert(raw_conn , alert_id , alert_name , alert_query , value_start , value_end ):
    is_alert = 0;
    try:
            cur = raw_conn.cursor()
            cur.execute(alert_query)
            rows = cur.fetchall()
            
            for row in rows:                                                
                        actual_alert_value    = row[0]  
            is_alert = actual_alert_value>= value_start and actual_alert_value <= value_end                       
            
    except Exception as e:                 
                    db_write_log(f"is_alert failed with error:{e}"   ,0,"is_alert" , "is_alert" )
                    return 0
    finally:
            db_write_log(f"✅ is_alert  complete."   ,0,"is_alert" , "is_alert" )
            return is_alert

def   fetch_data_report_once (_conn , _query , report_name ,start_time , end_time, server):
            try:
                cur = _conn.cursor()
                cur.execute(_query, (start_time, end_time,server))
                rows = cur.fetchall()
                columns = [desc[0] for desc in cur.description]

                cur.close()
                _conn.close()                
            except Exception as e:                 
                    db_write_log(f"fetch_data_report failed with error:{e}"   ,0,"fetch_data_report" , "fetch_data_report" )
            finally:
                db_write_log(f"✅ fetch_data_report  complete."   ,0,"fetch_data_report" , "fetch_data_report" )
                _conn.close()
                return columns, rows            