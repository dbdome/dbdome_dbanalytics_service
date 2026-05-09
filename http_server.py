import asyncio
import sqlite3
from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from utils.config_dotenv import  get_connection_string, get_public_or_ip
from utils.log4dbexpert import db_write_log
from sqlalchemy import create_engine, MetaData, Table, Column, Integer, String, Boolean, text
import json
import re
import time
import shutil
import uvicorn
from fastapi import Response
from fastapi.responses import RedirectResponse
import os
from  jobs.job_handler import fetch_data_report_once , export_to_pdf_once
import psycopg2
from datetime import datetime, timedelta
from email_utils.smtp_email_sender import   send_mail_with_attachment , send_mail_with_html_attachment
from urllib.parse import urlparse
from print_utils.dasboard_capture import capture_grafana_dashboard_pdf
from   ReportGenerator.json_report_generator import JSONReportGenerator
# ---- Absolute paths (safe & recommended) ----


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")
TEMPLATE_DIR = os.path.join(BASE_DIR, "templates")

import os
import sys

if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS
else:
    base_path = os.path.abspath(".")

os.environ["PLAYWRIGHT_BROWSERS_PATH"] = os.path.join(base_path, "ms-playwright")

# Icons live next to the exe (when frozen) or next to the source file (when running from source).
# reportlab's ImageReader cannot decode .ico, so the PDF logo must be a PNG.
APP_DIR = os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else BASE_DIR
LOGO_PATH = os.path.join(APP_DIR, "icons", "LOGO.png")

app = FastAPI()

# Static files (css, js, images)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# Templates directory
templates = Jinja2Templates(directory=TEMPLATE_DIR)


# ---------------------------------------------------------------------------
# Startup: update Grafana dashboard IPs to match current machine
# ---------------------------------------------------------------------------
import re as _re
import sqlite3 as _sqlite3

def update_dashboard_ip():
    """Read machine IP from config and update all Grafana dashboard links."""
    try:
        pg_conn = psycopg2.connect(get_connection_string())
        pg_cur = pg_conn.cursor()

        # Get machine IP
        pg_cur.execute("SELECT value FROM config.global_params WHERE key = 'local_ip'")
        row = pg_cur.fetchone()
        machine_ip = row[0] if row else None

        # Get grafana.db path
        pg_cur.execute("SELECT value FROM config.global_params WHERE key = 'grafana_db'")
        row = pg_cur.fetchone()
        grafana_db_path = row[0] if row else None

        pg_cur.close()
        pg_conn.close()

        if not machine_ip or not grafana_db_path:
            print(f"update_dashboard_ip: missing config (ip={machine_ip}, db={grafana_db_path})")
            return

        if not os.path.exists(grafana_db_path):
            print(f"update_dashboard_ip: grafana.db not found at {grafana_db_path}")
            return

        # Update dashboards
        gconn = _sqlite3.connect(grafana_db_path)
        gcur = gconn.cursor()
        gcur.execute("SELECT uid, id, data, version FROM dashboard")

        ip_pattern = _re.compile(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(8080|3000)')
        updated = 0

        for uid, dash_id, data, version in gcur.fetchall():
            new_data = data
            changed = False

            for match in ip_pattern.finditer(data):
                old_ip = match.group(1)
                port = match.group(2)
                if old_ip != machine_ip and old_ip not in ('127.0.0.1', '0.0.0.0'):
                    new_data = new_data.replace(f'{old_ip}:{port}', f'{machine_ip}:{port}')
                    changed = True

            if 'localhost:8080' in new_data:
                new_data = new_data.replace('localhost:8080', f'{machine_ip}:8080')
                changed = True
            if 'localhost:3000' in new_data:
                new_data = new_data.replace('localhost:3000', f'{machine_ip}:3000')
                changed = True

            if changed:
                import json as _json
                dashboard = _json.loads(new_data)
                dashboard['version'] = version + 1
                gcur.execute("UPDATE dashboard SET data = ?, version = ? WHERE id = ?",
                             (_json.dumps(dashboard), version + 1, dash_id))
                updated += 1

        gconn.commit()
        gconn.close()
        print(f"update_dashboard_ip: updated {updated} dashboards to {machine_ip}")
        db_write_log(f"Dashboard IPs updated: {updated} dashboards -> {machine_ip}", 0, "update_dashboard_ip", "")

    except Exception as e:
        print(f"update_dashboard_ip failed: {e}")


# Run on startup
update_dashboard_ip()

@app.get("/dbdome", response_class=RedirectResponse)
async def dbdome_main(request: Request):
    host_header = request.headers.get("host")
    db_write_log(f"/dbdome success host_header :{host_header}"   ,0,"get/dbdome","" )
    host = host_header.split(":")[0] if ":" in host_header else host_header
    db_write_log(f"/dbdome success host :{host}"   ,0,"get/dbdome","" )
    target_url = f"http://{host}:3000/d/ad7kkx7/dbdome?orgId=1&from=now-1h&to=now&timezone=browser"
    db_write_log(f"/dbdome success target_url :{target_url}"   ,0,"get/dbdome","" )
    return RedirectResponse(url=target_url, status_code=302)

@app.get("/", response_class=RedirectResponse)
async def dbdome_main(request: Request):
    host_header = request.headers.get("host")
    db_write_log(f"/dbdome success host_header :{host_header}"   ,0,"get/dbdome","" )
    host = host_header.split(":")[0] if ":" in host_header else host_header
    db_write_log(f"/dbdome success host :{host}"   ,0,"get/dbdome","" )
    target_url = f"http://{host}:3000/d/ad7kkx7/dbdome?orgId=1&from=now-1h&to=now&timezone=browser"
    db_write_log(f"/dbdome success target_url :{target_url}"   ,0,"get/dbdome","" )
    return RedirectResponse(url=target_url, status_code=302)


@app.get("/processform", response_class=HTMLResponse)
def processform_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "processform.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/serverform", response_class=HTMLResponse)
def serverform_page(request: Request):
    referer    = request.query_params.get("sender")
    with open(os.path.join(TEMPLATE_DIR, "serverform.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/siem_configuration", response_class=HTMLResponse)
def siem_configuration(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "siem_configuration.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/custom_metrics", response_class=HTMLResponse)
def serverform_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "custom_metrics.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


app.get("/custom_metric_enable", response_class=HTMLResponse)
def custom_metric_enable(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "custom_metric_enable.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/addrecipients", response_class=HTMLResponse)
def addrecipients(request:Request):
    mail_config_id = request.query_params.get("mail_config_id")
    referer    = request.query_params.get("sender")
    return f"""  
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Send Report by Mail</title>
  <style>
    body {{
      background-color: #111217;
      color: #d8d9da;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 16px;
    }}

    .panel {{
      max-width: 520px;
      margin: 40px auto;
      background-color: #181b1f;
      border: 1px solid #2c3235;
      border-radius: 6px;
      padding: 24px;
    }}

    .panel-header {{
      font-size: 18px;
      font-weight: 600;
      margin-bottom: 16px;
      color: #ffffff;
    }}

    .panel-subtitle {{
      font-size: 13px;
      color: #9fa1a4;
      margin-bottom: 24px;
    }}
    label {{
      font-size: 13px;
      font-weight: 500;
      display: block;
      margin-bottom: 6px;
      color: #c7c9cc;
    }}
    input[type="text"] {{
      width: 100%;
      padding: 10px;
      background-color: #111217;
      border: 1px solid #2c3235;
      border-radius: 4px;
      color: #ffffff;
      font-size: 14px;
      margin-bottom: 20px;
    }}

    input[type="text"]:focus {{
      outline: none;
      border-color: #5794f2;
    }}

    .actions {{
      text-align: right;
    }}

    input[type="submit"] {{
      background-color: #5794f2;
      color: #ffffff;
      border: none;
      border-radius: 4px;
      padding: 8px 16px;
      font-size: 14px;
      cursor: pointer;
    }}

    input[type="submit"]:hover {{
      background-color: #447bdc;
    }}

    .hint {{
      font-size: 12px;
      color: #9fa1a4;
      margin-top: -12px;
      margin-bottom: 20px;
    }}
  </style>
</head>

<body>

  <div class="panel">
    <div class="panel-header">Add recipients</div>
    <div class="panel-subtitle">
      Add recipients for this report execution
    </div>

    <form action="/submit-addrecipients" method="POST">

      <label for="group_name">Group name</label>
      <input
        type="text"
        id="group_name"
        name="group_name"
        placeholder="ops_team"
        required
      >
      <div class="hint">Unique label for this recipient group</div>

      <label for="recipients">Recipients</label>
      <input
        type="text"
        id="recipients"
        name="recipients"
        placeholder="user1@company.com, user2@company.com"
      >
      <div class="hint">Comma-separated email addresses</div>

      <!-- Hidden reference from Grafana -->
      <input type="hidden" name="referer" value="{referer}">
      <input type="hidden" name="mail_config_id" value="{mail_config_id}">
      <div class="actions">
        <input type="submit" value="Add recipients">
      </div>

    </form>
  </div>

</body>
</html>
    """
@app.get("/mailconfiguration", response_class=HTMLResponse)
def addrecipients(request:Request):
    referer = request.query_params.get("sender", "")
    row_id_q = request.query_params.get("row_id")

    smtp_server = ""
    smtp_port   = ""
    smtp_user   = ""
    smtp_password = ""
    tls_checked = "checked"
    smtp_sender = ""
    row_id_val  = ""
    page_title  = "Mail configuration"

    if row_id_q:
        try:
            engine = create_engine(get_connection_string())
            with engine.connect() as conn:
                row = conn.execute(
                    text("SELECT row_id, smtp_server, smtp_port, smtp_user, smtp_password, tls, mail_sender "
                         "FROM config.mail_config WHERE row_id = :id"),
                    {"id": int(row_id_q)},
                ).mappings().first()
            if row:
                row_id_val    = str(row["row_id"])
                smtp_server   = row["smtp_server"] or ""
                smtp_port     = str(row["smtp_port"] or "")
                smtp_user     = row["smtp_user"] or ""
                smtp_password = row["smtp_password"] or ""
                tls_checked   = "checked" if row["tls"] else ""
                smtp_sender   = row["mail_sender"] or ""
                page_title    = f"Mail configuration (edit #{row_id_val})"
        except Exception as e:
            db_write_log(f"mailconfiguration prefill failed: {e}", "", "mailconfiguration", "")

    return f"""
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Mail Configuration</title>
  <style>
    body {{
      background-color: #111217;
      color: #d8d9da;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 16px;
    }}

    .panel {{
      max-width: 520px;
      margin: 40px auto;
      background-color: #181b1f;
      border: 1px solid #2c3235;
      border-radius: 6px;
      padding: 24px;
    }}

    .panel-header {{
      font-size: 18px;
      font-weight: 600;
      margin-bottom: 8px;
      color: #ffffff;
    }}

    .panel-subtitle {{
      font-size: 13px;
      color: #9fa1a4;
      margin-bottom: 24px;
    }}

    label {{
      font-size: 13px;
      font-weight: 500;
      display: block;
      margin-bottom: 6px;
      color: #c7c9cc;
    }}

    input[type="text"],
    input[type="number"],
    input[type="password"] {{
      width: 100%;
      padding: 10px;
      background-color: #111217;
      border: 1px solid #2c3235;
      border-radius: 4px;
      color: #ffffff;
      font-size: 14px;
      margin-bottom: 20px;
    }}

    input:focus {{
      outline: none;
      border-color: #5794f2;
    }}

    .checkbox {{
      display: flex;
      align-items: center;
      margin-bottom: 20px;
    }}

    .checkbox input {{
      margin-right: 8px;
    }}
    
    .actions {{
      text-align: right;
    }}

    input[type="submit"] {{
      background-color: #5794f2;
      color: #ffffff;
      border: none;
      border-radius: 4px;
      padding: 8px 16px;
      font-size: 14px;
      cursor: pointer;
    }}

    input[type="submit"]:hover {{
      background-color: #447bdc;
    }}
  </style>
</head>

<body>

  <div class="panel">
    <div class="panel-header">{page_title}</div>
    <div class="panel-subtitle">
      Configure SMTP settings for sending reports
    </div>

    <form action="/submit-mailconfiguration" method="POST">

      <label for="smtp_server">SMTP server</label>
      <input type="text" id="smtp_server" name="smtp_server" value="{smtp_server}" placeholder="smtp.company.com" required>

      <label for="smtp_port">SMTP port</label>
      <input type="number" id="smtp_port" name="smtp_port" value="{smtp_port}" placeholder="587" required>

      <label for="smtp_user">SMTP user</label>
      <input type="text" id="smtp_user" name="smtp_user" value="{smtp_user}" placeholder="alerts@company.com">

      <label for="smtp_password">SMTP password</label>
      <input type="password" id="smtp_password" name="smtp_password" value="{smtp_password}">

      <div class="checkbox">
        <input type="checkbox" id="tls" name="tls" value="true" {tls_checked}>
        <label for="tls">Use TLS</label>
      </div>

      <label for="mail_sender">Mail sender</label>
      <input type="text" id="smtp_sender" name="smtp_sender" value="{smtp_sender}" placeholder="DBDOME Alerts <support@dbdome.com>" required>

      <!-- Hidden references -->
      <input type="hidden" name="referer" value="{referer}">
      <input type="hidden" name="row_id" value="{row_id_val}">
      <div class="actions">
        <input type="submit" value="Save mail configuration">
      </div>

    </form>
  </div>

</body>
</html>
    """


@app.post("/submit-mailconfiguration")
async def mailconfigure(
    request: Request,
    smtp_server: str = Form(...),
    smtp_user: str = Form(...),
    smtp_password: str = Form(...),
    smtp_port: int = Form(...),
    tls: bool = Form(False),
    smtp_sender: str = Form(...),
    referer: str = Form(""),
    row_id: str = Form(None),
    ):
    config = {
        "smtp_server"       :smtp_server,
        "smtp_user"         :smtp_user ,
        "smtp_password"     :smtp_password , 
        "smtp_port"         :smtp_port , 
        "tls"               :tls , 
        "smtp_sender"       :smtp_sender
    }
    new_config_id = None
    try:
        pg_connection_string = get_connection_string()
        pg_postgres_home_engine = create_engine(pg_connection_string)
        with pg_postgres_home_engine.begin() as conn:
            p_row_id = int(row_id) if row_id else None
            result = conn.execute(
                text("CALL config.save_mail_config(:p_row_id, :p_smtp_server, :p_smtp_port, :p_smtp_user, :p_smtp_password, :p_tls, :p_mail_sender)"),
                {
                    "p_row_id"        : p_row_id,
                    "p_smtp_server"   : smtp_server,
                    "p_smtp_port"     : smtp_port,
                    "p_smtp_user"     : smtp_user,
                    "p_smtp_password" : smtp_password,
                    "p_tls"           : tls,
                    "p_mail_sender"   : smtp_sender,
                }
            )
            try:
                new_config_id = result.scalar()
            except Exception:
                new_config_id = p_row_id
    except Exception as e:
            print("Error calling procedure save_mail_config :", e)
    except Exception as e:               
                    db_write_log(f"mail_config failed with error:{e}"   , "mail_config" ,"mail_config" ,"mail_config")
                    
    finally:                  
               
                #  Clean up
                conn.close()
                db_write_log(f"mail_config succeeded", "" ,"addrecipients" ,"")   
                _re_ip =  get_public_or_ip()                

    if referer:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{referer}", status_code=302)

@app.get("/capture_report/{reportname}", response_class=HTMLResponse)
def capture_report(reportname: str,request:Request):
    url = request.query_params.get("url")
    referer    = request.query_params.get("sender")
    return f"""
    <html>
    <head>
      <meta charset="UTF-8">
      <title>send report by mail</title>
      <style>
        body {{
          background-color: #1e1e2d;
          color: #e0e0e0;
          font-family: "Segoe UI", Roboto, sans-serif;
          margin: 0;
          padding: 20px;
        }}
        .container {{
          max-width: 600px;
          margin: auto;
          background-color: #2d2d3d;
          padding: 30px;
          border-radius: 8px;
          box-shadow: 0 0 10px #000;
        }}
        h2 {{
          text-align: center;
          margin-bottom: 20px;
          color: #f9f9f9;
        }}
        label {{
          display: block;
          margin-bottom: 8px;
          font-weight: 500;
        }}
        input, textarea {{
          width: 100%;
          padding: 10px;
          margin-bottom: 20px;
          border: none;
          border-radius: 4px;
          background-color: #3c3c4f;
          color: #ffffff;
          font-size: 14px;
        }}
        input[type="submit"] {{
          width: 100%;
          padding: 12px;
          background-color: #007acc;
          border: none;
          border-radius: 4px;
          color: white;
          font-size: 15px;
          cursor: pointer;
          transition: background 0.3s ease;
        }}
        input[type="submit"]:hover {{
          background-color: #005f99;
        }}
      </style>
    </head>
    <body>
      <div class="container">
        <h2>Send report by mail</h2>
        <form action="/submit-report_capture" method="POST">          

          <label for="recipients">Recipients (comma separated)</label>
          <input type="text" id="recipients" name="recipients">

          <!-- Hidden field to carry the reportname into the POST -->
          <input type="hidden" id="report" name="report" value="{reportname}">
          <input type="hidden" name="url" value="{url}">
          <input type="hidden" name="referer" value="{referer}">
          <input type="submit" value="Send Report By mail">
        </form>
      </div>
    </body>
    </html>
    """



@app.get("/generate_report/{reportname}", response_class=HTMLResponse)
def capture_report(reportname: str,request:Request):
    referer = request.query_params.get("sender") or request.headers.get("referer") or f"http://{get_public_or_ip()}:3000"
    return f"""
    <html>
    <head>
      <meta charset="UTF-8">
      <title>send report by mail</title>
      <style>
        body {{
          background-color: #1e1e2d;
          color: #e0e0e0;
          font-family: "Segoe UI", Roboto, sans-serif;
          margin: 0;
          padding: 20px;
        }}
        .container {{
          max-width: 600px;
          margin: auto;
          background-color: #2d2d3d;
          padding: 30px;
          border-radius: 8px;
          box-shadow: 0 0 10px #000;
        }}
        h2 {{
          text-align: center;
          margin-bottom: 20px;
          color: #f9f9f9;
        }}
        label {{
          display: block;
          margin-bottom: 8px;
          font-weight: 500;
        }}
        input, textarea {{
          width: 100%;
          padding: 10px;
          margin-bottom: 20px;
          border: none;
          border-radius: 4px;
          background-color: #3c3c4f;
          color: #ffffff;
          font-size: 14px;
        }}
        input[type="submit"] {{
          width: 100%;
          padding: 12px;
          background-color: #007acc;
          border: none;
          border-radius: 4px;
          color: white;
          font-size: 15px;
          cursor: pointer;
          transition: background 0.3s ease;
        }}
        input[type="submit"]:hover {{
          background-color: #005f99;
        }}
      </style>
    </head>
    <body>
      <div class="container">
        <h2>Send report by mail</h2>
        <form action="/submit-generate_report" method="POST">          

          <label for="recipients">Recipients (comma separated)</label>
          <input type="text" id="recipients" name="recipients">

          <!-- Hidden field to carry the reportname into the POST -->
          <input type="hidden" id="report" name="report" value="{reportname}">
          <input type="hidden" name="referer" value="{referer}">
          <input type="submit" value="Send Report By mail">
        </form>
      </div>
    </body>
    </html>
    """





@app.get("/reportbymail/{reportname}", response_class=HTMLResponse)
def show_send_report_by_mail(reportname: str,request:Request):
    start_time = request.query_params.get("start_time")
    end_time   = request.query_params.get("end_time")
    server     = request.query_params.get("server")
    referer    = request.query_params.get("sender")
    return f"""
    <html>
    <head>
      <meta charset="UTF-8">
      <title>send report by mail</title>
      <style>
        body {{
          background-color: #1e1e2d;
          color: #e0e0e0;
          font-family: "Segoe UI", Roboto, sans-serif;
          margin: 0;
          padding: 20px;
        }}
        .container {{
          max-width: 600px;
          margin: auto;
          background-color: #2d2d3d;
          padding: 30px;
          border-radius: 8px;
          box-shadow: 0 0 10px #000;
        }}
        h2 {{
          text-align: center;
          margin-bottom: 20px;
          color: #f9f9f9;
        }}
        label {{
          display: block;
          margin-bottom: 8px;
          font-weight: 500;
        }}
        input, textarea {{
          width: 100%;
          padding: 10px;
          margin-bottom: 20px;
          border: none;
          border-radius: 4px;
          background-color: #3c3c4f;
          color: #ffffff;
          font-size: 14px;
        }}
        input[type="submit"] {{
          width: 100%;
          padding: 12px;
          background-color: #007acc;
          border: none;
          border-radius: 4px;
          color: white;
          font-size: 15px;
          cursor: pointer;
          transition: background 0.3s ease;
        }}
        input[type="submit"]:hover {{
          background-color: #005f99;
        }}
      </style>
    </head>
    <body>
      <div class="container">
        <h2>Send report by mail</h2>
        <form action="/submit-reportbymail" method="POST">          

          <label for="recipients">Recipients (comma separated)</label>
          <input type="text" id="recipients" name="recipients">

          <!-- Hidden field to carry the reportname into the POST -->
          <input type="hidden" id="reportname" name="reportname" value="{reportname}">
           <input type="hidden" name="start_time" value="{start_time}">
          <input type="hidden" name="end_time" value="{end_time}">
          <input type="hidden" name="server" value="{server}">
          <input type="hidden" name="referer" value="{referer}">
          <input type="submit" value="Send Report By mail">
        </form>
      </div>
    </body>
    </html>
    """
@app.get("/download_report/{reportname}", response_class=HTMLResponse)
def download_report(reportname: str,request:Request):
    start_time = request.query_params.get("start_time")
    end_time   = request.query_params.get("end_time")
    server     = request.query_params.get("server")
    referer    = request.query_params.get("sender")
    try:
        
        pg_connection_string = get_connection_string()
        # Connect to the PostgreSQL database
        conn = psycopg2.connect(pg_connection_string)
        # Create a cursor
        cur = conn.cursor()
            # Query the view
        p_sqlcmd = f""" 
         select 
          c_mc.mail_sender , 
          c_mc.smtp_port , 
          c_mc.smtp_user , 
          c_mc.smtp_password , 
          c_mc.tls  , 
          c_mc.smtp_server
          from config.mail_config c_mc 
        """
    
        cur.execute(p_sqlcmd, (reportname,))

        # Fetch and print rows
        rows = cur.fetchall()
        for row in rows:                                     
           for row in rows:                                     
            mail_sender       = row[0]
            smtp_port         = row[1]
            smtp_user         = row[2]
            smtp_password     = row[3]            
            tls               = row[4]
            smtp_server       = row[5]
            
           p_report_sqlcmd = f"""
          select report_query from config.reports where report_name = %s
        """
        
        # Create a cursor        
        cur.execute(p_report_sqlcmd, (reportname,))
        rows = cur.fetchall()
        for row in rows:                                     
            report_query       = row[0]        

        columns , rows = fetch_data_report_once(conn , report_query , reportname  , start_time , end_time , server ) 
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

                        # Build PDF path
        output_dir = os.path.join(os.getcwd(), "reports")

                        # Make sure the folder exists
        os.makedirs(output_dir, exist_ok=True)

                        # Generate timestamp
        
                        # Build PDF path
        pdf_filename = f"{reportname}_{timestamp}.pdf"
        pdf_path = os.path.join(output_dir, pdf_filename)
        try:
          export_to_pdf_once(columns, rows, pdf_path , start_time , end_time , logo_path=LOGO_PATH , _header = reportname)     
        finally:
            db_write_log(f"download report succeeded"   , "download report succeeded" ,"download report succeeded" ,"download report succeeded")
    except Exception as e:               
                    db_write_log(f"download report failed with error:{e}"   , "download report" ,"download report" ,"download report")
                    
    finally:                  
               
                #  Clean up
                cur.close()
                conn.close()
                db_write_log(f"send_alert_email_and_log succeeded", "" ,"send_alert_email_and_log" ,"")   
                _re_ip =  get_public_or_ip()                

    if referer:
        return RedirectResponse(url=f"http://{referer}", status_code=302)
    


from fastapi import Request
from fastapi.responses import RedirectResponse, HTMLResponse
from sqlalchemy import create_engine, text

from fastapi import Request
from fastapi.responses import RedirectResponse, HTMLResponse
from sqlalchemy import create_engine, text

@app.get("/server_enable", response_class=HTMLResponse)
def server_enable(request: Request):
    referer = request.query_params.get("referer", "").strip()
    servername = request.query_params.get("servername", "").strip()

    try:
        pg_home_connection_string = get_connection_string()
        engine = create_engine(pg_home_connection_string)

        with engine.begin() as conn:
            conn.execute(
                text("CALL metrics.server_activate(:p_server_name)"),
                {"p_server_name": servername}
            )

        db_write_log(
            f"server_activate {servername} succeeded",
            "",
            "server_activate",
            ""
        )

    except Exception as e:
        print("Error calling procedure:", e)

        db_write_log(
            f"server_activate {servername} failed: {e}",
            "",
            "server_activate",
            ""
        )

    # 🔐 Safe redirect handling
    base_url = f"http://{get_public_or_ip()}:3000"

    if referer and not referer.startswith("http"):
        return RedirectResponse(
            url=f"{base_url}/{referer}",
            status_code=302
        )

    return RedirectResponse(
        url=f"{base_url}/d/ad6lv7f/transaction-report",
        status_code=302
    )

@app.post("/submit-addrecipients")
async def addrecipients(
    request: Request,
    mail_config_id: str = Form(...),
    group_name: str = Form(...),
    recipients: str = Form(...),
    referer: str = Form(...),
    row_id: str = Form(None),
    is_active: bool = Form(True),
    ):
    try:
        pg_connection_string = get_connection_string()
        pg_postgres_home_engine = create_engine(pg_connection_string)
        with pg_postgres_home_engine.begin() as conn:
            conn.execute(
                text("CALL config.save_mail_group(:p_row_id, :p_mail_config_id, :p_group_name, :p_recipients, :p_is_active)"),
                {
                    "p_row_id"         : int(row_id) if row_id else None,
                    "p_mail_config_id" : int(mail_config_id) if mail_config_id else None,
                    "p_group_name"     : group_name,
                    "p_recipients"     : recipients,
                    "p_is_active"      : is_active,
                }
            )
    except Exception as e:
            print("Error calling procedure save_mail_group:", e)
    except Exception as e:               
                    db_write_log(f"addrecipients failed with error:{e}"   , "addrecipients" ,"addrecipients" ,"addrecipients")
                    
    finally:                  
               
                #  Clean up
                conn.close()
                db_write_log(f"addrecipients succeeded", "" ,"addrecipients" ,"")   
                _re_ip =  get_public_or_ip()                

    if referer:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{referer}", status_code=302)
    

    # fallback if referer is missing
    return RedirectResponse(
        url=f"http://{get_public_or_ip()}:3000/d/ad6lv7f/transaction-report",
        status_code=302
    )
                
    return RedirectResponse(url=f"http://{_re_ip}:/3000/d/ad6lv7f/transaction-report", status_code=302)


@app.post("/api/mail-config/delete")
async def api_delete_mail_config(request: Request):
    body = await request.json()
    row_id = int(body.get("row_id"))
    force = bool(body.get("force", False))
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("CALL config.delete_mail_config(:p_row_id, :p_force)"),
                {"p_row_id": row_id, "p_force": force},
            )
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/mail-group/delete")
async def api_delete_mail_group(request: Request):
    body = await request.json()
    row_id = int(body.get("row_id"))
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("CALL config.delete_mail_group(:p_row_id)"),
                {"p_row_id": row_id},
            )
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


# ============================================================
# Report editor — enable/disable/reorder columns in rpt_*.json
# ============================================================

REPORTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates")
_REPORT_NAME_RE = re.compile(r"^rpt_[A-Za-z0-9_\-]+\.json$")


def _reports_list():
    if not os.path.isdir(REPORTS_DIR):
        return []
    return sorted(
        f for f in os.listdir(REPORTS_DIR)
        if re.match(r"^rpt_.*\.json$", f)
    )


def _safe_report_path(name: str) -> str:
    """Reject anything that isn't a plain rpt_*.json filename."""
    if not _REPORT_NAME_RE.match(name or ""):
        raise ValueError(f"invalid report name: {name}")
    path = os.path.join(REPORTS_DIR, name)
    # Extra defense in depth — prevent symlink / .. trickery.
    if os.path.commonpath([os.path.abspath(path), REPORTS_DIR]) != REPORTS_DIR:
        raise ValueError("path escapes reports dir")
    return path


def _discover_columns_for_query(sql: str):
    """Run SQL with LIMIT 0 and return the column names from the result."""
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()
        # Wrap so LIMIT 0 works even for SELECTs with ORDER BY / LIMIT
        cur.execute(f"SELECT * FROM ({sql}) _sub LIMIT 0")
        cols = [d.name for d in cur.description] if cur.description else []
        cur.close()
        conn.close()
        return cols, None
    except Exception as e:
        return [], str(e)


@app.get("/reports", response_class=HTMLResponse)
def reports_list_page(request: Request):
    sender = request.query_params.get("sender", "")
    files = _reports_list()
    rows_html = ""
    for f in files:
        edit_url = f"/reports/edit?name={f}&sender={sender}"
        rows_html += f'<tr><td>{f}</td><td><a href="{edit_url}">Edit</a></td></tr>'

    return f"""
<html><head><meta charset="UTF-8"><title>Reports</title>
<style>
  body {{ background:#111217; color:#d8d9da; font-family:-apple-system,Segoe UI,Roboto,sans-serif; margin:0; padding:24px; }}
  .panel {{ max-width:900px; margin:0 auto; background:#181b1f; border:1px solid #2c3235; border-radius:6px; padding:24px; }}
  h2 {{ color:#fff; margin-top:0; }}
  table {{ width:100%; border-collapse:collapse; }}
  th, td {{ text-align:left; padding:8px; border-bottom:1px solid #2c3235; font-size:13px; }}
  a {{ color:#5794f2; }}
</style></head><body>
<div class="panel">
<h2>Report definitions ({len(files)})</h2>
<table><thead><tr><th>File</th><th></th></tr></thead><tbody>{rows_html}</tbody></table>
</div></body></html>
"""


@app.get("/reports/edit", response_class=HTMLResponse)
def reports_edit_page(request: Request):
    name = request.query_params.get("name", "")
    sender = request.query_params.get("sender", "")
    try:
        path = _safe_report_path(name)
    except ValueError as e:
        return HTMLResponse(f"<pre>Bad request: {e}</pre>", status_code=400)
    if not os.path.isfile(path):
        return HTMLResponse(f"<pre>Not found: {name}</pre>", status_code=404)

    with open(path, "r", encoding="utf-8") as f:
        rpt = json.load(f)

    sections_html = ""
    table_idx = 0
    for section in rpt.get("sections", []):
        if section.get("type") != "table":
            continue
        sql = section.get("query", "") or ""
        current_headers = list(section.get("headers", []) or [])
        discovered, err = _discover_columns_for_query(sql)

        enabled_set = set(current_headers)
        # Order: enabled first (in current headers order), then disabled (in query order)
        enabled_cols = [h for h in current_headers if h in (set(discovered) if discovered else set(current_headers))]
        disabled_cols = [c for c in discovered if c not in enabled_set]
        # If the DB call failed, fall back to what's in headers
        if err:
            enabled_cols = current_headers
            disabled_cols = []

        all_in_display_order = enabled_cols + disabled_cols

        rows = ""
        for i, col in enumerate(all_in_display_order):
            checked = "checked" if col in enabled_set else ""
            rows += (
                f'<tr>'
                f'<td><input type="number" name="table_{table_idx}_order_{col}" value="{i}" min="0" style="width:60px"></td>'
                f'<td>{col}</td>'
                f'<td><input type="checkbox" name="table_{table_idx}_enabled_{col}" value="1" {checked}></td>'
                f'</tr>'
            )

        err_html = f'<div style="color:#ff9f40;padding:8px">DB query failed, editing only current headers: {err}</div>' if err else ''
        sections_html += f"""
<h3>Table #{table_idx + 1}</h3>
{err_html}
<details><summary style="cursor:pointer;color:#9fa1a4;">SQL</summary><pre style="background:#0b0d10;padding:10px;border-radius:4px;overflow-x:auto;">{sql}</pre></details>
<input type="hidden" name="table_{table_idx}_cols" value="{','.join(all_in_display_order)}">
<table><thead><tr><th>Order</th><th>Column</th><th>Enabled</th></tr></thead><tbody>{rows}</tbody></table>
"""
        table_idx += 1

    return f"""
<html><head><meta charset="UTF-8"><title>Edit {name}</title>
<style>
  body {{ background:#111217; color:#d8d9da; font-family:-apple-system,Segoe UI,Roboto,sans-serif; margin:0; padding:24px; }}
  .panel {{ max-width:900px; margin:0 auto; background:#181b1f; border:1px solid #2c3235; border-radius:6px; padding:24px; }}
  h2,h3 {{ color:#fff; }}
  table {{ width:100%; border-collapse:collapse; margin-bottom:20px; }}
  th, td {{ text-align:left; padding:8px; border-bottom:1px solid #2c3235; font-size:13px; }}
  input[type="submit"] {{ background:#5794f2; color:#fff; border:none; border-radius:4px; padding:10px 20px; font-size:14px; cursor:pointer; }}
  input[type="submit"]:hover {{ background:#447bdc; }}
  .actions {{ text-align:right; margin-top:16px; }}
</style></head><body>
<div class="panel">
<h2>{name}</h2>
<form action="/reports/save" method="POST">
<input type="hidden" name="name" value="{name}">
<input type="hidden" name="sender" value="{sender}">
<input type="hidden" name="table_count" value="{table_idx}">
{sections_html}
<div class="actions"><input type="submit" value="Save"></div>
</form>
</div></body></html>
"""


@app.post("/reports/save")
async def reports_save(request: Request):
    form = await request.form()
    name   = form.get("name", "")
    sender = form.get("sender", "")
    try:
        path = _safe_report_path(name)
    except ValueError as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)

    try:
        table_count = int(form.get("table_count", "0"))
    except ValueError:
        table_count = 0

    with open(path, "r", encoding="utf-8") as f:
        rpt = json.load(f)

    # Backup before write (single rolling .bak, overwritten each save)
    try:
        shutil.copy2(path, path + ".bak")
    except Exception:
        pass

    table_idx = 0
    for section in rpt.get("sections", []):
        if section.get("type") != "table":
            continue
        if table_idx >= table_count:
            break
        cols_csv = form.get(f"table_{table_idx}_cols", "")
        cols = [c for c in cols_csv.split(",") if c]
        kept = []
        for c in cols:
            enabled = form.get(f"table_{table_idx}_enabled_{c}") == "1"
            if not enabled:
                continue
            try:
                order = int(form.get(f"table_{table_idx}_order_{c}", "999"))
            except ValueError:
                order = 999
            kept.append((order, c))
        kept.sort(key=lambda t: (t[0], cols.index(t[1])))
        section["headers"] = [c for _, c in kept]
        table_idx += 1

    with open(path, "w", encoding="utf-8") as f:
        json.dump(rpt, f, indent=2, ensure_ascii=False)

    db_write_log(f"report {name} saved", "", "reports_save", "")
    if sender:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{sender}", status_code=302)
    return RedirectResponse(url=f"/reports?sender={sender}", status_code=302)


@app.get("/api/reports/list")
async def api_reports_list():
    return JSONResponse({"reports": _reports_list()})


@app.get("/risklevel", response_class=HTMLResponse)
def risklevel_page(request: Request):
    referer = request.query_params.get("sender", "")
    try:
        engine = create_engine(get_connection_string())
        with engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT row_id, trim(risk_level) AS risk_level, is_active "
                "FROM rootcause.risk_level ORDER BY row_id"
            )).mappings().all()
    except Exception as e:
        return HTMLResponse(f"<pre>Error loading risk levels: {e}</pre>", status_code=500)

    rows_html = ""
    for r in rows:
        checked = "checked" if r["is_active"] else ""
        rows_html += (
            f'<tr><td>{r["row_id"]}</td>'
            f'<td>{r["risk_level"]}</td>'
            f'<td><input type="checkbox" name="active_{r["row_id"]}" value="1" {checked}></td>'
            f'</tr>'
        )

    return f"""
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Risk Level Configuration</title>
  <style>
    body {{ background:#111217; color:#d8d9da; font-family:-apple-system,Segoe UI,Roboto,sans-serif; margin:0; padding:16px; }}
    .panel {{ max-width:520px; margin:40px auto; background:#181b1f; border:1px solid #2c3235; border-radius:6px; padding:24px; }}
    .panel-header {{ font-size:18px; font-weight:600; color:#fff; margin-bottom:8px; }}
    .panel-subtitle {{ font-size:13px; color:#9fa1a4; margin-bottom:24px; }}
    table {{ width:100%; border-collapse:collapse; margin-bottom:20px; }}
    th, td {{ text-align:left; padding:10px; border-bottom:1px solid #2c3235; font-size:13px; }}
    th {{ color:#9fa1a4; font-weight:500; }}
    .actions {{ text-align:right; }}
    input[type="submit"] {{ background:#5794f2; color:#fff; border:none; border-radius:4px; padding:8px 16px; font-size:14px; cursor:pointer; }}
    input[type="submit"]:hover {{ background:#447bdc; }}
  </style>
</head>
<body>
  <div class="panel">
    <div class="panel-header">Risk level configuration</div>
    <div class="panel-subtitle">Enable or disable each risk level</div>
    <form action="/submit-risklevel" method="POST">
      <table>
        <thead><tr><th>ID</th><th>Risk level</th><th>Active</th></tr></thead>
        <tbody>{rows_html}</tbody>
      </table>
      <input type="hidden" name="referer" value="{referer}">
      <input type="hidden" name="row_ids" value="{','.join(str(r['row_id']) for r in rows)}">
      <div class="actions"><input type="submit" value="Save"></div>
    </form>
  </div>
</body>
</html>
"""


@app.post("/submit-risklevel")
async def submit_risklevel(request: Request):
    form = await request.form()
    referer = form.get("referer", "")
    row_ids_raw = form.get("row_ids", "")
    if not row_ids_raw:
        return JSONResponse({"ok": False, "error": "no row_ids"}, status_code=400)

    row_ids = [int(x) for x in row_ids_raw.split(",") if x.strip()]
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            for rid in row_ids:
                is_active = form.get(f"active_{rid}") == "1"
                conn.execute(
                    text("UPDATE rootcause.risk_level SET is_active = :a WHERE row_id = :id"),
                    {"a": is_active, "id": rid},
                )
        db_write_log("risk_level toggle saved", "", "submit_risklevel", "")
    except Exception as e:
        db_write_log(f"submit_risklevel failed: {e}", "", "submit_risklevel", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)

    if referer:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{referer}", status_code=302)
    return JSONResponse({"ok": True})


@app.get("/risklevel_toggle")
def risklevel_toggle(request: Request):
    """
    Toggle (or set) is_active on a single rootcause.risk_level row.
    Query params:
        risk_level (required) — name e.g. 'low', 'medium', 'high', 'critical'
        action     (optional) — 'enable' | 'disable' | 'toggle' (default: toggle)
        sender     (optional) — Grafana dashboard return path
    """
    risk_level = (request.query_params.get("risk_level") or "").strip()
    action     = (request.query_params.get("action") or "toggle").strip().lower()
    referer    = request.query_params.get("sender", "")

    if not risk_level:
        return JSONResponse({"ok": False, "error": "risk_level is required"}, status_code=400)
    if action not in ("enable", "disable", "toggle"):
        return JSONResponse({"ok": False, "error": "action must be enable|disable|toggle"}, status_code=400)

    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            row = conn.execute(
                text("SELECT row_id, is_active FROM rootcause.risk_level "
                     "WHERE lower(trim(risk_level)) = lower(trim(:rl)) LIMIT 1"),
                {"rl": risk_level},
            ).fetchone()

            if row is None:
                return JSONResponse(
                    {"ok": False, "error": f"risk_level '{risk_level}' not found"},
                    status_code=404,
                )

            row_id, current = row[0], row[1]
            if action == "enable":
                new_state = True
            elif action == "disable":
                new_state = False
            else:
                new_state = not current

            conn.execute(
                text("UPDATE rootcause.risk_level SET is_active = :a WHERE row_id = :id"),
                {"a": new_state, "id": row_id},
            )

        db_write_log(
            f"risk_level '{risk_level}' set to is_active={new_state}",
            "", "risklevel_toggle", "",
        )
    except Exception as e:
        db_write_log(f"risklevel_toggle failed: {e}", "", "risklevel_toggle", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)

    if referer:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{referer}", status_code=302)
    return JSONResponse({"ok": True, "risk_level": risk_level, "is_active": new_state})


@app.get("/api/risk-level/list")
async def api_list_risk_levels():
    try:
        engine = create_engine(get_connection_string())
        with engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT row_id, trim(risk_level) AS risk_level, is_active "
                "FROM rootcause.risk_level ORDER BY row_id"
            )).mappings().all()
        return JSONResponse({"rows": [dict(r) for r in rows]})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


@app.get("/api/mail-config/list")
async def api_list_mail_config():
    try:
        engine = create_engine(get_connection_string())
        with engine.connect() as conn:
            cfgs = conn.execute(text(
                "SELECT row_id, smtp_server, smtp_port, smtp_user, tls, mail_sender FROM config.mail_config ORDER BY row_id"
            )).mappings().all()
            grps = conn.execute(text(
                "SELECT row_id, mail_config_id, group_name, recipients, is_active FROM config.mail_groups ORDER BY row_id"
            )).mappings().all()
        return JSONResponse({
            "configs": [dict(r) for r in cfgs],
            "groups":  [dict(r) for r in grps],
        })
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/submit-reportbymail")
async def submit_mail_report(   
    request: Request,
    server: str = Form(...), 
    start_time: str = Form(...),
    end_time: str = Form(...),
    recipients: str = Form(...) , 
    reportname:str = Form(...) , 
    referer:str = Form(...) , 
    ):
    config = {
        "start_time":start_time,
        "end_time": end_time ,
        "recipients":recipients 
    }
    try:
        
        pg_connection_string = get_connection_string()
        # Connect to the PostgreSQL database
        conn = psycopg2.connect(pg_connection_string)
        # Create a cursor
        cur = conn.cursor()
            # Query the view
        p_sqlcmd = f""" 
         select 
          c_mc.mail_sender , 
          c_mc.smtp_port , 
          c_mc.smtp_user , 
          c_mc.smtp_password , 
          c_mc.tls  , 
          c_mc.smtp_server
          from config.mail_config c_mc 
        """
    
        cur.execute(p_sqlcmd, (reportname,))

        # Fetch and print rows
        rows = cur.fetchall()
        for row in rows:                                     
           for row in rows:                                     
            mail_sender       = row[0]
            smtp_port         = row[1]
            smtp_user         = row[2]
            smtp_password     = row[3]            
            tls               = row[4]
            smtp_server       = row[5]
            
           p_report_sqlcmd = f"""
          select report_query from config.reports where report_name = %s
        """
        
        # Create a cursor        
        cur.execute(p_report_sqlcmd, (reportname,))
        rows = cur.fetchall()
        for row in rows:                                     
            report_query       = row[0]        

        columns , rows = fetch_data_report_once(conn , report_query , reportname  , start_time , end_time , server ) 
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

                        # Build PDF path
        output_dir = os.path.join(os.getcwd(), "reports")

                        # Make sure the folder exists
        os.makedirs(output_dir, exist_ok=True)

                        # Generate timestamp
        
                        # Build PDF path
        pdf_filename = f"{reportname}_{timestamp}.pdf"
        pdf_path = os.path.join(output_dir, pdf_filename)
        try:
          export_to_pdf_once(columns, rows, pdf_path , start_time , end_time , logo_path=LOGO_PATH , _header = reportname)     
          send_mail_with_attachment(pdf_path , reportname , recipients , mail_sender,pdf_filename ,smtp_user, smtp_server , smtp_port , smtp_password,mail_sender,tls)
        finally:
          if os.path.exists(pdf_path):
            os.remove(pdf_path)    
    except Exception as e:               
                    db_write_log(f"send_alert_email_and_log failed with error:{e}"   , "send_alert_email_and_log" ,"send_alert_email_and_log" ,"send_alert_email_and_log")
                    
    finally:                  
               
                #  Clean up
                cur.close()
                conn.close()
                db_write_log(f"send_alert_email_and_log succeeded", "" ,"send_alert_email_and_log" ,"")   
                _re_ip =  get_public_or_ip()                

    if referer:
        return RedirectResponse(url=f"http://{referer}", status_code=302)
    

    # fallback if referer is missing
    return RedirectResponse(
        url=f"http://{get_public_or_ip()}:3000/d/ad6lv7f/transaction-report",
        status_code=302
    )
                
    return RedirectResponse(url=f"http://{_re_ip}:/3000/d/ad6lv7f/transaction-report", status_code=302)

@app.post("/submit_custom_metrics")
async def submit_custom_metrics(
    request: Request,                 # ⬅ REQUIRED
    metric_name : str = Form (...) , 
    metric_desc : str = Form (...) , 
    query : str = Form (...) , 
    db_vendor_selector: str = Form (...) , 
    action_select : int  = Form (...)     
):
    
    data = {        
        "metric_name":metric_name , 
        "metric_desc":metric_desc , 
        "query":query,
        "db_vendor_selector":db_vendor_selector,
        "action_select":action_select
    }
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL gapi.custom_metrics_upsert(
                :p_metric_name , 
                :p_metric_desc , 
                :p_query               ,
                :p_db_vendor_selector , 
                :p_action_select      
            )
        """), {
            "p_metric_name": metric_name,
            "p_metric_desc":metric_desc , 
            "p_query":query , 
            "p_db_vendor_selector":db_vendor_selector , 
            "p_action_select":action_select
        })

    except Exception as e:                 
                        db_write_log(f"siem_upsert failed with error:{e}"   ,0,"siem_upsert","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)


@app.post("/submit_custom_metric_enable")
async def submit_custom_metric_enable(
    request: Request,                 # ⬅ REQUIRED
    row_id : str = Form (...)     
):
    
    data = {        
        "row_id":row_id 
    }

    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL gapi.custom_metric_enable(
                :p_row_id 
            )
        """), {
            "p_row_id": row_id
        })

    except Exception as e:                 
                        db_write_log(f"siem_upsert failed with error:{e}"   ,0,"siem_upsert","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)


@app.get("/email_configuration", response_class=HTMLResponse)
def serverform_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "email_configuration.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/retention_policy", response_class=HTMLResponse)
def serverform_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "retention_policy.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/metric_enable")
def metric_enable(request : Request):
    with open(os.path.join(TEMPLATE_DIR, "metric_enable.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.post("/submit_metrics_enable")
async def submit_metrics_enable(
    request: Request,                 # ⬅ REQUIRED
    action_select : str = Form (...) , 
    row_id: int = Form(...)          
):
    
    data = {
        "action_select": action_select,
        "row_id": row_id
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL gapi.metric_enable(
                :p_row_id , 
                :p_enable                 
            )
        """), {
            "p_row_id": row_id,
            "p_enable":action_select 
        })

    except Exception as e:                 
                        db_write_log(f"siem_upsert failed with error:{e}"   ,0,"siem_upsert","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.get("/metric_enable_all_servers")
def metric_enable(request : Request):
    with open(os.path.join(TEMPLATE_DIR, "metric_enable_all_servers.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.post("/submit_metrics_enable_all_servers")
async def submit_metrics_enable(
    request: Request,                 # ⬅ REQUIRED
    action_select : str = Form (...) , 
    row_id: int = Form(...)          
):
    
    data = {
        "action_select": action_select,
        "row_id": row_id
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL gapi.metric_enable_all_servers(
                :p_row_id , 
                :p_enable                 
            )
        """), {
            "p_row_id": row_id,
            "p_enable":action_select 
        })

    except Exception as e:                 
                        db_write_log(f"siem_upsert failed with error:{e}"   ,0,"siem_upsert","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.get("/serverform", response_class=HTMLResponse)
def serverform_page(request: Request):
    referer    = request.query_params.get("sender")
    with open(os.path.join(TEMPLATE_DIR, "serverform.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/update_schema_column", response_class=HTMLResponse)
def update_schema_column(request: Request):
    referer    = request.query_params.get("sender")
    column_name= request.query_params.get("schema_column")
    
    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL monitoring.sensitive_schema_column_enable(
                :p_column_name 
        """), {
            "p_column_name": column_name
        })

    except Exception as e:                    
                        db_write_log(f"monitoring.sensitive_schema_column_enable failed with error:{e}"   ,0,"sensitive_schema.column_enable","" )
    finally:
        _re_ip = get_public_or_ip()  # Your Grafana host IP    
    if referer:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{referer}", status_code=302)
    else:
        grafana_url = f"http://{_re_ip}:3000/d/adcdjsj/email-configuration?orgId=1&from=now-1h&to=now&timezone=browser"
        return RedirectResponse(url=grafana_url, status_code=302)


    



@app.post("/submit_email_configuration")
async def submit_email_configuration(
    request: Request,                 # ⬅ REQUIRED
    smtp_server : str = Form (...) , 
    smtp_port : int = Form (...) , 
    smtp_user: str = Form (...) , 
    smtp_password: str = Form (...) , 
    tls:bool = Form (...) 
):
    
    data = {
        "smtp_server": smtp_server,
        "smtp_port": smtp_port , 
        "smtp_user": smtp_user ,
        "smtp_password":smtp_password , 
        "tls":tls
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL gapi.email_configuration_upsert(
                :p_smtp_server , 
                :p_smtp_port   ,
                :p_smtp_user , 
                :p_smtp_password , 
                :p_tls               
            )
        """), {
            "p_smtp_server": smtp_server,
            "p_smtp_port":smtp_port  , 
            "p_smtp_user":smtp_user , 
            "p_smtp_password":smtp_password  , 
            "p_tls":tls        
        })

    except Exception as e:                    
                        db_write_log(f"email_configuration_upsert failed with error:{e}"   ,0,"email_configuration_upsert","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adcdjsj/email-configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.get("/custom_metrics_update")
def submit(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "custom_metrics.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.post("/submit_retention_policy")
def submit(row_id: int,request: Request):
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adc222t/retention-policy?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.get("/email_configuration")
def submit(row_id: int,request: Request):
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    _re_ip = get_public_or_ip()  # Your Grafana host IP     
    grafana_url = f"http://{_re_ip}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.get("/take_action")
def submit(row_id: int,request: Request):
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/ad2w7wd/take-action?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)



@app.post("/submit-processform")
async def show_processform(
    request: Request,                 # ⬅ REQUIRED
    process_name: str = Form(...),        
    interval: int = Form(...), 
    active: bool = Form(...)
):
    
    data = {
        "process_name": process_name,
        "Interval": interval,
        "Active": active
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.process_activate(
                :p_process_name,
                :p_interval,
                :p_active
            )
        """), {
            "p_process_name": process_name,
            "p_interval":interval ,
            "p_active": active
        })

    except Exception as e:                 
                        db_write_log(f"process_activate failed with error:{e}"   ,0,"process_activate","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/advf7vg/processes?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.post("/submit_custom_metrics_update")
async def show_custom_metrics_update(
    request: Request,                 # ⬅ REQUIRED
    row_id: int               
):
            pg_home_connection_string = get_connection_string()
            pg_postgres_home_engine = create_engine(pg_home_connection_string )
            _re_ip = get_public_or_ip()  # Your Grafana host IP    
            grafana_url = f"http://{_re_ip}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
            return RedirectResponse(url=grafana_url, status_code=302)

@app.post("/submit_custom_metrics")
async def show_custom_metrics(
    request: Request,                 # ⬅ REQUIRED
    process_name: str = Form(...),        
    interval: int = Form(...), 
    active: bool = Form(...)
):
    
    data = {
        "process_name": process_name,
        "Interval": interval,
        "Active": active
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.process_activate(
                :p_process_name,
                :p_interval,
                :p_active
            )
        """), {
            "p_process_name": process_name,
            "p_interval":interval ,
            "p_active": active
        })

    except Exception as e:                 
                        db_write_log(f"process_activate failed with error:{e}"   ,0,"process_activate","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/advf7vg/processes?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)


@app.post("/submit_metrics_enable")
async def show_metrics_enable(
    request: Request,                 # ⬅ REQUIRED
    process_name: str = Form(...),        
    interval: int = Form(...), 
    active: bool = Form(...)
):
    
    data = {
        "process_name": process_name,
        "Interval": interval,
        "Active": active
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.process_activate(
                :p_process_name,
                :p_interval,
                :p_active
            )
        """), {
            "p_process_name": process_name,
            "p_interval":interval ,
            "p_active": active
        })

    except Exception as e:                 
                        db_write_log(f"process_activate failed with error:{e}"   ,0,"process_activate","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/advf7vg/processes?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)


@app.post("/submit_retention_policy")
async def show_submit_retention_policy(
    request: Request,                 # ⬅ REQUIRED
    process_name: str = Form(...),        
    interval: int = Form(...), 
    active: bool = Form(...)
):
    
    data = {
        "process_name": process_name,
        "Interval": interval,
        "Active": active
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.process_activate(
                :p_process_name,
                :p_interval,
                :p_active
            )
        """), {
            "p_process_name": process_name,
            "p_interval":interval ,
            "p_active": active
        })

    except Exception as e:                 
                        db_write_log(f"process_activate failed with error:{e}"   ,0,"process_activate","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/advf7vg/processes?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)


@app.post("/test-connection")
async def test_connection(
    ipAddress: str = Form(...),
    port: str = Form(""),
    dbVendor: str = Form(...),
    authType: str = Form("sql"),
    user: str = Form(""),
    password: str = Form(""),
    service_name: str = Form("")
):
    try:
        if dbVendor.lower() in ('mssql', 'sqlserver'):
            import pyodbc
            drivers = pyodbc.drivers()
            driver = next((d for d in ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"] if d in drivers), None)
            if not driver:
                return JSONResponse({"success": False, "message": "No MSSQL ODBC driver installed"})
            if authType == "win":
                conn_str = f"DRIVER={{{driver}}};SERVER={ipAddress},{port};Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;Connect Timeout=10;"
            else:
                conn_str = f"DRIVER={{{driver}}};SERVER={ipAddress},{port};UID={user};PWD={password};Encrypt=yes;TrustServerCertificate=yes;Connect Timeout=10;"
            conn = pyodbc.connect(conn_str, timeout=10)
            cursor = conn.cursor()
            cursor.execute("SELECT @@VERSION")
            version = cursor.fetchone()[0]
            conn.close()
            return JSONResponse({"success": True, "message": f"Connected: {version[:80]}"})

        elif dbVendor.lower() in ('oracle',):
            import oracledb
            import os as _os
            oracledb.defaults.disable_oob = True
            # Use thick mode to avoid cryptography/x509 dependency
            lib_dir = _os.getenv("ORACLE_CLIENT_LIB_DIR", r"C:\oracle\instantclient_23_0")
            try:
                oracledb.init_oracle_client(lib_dir=lib_dir)
            except Exception:
                pass  # already initialized or not available
            dsn = f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={ipAddress})(PORT={int(port or 1521)}))(CONNECT_DATA=(SERVICE_NAME={service_name})))"
            try:
                conn = oracledb.connect(user=user, password=password, dsn=dsn)
            except Exception:
                dsn_ssl = f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST={ipAddress})(PORT={int(port or 1521)}))(CONNECT_DATA=(SERVICE_NAME={service_name}))(SECURITY=(SSL_SERVER_DN_MATCH=no)))"
                conn = oracledb.connect(user=user, password=password, dsn=dsn_ssl)
            cursor = conn.cursor()
            cursor.execute("SELECT banner FROM v$version WHERE ROWNUM = 1")
            version = cursor.fetchone()[0]
            conn.close()
            return JSONResponse({"success": True, "message": f"Connected: {version[:80]}"})

        elif dbVendor.lower() in ('postgres', 'postgresql'):
            conn = psycopg2.connect(host=ipAddress, port=int(port or 5432), user=user, password=password, dbname='postgres', connect_timeout=10)
            cursor = conn.cursor()
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            conn.close()
            return JSONResponse({"success": True, "message": f"Connected: {version[:80]}"})

        elif dbVendor.lower() in ('mysql', 'mariadb'):
            import pymysql
            conn = pymysql.connect(host=ipAddress, port=int(port or 3306), user=user, password=password, connect_timeout=10)
            cursor = conn.cursor()
            cursor.execute("SELECT VERSION()")
            version = cursor.fetchone()[0]
            conn.close()
            return JSONResponse({"success": True, "message": f"Connected: {version}"})

        else:
            return JSONResponse({"success": False, "message": f"Unsupported vendor: {dbVendor}"})

    except Exception as e:
        return JSONResponse({"success": False, "message": str(e)[:200]})


@app.post("/submit-serverform")
async def show_server_form(
    server: str = Form(...),
    add_delete_modify: str = Form(...),
    ipAddress: str = Form(...),
    port: int = Form(...),
    dbVendor: str = Form(...),
    dbVersion: str = Form(""),
    authType: str = Form(...),
    user: str = Form(""),       
    password: str = Form(""),
    service_name: str = Form("")
):
    
    data = {
        "server_name": server,
        "add_delete_modify":add_delete_modify,
        "ip_address": ipAddress,
        "port": port,
        "db_vendor": dbVendor,
        "db_version": dbVersion,
        "auth_type": authType,
        "user": user,
        "password": password , 
        "service_name":service_name
    }
    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters

            # Call the procedure using bind parameters
            

            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.upsert_monitored_server(
                :p_ip_address,
                :p_server_name,
                :p_db_vendor,
                :p_db_version,
                :p_auth_type,
                :p_username,
                :p_password , 
                :p_service_name,
                :p_port,                    
                :p_add_modify_delete
            )
        """), {
            "p_ip_address": ipAddress,
            "p_server_name":server ,
            "p_db_vendor": dbVendor,
            "p_db_version": dbVersion,
            "p_auth_type": authType,
            "p_username": user,
            "p_password": password,
            "p_service_name":service_name,
            "p_port": port,                 
            "p_add_modify_delete": add_delete_modify
        })

    except Exception as e:                 
                        db_write_log(f"save_servers failed with error:{e}"   ,0,"save_servers","" )

    with open("server_data.json", "w") as f:
        json.dump(data, f, indent=2)
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adsddxs/7-automation-and-workflows?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)
   
@app.post("/submit_siem_configuration")
async def show_siem_configuration(
    request: Request,                 # ⬅ REQUIRED
    select_vendor : str = Form (...) , 
    url: str = Form(...),        
    secret: str = Form(...)    
):
    
    data = {
        "siem_vendor": select_vendor,
        "url": url,
        "secret": secret
    }

    
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    metadata = MetaData(schema="metrics")  
    try:
            # Parameters
            # Call the procedure using bind parameters
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""                    
            CALL metrics.siem_upsert(
                :p_siem_interface_name , 
                :p_siem_url  , 
                :p_app_key 
            )
        """), {
            "p_siem_interface_name": select_vendor,
            "p_siem_url":url ,
            "p_app_key": secret
        })

    except Exception as e:                 
                        db_write_log(f"siem_upsert failed with error:{e}"   ,0,"siem_upsert","" )
    _re_ip = get_public_or_ip()  # Your Grafana host IP    
    grafana_url = f"http://{_re_ip}:3000/d/adgtwcf/siem-configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)

@app.post("/submit-generate_report")
async def report_capture(   
    request: Request,
    report: str = Form(...), 
    recipients:str = Form(...) , 
    referer:str = Form(...) , 
    ):
    try:        
        pg_connection_string = get_connection_string()
        # Connect to the PostgreSQL database
        conn = psycopg2.connect(pg_connection_string)
        # Create a cursor
        cur = conn.cursor()
            # Query the view
        p_report_sqlcmd = f"""
          select report_url from config.reports where report_name = %s
        """
        
        # Create a cursor        
        cur.execute(p_report_sqlcmd, (report,))
        rows = cur.fetchall()
        for row in rows:                                     
            report_file         = row[0]     
            generator = JSONReportGenerator(report_file)
            pdf_file  , html_file = generator.generate()             

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
                
                send_mail_with_html_attachment(
                    report , 
                    pdf_file , 
                    html_file,
                    recipients,
                    mail_sender,
                    smtp_user,
                    smtp_server,
                    smtp_port,
                    smtp_password,
                    tls , 
                    conn
                ) 
        db_write_log(f"send_alert_email_and_log succeeded", 0 ,"send_alert_email_and_log" ,"")   
    except Exception as e:               
        db_write_log(f"generate_report failed with error:{e}"   , 0 ,"generate_report" ,"generate_report")
    finally:                  
               
                #  Clean up
                cur.close()
                conn.close()
                _re_ip =  get_public_or_ip()       
    redirect_url = referer if referer and referer != "None" else f"http://{get_public_or_ip()}:3000/d/ad7kkx7/alerts"
    return RedirectResponse(url=redirect_url, status_code=302)




@app.post("/submit-report_capture")
async def report_capture(   
    request: Request,
    report: str = Form(...), 
    url: str = Form(...),
    recipients:str = Form(...) , 
    referer:str = Form(...) , 
    ):
    try:        
        await capture_grafana_dashboard_pdf (url , report , recipients)
    except Exception as e:               
        db_write_log(f"send_alert_email_and_log failed with error:{e}"   , "send_alert_email_and_log" ,"send_alert_email_and_log" ,"send_alert_email_and_log")
    finally:                    
            _re_ip =  get_public_or_ip()                

    if referer:
        return RedirectResponse(url=f"{referer}", status_code=302)
    

    # fallback if referer is missing
    return RedirectResponse(
        url=f"http://{get_public_or_ip()}:3000/d/ad6lv7f/transaction-report",
        status_code=302
    )
                
    return RedirectResponse(url=f"http://{_re_ip}:/3000/d/ad6lv7f/transaction-report", status_code=302)


# ---------------------------------------------------------------------------
# Alert Dashboard — Security alert flowchart
# ---------------------------------------------------------------------------

ALERT_DASHBOARD_SQL = """
    SELECT
        mal.server,
        mal.metric_name AS root_cause_id,
        mal.subject,
        mal.entry_date,
        rc.name AS root_cause_name,
        rc.description AS root_cause_desc,
        i.issue_id,
        i.name AS issue_name,
        a.code AS area_code,
        a.name AS area_name,
        d.code AS domain_code,
        d.name AS domain_name,
        COALESCE(
            (SELECT ds.expected->>'severity'
             FROM rootcause.detection_paths dp
             JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id AND dps.sequence = 1
             JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
             WHERE dp.root_cause_id = mal.metric_name AND dp.is_active = true
             LIMIT 1), 'medium') AS severity
    FROM alerts.mail_alert_log mal
    LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = mal.metric_name
    LEFT JOIN rootcause.issues i ON i.issue_id = rc.issue_id
    LEFT JOIN rootcause.areas a ON a.code = i.area_code AND a.database_type_code = i.database_type_code
    LEFT JOIN rootcause.domains d ON d.code = i.domain_code
    WHERE mal.entry_date >= NOW() - make_interval(days => %s)
      AND (d.code = 'SEC' OR d.code IS NULL)
"""


def build_alert_tree(rows):
    """Build hierarchical tree from alert rows."""
    tree = {"name": "SEC - Security", "type": "domain", "id": "SEC", "code": "SEC", "children": []}

    server_map = {}
    for r in rows:
        srv = r["server"] or "unknown"
        area_code = r.get("area_code") or "UNK"
        area_name = r.get("area_name") or "Unknown Area"
        issue_id = r.get("issue_id") or "UNK"
        issue_name = r.get("issue_name") or "Unknown Issue"
        rc_id = r.get("root_cause_id") or "UNK"
        rc_name = r.get("root_cause_name") or rc_id
        rc_desc = r.get("root_cause_desc") or ""
        sev = r.get("severity") or "medium"
        entry_date = r["entry_date"].strftime("%Y-%m-%d %H:%M") if r.get("entry_date") else ""

        if srv not in server_map:
            server_map[srv] = {"name": srv, "type": "server", "id": f"srv-{srv}", "_areas": {}}

        am = server_map[srv]["_areas"]
        if area_code not in am:
            am[area_code] = {"name": f"{area_code} - {area_name}", "type": "area", "id": f"{srv}-{area_code}", "code": area_code, "_issues": {}}

        im = am[area_code]["_issues"]
        if issue_id not in im:
            im[issue_id] = {"name": issue_name, "type": "issue", "id": f"{srv}-{issue_id}", "code": issue_id, "_rcs": {}}

        rm = im[issue_id]["_rcs"]
        if rc_id not in rm:
            rm[rc_id] = {
                "name": rc_name, "type": "rootcause", "id": f"{srv}-{rc_id}",
                "code": rc_id, "severity": sev, "description": rc_desc,
                "alert_count": 0, "last_alert": ""
            }
        rm[rc_id]["alert_count"] += 1
        if entry_date > rm[rc_id].get("last_alert", ""):
            rm[rc_id]["last_alert"] = entry_date

    # Convert nested dicts to children arrays
    for srv_node in server_map.values():
        srv_node["children"] = []
        for area_node in srv_node.pop("_areas").values():
            area_node["children"] = []
            for issue_node in area_node.pop("_issues").values():
                issue_node["children"] = list(issue_node.pop("_rcs").values())
                area_node["children"].append(issue_node)
            srv_node["children"].append(area_node)
        tree["children"].append(srv_node)

    return tree


@app.get("/alert_dashboard", response_class=HTMLResponse)
async def alert_dashboard(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "alert_dashboard.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/api/alert_dashboard")
async def api_alert_dashboard(days: int = 7, server: str = None, severity: str = None):
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        sql = ALERT_DASHBOARD_SQL
        params = [days]
        if server:
            sql += " AND mal.server = %s"
            params.append(server)
        sql += " ORDER BY mal.entry_date DESC"
        cur.execute(sql, params)
        columns = [desc[0] for desc in cur.description]
        rows = [dict(zip(columns, row)) for row in cur.fetchall()]
        if severity:
            rows = [r for r in rows if r.get('severity') == severity]

        sev_counts = {"critical": 0, "high": 0, "medium": 0}
        servers_set, rc_set = set(), set()
        for r in rows:
            servers_set.add(r["server"])
            rc_set.add(r["root_cause_id"])
            s = r.get("severity", "medium")
            if s in sev_counts:
                sev_counts[s] += 1

        cur.execute("SELECT DISTINCT server FROM alerts.mail_alert_log WHERE entry_date >= NOW() - INTERVAL '90 days' ORDER BY server")
        all_servers = [r[0] for r in cur.fetchall()]

        return JSONResponse({
            "stats": {"total_alerts": len(rows), **sev_counts, "servers": len(servers_set), "root_causes": len(rc_set)},
            "servers": all_servers,
            "tree": build_alert_tree(rows)
        })
    except Exception as e:
        return JSONResponse({"error": str(e), "stats": {"total_alerts":0,"critical":0,"high":0,"medium":0,"servers":0,"root_causes":0}, "servers": [], "tree": {"name":"SEC","type":"domain","children":[]}}, status_code=500)
    finally:
        cur.close()
        conn.close()


# ---------------------------------------------------------------------------
# Report Scheduling Configuration
# ---------------------------------------------------------------------------

@app.get("/report_schedule", response_class=HTMLResponse)
async def report_schedule_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "report_schedule.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/api/report-schedules")
async def api_report_schedules():
    """Return all reports and their schedule configurations."""
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        # All reports
        cur.execute("SELECT row_id, report_name, is_active, report_url FROM config.reports ORDER BY row_id")
        reports = [{"row_id": r[0], "report_name": r[1], "is_active": r[2], "report_url": r[3]} for r in cur.fetchall()]

        # Scheduled reports with job info
        cur.execute("""
            SELECT r.row_id AS report_id, r.report_name, r.is_active, r.report_url,
                   j.occurance, j.occurs_at::text,
                   mg.recipients
            FROM config.reports r
            LEFT JOIN config.reports_jobs rj ON rj.report_id = r.row_id
            LEFT JOIN jobs.jobs j ON j.row_id = rj.job_id
            LEFT JOIN config.mail_groups mg ON mg.mail_config_id = 1 AND mg.is_active = true
            ORDER BY r.row_id
        """)
        columns = [desc[0] for desc in cur.description]
        schedules = [dict(zip(columns, row)) for row in cur.fetchall()]

        return JSONResponse({"reports": reports, "schedules": schedules})
    except Exception as e:
        return JSONResponse({"error": str(e), "reports": [], "schedules": []}, status_code=500)
    finally:
        cur.close()
        conn.close()


@app.post("/submit-report-schedule")
async def submit_report_schedule(
    report_id: str = Form(None),
    report_name: str = Form(None),
    schedule: str = Form("daily"),
    occurs_at: str = Form("06:00"),
    recipients: str = Form(None),
    report_type: str = Form("json"),
    report_query: str = Form(None),
    report_url: str = Form(None),
    is_active: str = Form("true"),
):
    """Create or update a report schedule."""
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = False
    cur = conn.cursor()
    try:
        active = is_active == "true"

        # Create new report or use existing
        if report_id == "new" or not report_id:
            if not report_name:
                return JSONResponse({"message": "Report name is required"}, status_code=400)
            query = report_query or "JSON-based report - see report_url for template"
            cur.execute(
                "INSERT INTO config.reports (report_name, report_query, is_active, report_url) VALUES (%s, %s, %s, %s) RETURNING row_id",
                (report_name, query, active, report_url)
            )
            rid = cur.fetchone()[0]
        else:
            rid = int(report_id)
            # Update existing report
            updates = ["is_active = %s"]
            params = [active]
            if report_url:
                updates.append("report_url = %s")
                params.append(report_url)
            if report_query and report_type == "query":
                updates.append("report_query = %s")
                params.append(report_query)
            params.append(rid)
            cur.execute(f"UPDATE config.reports SET {', '.join(updates)} WHERE row_id = %s", params)

        # Create or find job schedule
        schedule_type = 1 if schedule in ("daily", "hourly", "weekly", "monthly") else 2
        cur.execute(
            "SELECT row_id FROM jobs.jobs WHERE occurance = %s AND occurs_at = %s::time LIMIT 1",
            (schedule, occurs_at)
        )
        job_row = cur.fetchone()
        if job_row:
            job_id = job_row[0]
        else:
            cur.execute(
                "INSERT INTO jobs.jobs (schedule_type, occurance, occurs_at) VALUES (%s, %s, %s::time) RETURNING row_id",
                (schedule_type, schedule, occurs_at)
            )
            job_id = cur.fetchone()[0]

        # Link report to job (upsert)
        cur.execute("SELECT row_id FROM config.reports_jobs WHERE report_id = %s", (rid,))
        if cur.fetchone():
            cur.execute("UPDATE config.reports_jobs SET job_id = %s WHERE report_id = %s", (job_id, rid))
        else:
            cur.execute("INSERT INTO config.reports_jobs (report_id, job_id) VALUES (%s, %s)", (rid, job_id))

        # Create job schedule entry if not exists
        cur.execute("SELECT row_id FROM jobs.job_schedules WHERE report_id = %s", (rid,))
        if not cur.fetchone():
            cur.execute(
                "INSERT INTO jobs.job_schedules (report_id, schedule_id, next_run) VALUES (%s, %s, NOW())",
                (rid, job_id)
            )

        # Update recipients if provided
        if recipients and recipients.strip():
            cur.execute(
                """INSERT INTO config.mail_groups (mail_config_id, group_name, recipients, is_active)
                   VALUES (1, %s, %s, true)
                   ON CONFLICT DO NOTHING""",
                (f"report_{rid}", recipients.strip())
            )

        conn.commit()
        return JSONResponse({"message": f"Report schedule saved (ID: {rid})", "report_id": rid})

    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": f"Error: {str(e)}"}, status_code=500)
    finally:
        cur.close()
        conn.close()


@app.post("/api/toggle-report")
async def api_toggle_report(request: Request):
    """Toggle a report's active status."""
    data = await request.json()
    report_id = data.get("report_id")
    is_active = data.get("is_active", False)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("UPDATE config.reports SET is_active = %s WHERE row_id = %s", (is_active, report_id))
        conn.commit()
        return JSONResponse({"message": "Updated", "report_id": report_id, "is_active": is_active})
    except Exception as e:
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close()
        conn.close()


# ---------------------------------------------------------------------------
# Sensitive Schema Configuration
# ---------------------------------------------------------------------------

PII_PATTERNS = (
    '(ssn|social_sec|national_id|tax_id|id_number|id_card|identity|passport|'
    'credit_card|card_num|card_number|cvv|ccv|'
    'email|e_mail|mail_address|'
    'phone|mobile|cell|fax|telephone|'
    'birth_date|dob|date_of_birth|birthday|'
    'first_name|last_name|full_name|surname|family_name|given_name|'
    'address|street|city|zip_code|postal|zipcode|'
    'salary|income|wage|compensation|'
    'bank_account|iban|routing_num|account_num|swift|'
    'password|pwd|secret|token|api_key|'
    'ip_address|mac_address|'
    'gender|sex|race|ethnicity|religion|'
    'medical|diagnosis|prescription|patient|health|'
    'driver_license|licence|social_security)'
)


@app.get("/sensitive_schema", response_class=HTMLResponse)
async def sensitive_schema_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "sensitive_schema.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/api/sensitive-schema")
async def api_sensitive_schema():
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        # Get sensitive columns
        cur.execute("""
            SELECT row_id, server, database_name, table_name, column_name, data_type, 'sensitive' AS source, true AS is_enabled, true AS is_sensitive
            FROM monitoring.sensitive_schema
            UNION ALL
            SELECT row_id, server, table_catalog AS database_name, table_name, column_name, data_type, 'schema' AS source, COALESCE(is_enabled, true), false AS is_sensitive
            FROM monitoring.schema
            WHERE lower(column_name) ~ %s
              AND NOT EXISTS (
                  SELECT 1 FROM monitoring.sensitive_schema ss
                  WHERE ss.server = monitoring.schema.server
                    AND COALESCE(ss.database_name, '') = COALESCE(monitoring.schema.table_catalog, '')
                    AND ss.table_name = monitoring.schema.table_name
                    AND ss.column_name = monitoring.schema.column_name
              )
            ORDER BY server, database_name, table_name, column_name
        """, (PII_PATTERNS,))
        columns_list = [desc[0] for desc in cur.description]
        all_columns = [dict(zip(columns_list, row)) for row in cur.fetchall()]

        # Stats
        cur.execute("SELECT COUNT(*) FROM monitoring.schema")
        total = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM monitoring.sensitive_schema")
        sensitive = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM monitoring.schema WHERE is_enabled = true AND lower(column_name) ~ %s", (PII_PATTERNS,))
        enabled = cur.fetchone()[0]

        # Servers and databases
        cur.execute("SELECT DISTINCT server FROM monitoring.schema ORDER BY server")
        servers = [r[0] for r in cur.fetchall()]
        cur.execute("SELECT DISTINCT table_catalog FROM monitoring.schema WHERE table_catalog IS NOT NULL ORDER BY table_catalog")
        databases = [r[0] for r in cur.fetchall()]

        return JSONResponse({
            "columns": all_columns,
            "stats": {
                "total_columns": total,
                "sensitive_columns": sensitive,
                "enabled": enabled,
                "disabled": len(all_columns) - enabled,
                "servers": len(servers),
            },
            "servers": servers,
            "databases": databases,
        })
    except Exception as e:
        return JSONResponse({"error": str(e), "columns": [], "stats": {}, "servers": [], "databases": []}, status_code=500)
    finally:
        cur.close()
        conn.close()


@app.post("/api/sensitive-schema/toggle")
async def api_toggle_sensitive(request: Request):
    data = await request.json()
    source = data.get("source")
    row_id = data.get("row_id")
    is_enabled = data.get("is_enabled", True)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        if source == "schema":
            cur.execute("UPDATE monitoring.schema SET is_enabled = %s WHERE row_id = %s", (is_enabled, row_id))
        elif source == "sensitive":
            if not is_enabled:
                cur.execute("DELETE FROM monitoring.sensitive_schema WHERE row_id = %s", (row_id,))
            # Re-insert handled by discovery
        conn.commit()
        return JSONResponse({"message": "Updated"})
    except Exception as e:
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close()
        conn.close()


@app.post("/api/sensitive-schema/bulk-toggle")
async def api_bulk_toggle_sensitive(request: Request):
    data = await request.json()
    items = data.get("items", [])
    is_enabled = data.get("is_enabled", True)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        for item in items:
            if item["source"] == "schema":
                cur.execute("UPDATE monitoring.schema SET is_enabled = %s WHERE row_id = %s", (is_enabled, item["row_id"]))
            elif item["source"] == "sensitive" and not is_enabled:
                cur.execute("DELETE FROM monitoring.sensitive_schema WHERE row_id = %s", (item["row_id"],))
        conn.commit()
        return JSONResponse({"message": f"{len(items)} columns updated"})
    except Exception as e:
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close()
        conn.close()


@app.post("/api/sensitive-schema/discover")
async def api_discover_sensitive():
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = False
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO monitoring.sensitive_schema
                (server, database_name, table_schema, table_name, column_name, data_type)
            SELECT DISTINCT s.server, s.table_catalog, NULL, s.table_name, s.column_name, s.data_type
            FROM monitoring.schema s
            WHERE lower(s.column_name) ~ %s
              AND s.is_enabled = true
              AND NOT EXISTS (
                  SELECT 1 FROM monitoring.sensitive_schema ss
                  WHERE ss.server = s.server
                    AND COALESCE(ss.database_name, '') = COALESCE(s.table_catalog, '')
                    AND ss.table_name = s.table_name
                    AND ss.column_name = s.column_name
              )
        """, (PII_PATTERNS,))
        inserted = cur.rowcount
        conn.commit()
        cur.execute("SELECT COUNT(*) FROM monitoring.sensitive_schema")
        total = cur.fetchone()[0]
        return JSONResponse({"message": f"Discovery complete: {inserted} new sensitive columns found ({total} total)"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": f"Discovery failed: {str(e)}"}, status_code=500)
    finally:
        cur.close()
        conn.close()


# ---------------------------------------------------------------------------
# Alert Thresholds Configuration
# ---------------------------------------------------------------------------

@app.get("/alert_thresholds", response_class=HTMLResponse)
async def alert_thresholds_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "alert_thresholds.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/alert-thresholds")
async def api_alert_thresholds():
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT at.row_id, a.alert_name, t.level, t.value_start, t.value_end, at.alert_id, at.threshold_id
            FROM config.alerts_thresholds at
            JOIN config.alerts a ON a.row_id = at.alert_id
            JOIN config.thresholds t ON t.row_id = at.threshold_id
            ORDER BY a.alert_name
        """)
        cols = [d[0] for d in cur.description]
        thresholds = [dict(zip(cols, r)) for r in cur.fetchall()]
        # Convert Decimal to float
        for t in thresholds:
            t['value_start'] = float(t['value_start']) if t['value_start'] else 0
            t['value_end'] = float(t['value_end']) if t['value_end'] else 0

        cur.execute("SELECT row_id, alert_name FROM config.alerts ORDER BY alert_name")
        alerts = [{"row_id": r[0], "alert_name": r[1]} for r in cur.fetchall()]

        return JSONResponse({"thresholds": thresholds, "alerts": alerts})
    except Exception as e:
        return JSONResponse({"error": str(e), "thresholds": [], "alerts": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/submit-alert-threshold")
async def submit_alert_threshold(
    alert_id: int = Form(...), level: int = Form(3),
    value_start: float = Form(0), value_end: float = Form(100),
    row_id: int = Form(None)
):
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        if row_id:
            cur.execute("""
                UPDATE config.thresholds SET level=%s, value_start=%s, value_end=%s
                WHERE row_id = (SELECT threshold_id FROM config.alerts_thresholds WHERE row_id=%s)
            """, (level, value_start, value_end, row_id))
        else:
            cur.execute("INSERT INTO config.thresholds (level, value_start, value_end) VALUES (%s,%s,%s) RETURNING row_id",
                        (level, value_start, value_end))
            tid = cur.fetchone()[0]
            cur.execute("INSERT INTO config.alerts_thresholds (alert_id, threshold_id) VALUES (%s,%s)", (alert_id, tid))
        conn.commit()
        return JSONResponse({"message": "Threshold saved"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/delete-threshold")
async def api_delete_threshold(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("SELECT threshold_id FROM config.alerts_thresholds WHERE row_id=%s", (data["row_id"],))
        row = cur.fetchone()
        cur.execute("DELETE FROM config.alerts_thresholds WHERE row_id=%s", (data["row_id"],))
        if row:
            cur.execute("DELETE FROM config.thresholds WHERE row_id=%s", (row[0],))
        conn.commit()
        return JSONResponse({"message": "Deleted"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# Alert Rules Configuration
# ---------------------------------------------------------------------------

@app.get("/alert_rules", response_class=HTMLResponse)
async def alert_rules_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "alert_rules.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/alert-rules")
async def api_alert_rules():
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT air.row_id, air.issue_id, air.rootcause_number, air.event_rule_id,
                   a.alert_name,
                   COALESCE(wa.send_mail_alert, false) AS send_mail,
                   COALESCE(wa.send_siem_alert, false) AS send_siem,
                   COALESCE(wa.send_diagnosis_evidence, false) AS send_diagnosis
            FROM config.alerts_issue_root_causes air
            LEFT JOIN config.alerts a ON a.row_id = air.event_rule_id
            LEFT JOIN config.webook_alerts wa ON wa.row_id = 1
            ORDER BY air.issue_id, air.rootcause_number
        """)
        cols = [d[0] for d in cur.description]
        rules = [dict(zip(cols, r)) for r in cur.fetchall()]

        cur.execute("SELECT DISTINCT issue_id, name FROM rootcause.issues ORDER BY issue_id")
        issues = [{"issue_id": r[0], "name": r[1]} for r in cur.fetchall()]

        cur.execute("SELECT row_id, alert_name FROM config.alerts ORDER BY alert_name")
        alerts = [{"row_id": r[0], "alert_name": r[1]} for r in cur.fetchall()]

        return JSONResponse({"rules": rules, "issues": issues, "alerts": alerts})
    except Exception as e:
        return JSONResponse({"error": str(e), "rules": [], "issues": [], "alerts": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/submit-alert-rule")
async def submit_alert_rule(
    issue_id: str = Form(...), rootcause_number: int = Form(1),
    event_rule_id: int = Form(...), row_id: int = Form(None)
):
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        if row_id:
            cur.execute("UPDATE config.alerts_issue_root_causes SET issue_id=%s, rootcause_number=%s, event_rule_id=%s WHERE row_id=%s",
                        (issue_id, rootcause_number, event_rule_id, row_id))
        else:
            cur.execute("INSERT INTO config.alerts_issue_root_causes (issue_id, rootcause_number, event_rule_id) VALUES (%s,%s,%s)",
                        (issue_id, rootcause_number, event_rule_id))
        conn.commit()
        return JSONResponse({"message": "Alert rule saved"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/delete-alert-rule")
async def api_delete_alert_rule(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM config.alerts_issue_root_causes WHERE row_id=%s", (data["row_id"],))
        conn.commit()
        return JSONResponse({"message": "Deleted"})
    except Exception as e:
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# Global Parameters
# ---------------------------------------------------------------------------

@app.get("/global_params", response_class=HTMLResponse)
async def global_params_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "global_params.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/global-params")
async def api_global_params():
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("SELECT key, value FROM config.global_params ORDER BY key")
        params = [{"key": r[0], "value": r[1]} for r in cur.fetchall()]
        return JSONResponse({"params": params})
    except Exception as e:
        return JSONResponse({"error": str(e), "params": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/submit-global-param")
async def submit_global_param(key: str = Form(...), value: str = Form("")):
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("SELECT 1 FROM config.global_params WHERE key=%s", (key,))
        if cur.fetchone():
            cur.execute("UPDATE config.global_params SET value=%s WHERE key=%s", (value, key))
        else:
            cur.execute("INSERT INTO config.global_params (key, value) VALUES (%s,%s)", (key, value))
        conn.commit()
        return JSONResponse({"message": f"Parameter '{key}' saved"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/delete-global-param")
async def api_delete_global_param(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM config.global_params WHERE key=%s", (data["key"],))
        conn.commit()
        return JSONResponse({"message": "Deleted"})
    except Exception as e:
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# Webhook & Alert Channels
# ---------------------------------------------------------------------------

@app.get("/webhook_alerts", response_class=HTMLResponse)
async def webhook_alerts_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "webhook_alerts.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/webhook-alerts")
async def api_webhook_alerts():
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("SELECT row_id, metric_type, send_mail_alert, send_siem_alert, send_diagnosis_evidence FROM config.webook_alerts ORDER BY metric_type")
        cols = [d[0] for d in cur.description]
        channels = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"channels": channels})
    except Exception as e:
        return JSONResponse({"error": str(e), "channels": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/submit-webhook-alert")
async def submit_webhook_alert(
    metric_type: str = Form(...),
    send_mail_alert: str = Form("false"),
    send_siem_alert: str = Form("false"),
    send_diagnosis_evidence: str = Form("false"),
    row_id: int = Form(None)
):
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        mail = send_mail_alert == "true"
        siem = send_siem_alert == "true"
        diag = send_diagnosis_evidence == "true"
        if row_id:
            cur.execute("UPDATE config.webook_alerts SET metric_type=%s, send_mail_alert=%s, send_siem_alert=%s, send_diagnosis_evidence=%s WHERE row_id=%s",
                        (metric_type, mail, siem, diag, row_id))
        else:
            cur.execute("INSERT INTO config.webook_alerts (metric_type, send_mail_alert, send_siem_alert, send_diagnosis_evidence) VALUES (%s,%s,%s,%s)",
                        (metric_type, mail, siem, diag))
        conn.commit()
        return JSONResponse({"message": "Alert channel saved"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/delete-webhook-alert")
async def api_delete_webhook_alert(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM config.webook_alerts WHERE row_id=%s", (data["row_id"],))
        conn.commit()
        return JSONResponse({"message": "Deleted"})
    except Exception as e:
        return JSONResponse({"message": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# Print Panel to PDF
#
# Re-runs a Grafana panel's SQL using the current dashboard variable values
# and returns a generated PDF. Wired up to a "Print PDF" Panel Link added
# to each table panel by tools/add_print_links_to_panels.py.
#
# NOTE: only dashboard variables (e.g. $server, $risk_level) are honored —
# Grafana panel links can't pass the table's local row-search field.
# ---------------------------------------------------------------------------
def _grafana_db_path():
    """Path to grafana.db. GRAFANA_DB env var overrides; default is
    platform-specific (Windows ProgramData, Linux /var/lib/grafana)."""
    p = os.getenv("GRAFANA_DB")
    if p:
        return p
    if os.name == "nt":
        return r"C:\ProgramData\DBDOME\data\grafana.db"
    return "/var/lib/grafana/grafana.db"


def _walk_panels(panels):
    """Yield panels including those nested inside row containers."""
    for panel in panels or []:
        yield panel
        for sub in panel.get("panels", []):
            yield sub


def _lookup_panel_sql(dashboard_uid, panel_id):
    """Return (panel_title, raw_sql, var_defaults) for the requested panel
    by reading grafana.db directly. `var_defaults` maps each dashboard
    templating variable name to its current value (used as a fallback when
    the print/email link URL was generated before the variable existed).
    Raises ValueError if not found."""
    panel_id_int = int(panel_id)
    conn = sqlite3.connect(_grafana_db_path())
    try:
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("SELECT data FROM dashboard WHERE uid = ? LIMIT 1", (dashboard_uid,))
        row = cur.fetchone()
        if row is None:
            raise ValueError(f"Dashboard not found: uid={dashboard_uid}")
        dash = json.loads(row["data"])
        var_defaults = {}
        for v in (dash.get("templating", {}).get("list") or []):
            name = v.get("name")
            if not name:
                continue
            cur_v = (v.get("current") or {}).get("value")
            if isinstance(cur_v, list):
                cur_v = cur_v[0] if cur_v else ""
            if cur_v is None:
                cur_v = ""
            var_defaults[name] = str(cur_v)
        for panel in _walk_panels(dash.get("panels", [])):
            if panel.get("id") == panel_id_int:
                title = panel.get("title", "")
                targets = panel.get("targets", []) or []
                if not targets:
                    raise ValueError(f"Panel {panel_id} has no SQL targets")
                sql = (
                    targets[0].get("rawSql")
                    or targets[0].get("query")
                    or targets[0].get("expr")
                    or ""
                )
                if not sql:
                    raise ValueError(f"Panel {panel_id} target has no SQL")
                return title, sql, var_defaults
        raise ValueError(f"Panel id {panel_id} not in dashboard {dashboard_uid}")
    finally:
        conn.close()


def _parse_grafana_time(value, default):
    """Parse a Grafana time value: epoch ms/s, ISO string, or 'now[-Nunit]'
    where unit is s/m/h/d/w/M/y. Returns a datetime; falls back to default."""
    if value is None or value == "":
        return default
    s = str(value).strip()
    try:
        n = int(s)
        return datetime.utcfromtimestamp(n / 1000.0 if n > 10**12 else n)
    except (ValueError, TypeError):
        pass
    if s.startswith("now"):
        rest = s[3:]
        if not rest:
            return datetime.utcnow()
        m = re.match(r'^-(\d+)([smhdwMy])$', rest)
        if m:
            n, unit = int(m.group(1)), m.group(2)
            now = datetime.utcnow()
            mult = {"s": timedelta(seconds=1), "m": timedelta(minutes=1),
                    "h": timedelta(hours=1),   "d": timedelta(days=1),
                    "w": timedelta(weeks=1),   "M": timedelta(days=30),
                    "y": timedelta(days=365)}[unit]
            return now - n * mult
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return default


def _substitute_grafana_time_macros(sql, time_from, time_to):
    """Replace $__timeFrom(), $__timeTo(), and $__timeFilter(col) with
    SQL-literal timestamps so the panel SQL is executable outside Grafana."""
    from_lit = "'" + time_from.strftime("%Y-%m-%d %H:%M:%S") + "'"
    to_lit   = "'" + time_to.strftime("%Y-%m-%d %H:%M:%S")   + "'"
    sql = re.sub(r'\$__timeFrom\s*\(\s*\)', from_lit, sql)
    sql = re.sub(r'\$__timeTo\s*\(\s*\)',   to_lit,   sql)
    sql = re.sub(r'\$__timeFrom\b(?!\s*\()', from_lit, sql)
    sql = re.sub(r'\$__timeTo\b(?!\s*\()',   to_lit,   sql)
    sql = re.sub(
        r'\$__timeFilter\s*\(\s*([a-zA-Z_][\w\.]*)\s*\)',
        lambda m: f"{m.group(1)} BETWEEN {from_lit} AND {to_lit}",
        sql,
    )
    return sql


def _substitute_grafana_vars(sql, params):
    """Substitute ${var} and $var placeholders verbatim, matching the
    Grafana PostgreSQL plugin: the value is inlined as-is with no auto-
    quoting. Panel authors wrap the placeholder in single quotes when the
    value is meant to be a string literal (e.g. WHERE col = '${var}'); if
    we auto-quoted, that pattern would produce ''value'' and a syntax
    error. Variables not in `params` are left untouched."""
    def repl(m):
        name = m.group(1) or m.group(2)
        if name not in params:
            return m.group(0)
        v = params[name]
        return "" if v is None else str(v)
    sql = re.sub(r'\$\{([a-zA-Z_][a-zA-Z0-9_]*)\}', repl, sql)
    sql = re.sub(r'\$([a-zA-Z_][a-zA-Z0-9_]*)', repl, sql)
    return sql


def _build_panel_pdf(dashboard_uid, panel_id, params, from_param, to_param):
    """Resolve the panel's SQL, run it, render a PDF, and return
    (pdf_path, pdf_filename, title). Raises ValueError for missing
    panels/dashboards; other exceptions propagate."""
    title, raw_sql, var_defaults = _lookup_panel_sql(dashboard_uid, panel_id)
    default_to   = datetime.utcnow()
    default_from = default_to - timedelta(hours=6)
    time_to   = _parse_grafana_time(to_param,   default_to)
    time_from = _parse_grafana_time(from_param, default_from)
    merged_params = dict(var_defaults)
    merged_params.update(params)
    sql = _substitute_grafana_time_macros(raw_sql, time_from, time_to)
    sql = _substitute_grafana_vars(sql, merged_params)

    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute(sql)
        columns = [d[0] for d in cur.description] if cur.description else []
        rows    = cur.fetchall() if cur.description else []
    finally:
        conn.close()

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    output_dir = os.path.join(os.getcwd(), "reports")
    os.makedirs(output_dir, exist_ok=True)
    safe = re.sub(r'[^\w\-]+', '_', title or f"panel{panel_id}")[:80] or "panel"
    pdf_filename = f"{safe}_{timestamp}.pdf"
    pdf_path = os.path.join(output_dir, pdf_filename)

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    export_to_pdf_once(
        columns, rows, pdf_path,
        now_str, now_str,
        logo_path=LOGO_PATH,
        _header=title or f"Panel {panel_id}",
    )
    return pdf_path, pdf_filename, title


def _load_mail_config():
    """Return a dict with SMTP fields from config.mail_config (first row),
    or None if not configured. Keys: mail_sender, smtp_port, smtp_user,
    smtp_password, tls, smtp_server."""
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT mail_sender, smtp_port, smtp_user, smtp_password, "
            "       tls, smtp_server "
            "FROM config.mail_config LIMIT 1"
        )
        row = cur.fetchone()
    finally:
        conn.close()
    if not row:
        return None
    return {
        "mail_sender":   row[0],
        "smtp_port":     row[1],
        "smtp_user":     row[2],
        "smtp_password": row[3],
        "tls":           row[4],
        "smtp_server":   row[5],
    }


def _send_pdf_email(pdf_path, pdf_filename, recipients, subject, body, mc):
    """Send `pdf_path` as an attachment to `recipients` (list[str]) using
    the SMTP details in `mc` (dict from _load_mail_config)."""
    import smtplib
    from email.message import EmailMessage
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"]    = mc["mail_sender"]
    msg["To"]      = ", ".join(recipients)
    msg.set_content(body or subject)
    with open(pdf_path, "rb") as f:
        msg.add_attachment(
            f.read(),
            maintype="application",
            subtype="pdf",
            filename=pdf_filename,
        )
    server = smtplib.SMTP(mc["smtp_server"], mc["smtp_port"], timeout=30)
    try:
        server.ehlo()
        if mc.get("tls"):
            server.starttls()
            server.ehlo()
        if mc.get("smtp_user") and str(mc["smtp_user"]).strip():
            server.login(mc["smtp_user"], mc["smtp_password"])
        server.send_message(msg, to_addrs=recipients)
    finally:
        try:
            server.quit()
        except Exception:
            pass


@app.get("/api/print-panel")
def print_panel(request: Request):
    """Generate a PDF report for a Grafana table panel.

    Required query params:
        dashboard: dashboard uid (e.g. ad7kkx7)
        panel:     numeric panel id

    All other query params are treated as Grafana template variable
    values (e.g. ?server=foo&risk_level=high). Variables found in the
    panel's SQL but not in the request stay as $name and will likely
    fail at execute time — pass everything the panel needs.
    """
    params = dict(request.query_params)
    dashboard_uid = params.pop("dashboard", None)
    panel_id      = params.pop("panel", None)
    from_param    = params.pop("from", None)
    to_param      = params.pop("to", None)
    if not dashboard_uid or not panel_id:
        raise HTTPException(status_code=400,
                            detail="dashboard and panel query params are required")
    try:
        pdf_path, pdf_filename, _title = _build_panel_pdf(
            dashboard_uid, panel_id, params, from_param, to_param,
        )
        return FileResponse(
            pdf_path,
            media_type="application/pdf",
            filename=pdf_filename,
        )
    except ValueError as ve:
        db_write_log(f"print-panel lookup failed: {ve}", 0, "print_panel", "")
        raise HTTPException(status_code=404, detail=str(ve))
    except HTTPException:
        raise
    except Exception as e:
        db_write_log(f"print-panel failed: {e}", 0, "print_panel", "")
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {e}")


@app.get("/api/email-panel-form", response_class=HTMLResponse)
def email_panel_form(request: Request):
    """Render a small HTML dialog form prompting for email recipients.
    All incoming query params (dashboard, panel, from, to, and every
    Grafana variable) are preserved as hidden inputs, so submitting
    the form posts everything needed to /api/email-panel."""
    import html as _html
    qp = dict(request.query_params)
    dashboard_uid = qp.get("dashboard", "")
    panel_id      = qp.get("panel", "")
    if not dashboard_uid or not panel_id:
        raise HTTPException(status_code=400,
                            detail="dashboard and panel query params are required")
    try:
        title, _, _ = _lookup_panel_sql(dashboard_uid, panel_id)
    except ValueError:
        title = f"Panel {panel_id}"

    hidden_inputs = "\n".join(
        f'<input type="hidden" name="{_html.escape(k)}" value="{_html.escape(v)}">'
        for k, v in qp.items()
    )
    default_subject = f"DBDOME report: {title}"
    page = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Email PDF — {_html.escape(title)}</title>
<style>
 body {{ font-family: Arial, sans-serif; background:#f4f6f8; margin:0;
        display:flex; align-items:center; justify-content:center; min-height:100vh; }}
 .dialog {{ background:#fff; border-radius:8px; padding:24px 28px; width:480px;
           box-shadow:0 6px 24px rgba(0,0,0,0.12); }}
 h2 {{ margin:0 0 16px; color:#1f4e79; font-size:18px; }}
 label {{ display:block; margin:12px 0 4px; font-size:13px; color:#333; }}
 input[type=text], input[type=email], textarea {{
     width:100%; padding:8px 10px; border:1px solid #ccc; border-radius:4px;
     font-size:14px; box-sizing:border-box; font-family:inherit; }}
 textarea {{ min-height:64px; resize:vertical; }}
 .hint {{ font-size:11px; color:#888; margin-top:4px; }}
 .actions {{ margin-top:20px; display:flex; gap:8px; justify-content:flex-end; }}
 button {{ padding:8px 16px; border:none; border-radius:4px; font-size:14px;
          cursor:pointer; }}
 .send {{ background:#1f4e79; color:#fff; }}
 .send:hover {{ background:#163e63; }}
 .cancel {{ background:#e0e0e0; color:#333; }}
</style></head>
<body>
<div class="dialog">
  <h2>Send PDF by email</h2>
  <div style="font-size:13px;color:#555;">Report: <b>{_html.escape(title)}</b></div>
  <form method="post" action="/api/email-panel">
    {hidden_inputs}
    <label for="recipients">Recipients</label>
    <input id="recipients" name="recipients" type="text" required
           placeholder="alice@example.com, bob@example.com">
    <div class="hint">Comma- or semicolon-separated email addresses.</div>

    <label for="subject">Subject</label>
    <input id="subject" name="subject" type="text"
           value="{_html.escape(default_subject)}">

    <label for="body">Message (optional)</label>
    <textarea id="body" name="body"
              placeholder="Optional note to include in the email body…"></textarea>

    <div class="actions">
      <button type="button" class="cancel" onclick="window.close()">Cancel</button>
      <button type="submit" class="send">Send</button>
    </div>
  </form>
</div>
</body></html>"""
    return HTMLResponse(content=page)


@app.post("/api/email-panel", response_class=HTMLResponse)
async def email_panel(request: Request):
    """Generate the panel PDF and email it to the supplied recipients.
    Reads SMTP details from config.mail_config."""
    import html as _html
    form = await request.form()
    params = {k: v for k, v in form.items()}
    dashboard_uid = params.pop("dashboard", None)
    panel_id      = params.pop("panel", None)
    from_param    = params.pop("from", None)
    to_param      = params.pop("to", None)
    recipients_raw = (params.pop("recipients", "") or "").strip()
    subject = (params.pop("subject", "") or "").strip()
    body    = (params.pop("body", "") or "").strip()

    if not dashboard_uid or not panel_id:
        raise HTTPException(status_code=400,
                            detail="dashboard and panel form fields are required")
    if not recipients_raw:
        raise HTTPException(status_code=400, detail="recipients is required")

    recipients = [r.strip() for r in re.split(r'[,;]', recipients_raw) if r.strip()]
    if not recipients:
        raise HTTPException(status_code=400, detail="no valid recipients")

    try:
        pdf_path, pdf_filename, title = _build_panel_pdf(
            dashboard_uid, panel_id, params, from_param, to_param,
        )
        if not subject:
            subject = f"DBDOME report: {title or 'Panel ' + str(panel_id)}"

        mc = _load_mail_config()
        if mc is None:
            raise HTTPException(status_code=500,
                                detail="config.mail_config has no rows — SMTP not configured")
        _send_pdf_email(pdf_path, pdf_filename, recipients, subject, body, mc)
        db_write_log(
            f"email-panel sent '{title}' to {recipients}",
            0, "email_panel", "",
        )
        ok_html = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Email sent</title>
<style>body{{font-family:Arial,sans-serif;background:#f4f6f8;margin:0;
display:flex;align-items:center;justify-content:center;min-height:100vh;}}
.box{{background:#fff;padding:28px 32px;border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);
text-align:center;max-width:480px;}}
h2{{color:#2e7d32;margin:0 0 12px;}}
.recipients{{font-size:13px;color:#555;word-break:break-word;}}
button{{margin-top:18px;padding:8px 18px;border:none;border-radius:4px;
background:#1f4e79;color:#fff;font-size:14px;cursor:pointer;}}
</style></head><body>
<div class="box">
  <h2>✅ Email sent</h2>
  <div>Report: <b>{_html.escape(title or '')}</b></div>
  <div class="recipients">To: {_html.escape(', '.join(recipients))}</div>
  <button onclick="window.close()">Close</button>
</div></body></html>"""
        return HTMLResponse(content=ok_html)
    except ValueError as ve:
        db_write_log(f"email-panel lookup failed: {ve}", 0, "email_panel", "")
        raise HTTPException(status_code=404, detail=str(ve))
    except HTTPException:
        raise
    except Exception as e:
        db_write_log(f"email-panel failed: {e}", 0, "email_panel", "")
        raise HTTPException(status_code=500, detail=f"Email send failed: {e}")


# ---------------------------------------------------------------------------
# GRC Phase 5: Policy Management UI
# ---------------------------------------------------------------------------

# ── Page routes ──────────────────────────────────────────────────────────────

@app.get("/grc/policies", response_class=HTMLResponse)
async def grc_policies_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "firewall_policies.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/grc/audit-log", response_class=HTMLResponse)
async def grc_audit_log_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "firewall_audit_log.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/grc/compliance-reports", response_class=HTMLResponse)
async def grc_compliance_reports_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "compliance_reports.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/grc/risk-dashboard", response_class=HTMLResponse)
async def grc_risk_dashboard_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "risk_dashboard.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/grc/masking-rules", response_class=HTMLResponse)
async def grc_masking_rules_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "masking_rules.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


# ── Firewall Policies API ────────────────────────────────────────────────────

@app.get("/api/firewall-policies")
async def api_get_policies(
    action: str = None, regulation: str = None, is_active: str = None
):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if action:
            conditions.append("action=%s"); params.append(action)
        if regulation:
            conditions.append("regulation=%s"); params.append(regulation)
        if is_active is not None:
            conditions.append("is_active=%s"); params.append(is_active.lower() == "true")
        cur.execute(
            f"""SELECT policy_id, policy_name, vendor, action, condition_type,
                       condition_value, severity, regulation, priority, is_active,
                       created_at, updated_at
                FROM config.firewall_policies
                WHERE {' AND '.join(conditions)}
                ORDER BY priority, policy_id""",
            params,
        )
        cols = [d[0] for d in cur.description]
        policies = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("created_at"): d["created_at"] = d["created_at"].isoformat()
            if d.get("updated_at"): d["updated_at"] = d["updated_at"].isoformat()
            policies.append(d)
        return JSONResponse({"policies": policies})
    except Exception as e:
        db_write_log(f"api_get_policies failed: {e}", 0, "api_get_policies", "")
        return JSONResponse({"error": str(e), "policies": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/firewall-policies")
async def api_create_policy(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.firewall_policies
                (policy_name, vendor, action, condition_type, condition_value,
                 priority, is_active, regulation, severity)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
               RETURNING policy_id""",
            (
                data["policy_name"],
                data.get("vendor", "all"),
                data.get("action", "ALERT"),
                data.get("condition_type", "query_pattern"),
                data.get("condition_value", ""),
                data.get("priority", 100),
                data.get("is_active", True),
                data.get("regulation"),
                data.get("severity", "MEDIUM"),
            ),
        )
        policy_id = cur.fetchone()[0]
        conn.commit()
        from processes.firewall_policy_engine import reload_policy_cache
        reload_policy_cache()
        db_write_log(f"Policy created: {data['policy_name']} (id={policy_id})", 0, "api_create_policy", "")
        return JSONResponse({"message": "Policy created", "policy_id": policy_id})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_create_policy failed: {e}", 0, "api_create_policy", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.put("/api/firewall-policies/{policy_id}")
async def api_update_policy(policy_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("policy_name", "vendor", "action", "condition_type", "condition_value",
                    "priority", "is_active", "regulation", "severity"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        sets.append("updated_at=NOW()")
        params.append(policy_id)
        cur.execute(f"UPDATE config.firewall_policies SET {', '.join(sets)} WHERE policy_id=%s", params)
        conn.commit()
        from processes.firewall_policy_engine import reload_policy_cache
        reload_policy_cache()
        db_write_log(f"Policy updated id={policy_id}", 0, "api_update_policy", "")
        return JSONResponse({"message": "Policy updated"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_update_policy failed: {e}", 0, "api_update_policy", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.delete("/api/firewall-policies/{policy_id}")
async def api_delete_policy(policy_id: int):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("DELETE FROM config.firewall_policies WHERE policy_id=%s", (policy_id,))
        conn.commit()
        from processes.firewall_policy_engine import reload_policy_cache
        reload_policy_cache()
        db_write_log(f"Policy deleted id={policy_id}", 0, "api_delete_policy", "")
        return JSONResponse({"message": "Policy deleted"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_delete_policy failed: {e}", 0, "api_delete_policy", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/firewall-policies/apply-template")
async def api_apply_template(request: Request):
    """Insert the default seed policies for a regulation (skips conflicts)."""
    data = await request.json()
    regulation = data.get("regulation", "")
    if regulation not in ("PCI-DSS", "HIPAA", "GDPR", "SOC2"):
        return JSONResponse({"detail": "Unknown regulation"}, status_code=400)
    # (policy_name, action, condition_type, condition_value, priority, severity)
    _TEMPLATES = {
        "PCI-DSS": [
            ("PCI-DSS: Block card data export",  "BLOCK", "query_pattern",
             r"INTO\s+OUTFILE|INTO\s+DUMPFILE|xp_cmdshell|BULK\s+INSERT",         5,  "CRITICAL"),
            ("PCI-DSS: Block anonymous logins",  "BLOCK", "user",
             "anonymous|guest|public",                                             10, "HIGH"),
            ("PCI-DSS: Alert bulk SELECT",       "ALERT", "query_pattern",
             r"SELECT.{0,200}(TOP\s+[1-9]\d{3,}|LIMIT\s+[1-9]\d{3,})",           20, "HIGH"),
            ("PCI-DSS: Mask cardholder columns", "MASK",  "table_name",
             "credit_card|cardholder|pan|card_number",                             40, "HIGH"),
        ],
        "HIPAA": [
            ("HIPAA: Block PHI export",          "BLOCK", "query_pattern",
             r"INTO\s+OUTFILE|xp_cmdshell",                                        5,  "CRITICAL"),
            ("HIPAA: Alert PHI table access",    "ALERT", "table_name",
             "patient|medical_record|phi|diagnosis|prescription",                  15, "HIGH"),
            ("HIPAA: Block after-hours SA",      "BLOCK", "time_range",
             "00:00-06:00",                                                        10, "HIGH"),
            ("HIPAA: Mask PHI columns",          "MASK",  "table_name",
             "phi|patient_data|health_record",                                     30, "HIGH"),
        ],
        "GDPR": [
            ("GDPR: Block DROP on PII tables",   "BLOCK", "query_pattern",
             r"^\s*DROP\s+(TABLE|DATABASE|SCHEMA)",                                5,  "CRITICAL"),
            ("GDPR: Alert PII column SELECT",    "ALERT", "query_pattern",
             "ssn|social_security|passport|credit_card|date_of_birth",             20, "MEDIUM"),
            ("GDPR: Mask PII data",              "MASK",  "table_name",
             "customers|users|persons|employees",                                  25, "HIGH"),
            ("GDPR: Alert bulk PII access",      "ALERT", "query_pattern",
             r"SELECT\s+\*\s+FROM",                                                30, "MEDIUM"),
        ],
        "SOC2": [
            ("SOC2: Block SQL injection",        "BLOCK", "query_pattern",
             r";\s*DROP|;\s*DELETE|UNION\s+SELECT|' OR '1'='1",                   5,  "CRITICAL"),
            ("SOC2: Alert sysadmin activity",    "ALERT", "role",
             "sysadmin|db_owner|DBA|SYSDBA|rdsadmin|sa",                          30, "MEDIUM"),
            ("SOC2: Alert off-hours admin",      "ALERT", "time_range",
             "22:00-06:00",                                                        40, "MEDIUM"),
        ],
    }
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        added = 0
        for (name, action, ctype, cvalue, priority, severity) in _TEMPLATES.get(regulation, []):
            cur.execute(
                """INSERT INTO config.firewall_policies
                    (policy_name, vendor, action, condition_type, condition_value,
                     priority, regulation, severity)
                   VALUES (%s,'all',%s,%s,%s,%s,%s,%s)
                   ON CONFLICT DO NOTHING""",
                (name, action, ctype, cvalue, priority, regulation, severity),
            )
            added += cur.rowcount
        conn.commit()
        from processes.firewall_policy_engine import reload_policy_cache
        reload_policy_cache()
        db_write_log(f"Template applied: {regulation} ({added} policies)", 0, "api_apply_template", "")
        return JSONResponse({"message": "Template applied", "added": added})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_apply_template failed: {e}", 0, "api_apply_template", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Firewall Audit Log API ───────────────────────────────────────────────────

@app.get("/api/audit-log")
async def api_audit_log(
    page: int = 1, page_size: int = 50,
    action: str = None, server_name: str = None, db_user: str = None,
    from_dt: str = None, to_dt: str = None,
):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if action:
            conditions.append("a.action_taken=%s"); params.append(action)
        if server_name:
            conditions.append("a.server_name ILIKE %s"); params.append(f"%{server_name}%")
        if db_user:
            conditions.append("a.db_user ILIKE %s"); params.append(f"%{db_user}%")
        if from_dt:
            conditions.append("a.event_time >= %s"); params.append(from_dt)
        if to_dt:
            conditions.append("a.event_time <= %s"); params.append(to_dt)
        where = " AND ".join(conditions)

        cur.execute(
            f"""SELECT COUNT(*) FROM log.firewall_audit_log a
                LEFT JOIN config.firewall_policies p ON p.policy_id = a.matched_policy
                WHERE {where}""",
            params,
        )
        total = cur.fetchone()[0]

        offset = (page - 1) * page_size
        cur.execute(
            f"""SELECT a.audit_id AS event_id, a.event_time, a.server_name, a.vendor,
                       a.db_user, a.client_ip, a.db_name, a.action_taken,
                       p.policy_name, a.regulation, a.risk_score,
                       left(a.sql_statement, 200) AS sql_statement
                FROM log.firewall_audit_log a
                LEFT JOIN config.firewall_policies p ON p.policy_id = a.matched_policy
                WHERE {where}
                ORDER BY a.event_time DESC
                LIMIT %s OFFSET %s""",
            params + [page_size, offset],
        )
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("event_time"):
                d["event_time"] = d["event_time"].isoformat()
            rows.append(d)
        return JSONResponse({"total": total, "rows": rows})
    except Exception as e:
        db_write_log(f"api_audit_log failed: {e}", 0, "api_audit_log", "")
        return JSONResponse({"error": str(e), "total": 0, "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Compliance Reports API ───────────────────────────────────────────────────

@app.get("/api/compliance-reports/schedules")
async def api_get_schedules():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """SELECT schedule_id, regulation, frequency, is_active,
                      recipients, last_run_at
               FROM config.compliance_report_schedules
               ORDER BY regulation"""
        )
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("last_run_at"):
                d["last_run_at"] = d["last_run_at"].isoformat()
            rows.append(d)
        return JSONResponse({"schedules": rows})
    except Exception as e:
        db_write_log(f"api_get_schedules failed: {e}", 0, "api_get_schedules", "")
        return JSONResponse({"error": str(e), "schedules": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.put("/api/compliance-reports/schedules/{schedule_id}")
async def api_update_schedule(schedule_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("is_active", "recipients", "frequency"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(schedule_id)
        cur.execute(
            f"UPDATE config.compliance_report_schedules SET {', '.join(sets)} WHERE schedule_id=%s",
            params,
        )
        conn.commit()
        return JSONResponse({"message": "Schedule updated"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_update_schedule failed: {e}", 0, "api_update_schedule", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/compliance-reports")
async def api_list_reports():
    """List generated PDF files in the reports/compliance directory."""
    import glob as _glob
    from pathlib import Path
    report_dir = os.path.join(BASE_DIR, "reports", "compliance")
    try:
        pdfs = sorted(Path(report_dir).glob("*.pdf"), key=os.path.getmtime, reverse=True) if os.path.isdir(report_dir) else []
        reports = []
        for p in pdfs:
            name = p.name
            reg  = "UNKNOWN"
            for r in ("PCI-DSS", "HIPAA", "GDPR", "SOC2"):
                if r.lower().replace("-", "_") in name.lower() or r in name.upper():
                    reg = r; break
            mtime = datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
            size  = round(p.stat().st_size / 1024, 1)
            reports.append({"filename": name, "regulation": reg, "generated_at": mtime, "size_kb": size})
        return JSONResponse({"reports": reports})
    except Exception as e:
        db_write_log(f"api_list_reports failed: {e}", 0, "api_list_reports", "")
        return JSONResponse({"error": str(e), "reports": []}, status_code=500)


@app.get("/api/compliance-reports/download/{filename}")
async def api_download_report(filename: str):
    report_dir = os.path.join(BASE_DIR, "reports", "compliance")
    safe_name  = os.path.basename(filename)
    path       = os.path.join(report_dir, safe_name)
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail="Report not found")
    return FileResponse(path, media_type="application/pdf", filename=safe_name)


@app.post("/api/compliance-reports/run")
async def api_run_report(request: Request):
    data       = await request.json()
    regulation = data.get("regulation", "")
    days       = int(data.get("lookback_days", 7))
    recipients = data.get("recipients", "")
    if regulation not in ("PCI-DSS", "HIPAA", "GDPR", "SOC2"):
        return JSONResponse({"detail": "Unknown regulation"}, status_code=400)
    try:
        from processes.compliance_report_generator import run_compliance_report_on_demand
        pdf_path = run_compliance_report_on_demand(regulation, days, recipients)
        filename = os.path.basename(pdf_path)
        db_write_log(f"On-demand report generated: {filename}", 0, "api_run_report", "")
        return JSONResponse({"message": "Report generated", "filename": filename})
    except Exception as e:
        db_write_log(f"api_run_report failed: {e}", 0, "api_run_report", "")
        return JSONResponse({"detail": str(e)}, status_code=500)


# ── Risk Scores API ──────────────────────────────────────────────────────────

@app.get("/api/risk-scores")
async def api_risk_scores(
    min_risk_score: int = 0, server_name: str = None, login_name: str = None
):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["risk_score >= %s"]
        params = [min_risk_score]
        if server_name:
            conditions.append("server_name ILIKE %s"); params.append(f"%{server_name}%")
        if login_name:
            conditions.append("login_name ILIKE %s"); params.append(f"%{login_name}%")
        cur.execute(
            f"""SELECT server_name, login_name, risk_score, consecutive_high_risk,
                       avg_queries_per_hour, avg_duration_secs, avg_logical_reads,
                       typical_tables, typical_hour_start, typical_hour_end,
                       last_updated
                FROM monitoring.user_risk_profiles
                WHERE {' AND '.join(conditions)}
                ORDER BY risk_score DESC, login_name""",
            params,
        )
        cols = [d[0] for d in cur.description]
        users = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("last_updated"):
                d["last_updated"] = d["last_updated"].isoformat()
            users.append(d)
        return JSONResponse({"users": users})
    except Exception as e:
        db_write_log(f"api_risk_scores failed: {e}", 0, "api_risk_scores", "")
        return JSONResponse({"error": str(e), "users": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/risk-scores/{server_name}/{login_name}/events")
async def api_risk_events(server_name: str, login_name: str):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """SELECT event_time, risk_score, risk_factors
               FROM monitoring.user_risk_events
               WHERE server_name=%s AND login_name=%s
               ORDER BY event_time DESC LIMIT 20""",
            (server_name, login_name),
        )
        cols = [d[0] for d in cur.description]
        events = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("event_time"):
                d["event_time"] = d["event_time"].isoformat()
            events.append(d)
        return JSONResponse({"events": events})
    except Exception as e:
        db_write_log(f"api_risk_events failed: {e}", 0, "api_risk_events", "")
        return JSONResponse({"error": str(e), "events": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Masking Rules API ────────────────────────────────────────────────────────

@app.get("/api/masking-rules")
async def api_get_masking_rules(
    pii_type: str = None, mask_type: str = None,
    is_active: str = None, server_name: str = None,
):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if pii_type:
            conditions.append("pii_type=%s"); params.append(pii_type)
        if mask_type:
            conditions.append("mask_type=%s"); params.append(mask_type)
        if is_active is not None:
            conditions.append("is_active=%s"); params.append(is_active.lower() == "true")
        if server_name:
            conditions.append("server_name ILIKE %s"); params.append(f"%{server_name}%")
        cur.execute(
            f"""SELECT rule_id, server_name, database_name, table_name, column_name,
                       pii_type, mask_type, allowed_roles, regulation, is_active, updated_at
                FROM config.masking_rules
                WHERE {' AND '.join(conditions)}
                ORDER BY server_name, table_name, column_name""",
            params,
        )
        cols = [d[0] for d in cur.description]
        rules = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("updated_at"):
                d["updated_at"] = d["updated_at"].isoformat()
            rules.append(d)
        return JSONResponse({"rules": rules})
    except Exception as e:
        db_write_log(f"api_get_masking_rules failed: {e}", 0, "api_get_masking_rules", "")
        return JSONResponse({"error": str(e), "rules": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/masking-rules")
async def api_create_masking_rule(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.masking_rules
                (server_name, database_name, table_name, column_name,
                 pii_type, mask_type, allowed_roles, regulation)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
               ON CONFLICT (server_name, table_name, column_name) DO UPDATE
                 SET pii_type=EXCLUDED.pii_type, mask_type=EXCLUDED.mask_type,
                     allowed_roles=EXCLUDED.allowed_roles, regulation=EXCLUDED.regulation,
                     updated_at=NOW()
               RETURNING rule_id""",
            (
                data["server_name"], data.get("database_name", ""),
                data["table_name"], data["column_name"],
                data.get("pii_type", "GENERIC"), data.get("mask_type", "HASH"),
                data.get("allowed_roles") or [], data.get("regulation"),
            ),
        )
        rule_id = cur.fetchone()[0]
        conn.commit()
        from processes.data_masking_engine import reload_rule_cache
        reload_rule_cache()
        db_write_log(f"Masking rule upserted id={rule_id}", 0, "api_create_masking_rule", "")
        return JSONResponse({"message": "Rule saved", "rule_id": rule_id})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_create_masking_rule failed: {e}", 0, "api_create_masking_rule", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.put("/api/masking-rules/{rule_id}")
async def api_update_masking_rule(rule_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("pii_type", "mask_type", "allowed_roles", "regulation", "is_active",
                    "server_name", "table_name", "column_name", "database_name"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        sets.append("updated_at=NOW()")
        params.append(rule_id)
        cur.execute(f"UPDATE config.masking_rules SET {', '.join(sets)} WHERE rule_id=%s", params)
        conn.commit()
        from processes.data_masking_engine import reload_rule_cache
        reload_rule_cache()
        db_write_log(f"Masking rule updated id={rule_id}", 0, "api_update_masking_rule", "")
        return JSONResponse({"message": "Rule updated"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_update_masking_rule failed: {e}", 0, "api_update_masking_rule", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/masking-rules/sync")
async def api_sync_masking_rules():
    """Trigger an immediate sync from monitoring.sensitive_schema."""
    try:
        from processes.data_masking_engine import sync_masking_rules
        sync_masking_rules()
        db_write_log("Masking rules synced via UI", 0, "api_sync_masking_rules", "")
        return JSONResponse({"message": "Sync complete — rules reloaded from sensitive_schema"})
    except Exception as e:
        db_write_log(f"api_sync_masking_rules failed: {e}", 0, "api_sync_masking_rules", "")
        return JSONResponse({"detail": str(e)}, status_code=500)


# This is the key addition - run the server when the script is executed
if __name__ == "__main__":
    _ip = get_public_or_ip ()
    print(f"Starting FastAPI server...")
    print(f"Server will be available at: http://{_ip}:8080")
    print(f"Add Server Form: http://{_ip}:8080/add-server")
    print(f"Users Form: http://{_ip}:8080/users")
    print(f"Customized report Form: http://{_ip}:8080/add-customized_report")
    print(f"Customized report Form: http://{_ip}:8080/add-customized_metrics")
    print(f"Mail Config Form: http://{_ip}:8080/configure-mail")
    print(f"SIEM Config Form: http://{_ip}:8080/configure-siem")
    print(f"logout Form: http://{_ip}:8080/logout")
    print(f"logout Form: http://{_ip}:8080/sendreportbymail_connectivity")
    print(f"Press Ctrl+C to stop the server")
    
    uvicorn.run(app, host="0.0.0.0", port=8080)