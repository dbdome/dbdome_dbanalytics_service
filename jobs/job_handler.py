import asyncio
#job_handler.py
from processes.data_masking_engine import apply_masking
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
from  email_utils.smtp_email_sender import send_mail_with_attachment , send_mail_with_pdf_attachment , send_report_files_email
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
    

def apply_server_filter(query, server_name):
    """Substitute the {server} placeholder in a report query.

    Selected server -> its name (quotes doubled for SQL-literal safety);
    no server filter -> '%' so `server LIKE '{server}'` matches everything.
    """
    if not query or '{server}' not in query:
        return query
    value = (server_name or '').replace("'", "''") or '%'
    return query.replace('{server}', value)


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
    report_url ,
    server_name
	    from monitoring.v_job_scheduler
        """
        try:
            cur = raw_conn.cursor()
            cur.execute(p_sql_cmd)
            rows = cur.fetchall()

            # Visibility: how many reports the scheduler view considers due this
            # cycle. 0 due (nothing armed with last_run IS NULL and next_run<=now)
            # is the usual reason "nothing was emailed" — now it's in the log.
            # NB: `rows` is rebound to report DATA inside the loop, so hold the
            # due count separately for the end-of-cycle summary.
            _due = len(rows)
            db_write_log(f"job_next_run: {_due} scheduled report(s) due this cycle", 0, "job_next_run", "")

            _sent = 0
            _skipped = 0
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
                        server_name_filter  = row[21]

                        # Per-server report filter: {server} in report queries
                        # becomes the configured server ('%' when unfiltered),
                        # and the emailed report name carries the server.
                        report_query = apply_server_filter(report_query, server_name_filter)
                        if server_name_filter:
                            report_name = f"{report_name} - {server_name_filter}"

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
                              _skipped += 1
                              db_write_log(
                                  f"scheduled report '{report_name}' NOT sent — gating alert "
                                  f"'{alert_name}' is not currently triggered", 0, "job_next_run", "")
                              continue

                        # No recipients resolved (empty mail group / unlinked
                        # mail config) means the mail goes nowhere — surface it
                        # instead of "succeeding" silently, and don't re-arm.
                        if not recipients or not str(recipients).strip():
                            _skipped += 1
                            db_write_log(
                                f"scheduled report '{report_name}' NOT sent — no recipients "
                                f"resolved (check the mail group linked to its mail config)",
                                0, "job_next_run", "")
                            continue

                        if report_url is not None:
                            # Bind before the try: when generate() failed, the finally
                            # below touched an unassigned `conn`, raising UnboundLocalError
                            # OUT of the loop and killing every remaining report in the
                            # queue (one bad template silently blocked all the others).
                            conn = None
                            cur = None
                            try:
                                generator = JSONReportGenerator(report_url, server_name=server_name_filter)
                                # generate() returns (pdf_path, html_path, csv_path); the old
                                # code captured the whole tuple into pdf_file and the
                                # send failed, so scheduled reports were never emailed.
                                pdf_file, html_file, csv_file = generator.generate()
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
                                            # Email the actual generated files (raises on failure).
                                            send_report_files_email(
                                                (report_name or "DBDOME Report"),
                                                recipients,
                                                [html_file, pdf_file, csv_file],
                                                mail_sender,
                                                smtp_user,
                                                smtp_server,
                                                smtp_port,
                                                smtp_password,
                                                tls
                                            )
                                            _sent += 1
                                            db_write_log(f"scheduled report '{report_name}' emailed to {recipients}", 0 ,"job_next_run" ,"")
                                            # Mark it run — without this a JSON report stays
                                            # due in v_job_scheduler and re-emails every cycle.
                                            cur.execute("CALL jobs.job_schedule_insert(%s, %s);", (report_id, job_id))
                                            conn.commit()
                                else:
                                            db_write_log(
                                                f"scheduled report '{report_name}' NOT sent — "
                                                f"config.mail_config is empty (no SMTP configured)",
                                                0, "job_next_run", "")
                            except Exception as e:
                                    db_write_log(f"generate_report '{report_name}' failed with error:{e}", 0, "generate_report", "generate_report")
                                    continue   # leave it due; the next cycle retries it
                            finally:
                                            #  Clean up
                                            if cur is not None:
                                                cur.close()
                                            if conn is not None:
                                                conn.close()





                        else:
                            columns , rows = fetch_data_report(raw_conn , report_query)

                            # Build output paths (PDF + companion CSV)
                            output_dir = os.path.join(os.getcwd(), "reports")
                            os.makedirs(output_dir, exist_ok=True)
                            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

                            pdf_filename = f"{report_name}_{timestamp}.pdf"
                            pdf_path = os.path.join(output_dir, pdf_filename)
                            csv_filename = f"{report_name}_{timestamp}.csv"
                            csv_path = os.path.join(output_dir, csv_filename)
                            try:
                                header = alert_name if alert_triggered else report_name
                                export_to_pdf(
                                            columns,
                                            rows,
                                            pdf_path,
                                            logo_path="./icons/logo.png",
                                            _header=header
                                        )
                                # Companion CSV so SQL-query scheduled reports (e.g.
                                # DAM_report, transaction_report) go out as BOTH PDF
                                # and CSV, matching the JSON-template report path.
                                export_report_csv(columns, rows, csv_path)
                                send_report_files_email(
                                            (report_name or "DBDOME Report"),
                                            recipients,
                                            [pdf_path, csv_path],
                                            mail_sender,
                                            smtp_user,
                                            smtp_server,
                                            smtp_port,
                                            smtp_password,
                                            tls
                                        )
                                _sent += 1
                                db_write_log(f"scheduled report '{report_name}' emailed (PDF+CSV) to {recipients}", 0, "job_next_run", "")
                            except Exception as e:
                                # One failed report must not abort the rest of the
                                # queue; leave it due (no job_schedule_insert) so
                                # the next cycle retries it.
                                db_write_log(f"scheduled report '{report_name}' FAILED: {e}", 0, "job_next_run", "")
                                continue
                            finally:
                                for _tmp in (pdf_path, csv_path):
                                    if os.path.exists(_tmp):
                                        os.remove(_tmp)
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
            
            db_write_log(
                f"job_next_run: {_sent} report(s) emailed, {_skipped} skipped, "
                f"{_due} due this cycle", 0, "job_next_run", "")

        except Exception as e:
                    db_write_log(f"job_next_run failed with error:{e}"   ,0,"job_next_run" , "job_next_run" )
        finally:
            db_write_log(f"✅ job_next_run  complete."   ,0,"job_next_run" , "job_next_run" )
            raw_conn.close()


def   fetch_data_report_once (_conn , _query , report_name ,start_time , end_time, server_name="", db_user="", user_roles=None):
            columns, rows = [], []   # so a query error returns empty (not UnboundLocalError that aborts the whole report cycle)
            try:
                cur = _conn.cursor()
                cur.execute(_query, (start_time, end_time))
                rows = cur.fetchall()
                columns = [desc[0] for desc in cur.description]
                rows = apply_masking(rows, columns, server_name, db_user, user_roles=user_roles)
                cur.close()
                _conn.close()
            except Exception as e:
                    db_write_log(f"fetch_data_report failed with error:{e}"   ,0,"fetch_data_report" , "fetch_data_report" )
            finally:
                db_write_log(f"✅ fetch_data_report  complete."   ,0,"fetch_data_report" , "fetch_data_report" )
                _conn.close()
            return columns, rows

def   fetch_data_report (_conn , _query , server_name="", db_user="", user_roles=None):
            columns, rows = [], []   # so a query error returns empty (not UnboundLocalError that aborts the whole report cycle)
            try:
                cur = _conn.cursor()
                cur.execute(_query)
                rows = cur.fetchall()
                columns = [desc[0] for desc in cur.description]
                rows = apply_masking(rows, columns, server_name, db_user, user_roles=user_roles)
                cur.close()
                _conn.close()
            except Exception as e:
                    db_write_log(f"fetch_data_report failed with error:{e}"   ,0,"fetch_data_report" , "fetch_data_report" )
            finally:
                db_write_log(f"✅ fetch_data_report  complete."   ,0,"fetch_data_report" , "fetch_data_report" )
                _conn.close()
            return columns, rows

def export_report_csv(columns, rows, csv_path):
    """Write a scheduled report's resultset to CSV (UTF-8 BOM so Excel opens it
    cleanly) — the companion to export_to_pdf so SQL-query scheduled reports can
    be emailed as BOTH PDF and CSV, mirroring the JSON-template report path."""
    import csv as _csv
    with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
        w = _csv.writer(f)
        w.writerow([str(c) for c in (columns or [])])
        for r in (rows or []):
            w.writerow(["" if v is None else v for v in r])
    return csv_path


_MAX_CELL_CHARS = 2500  # one row with CJK wrap stays under landscape-A4 frame height

def wrap_cell(value, max_chars=_MAX_CELL_CHARS):
    import html as _html
    if value is None:
        return ""
    if isinstance(value, (int, float)):
        return str(value)
    s = str(value)
    if len(s) > max_chars:
        s = s[:max_chars] + " …"
    return Paragraph(_html.escape(s), cell_style)


def _cell_char_caps(col_widths, frame_height):
    """Per-column character cap so a cell can never wrap taller than the page.

    A long value (e.g. full SQL text) in a NARROW column wraps to many lines; with
    16 columns each column is ~45pt wide and an uncapped cell became 1400+pt tall,
    overflowing the page and aborting the PDF. For each column we allow at most
    (usable lines) × (chars per line at its width), so the tallest possible cell
    stays within one page.
    """
    LEADING = 11.0          # matches cell_style leading
    CHAR_PT = 7.0           # CONSERVATIVE char width: under-count chars/line so the
                            # cap never permits more lines than actually fit.
    # 0.80 safety factor: CJK char-wrap + padding make real height a bit more than
    # lines*leading, so leave headroom below the frame.
    max_lines = max(3, int((frame_height * 0.80) / LEADING))
    caps = []
    for w in (col_widths or []):
        chars_per_line = max(1, (w - 10) / CHAR_PT)   # minus L/R padding
        caps.append(max(20, int(chars_per_line * max_lines)))
    return caps


# Header cells must wrap too — a plain string header does not break, so a long
# column name forces the column wide (or off the page). Wrapping the header in a
# Paragraph lets a long header break onto several lines, like the body cells.
_HEADER_STYLE = ParagraphStyle(
    name="HeaderCellStyle",
    fontName="Helvetica-Bold",
    fontSize=9,
    leading=11,
    alignment=TA_LEFT,
    textColor=colors.whitesmoke,
    wordWrap='CJK',   # break long unbroken tokens anywhere, so nothing overflows
)


def _wrap_header(value):
    import html as _html
    return Paragraph(_html.escape("" if value is None else str(value)), _HEADER_STYLE)


def _compute_col_widths(columns, rows, avail_width):
    """Column widths that fill `avail_width` and let every column wrap.

    Without explicit widths reportlab sizes columns to their natural (unwrapped)
    content, so wordWrap never kicks in and wide values push the table off the
    page. We estimate each column's natural width from the longest header/cell
    text (sampled + capped), then scale the set to exactly fit the frame — so a
    long-text column gets proportionally more room, but the table always fits and
    both headers and cells wrap within their column.
    """
    n = len(columns)
    if n == 0:
        return None
    CHAR_PT = 5.1          # ~ width of one char at 9pt Helvetica
    PAD_PT  = 12           # left+right cell padding
    MIN_W   = 1.4 * cm     # a column never narrower than this
    MAX_W   = 9.0 * cm     # ...nor wider than this before scaling
    sample = rows[:500]    # bound cost on huge result sets
    naturals = []
    for i, col in enumerate(columns):
        longest = len(str(col))                    # header length counts too
        for r in sample:
            v = r[i]
            if v is not None:
                longest = max(longest, min(len(str(v)), 80))  # cap a giant cell's pull
        naturals.append(max(MIN_W, min(MAX_W, longest * CHAR_PT + PAD_PT)))
    total = sum(naturals)
    if total <= avail_width:
        # scale UP proportionally so the table spans the full frame width (tidier)
        factor = avail_width / total
        return [w * factor for w in naturals]
    # scale DOWN to fit the frame; wrapping absorbs the reduced width
    factor = avail_width / total
    return [w * factor for w in naturals]

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
    # Headers wrapped (so a long column name breaks onto multiple lines) plus
    # explicit column widths that fit the page. A per-column character cap keeps
    # any single cell (e.g. a long SQL statement in a narrow column) from wrapping
    # taller than one page, which would otherwise abort the PDF build.
    avail_width = pagesize[0] - 4 * cm     # landscape A4 minus 2cm L + 2cm R
    col_widths = _compute_col_widths(columns, rows, avail_width)
    frame_height = pagesize[1] - 3.5 * cm  # top 2cm + bottom 1.5cm margins
    caps = _cell_char_caps(col_widths, frame_height)

    def _cap(i):
        return caps[i] if i < len(caps) else _MAX_CELL_CHARS

    table_data = [
        [_wrap_header(col) for col in columns]
    ] + [
        [wrap_cell(row[i], _cap(i)) for i in range(len(columns))]
        for row in rows
    ]

    table = Table(table_data, repeatRows=1, colWidths=col_widths)

    table.setStyle(TableStyle([
        # Header
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#2F4F4F")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('FONT', (0,0), (-1,0), 'Helvetica-Bold'),
        ('VALIGN', (0,0), (-1,0), 'TOP'),   # multi-line headers align at the top

        # Body
        ('FONT', (0,1), (-1,-1), 'Helvetica'),
        ('BACKGROUND', (0,1), (-1,-1), colors.beige),
        ('ROWBACKGROUNDS', (0,1), (-1,-1),
         [colors.whitesmoke, colors.lightgrey]),

        # Grid & alignment
        ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,1), (-1,-1), 'TOP'),  # multi-line cells align at the top

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
    # Headers wrapped (so a long column name breaks onto multiple lines) plus
    # explicit column widths that fit the page. A per-column character cap keeps
    # any single cell (e.g. a long SQL statement in a narrow column) from wrapping
    # taller than one page, which would otherwise abort the PDF build.
    avail_width = pagesize[0] - 4 * cm     # landscape A4 minus 2cm L + 2cm R
    col_widths = _compute_col_widths(columns, rows, avail_width)
    frame_height = pagesize[1] - 3.5 * cm  # top 2cm + bottom 1.5cm margins
    caps = _cell_char_caps(col_widths, frame_height)

    def _cap(i):
        return caps[i] if i < len(caps) else _MAX_CELL_CHARS

    table_data = [
        [_wrap_header(col) for col in columns]
    ] + [
        [wrap_cell(row[i], _cap(i)) for i in range(len(columns))]
        for row in rows
    ]

    table = Table(table_data, repeatRows=1, colWidths=col_widths)

    table.setStyle(TableStyle([
        # Header
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#2F4F4F")),
        ('TEXTCOLOR', (0,0), (-1,0), colors.whitesmoke),
        ('FONT', (0,0), (-1,0), 'Helvetica-Bold'),
        ('VALIGN', (0,0), (-1,0), 'TOP'),   # multi-line headers align at the top

        # Body
        ('FONT', (0,1), (-1,-1), 'Helvetica'),
        ('BACKGROUND', (0,1), (-1,-1), colors.beige),
        ('ROWBACKGROUNDS', (0,1), (-1,-1),
         [colors.whitesmoke, colors.lightgrey]),

        # Grid & alignment
        ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,1), (-1,-1), 'TOP'),  # multi-line cells align at the top

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