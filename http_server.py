import asyncio
import sqlite3
from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from utils.config_dotenv import  get_connection_string, get_public_or_ip
from utils.log4dbexpert import db_write_log
from utils.oracle_client import oracle_connect as _oracle_connect
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
from datetime import datetime, timedelta, timezone
from email_utils.smtp_email_sender import   send_mail_with_attachment , send_mail_with_html_attachment , send_report_files_email
from utils.secrets_crypto import encrypt_secret, decrypt_secret
from utils.ssl_cert import web_scheme as _web_scheme
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

app = FastAPI(
    title="DBDOME API",
    version="1.0.0",
    docs_url=None,   # default /docs disabled; re-served below from locally bundled assets
    redoc_url=None,  # default /redoc disabled; re-served below from locally bundled assets
    description=(
        "DBDOME database-security REST API.\n\n"
        "Versioned data-extraction endpoints are served under **/api/v1** (grouped "
        "under the `v1` tag) and mirror the DBDOME dashboards. They are all `GET`, "
        "return JSON, and accept optional `from`/`to` query parameters (Grafana "
        "epoch-milliseconds, e.g. `1784020822440`, or an ISO / `YYYY-MM-DD HH:MM` "
        "local datetime).\n\n"
        "OpenAPI spec: `/openapi.json` · Swagger UI: `/docs` · ReDoc: `/redoc`. "
        "The legacy unversioned `/api/...` paths remain for backward compatibility."
    ),
    openapi_tags=[{
        "name": "v1",
        "description": "Versioned read / data-extraction API — alerts, IPS report, "
                       "retention, blocker activity, and detection views.",
    }],
)

# Static files (css, js, images)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# Offline Swagger UI / ReDoc: serve /docs and /redoc from locally bundled assets
# (static/apidocs/*) instead of a CDN, so they render on air-gapped appliances.
from fastapi.openapi.docs import (get_swagger_ui_html, get_redoc_html,
                                  get_swagger_ui_oauth2_redirect_html)

_APIDOCS_ASSETS = "/static/apidocs"


@app.get("/docs", include_in_schema=False)
async def _custom_swagger_ui():
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} - Swagger UI",
        oauth2_redirect_url=app.swagger_ui_oauth2_redirect_url,
        swagger_js_url=f"{_APIDOCS_ASSETS}/swagger-ui-bundle.js",
        swagger_css_url=f"{_APIDOCS_ASSETS}/swagger-ui.css",
        swagger_favicon_url=f"{_APIDOCS_ASSETS}/favicon.png",
    )


@app.get(app.swagger_ui_oauth2_redirect_url, include_in_schema=False)
async def _swagger_ui_redirect():
    return get_swagger_ui_oauth2_redirect_html()


@app.get("/redoc", include_in_schema=False)
async def _custom_redoc():
    return get_redoc_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} - ReDoc",
        redoc_js_url=f"{_APIDOCS_ASSETS}/redoc.standalone.js",
        redoc_favicon_url=f"{_APIDOCS_ASSETS}/favicon.png",
        with_google_fonts=False,
    )

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

        # OS-aware fallback: the configured grafana_db value may originate from
        # another host (e.g. a Windows backup restored on Linux). Honor it when
        # it exists here, otherwise fall back to the platform default so the IP
        # rewrite still runs. GRAFANA_DB env var overrides everything.
        _default_db = (os.environ.get("GRAFANA_DB")
                       or (r"C:\ProgramData\DBDOME\data\grafana.db" if os.name == "nt"
                           else "/var/lib/grafana/grafana.db"))
        if not grafana_db_path or not os.path.exists(grafana_db_path):
            grafana_db_path = _default_db

        if not machine_ip:
            print(f"update_dashboard_ip: missing config (ip={machine_ip})")
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

            # Keep the scheme of the DBDOME API links (:8080) in sync with how the
            # web server actually serves: once TLS is on, http://<ip>:8080 links
            # must become https:// or the dashboard buttons hit a closed HTTP port.
            # Grafana (:3000) is untouched — it has its own scheme.
            try:
                _api_https = _web_scheme() == "https"
            except Exception:
                _api_https = False
            if _api_https:
                new_data2 = _re.sub(r'http://([^/"\s:]+):8080', r'https://\1:8080', new_data)
                if new_data2 != new_data:
                    new_data = new_data2
                    changed = True
            else:
                new_data2 = _re.sub(r'https://([^/"\s:]+):8080', r'http://\1:8080', new_data)
                if new_data2 != new_data:
                    new_data = new_data2
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
    # request.url.hostname strips the port and unwraps IPv6 brackets. The old
    # host_header.split(":") raised TypeError -> 500 whenever a client sent no
    # Host header (HTTP/1.0 clients, port scanners, some health probes).
    # With no Host header Starlette falls back to the ASGI server address, which
    # is the wildcard bind here, so redirect to the configured address instead.
    host = request.url.hostname
    if not host or host in ("0.0.0.0", "::"):
        host = get_public_or_ip()
    if ":" in host:                      # IPv6 literal must stay bracketed in a URL
        host = f"[{host}]"
    db_write_log(f"/dbdome success host :{host}"   ,0,"get/dbdome","" )
    target_url = f"http://{host}:3000/d/ad7kkx7/dbdome?orgId=1&from=now-1h&to=now&timezone=browser"
    db_write_log(f"/dbdome success target_url :{target_url}"   ,0,"get/dbdome","" )
    return RedirectResponse(url=target_url, status_code=302)

@app.get("/", response_class=RedirectResponse)
async def dbdome_main(request: Request):
    host_header = request.headers.get("host")
    db_write_log(f"/dbdome success host_header :{host_header}"   ,0,"get/dbdome","" )
    # request.url.hostname strips the port and unwraps IPv6 brackets. The old
    # host_header.split(":") raised TypeError -> 500 whenever a client sent no
    # Host header (HTTP/1.0 clients, port scanners, some health probes).
    # With no Host header Starlette falls back to the ASGI server address, which
    # is the wildcard bind here, so redirect to the configured address instead.
    host = request.url.hostname
    if not host or host in ("0.0.0.0", "::"):
        host = get_public_or_ip()
    if ":" in host:                      # IPv6 literal must stay bracketed in a URL
        host = f"[{host}]"
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
    group_name_val = ""
    recipients_val = ""
    group_id_val   = ""
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
                    smtp_password = decrypt_secret(row["smtp_password"]) or ""
                    tls_checked   = "checked" if row["tls"] else ""
                    smtp_sender   = row["mail_sender"] or ""
                    page_title    = f"Mail configuration (edit #{row_id_val})"
                    # prefill the recipients group linked to this mail config (first active group)
                    grp = conn.execute(
                        text("SELECT row_id, group_name, recipients FROM config.mail_groups "
                             "WHERE mail_config_id = :id ORDER BY is_active DESC, row_id ASC LIMIT 1"),
                        {"id": int(row_id_q)},
                    ).mappings().first()
                    if grp:
                        group_id_val   = str(grp["row_id"])
                        group_name_val = grp["group_name"] or ""
                        recipients_val = grp["recipients"] or ""
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

    .actions {{
      display: flex;
      gap: 8px;
      justify-content: flex-end;
      align-items: center;
    }}

    button.test-btn {{
      background-color: transparent;
      color: #5794f2;
      border: 1px solid #5794f2;
      border-radius: 4px;
      padding: 8px 16px;
      font-size: 14px;
      cursor: pointer;
    }}

    button.test-btn:hover {{
      background-color: #1f2a3d;
    }}

    button.test-btn:disabled {{
      opacity: 0.6;
      cursor: default;
    }}

    #test_result {{
      font-size: 13px;
      margin: 14px 0 0;
      min-height: 18px;
    }}

    #test_result.ok  {{ color: #73bf69; }}
    #test_result.err {{ color: #f2495c; }}
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

      <hr style="border:none;border-top:1px solid #2c3235;margin:8px 0 20px;">

      <label for="group_name">Recipients group name</label>
      <input type="text" id="group_name" name="group_name" value="{group_name_val}" placeholder="ops_team">

      <label for="recipients">Recipients</label>
      <input type="text" id="recipients" name="recipients" value="{recipients_val}" placeholder="user1@company.com, user2@company.com">
      <div style="font-size:12px;color:#9fa1a4;margin-top:-12px;margin-bottom:20px;">Comma-separated email addresses (leave blank to skip)</div>

      <!-- Hidden references -->
      <input type="hidden" name="referer" value="{referer}">
      <input type="hidden" name="row_id" value="{row_id_val}">
      <input type="hidden" name="group_id" value="{group_id_val}">
      <div class="actions">
        <button type="button" class="test-btn" id="test_btn" onclick="sendTestEmail()">Send test email</button>
        <input type="submit" value="Save mail configuration">
      </div>
      <div id="test_result"></div>

    </form>
  </div>

  <script>
    async function sendTestEmail() {{
      var form = document.querySelector('form');
      var res  = document.getElementById('test_result');
      var btn  = document.getElementById('test_btn');
      if (!form.smtp_server.value || !form.smtp_port.value) {{
        res.className = 'err';
        res.textContent = 'Fill in SMTP server and port first.';
        return;
      }}
      // Default the test recipient to the first address in the recipients box,
      // else let the operator type one.
      var firstRecipient = (form.recipients.value || '').split(/[,;]/)[0].trim();
      var to = prompt('Send a test email to:', firstRecipient || form.smtp_user.value || '');
      if (to === null) return;   // cancelled

      var data = new URLSearchParams();
      data.append('smtp_server',   form.smtp_server.value);
      data.append('smtp_port',     form.smtp_port.value);
      data.append('smtp_user',     form.smtp_user.value);
      data.append('smtp_password', form.smtp_password.value);
      data.append('tls',           form.tls.checked ? 'true' : 'false');
      data.append('smtp_sender',   form.smtp_sender.value);
      data.append('test_recipient', to);

      btn.disabled = true;
      res.className = '';
      res.textContent = 'Sending test email…';
      try {{
        var r = await fetch('/api/mailconfiguration/test', {{ method: 'POST', body: data }});
        var j = await r.json();
        res.className = j.ok ? 'ok' : 'err';
        res.textContent = (j.ok ? '✓ ' : '✗ ') + j.message;
      }} catch (e) {{
        res.className = 'err';
        res.textContent = '✗ Request failed: ' + e;
      }} finally {{
        btn.disabled = false;
      }}
    }}
  </script>

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
    group_name: str = Form(""),
    recipients: str = Form(""),
    group_id: str = Form(None),
    ):
    config = {
        "smtp_server"       :smtp_server,
        "smtp_user"         :smtp_user ,
        "smtp_password"     :smtp_password , 
        "smtp_port"         :smtp_port , 
        "tls"               :tls , 
        "smtp_sender"       :smtp_sender
    }
    # Two SEPARATE transactions on purpose: a failing recipients-group save must
    # not roll back the SMTP config insert (they used to share one engine.begin(),
    # so a group failure silently undid the config row — sequence advanced, table
    # empty, and the old `finally` still logged "mail_config succeeded").
    def _error_page(stage, err):
        import html as _html
        db_write_log(f"mail_config {stage} FAILED: {err}", "ERROR", "mail_config", "")
        return HTMLResponse(f"""<!doctype html>
<html><head><meta charset="UTF-8"><title>Mail configuration failed</title></head>
<body style="background:#111217;color:#d8d9da;font-family:sans-serif;padding:40px;">
<h2 style="color:#f56b6b;">Mail configuration NOT saved</h2>
<p>{_html.escape(stage)} failed:</p>
<pre style="background:#181b1f;padding:14px;border-radius:6px;white-space:pre-wrap;">{_html.escape(str(err))}</pre>
<p><a style="color:#3d71d9;" href="javascript:history.back()">&larr; back to the form</a></p>
</body></html>""", status_code=500)

    new_config_id = None
    pg_postgres_home_engine = create_engine(get_connection_string())
    p_row_id = int(row_id) if row_id else None

    # 1) SMTP config — its own transaction, committed before the group save.
    try:
        with pg_postgres_home_engine.begin() as conn:
            result = conn.execute(
                text("CALL config.save_mail_config(:p_row_id, :p_smtp_server, :p_smtp_port, :p_smtp_user, :p_smtp_password, :p_tls, :p_mail_sender)"),
                {
                    "p_row_id"        : p_row_id,
                    "p_smtp_server"   : smtp_server,
                    "p_smtp_port"     : smtp_port,
                    "p_smtp_user"     : smtp_user,
                    "p_smtp_password" : encrypt_secret(smtp_password),
                    "p_tls"           : tls,
                    "p_mail_sender"   : smtp_sender,
                }
            )
            try:
                new_config_id = result.scalar()
            except Exception:
                new_config_id = p_row_id
    except Exception as e:
        return _error_page("saving the SMTP configuration (config.save_mail_config)", e)

    # 2) Recipients group — separate transaction; the config above stays saved
    #    even if this fails, and the operator is told exactly what happened.
    if recipients and recipients.strip():
        try:
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(
                    text("CALL config.save_mail_group(:p_row_id, :p_mail_config_id, :p_group_name, :p_recipients, :p_is_active)"),
                    {
                        "p_row_id"         : int(group_id) if group_id else None,
                        "p_mail_config_id" : int(new_config_id) if new_config_id else None,
                        "p_group_name"     : (group_name.strip() or "default"),
                        "p_recipients"     : recipients.strip(),
                        "p_is_active"      : True,
                    }
                )
        except Exception as e:
            return _error_page(
                f"SMTP configuration was SAVED (row {new_config_id}), but saving "
                f"the recipients group (config.save_mail_group)", e)

    db_write_log(f"mail_config saved (row {new_config_id})", "", "mail_config", "")

    if referer:
        return RedirectResponse(url=f"http://{get_public_or_ip()}:3000{referer}", status_code=302)
    # No referer (page opened directly) — fall back to the configuration dashboard
    # instead of returning None, which FastAPI renders as the literal `null`.
    grafana_url = f"http://{get_public_or_ip()}:3000/d/adnz9dq/configuration?orgId=1&from=now-1h&to=now&timezone=browser"
    return RedirectResponse(url=grafana_url, status_code=302)


@app.post("/api/mailconfiguration/test")
async def mailconfiguration_test(
    smtp_server: str = Form(...),
    smtp_port: int = Form(...),
    smtp_user: str = Form(""),
    smtp_password: str = Form(""),
    tls: bool = Form(False),
    smtp_sender: str = Form(...),
    test_recipient: str = Form(""),
):
    """Send a test email using the SMTP settings currently in the form, WITHOUT
    saving them — so the operator can validate credentials before committing.

    The password arrives as plaintext from the form (the GET decrypts it for
    prefill), so it is used as-is. Returns JSON {ok, message}."""
    import smtplib
    from email.message import EmailMessage

    to_addr = (test_recipient or "").strip() or (smtp_user or "").strip() or (smtp_sender or "").strip()
    if not to_addr:
        return JSONResponse({"ok": False, "message": "No recipient — set a test recipient, SMTP user or sender."}, status_code=400)
    recipients = [r.strip() for r in re.split(r"[,;]", to_addr) if r.strip()]

    msg = EmailMessage()
    msg["Subject"] = "DBDOME SMTP test"
    msg["From"] = smtp_sender or smtp_user
    msg["To"] = ", ".join(recipients)
    msg.set_content(
        "This is a test message from the DBDOME mail-configuration page.\n"
        f"Server: {smtp_server}:{smtp_port}  TLS: {bool(tls)}\n"
        "If you received this, outgoing mail is configured correctly."
    )
    try:
        server = smtplib.SMTP(smtp_server, int(smtp_port), timeout=20)
        try:
            server.ehlo()
            if tls:
                server.starttls()
                server.ehlo()
            if smtp_user and str(smtp_user).strip():
                server.login(smtp_user, smtp_password)
            server.send_message(msg, to_addrs=recipients)
        finally:
            try:
                server.quit()
            except Exception:
                pass
        db_write_log(f"mailconfiguration test sent to {recipients} via {smtp_server}:{smtp_port}", 0, "mailconfiguration_test", "")
        return JSONResponse({"ok": True, "message": f"Test email sent to {', '.join(recipients)}."})
    except Exception as e:
        db_write_log(f"mailconfiguration test failed: {e}", 2, "mailconfiguration_test", "")
        return JSONResponse({"ok": False, "message": f"Send failed: {e}"}, status_code=200)


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

@app.get("/webook_alert_set", response_class=HTMLResponse)
def webook_alert_set(request: Request):
    """Toggle a config.webook_alerts flag via the set_webook_alert procedure, then
    redirect back to the referring dashboard (same pattern as /server_enable)."""
    referer = request.query_params.get("referer", "").strip()
    row_id  = request.query_params.get("row_id", "").strip()
    field   = request.query_params.get("field", "").strip()
    value   = request.query_params.get("value", "").strip()

    try:
        p_value = str(value).strip().lower() in ("true", "t", "1", "yes", "on")
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("CALL config.set_webook_alert(:p_row_id, :p_field, :p_value)"),
                {"p_row_id": int(row_id) if row_id else None, "p_field": field, "p_value": p_value},
            )
        db_write_log(f"set_webook_alert row {row_id} {field}={p_value} succeeded",
                     "", "set_webook_alert", "")
    except Exception as e:
        print("Error calling set_webook_alert:", e)
        db_write_log(f"set_webook_alert row {row_id} {field}={value} failed: {e}",
                     "", "set_webook_alert", "")

    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/adwhcfg1/webhook-alerts-config", status_code=302)


@app.get("/sensitive_column_add", response_class=HTMLResponse)
def sensitive_column_add(request: Request):
    """Add a column to metrics.sensitive_columns via add_sensitive_column, then
    redirect back to the referring dashboard (same pattern as /webook_alert_set).

    untrack=1 blacklists the column instead of tracking it (7430): it is dropped
    from metrics.v_sensitive_columns_all so detections never receive it, and
    alerts whose query text quotes it are suppressed by the alert_log trigger.
    Accepts 1/true/yes/on; anything else (including absent) means track."""
    q = request.query_params
    referer = q.get("referer", "").strip()
    untrack = q.get("untrack", "").strip().lower() in ("1", "true", "yes", "on")
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("CALL metrics.add_sensitive_column("
                     ":p_server,:p_db,:p_schema,:p_table,:p_column,:p_pii,:p_untrack)"),
                {"p_server": q.get("server", "").strip() or None,
                 "p_db":     q.get("db", "").strip() or None,
                 "p_schema": q.get("schema", "").strip() or None,
                 "p_table":  q.get("table", "").strip() or None,
                 "p_column": q.get("column", "").strip() or None,
                 # a blacklisted column is insensitive by definition, so give it a
                 # self-describing category rather than whatever discovery guessed
                 "p_pii":    ("Blacklisted (insensitive)" if untrack
                              else (q.get("pii", "").strip() or None)),
                 "p_untrack": untrack},
            )
        db_write_log(f"add_sensitive_column {q.get('table')}.{q.get('column')} "
                     f"({'untrack' if untrack else 'track'}) succeeded",
                     "", "add_sensitive_column", "")
    except Exception as e:
        print("Error calling add_sensitive_column:", e)
        db_write_log(f"add_sensitive_column {q.get('table')}.{q.get('column')} "
                     f"({'untrack' if untrack else 'track'}) failed: {e}",
                     "", "add_sensitive_column", "")
    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/adpiicol/sensitive-columns-explorer", status_code=302)


@app.get("/global_param_set", response_class=HTMLResponse)
def global_param_set(request: Request):
    """Set a whitelisted config.global_params key via set_global_param, then
    redirect back to the referring dashboard (same pattern as /webook_alert_set)."""
    referer = request.query_params.get("referer", "").strip()
    key     = request.query_params.get("key", "").strip()
    value   = request.query_params.get("value", "").strip()

    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("CALL config.set_global_param(:p_key, :p_value)"),
                {"p_key": key, "p_value": value},
            )
        db_write_log(f"set_global_param {key}={value} succeeded", "", "set_global_param", "")
    except Exception as e:
        print("Error calling set_global_param:", e)
        db_write_log(f"set_global_param {key}={value} failed: {e}", "", "set_global_param", "")

    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/adwhcfg1/webhook-alerts-config", status_code=302)


@app.get("/exclude_login_set", response_class=HTMLResponse)
def exclude_login_set(request: Request):
    """Toggle metrics.exclude_logins.is_active via set_exclude_login, then
    redirect back to the referring dashboard (same pattern as /webook_alert_set)."""
    referer = request.query_params.get("referer", "").strip()
    row_id  = request.query_params.get("row_id", "").strip()
    value   = request.query_params.get("value", "").strip()

    try:
        p_value = str(value).strip().lower() in ("true", "t", "1", "yes", "on")
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("CALL metrics.set_exclude_login(:p_row_id, :p_value)"),
                {"p_row_id": int(row_id) if row_id else None, "p_value": p_value},
            )
        db_write_log(f"set_exclude_login row {row_id} is_active={p_value} succeeded",
                     "", "set_exclude_login", "")
    except Exception as e:
        print("Error calling set_exclude_login:", e)
        db_write_log(f"set_exclude_login row {row_id} is_active={value} failed: {e}",
                     "", "set_exclude_login", "")

    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/exclude-logins/excluded-logins-self-activity", status_code=302)


@app.get("/api/exclude-logins")
def api_exclude_logins_list():
    """All rows of metrics.exclude_logins for the /exclude_logins config page."""
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()
        cur.execute("""SELECT row_id, login_name, is_active, entry_date
                       FROM metrics.exclude_logins ORDER BY login_name""")
        rows = [{"row_id": r[0], "login_name": r[1], "is_active": r[2],
                 "entry_date": r[3].isoformat() if r[3] else None}
                for r in cur.fetchall()]
        cur.close()
        conn.close()
        return JSONResponse({"ok": True, "rows": rows})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/exclude-logins/add")
async def api_exclude_logins_add(request: Request):
    body = await request.json()
    login = str(body.get("login_name", "")).strip()
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(text("CALL metrics.add_exclude_login(:p_login)"),
                         {"p_login": login})
        db_write_log(f"add_exclude_login {login} succeeded", "", "add_exclude_login", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        db_write_log(f"add_exclude_login {login} failed: {e}", "", "add_exclude_login", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/exclude-logins/set")
async def api_exclude_logins_set(request: Request):
    body = await request.json()
    row_id = int(body.get("row_id"))
    is_active = bool(body.get("is_active", True))
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(text("CALL metrics.set_exclude_login(:p_row_id, :p_value)"),
                         {"p_row_id": row_id, "p_value": is_active})
        db_write_log(f"set_exclude_login row {row_id} is_active={is_active} succeeded",
                     "", "set_exclude_login", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/exclude-logins/delete")
async def api_exclude_logins_delete(request: Request):
    body = await request.json()
    row_id = int(body.get("row_id"))
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(text("CALL metrics.delete_exclude_login(:p_row_id)"),
                         {"p_row_id": row_id})
        db_write_log(f"delete_exclude_login row {row_id} succeeded",
                     "", "delete_exclude_login", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.get("/exclude_logins", response_class=HTMLResponse)
def exclude_logins_page(request: Request):
    """Config page for metrics.exclude_logins (opened from the Excluded Logins
    dashboard button): list, add, enable/disable and delete excluded logins via
    the /api/exclude-logins endpoints."""
    return """
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Excluded Logins - Self Activity</title>
  <style>
    body {
      background-color: #111217;
      color: #d8d9da;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 16px;
    }
    .panel {
      max-width: 720px;
      margin: 40px auto;
      background-color: #181b1f;
      border: 1px solid #2c3235;
      border-radius: 6px;
      padding: 24px;
    }
    .panel-header { font-size: 18px; font-weight: 600; margin-bottom: 6px; color: #ffffff; }
    .panel-sub { font-size: 12px; color: #9aa0a6; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #2c3235; font-size: 14px; }
    th { color: #9aa0a6; font-weight: 600; }
    .badge { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: 12px; font-weight: 600; }
    .on  { background-color: #1a7f37; color: #ffffff; }
    .off { background-color: #6e2226; color: #ffffff; }
    button {
      background-color: #3d71d9; color: #fff; border: none; border-radius: 4px;
      padding: 6px 12px; font-size: 13px; cursor: pointer; margin-right: 6px;
    }
    button:hover { background-color: #345fb4; }
    button.danger { background-color: #6e2226; }
    button.danger:hover { background-color: #8d2a30; }
    input[type=text] {
      background-color: #111217; color: #d8d9da; border: 1px solid #2c3235;
      border-radius: 4px; padding: 8px 10px; font-size: 14px; width: 60%;
    }
    .addrow { display: flex; gap: 8px; align-items: center; }
    #msg { margin-top: 12px; font-size: 13px; color: #e0b840; min-height: 18px; }
  </style>
</head>
<body>
  <div class="panel">
    <div class="panel-header">Excluded Logins</div>
    <div class="panel-sub">Activity of these logins is treated as DBDOME self-activity:
      collected transaction rows with these login names never reach monitoring results or alerts.</div>
    <table>
      <thead><tr><th>Login</th><th>Enabled</th><th>Added</th><th>Actions</th></tr></thead>
      <tbody id="rows"></tbody>
    </table>
    <div class="addrow">
      <input type="text" id="newlogin" placeholder="login_name to exclude">
      <button onclick="addLogin()">Add</button>
    </div>
    <div id="msg"></div>
  </div>
  <script>
    async function api(path, body) {
      const opts = body
        ? {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)}
        : {};
      const r = await fetch(path, opts);
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || 'request failed');
      return j;
    }
    function esc(s) {
      return String(s).replace(/[&<>"']/g,
        c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    }
    async function load() {
      try {
        const j = await api('/api/exclude-logins');
        document.getElementById('rows').innerHTML = j.rows.map(r => `
          <tr>
            <td>${esc(r.login_name)}</td>
            <td><span class="badge ${r.is_active ? 'on' : 'off'}">${r.is_active ? 'enabled' : 'disabled'}</span></td>
            <td>${r.entry_date ? esc(r.entry_date.substring(0, 19).replace('T', ' ')) : ''}</td>
            <td>
              <button onclick="setLogin(${r.row_id}, ${!r.is_active})">${r.is_active ? 'Disable' : 'Enable'}</button>
              <button class="danger" onclick="delLogin(${r.row_id}, '${esc(r.login_name)}')">Delete</button>
            </td>
          </tr>`).join('');
      } catch (e) { msg('Load failed: ' + e.message); }
    }
    function msg(t) { document.getElementById('msg').textContent = t || ''; }
    async function addLogin() {
      const v = document.getElementById('newlogin').value.trim();
      if (!v) { msg('Enter a login name.'); return; }
      try { await api('/api/exclude-logins/add', {login_name: v});
            document.getElementById('newlogin').value = ''; msg(''); load(); }
      catch (e) { msg('Add failed: ' + e.message); }
    }
    async function setLogin(rowId, isActive) {
      try { await api('/api/exclude-logins/set', {row_id: rowId, is_active: isActive}); msg(''); load(); }
      catch (e) { msg('Update failed: ' + e.message); }
    }
    async function delLogin(rowId, name) {
      if (!confirm('Delete excluded login "' + name + '"?')) return;
      try { await api('/api/exclude-logins/delete', {row_id: rowId}); msg(''); load(); }
      catch (e) { msg('Delete failed: ' + e.message); }
    }
    load();
  </script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# app_login_guard watchlists: metrics.app_logins + metrics.programs config UI,
# mirroring the Excluded Logins dashboard/page pattern. Each row is a value
# (login / program, LIKE pattern) plus a server ('%' = all servers).
# ---------------------------------------------------------------------------
def _watchlist_list(table, value_col):
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute(f"SELECT row_id, {value_col}, COALESCE(server,'%%'), is_active, entry_date "
                    f"FROM metrics.{table} ORDER BY {value_col}")
        return [{"row_id": r[0], "value": r[1], "server": r[2], "is_active": r[3],
                 "entry_date": r[4].isoformat() if r[4] else None} for r in cur.fetchall()]
    finally:
        conn.close()


def _watchlist_add(table, value_col, value, server):
    conn = psycopg2.connect(get_connection_string()); conn.autocommit = True
    try:
        cur = conn.cursor()
        cur.execute(f"INSERT INTO metrics.{table} ({value_col}, server) VALUES (%s, %s)",
                    (value, server or "%"))
    finally:
        conn.close()


def _watchlist_set(table, row_id, is_active):
    conn = psycopg2.connect(get_connection_string()); conn.autocommit = True
    try:
        conn.cursor().execute(f"UPDATE metrics.{table} SET is_active=%s WHERE row_id=%s",
                              (is_active, row_id))
    finally:
        conn.close()


def _watchlist_delete(table, row_id):
    conn = psycopg2.connect(get_connection_string()); conn.autocommit = True
    try:
        conn.cursor().execute(f"DELETE FROM metrics.{table} WHERE row_id=%s", (row_id,))
    finally:
        conn.close()


@app.get("/api/app-logins")
def api_app_logins_list():
    try:
        return JSONResponse({"ok": True, "rows": _watchlist_list("app_logins", "applicative_login")})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/app-logins/add")
async def api_app_logins_add(request: Request):
    b = await request.json()
    v = str(b.get("value", "")).strip()
    if not v:
        return JSONResponse({"ok": False, "error": "applicative_login is required"}, status_code=400)
    try:
        _watchlist_add("app_logins", "applicative_login", v, str(b.get("server", "")).strip())
        db_write_log(f"app_logins add {v}", 0, "api_app_logins_add", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/app-logins/set")
async def api_app_logins_set(request: Request):
    b = await request.json()
    try:
        _watchlist_set("app_logins", int(b.get("row_id")), bool(b.get("is_active", True)))
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/app-logins/delete")
async def api_app_logins_delete(request: Request):
    b = await request.json()
    try:
        _watchlist_delete("app_logins", int(b.get("row_id")))
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.get("/api/programs")
def api_programs_list():
    try:
        return JSONResponse({"ok": True, "rows": _watchlist_list("programs", "program_name")})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/programs/add")
async def api_programs_add(request: Request):
    b = await request.json()
    v = str(b.get("value", "")).strip()
    if not v:
        return JSONResponse({"ok": False, "error": "program_name is required"}, status_code=400)
    try:
        _watchlist_add("programs", "program_name", v, str(b.get("server", "")).strip())
        db_write_log(f"programs add {v}", 0, "api_programs_add", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/programs/set")
async def api_programs_set(request: Request):
    b = await request.json()
    try:
        _watchlist_set("programs", int(b.get("row_id")), bool(b.get("is_active", True)))
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/programs/delete")
async def api_programs_delete(request: Request):
    b = await request.json()
    try:
        _watchlist_delete("programs", int(b.get("row_id")))
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.get("/app_login_guard", response_class=HTMLResponse)
def app_login_guard_page(request: Request):
    """Config page for the app_login_guard watchlists (metrics.app_logins +
    metrics.programs), mirroring the Excluded Logins page. Opened from a dashboard
    button. Entries are case-insensitive LIKE patterns; server '%' = all servers."""
    return """
<html lang="en"><head><meta charset="UTF-8"><title>App Login Guard - Watchlists</title>
<style>
 body{background:#111217;color:#d8d9da;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;margin:0;padding:16px;}
 .panel{max-width:820px;margin:24px auto;background:#181b1f;border:1px solid #2c3235;border-radius:6px;padding:24px;}
 .panel-header{font-size:18px;font-weight:600;margin-bottom:6px;color:#fff;}
 .panel-sub{font-size:12px;color:#9aa0a6;margin-bottom:16px;}
 table{width:100%;border-collapse:collapse;margin-bottom:16px;}
 th,td{text-align:left;padding:8px 10px;border-bottom:1px solid #2c3235;font-size:14px;}
 th{color:#9aa0a6;font-weight:600;}
 .badge{display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:600;}
 .on{background:#1a7f37;color:#fff;} .off{background:#6e2226;color:#fff;}
 button{background:#3d71d9;color:#fff;border:none;border-radius:4px;padding:6px 12px;font-size:13px;cursor:pointer;margin-right:6px;}
 button:hover{background:#345fb4;} button.danger{background:#6e2226;} button.danger:hover{background:#8d2a30;}
 input[type=text]{background:#111217;color:#d8d9da;border:1px solid #2c3235;border-radius:4px;padding:8px 10px;font-size:14px;}
 .addrow{display:flex;gap:8px;align-items:center;flex-wrap:wrap;}
 .msg{margin-top:10px;font-size:13px;color:#e0b840;min-height:18px;}
</style></head><body>
 <div class="panel">
   <div class="panel-header">App Login Guard &mdash; Watchlists</div>
   <div class="panel-sub">When an <b>applicative login</b> below is seen in an active transaction (SEC-SQL-ACC-011-RC02)
     together with a <b>watched program</b> below on the same server, an alert is raised and the session is killed
     (subject to the <code>blocker_dry_run</code> switch). Values are case-insensitive LIKE patterns
     (e.g. <code>svc_app</code>, <code>%SSMS%</code>); server <code>%</code> = all servers.</div>

   <h3 style="color:#fff;font-size:15px;">Applicative logins (metrics.app_logins)</h3>
   <table><thead><tr><th>Login (LIKE)</th><th>Server</th><th>Enabled</th><th>Added</th><th>Actions</th></tr></thead>
     <tbody id="al_rows"></tbody></table>
   <div class="addrow">
     <input type="text" id="al_val" placeholder="applicative_login e.g. svc_app or %app%">
     <input type="text" id="al_srv" placeholder="server (blank = all)">
     <button onclick="add('app-logins','al_val','al_srv')">Add login</button>
   </div>
   <div class="msg" id="al_msg"></div>

   <h3 style="color:#fff;font-size:15px;margin-top:26px;">Programs (metrics.programs)</h3>
   <table><thead><tr><th>Program (LIKE)</th><th>Server</th><th>Enabled</th><th>Added</th><th>Actions</th></tr></thead>
     <tbody id="pg_rows"></tbody></table>
   <div class="addrow">
     <input type="text" id="pg_val" placeholder="program_name e.g. %SSMS% or sqlcmd%">
     <input type="text" id="pg_srv" placeholder="server (blank = all)">
     <button onclick="add('programs','pg_val','pg_srv')">Add program</button>
   </div>
   <div class="msg" id="pg_msg"></div>
 </div>
<script>
 const CFG={'app-logins':{rows:'al_rows',msg:'al_msg'},'programs':{rows:'pg_rows',msg:'pg_msg'}};
 function esc(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
 function msg(k,t){document.getElementById(CFG[k].msg).textContent=t||'';}
 async function api(path,body){const o=body?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}:{};
   const r=await fetch(path,o);const j=await r.json();if(!j.ok)throw new Error(j.error||'request failed');return j;}
 async function load(k){try{const j=await api('/api/'+k);
   document.getElementById(CFG[k].rows).innerHTML=j.rows.map(r=>`<tr>
     <td>${esc(r.value)}</td><td>${esc(r.server)}</td>
     <td><span class="badge ${r.is_active?'on':'off'}">${r.is_active?'enabled':'disabled'}</span></td>
     <td>${r.entry_date?esc(r.entry_date.substring(0,19).replace('T',' ')):''}</td>
     <td><button onclick="setrow('${k}',${r.row_id},${!r.is_active})">${r.is_active?'Disable':'Enable'}</button>
     <button class="danger" onclick="del('${k}',${r.row_id},'${esc(r.value)}')">Delete</button></td></tr>`).join('');
   }catch(e){msg(k,'Load failed: '+e.message);}}
 async function add(k,vid,sid){const v=document.getElementById(vid).value.trim();
   if(!v){msg(k,'Enter a value.');return;}
   try{await api('/api/'+k+'/add',{value:v,server:document.getElementById(sid).value.trim()});
     document.getElementById(vid).value='';document.getElementById(sid).value='';msg(k,'');load(k);}
   catch(e){msg(k,'Add failed: '+e.message);}}
 async function setrow(k,id,active){try{await api('/api/'+k+'/set',{row_id:id,is_active:active});msg(k,'');load(k);}catch(e){msg(k,'Update failed: '+e.message);}}
 async function del(k,id,name){if(!confirm('Delete "'+name+'"?'))return;
   try{await api('/api/'+k+'/delete',{row_id:id});msg(k,'');load(k);}catch(e){msg(k,'Delete failed: '+e.message);}}
 load('app-logins');load('programs');
</script></body></html>
"""


# ---------------------------------------------------------------------------
# TLS / SSL certificate management
#   /ssl_certificate      config page (status + upload + revert)
#   /api/ssl/status       current cert status JSON
#   /api/ssl/upload       install a customer cert+key (multipart)
#   /api/ssl/revert       switch back to the self-signed personal cert
# The web server binds the cert once at startup, so changes take effect after a
# DBDOME web-service restart (surfaced in the UI).
# ---------------------------------------------------------------------------
from fastapi import UploadFile, File


@app.get("/ssl_certificate", response_class=HTMLResponse)
def ssl_certificate_page(request: Request):
    """Config page to view the active TLS certificate, upload the customer's own
    certificate, or revert to the self-signed personal certificate."""
    return """
<html lang="en"><head><meta charset="UTF-8"><title>TLS Certificate</title>
<style>
 body{background:#111217;color:#d8d9da;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;margin:0;padding:16px;}
 .panel{max-width:820px;margin:24px auto;background:#181b1f;border:1px solid #2c3235;border-radius:6px;padding:24px;}
 .panel-header{font-size:18px;font-weight:600;margin-bottom:6px;color:#fff;}
 .panel-sub{font-size:12px;color:#9aa0a6;margin-bottom:16px;}
 table{width:100%;border-collapse:collapse;margin-bottom:16px;}
 th,td{text-align:left;padding:8px 10px;border-bottom:1px solid #2c3235;font-size:14px;vertical-align:top;}
 th{color:#9aa0a6;font-weight:600;width:150px;}
 .badge{display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:600;}
 .on{background:#1a7f37;color:#fff;} .off{background:#6e2226;color:#fff;} .warn{background:#8a6d00;color:#fff;}
 button{background:#3d71d9;color:#fff;border:none;border-radius:4px;padding:8px 14px;font-size:13px;cursor:pointer;margin-right:6px;}
 button:hover{background:#345fb4;} button.danger{background:#6e2226;} button.danger:hover{background:#8d2a30;}
 input[type=text],input[type=password]{background:#111217;color:#d8d9da;border:1px solid #2c3235;border-radius:4px;padding:8px 10px;font-size:14px;width:340px;}
 input[type=file]{color:#d8d9da;font-size:13px;}
 .field{margin:10px 0;} .field label{display:block;color:#9aa0a6;font-size:12px;margin-bottom:4px;}
 .msg{margin-top:10px;font-size:13px;min-height:18px;} .ok{color:#4caf50;} .err{color:#f56b6b;}
 h3{color:#fff;font-size:15px;margin-top:26px;}
 code{background:#0d0e12;padding:1px 5px;border-radius:3px;}
 .note{font-size:12px;color:#9aa0a6;margin-top:6px;}
</style></head><body>
 <div class="panel">
   <div class="panel-header">TLS / SSL Certificate</div>
   <div class="panel-sub">The DBDOME web server serves HTTPS using the <b>active</b> certificate below.
     Out of the box that is a self-signed <b>personal</b> certificate (browsers show a trust warning).
     Upload your organization's own certificate to replace it, or revert to the personal certificate at any time.
     Changes take effect after the <b>DBDOME web service is restarted</b>.</div>

   <div id="status">Loading status&hellip;</div>

   <h3>Install customer certificate</h3>
   <div class="field"><label>Certificate (PEM &mdash; .crt/.pem, full chain if applicable)</label>
     <input type="file" id="cert_file" accept=".crt,.pem,.cer"></div>
   <div class="field"><label>Private key (PEM &mdash; .key/.pem)</label>
     <input type="file" id="key_file" accept=".key,.pem"></div>
   <div class="field"><label>Key password (only if the private key is encrypted)</label>
     <input type="password" id="key_pw" placeholder="leave blank if none"></div>
   <button onclick="upload()">Install &amp; activate</button>
   <button class="danger" onclick="revert()">Revert to personal</button>
   <div class="msg" id="msg"></div>
   <div class="note">The certificate and key are validated together before anything is changed &mdash; a bad pair never
     replaces a working certificate. Encrypted key passwords are stored encrypted on the host.</div>
 </div>
<script>
 function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
 function msg(t,cls){const m=document.getElementById('msg');m.textContent=t||'';m.className='msg '+(cls||'');}
 function certRow(title,c,activeName,activeKey){
   if(!c||!c.exists) return '<tr><th>'+title+'</th><td><span class="badge off">not present</span></td></tr>';
   const act = activeKey===activeName ? ' <span class="badge on">ACTIVE</span>' : '';
   let exp = c.expired ? '<span class="badge off">EXPIRED</span>'
            : (c.days_left!=null && c.days_left<30 ? '<span class="badge warn">'+c.days_left+' days left</span>'
            : (c.days_left!=null ? c.days_left+' days left' : ''));
   const ss = c.self_signed ? ' <span class="badge warn">self-signed</span>' : '';
   return '<tr><th>'+title+act+'</th><td>'
     +'<b>Subject:</b> '+esc(c.subject)+ss+'<br>'
     +'<b>Issuer:</b> '+esc(c.issuer)+'<br>'
     +'<b>Valid:</b> '+esc(c.not_before)+' &rarr; '+esc(c.not_after)+' &nbsp; '+exp+'<br>'
     +(c.sans&&c.sans.length?'<b>SANs:</b> '+esc(c.sans.join(', ')):'')
     +'</td></tr>';
 }
 async function load(){
   try{const r=await fetch('/api/ssl/status');const j=await r.json();
     if(!j.ok)throw new Error(j.error||'failed');
     const s=j.status;
     let head='<table><tr><th>HTTPS enabled</th><td><span class="badge '+(s.enabled?'on':'off')+'">'
        +(s.enabled?'enabled ('+esc(s.scheme)+')':'disabled &mdash; serving plain HTTP')+'</span>'
        +(s.enabled?'':' &mdash; set <code>WEB_SSL_ENABLED=true</code> in .env')+'</td></tr>';
     if(s.env_override){head+='<tr><th>.env override</th><td><span class="badge warn">WEB_SSL_CERT</span> '
        +esc(s.env_cert)+'<div class="note">A hard path override is set in .env; it takes priority over the slots below.</div></td></tr>';}
     head+=certRow('Personal (self-signed)',s.personal,s.active,'personal');
     head+=certRow('Customer',s.customer,s.active,'customer');
     head+='</table>';
     document.getElementById('status').innerHTML=head;
   }catch(e){document.getElementById('status').innerHTML='<span class="err">Status failed: '+esc(e.message)+'</span>';}
 }
 async function upload(){
   const cf=document.getElementById('cert_file').files[0];
   const kf=document.getElementById('key_file').files[0];
   if(!cf||!kf){msg('Choose both a certificate and a private key file.','err');return;}
   const fd=new FormData();fd.append('cert',cf);fd.append('key',kf);
   fd.append('password',document.getElementById('key_pw').value||'');
   msg('Validating and installing…');
   try{const r=await fetch('/api/ssl/upload',{method:'POST',body:fd});const j=await r.json();
     if(!j.ok)throw new Error(j.error||'install failed');
     msg('Installed. Subject: '+esc(j.summary&&j.summary.subject)+'. Restart the DBDOME web service to serve it.','ok');
     load();}
   catch(e){msg('Install failed: '+e.message,'err');}
 }
 async function revert(){
   if(!confirm('Revert to the self-signed personal certificate?'))return;
   msg('Reverting…');
   try{const r=await fetch('/api/ssl/revert',{method:'POST'});const j=await r.json();
     if(!j.ok)throw new Error(j.error||'revert failed');
     msg('Reverted to personal certificate. Restart the DBDOME web service to serve it.','ok');load();}
   catch(e){msg('Revert failed: '+e.message,'err');}
 }
 load();
</script></body></html>
"""


@app.get("/api/ssl/status")
def api_ssl_status(request: Request):
    try:
        from utils.ssl_cert import get_status
        return JSONResponse({"ok": True, "status": get_status()})
    except Exception as e:
        db_write_log(f"ssl status failed: {e}", "ERROR", "api_ssl_status", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


@app.post("/api/ssl/upload")
async def api_ssl_upload(cert: UploadFile = File(...),
                         key: UploadFile = File(...),
                         password: str = Form("")):
    """Install a customer-supplied certificate + private key and activate it."""
    try:
        from utils.ssl_cert import install_customer_cert
        cert_bytes = await cert.read()
        key_bytes = await key.read()
        if not cert_bytes or not key_bytes:
            return JSONResponse({"ok": False, "error": "empty certificate or key file"},
                                status_code=400)
        summary = install_customer_cert(cert_bytes, key_bytes, (password or None))
        db_write_log(f"customer TLS cert installed: subject={summary.get('subject')} "
                     f"issuer={summary.get('issuer')} expires={summary.get('not_after')}",
                     "INFO", "api_ssl_upload", "")
        return JSONResponse({"ok": True, "summary": summary})
    except ValueError as e:
        # validation failure — expected, not a server error
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)
    except Exception as e:
        db_write_log(f"ssl upload failed: {e}", "ERROR", "api_ssl_upload", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


@app.post("/api/ssl/revert")
def api_ssl_revert(request: Request):
    try:
        from utils.ssl_cert import revert_to_personal
        revert_to_personal()
        db_write_log("TLS cert reverted to personal (self-signed)", "INFO", "api_ssl_revert", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        db_write_log(f"ssl revert failed: {e}", "ERROR", "api_ssl_revert", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


# ---------------------------------------------------------------------------
# LDAP / Active Directory login (Grafana) — config UI + apply
#   /ldap_settings        config page (status + settings + group mappings)
#   /api/ldap/status      saved settings + live ini/toml/service state
#   /api/ldap/save        persist settings (bind password enc:v1:)
#   /api/ldap/test        bind + optional user lookup/credential check (ldap3)
#   /api/ldap/apply       render ldap.toml + patch custom.ini + restart Grafana
# Authentication itself is Grafana's native LDAP; this only manages its config.
# Local Grafana logins stay enabled as fallback. See utils/ldap_settings.py and
# sql_scripts/7400_ldap_settings.sql.
# ---------------------------------------------------------------------------

@app.get("/login_authorizations", response_class=HTMLResponse)
def login_authorizations_page(request: Request):
    """Config page for the login authorisation guard (SEC-SQL-AUD-011-RC06)."""
    return """
<html lang="en"><head><meta charset="UTF-8"><title>Login Authorisation Guard</title>
<style>
 body{background:#111217;color:#d8d9da;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;margin:0;padding:16px;}
 .panel{max-width:1100px;margin:24px auto;background:#181b1f;border:1px solid #2c3235;border-radius:6px;padding:24px;}
 .panel-header{font-size:18px;font-weight:600;margin-bottom:6px;color:#fff;}
 .panel-sub{font-size:12px;color:#9aa0a6;margin-bottom:16px;line-height:1.55;}
 .badge{display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:600;}
 .on{background:#1a7f37;color:#fff;} .off{background:#6e2226;color:#fff;} .warn{background:#8a6d00;color:#fff;}
 .white{background:#1f6feb;color:#fff;} .black{background:#6e2226;color:#fff;}
 button{background:#3d71d9;color:#fff;border:none;border-radius:4px;padding:8px 14px;font-size:13px;cursor:pointer;margin-right:6px;}
 button:hover{background:#345fb4;} button.danger{background:#6e2226;} button.minor{background:#2c3235;}
 input[type=text],select{background:#111217;color:#d8d9da;border:1px solid #2c3235;border-radius:4px;padding:7px 9px;font-size:13px;}
 table{width:100%;border-collapse:collapse;margin:10px 0;}
 th,td{text-align:left;padding:6px 8px;border-bottom:1px solid #2c3235;font-size:13px;vertical-align:middle;}
 th{color:#9aa0a6;font-weight:600;}
 h3{color:#fff;font-size:15px;margin-top:26px;border-top:1px solid #2c3235;padding-top:16px;}
 code{background:#0d0e12;padding:1px 5px;border-radius:3px;}
 .note{font-size:12px;color:#9aa0a6;margin-top:6px;line-height:1.5;}
 .msg{margin-top:10px;font-size:13px;min-height:18px;white-space:pre-wrap;}
 .ok{color:#4caf50;} .err{color:#f56b6b;}
 .ops label{margin-right:10px;font-size:12px;color:#d8d9da;white-space:nowrap;}
 .grid{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-end;}
 .f label{display:block;color:#9aa0a6;font-size:12px;margin-bottom:4px;}
</style></head><body>
 <div class="panel">
   <div class="panel-header">Login Authorisation Guard</div>
   <div class="panel-sub">Declare which statements each login may run. When a login runs something it may not,
     DBDOME raises the critical root cause
     <code>SEC-SQL-AUD-011-RC06</code> &mdash; <i>Unauthorised INSERT, UPDATE, DELETE or DROP statement executed by a login</i>.
     <br><b>White</b> rule = the ticked operations are the <b>only</b> ones that login may run.
     <b>Black</b> rule = the ticked operations are <b>forbidden</b>. A black rule always wins over a white one.
     <br>A login with no active rule is unrestricted &mdash; while this table is empty nothing is ever flagged.
     <code>login</code> and <code>server</code> are case-insensitive LIKE patterns; server <code>%</code> means all servers.</div>

   <h3>Add a rule</h3>
   <div class="grid">
     <div class="f"><label>Login (LIKE pattern)</label><input type="text" id="login_name" placeholder="app_%" style="width:210px"></div>
     <div class="f"><label>Server</label><input type="text" id="server" placeholder="%" style="width:150px"></div>
     <div class="f"><label>Mode</label><select id="mode" style="width:110px">
        <option value="white">white</option><option value="black">black</option></select></div>
     <div class="f"><label>Operations</label><span class="ops" id="ops"></span></div>
     <div class="f"><label>Note (optional)</label><input type="text" id="description" style="width:200px"></div>
     <div class="f"><button onclick="addRule()">Add rule</button></div>
   </div>

   <h3>Rules</h3>
   <table><thead><tr><th>Login</th><th>Server</th><th>Mode</th><th>Operations</th>
     <th>Note</th><th>Active</th><th></th></tr></thead><tbody id="rules"></tbody></table>

   <h3>Check a login</h3>
   <div class="grid">
     <div class="f"><label>Login</label><input type="text" id="t_login" style="width:180px"></div>
     <div class="f"><label>Server</label><input type="text" id="t_server" placeholder="%" style="width:140px"></div>
     <div class="f"><label>Operation</label><select id="t_cmd">
        <option>select</option><option>insert</option><option>update</option>
        <option>delete</option><option>drop</option><option>truncate</option></select></div>
     <div class="f"><button class="minor" onclick="testRule()">Would this be allowed?</button></div>
   </div>
   <div class="note">Evaluated by <code>metrics.is_login_authorized()</code> in the database &mdash; the same
     function the detection uses, so this preview cannot disagree with it.</div>

   <h3>Unauthorised statements seen today</h3>
   <button class="minor" onclick="loadViolations()">Refresh</button>
   <table><thead><tr><th>When</th><th>Server</th><th>Login</th><th>Op</th>
     <th>Database</th><th>Program</th><th>Statement</th></tr></thead><tbody id="viol"></tbody></table>

   <div class="msg" id="msg"></div>
 </div>
<script>
 const OPS=['select','insert','update','delete','drop','truncate'];
 function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
 function msg(t,c){const m=document.getElementById('msg');m.textContent=t||'';m.className='msg '+(c||'');}
 document.getElementById('ops').innerHTML=OPS.map(o=>
   '<label><input type="checkbox" class="op" value="'+o+'"> '+o+'</label>').join('');

 async function post(url,body){
   const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
   const j=await r.json(); if(!j.ok) throw new Error(j.error||'failed'); return j;
 }
 async function load(){
   try{
     const j=await (await fetch('/api/login-authorizations')).json();
     if(!j.ok) throw new Error(j.error);
     document.getElementById('rules').innerHTML = j.rows.length? j.rows.map(r=>{
       const ops=OPS.filter(o=>r.ops[o]).join(', ')||'<i>none</i>';
       return '<tr><td><code>'+esc(r.login_name)+'</code></td><td>'+esc(r.server)+'</td>'
         +'<td><span class="badge '+(r.mode==='black'?'black':'white')+'">'+r.mode+'</span></td>'
         +'<td>'+ops+'</td><td>'+esc(r.description)+'</td>'
         +'<td><span class="badge '+(r.is_active?'on':'off')+'">'+(r.is_active?'active':'off')+'</span></td>'
         +'<td><button class="minor" onclick="toggle('+r.row_id+','+(!r.is_active)+')">'
         +(r.is_active?'disable':'enable')+'</button>'
         +'<button class="danger" onclick="del('+r.row_id+')">delete</button></td></tr>';
     }).join('') : '<tr><td colspan="7"><i>No rules \\u2014 the guard is inactive and nothing will be flagged.</i></td></tr>';
   }catch(e){msg('Load failed: '+e.message,'err');}
 }
 async function addRule(){
   const ops={}; document.querySelectorAll('.op').forEach(c=>ops[c.value]=c.checked);
   try{
     await post('/api/login-authorizations/add',{
       login_name:document.getElementById('login_name').value.trim(),
       server:document.getElementById('server').value.trim(),
       mode:document.getElementById('mode').value,
       description:document.getElementById('description').value.trim(), ops:ops});
     document.getElementById('login_name').value='';document.getElementById('description').value='';
     document.querySelectorAll('.op').forEach(c=>c.checked=false);
     msg('Rule saved.','ok'); load();
   }catch(e){msg('Add failed: '+e.message,'err');}
 }
 async function toggle(id,active){ try{ await post('/api/login-authorizations/set',{row_id:id,is_active:active}); load(); }catch(e){msg(e.message,'err');} }
 async function del(id){ if(!confirm('Delete this rule?'))return;
   try{ await post('/api/login-authorizations/delete',{row_id:id}); load(); }catch(e){msg(e.message,'err');} }
 async function testRule(){
   try{
     const j=await post('/api/login-authorizations/test',{
       login_name:document.getElementById('t_login').value.trim(),
       server:document.getElementById('t_server').value.trim(),
       command:document.getElementById('t_cmd').value});
     msg(j.authorized ? 'Allowed \\u2014 no alert would be raised.'
                      : 'NOT allowed \\u2014 this would raise SEC-SQL-AUD-011-RC06 (critical).',
         j.authorized?'ok':'err');
   }catch(e){msg('Check failed: '+e.message,'err');}
 }
 async function loadViolations(){
   try{
     const j=await (await fetch('/api/login-authorizations/violations')).json();
     if(!j.ok) throw new Error(j.error);
     document.getElementById('viol').innerHTML = j.rows.length? j.rows.map(r=>
       '<tr><td>'+esc((r.entry_date||'').replace('T',' ').slice(0,19))+'</td>'
       +'<td>'+esc(r.servername||r.server)+'</td><td>'+esc(r.login_name)+'</td>'
       +'<td><b>'+esc(r.command)+'</b></td><td>'+esc(r.database_name)+'</td>'
       +'<td>'+esc(r.program_name)+'</td><td><code>'+esc((r.query||'').slice(0,140))+'</code></td></tr>'
     ).join('') : '<tr><td colspan="7"><i>None.</i></td></tr>';
   }catch(e){msg('Load failed: '+e.message,'err');}
 }
 load(); loadViolations();
</script></body></html>
"""


@app.get("/ldap_settings", response_class=HTMLResponse)
def ldap_settings_page(request: Request):
    """Config page for LDAP / Active Directory login to the DBDOME UI."""
    return """
<html lang="en"><head><meta charset="UTF-8"><title>LDAP / Active Directory Login</title>
<style>
 body{background:#111217;color:#d8d9da;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;margin:0;padding:16px;}
 .panel{max-width:900px;margin:24px auto;background:#181b1f;border:1px solid #2c3235;border-radius:6px;padding:24px;}
 .panel-header{font-size:18px;font-weight:600;margin-bottom:6px;color:#fff;}
 .panel-sub{font-size:12px;color:#9aa0a6;margin-bottom:16px;}
 .badge{display:inline-block;padding:2px 10px;border-radius:10px;font-size:12px;font-weight:600;}
 .on{background:#1a7f37;color:#fff;} .off{background:#6e2226;color:#fff;} .warn{background:#8a6d00;color:#fff;}
 button{background:#3d71d9;color:#fff;border:none;border-radius:4px;padding:8px 14px;font-size:13px;cursor:pointer;margin-right:6px;}
 button:hover{background:#345fb4;} button.danger{background:#6e2226;} button.danger:hover{background:#8d2a30;}
 button.minor{background:#2c3235;} button.minor:hover{background:#3a4146;}
 input[type=text],input[type=password],select{background:#111217;color:#d8d9da;border:1px solid #2c3235;border-radius:4px;padding:8px 10px;font-size:14px;width:340px;}
 textarea{background:#111217;color:#d8d9da;border:1px solid #2c3235;border-radius:4px;padding:8px 10px;font-size:13px;width:520px;font-family:Consolas,monospace;}
 .field{margin:10px 0;} .field label{display:block;color:#9aa0a6;font-size:12px;margin-bottom:4px;}
 .row{display:flex;gap:18px;flex-wrap:wrap;}
 .msg{margin-top:10px;font-size:13px;min-height:18px;white-space:pre-wrap;} .ok{color:#4caf50;} .err{color:#f56b6b;}
 h3{color:#fff;font-size:15px;margin-top:26px;border-top:1px solid #2c3235;padding-top:16px;}
 code{background:#0d0e12;padding:1px 5px;border-radius:3px;}
 .note{font-size:12px;color:#9aa0a6;margin-top:6px;}
 table.map{width:100%;border-collapse:collapse;margin:8px 0;}
 table.map th,table.map td{text-align:left;padding:6px 8px;border-bottom:1px solid #2c3235;font-size:13px;}
 table.map input[type=text]{width:96%;}
 #live td,#live th{padding:6px 8px;font-size:13px;border-bottom:1px solid #2c3235;text-align:left;}
</style></head><body>
 <div class="panel">
   <div class="panel-header">LDAP / Active Directory Login</div>
   <div class="panel-sub">Let your team sign in to the DBDOME UI (Grafana) with their corporate
     directory credentials. Users are created automatically on first login and get their role from
     the <b>group mappings</b> below. Local logins (the built-in <code>dbdome</code> and
     <code>admin</code> users) always keep working as a fallback, so a bad LDAP config can't lock you out.
     <b>Save</b> stores the settings; <b>Test</b> verifies them against your directory;
     <b>Apply</b> activates them (restarts the DBDOME Grafana service, ~10 seconds).</div>

   <table id="live"></table>

   <h3>Server</h3>
   <div class="row">
     <div class="field"><label>LDAP host (name or IP)</label><input type="text" id="host" placeholder="dc1.corp.local"></div>
     <div class="field"><label>Port</label><input type="text" id="port" style="width:90px" placeholder="636" onchange="portWarn()"></div>
     <div class="field"><label>Encryption</label>
       <select id="encryption" onchange="syncPort()">
         <option value="ldaps">LDAPS (SSL, port 636)</option>
         <option value="starttls">StartTLS (port 389)</option>
         <option value="none">None (port 389, not recommended)</option>
       </select></div>
     <div class="field"><label>Skip TLS certificate verification</label>
       <select id="ssl_skip_verify" style="width:120px"><option value="false">no</option><option value="true">yes</option></select></div>
   </div>
   <div class="note" id="portwarn"></div>
   <div class="field"><label>CA certificate for the directory server (PEM, optional &mdash; needed when your AD uses an internal CA)</label>
     <textarea id="root_ca_cert" rows="3" placeholder="-----BEGIN CERTIFICATE-----"></textarea></div>

   <h3>Service account (read-only bind user)</h3>
   <div class="row">
     <div class="field"><label>Bind DN / UPN</label><input type="text" id="bind_dn" placeholder="CN=svc_dbdome,OU=Service Accounts,DC=corp,DC=local"></div>
     <div class="field"><label>Bind password <span id="pwset"></span></label>
       <input type="password" id="bind_password" placeholder="leave blank to keep current"></div>
   </div>

   <h3>User lookup</h3>
   <div class="field"><label>User search base DN(s) &mdash; one per line</label>
     <textarea id="search_base_dns" rows="2" placeholder="OU=Users,DC=corp,DC=local"></textarea></div>
   <div class="row">
     <div class="field"><label>Search filter (<code>%s</code> = the typed login)</label>
       <input type="text" id="search_filter" placeholder="(sAMAccountName=%s)"></div>
     <div class="field"><label>Group search base DN(s), optional</label>
       <input type="text" id="group_search_base_dns" placeholder="OU=Groups,DC=corp,DC=local"></div>
   </div>

   <h3>Group &rarr; role mappings <span class="note">(first match wins; <code>*</code> matches everyone)</span></h3>
   <table class="map"><thead><tr><th style="width:60%">AD group DN</th><th>DBDOME role</th><th>Grafana admin</th><th></th></tr></thead>
     <tbody id="maps"></tbody></table>
   <button class="minor" onclick="addMap('','Viewer',false)">+ add mapping</button>
   <div class="note">Users in no mapped group are <b>denied login</b> (unless a <code>*</code> mapping exists).
     Roles: <b>Viewer</b> = dashboards read-only, <b>Editor</b> = edit dashboards, <b>Admin</b> = org admin.</div>

   <h3>Directory sync <span class="note">(optional &mdash; pre-provision users and react to AD group changes without waiting for a login)</span></h3>
   <div class="note">Grafana OSS resolves group&rarr;role only <i>at login</i>: a user who has never signed in
     does not exist here yet, and an AD group change lands at their <b>next</b> login. Enabling sync reconciles
     the mapped groups into Grafana on a timer instead. Mappings above drive both, so they cannot disagree.</div>
   <div class="row">
     <div class="field"><label>Scheduled sync</label>
       <select id="sync_enabled" style="width:120px"><option value="false">disabled</option><option value="true">enabled</option></select></div>
     <div class="field"><label>Mode</label>
       <select id="sync_dry_run" style="width:220px">
         <option value="true">dry run &mdash; log only, change nothing</option>
         <option value="false">live &mdash; apply changes</option></select></div>
     <div class="field"><label>When a user leaves every mapped group</label>
       <select id="sync_deprovision" style="width:210px">
         <option value="none">do nothing</option>
         <option value="viewer">downgrade to Viewer</option>
         <option value="remove">remove from org</option>
         <option value="disable">disable the account</option></select></div>
   </div>
   <div class="row">
     <div class="field"><label>Grafana URL</label><input type="text" id="grafana_url" placeholder="http://127.0.0.1:3000"></div>
     <div class="field"><label>Service-account token <span id="gtokset"></span></label>
       <input type="password" id="grafana_token" placeholder="leave blank to keep current"></div>
   </div>
   <div class="row">
     <div class="field"><label>Admin user (fallback if no token)</label><input type="text" id="grafana_admin_user" placeholder="admin"></div>
     <div class="field"><label>Admin password <span id="gpwset"></span></label>
       <input type="password" id="grafana_admin_password" placeholder="leave blank to keep current"></div>
   </div>
   <div class="note"><b>admin</b> and <b>dbdome_user</b> are never created, changed or deprovisioned by the sync.
     A directory read that returns no users is treated as a fault and skipped, never as &ldquo;remove everyone&rdquo;.
     Prefer a service-account token: it is revocable without changing the admin password.</div>
   <div class="row">
     <div class="field"><button class="minor" onclick="syncNow()">Sync now</button></div>
     <div class="field" style="flex:3"><label>Last run</label><div id="syncstat" class="note">&mdash;</div></div>
   </div>

   <h3>Activate</h3>
   <div class="row">
     <div class="field"><label>Enable LDAP login</label>
       <select id="enabled" style="width:120px"><option value="false">disabled</option><option value="true">enabled</option></select></div>
     <div class="field"><label>Test user (optional, for Test)</label><input type="text" id="test_user" placeholder="jdoe"></div>
     <div class="field"><label>Test user password (optional)</label><input type="password" id="test_pw"></div>
   </div>
   <button onclick="save()">Save</button>
   <button class="minor" onclick="save(true)">Save &amp; Test</button>
   <button onclick="applyCfg()">Apply &amp; restart Grafana</button>
   <div class="msg" id="msg"></div>
   <div class="note">The bind password is stored encrypted on the host. Attribute mapping defaults fit
     Active Directory (<code>sAMAccountName</code>/<code>mail</code>/<code>memberOf</code>) and rarely need changing.</div>
 </div>
<script>
 function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
 function msg(t,cls){const m=document.getElementById('msg');m.textContent=t||'';m.className='msg '+(cls||'');}
 function val(id){return document.getElementById(id).value;}
 function setVal(id,v){document.getElementById(id).value=(v==null?'':String(v));}
 function addMap(dn,role,ga){
   const tb=document.getElementById('maps');const tr=document.createElement('tr');
   tr.innerHTML='<td><input type="text" class="m_dn" value="'+esc(dn)+'"></td>'
     +'<td><select class="m_role">'+['Viewer','Editor','Admin'].map(r=>'<option'+(r===role?' selected':'')+'>'+r+'</option>').join('')+'</select></td>'
     +'<td><input type="checkbox" class="m_ga"'+(ga?' checked':'')+'></td>'
     +'<td><button class="danger" onclick="this.closest(\\'tr\\').remove()">remove</button></td>';
   tb.appendChild(tr);
 }
 function readMaps(){
   return Array.from(document.querySelectorAll('#maps tr')).map(tr=>({
     group_dn:tr.querySelector('.m_dn').value.trim(),
     org_role:tr.querySelector('.m_role').value,
     grafana_admin:tr.querySelector('.m_ga').checked})).filter(m=>m.group_dn);
 }
 // A cleartext bind on 636 (or LDAPS on 389) is silently dropped by the DC and
 // surfaces only as "connection forcibly closed" - keep the pair consistent.
 function syncPort(){
   const enc=val('encryption'),p=parseInt(val('port')||'0',10);
   if(enc==='ldaps'&&(p===389||p===0))setVal('port',636);
   if(enc!=='ldaps'&&p===636)setVal('port',389);
   portWarn();
 }
 function portWarn(){
   const enc=val('encryption'),p=parseInt(val('port')||'0',10),w=document.getElementById('portwarn');
   let t='';
   if(enc!=='ldaps'&&(p===636||p===3269))t='Port '+p+' is the LDAPS port \\u2014 a cleartext bind there is dropped by the server.';
   if(enc==='ldaps'&&(p===389||p===3268))t='Port '+p+' is the cleartext port \\u2014 LDAPS cannot handshake there; use StartTLS.';
   w.textContent=t;w.className=t?'note err':'note';
 }
 function payload(){
   return {enabled:val('enabled')==='true',host:val('host').trim(),port:parseInt(val('port')||'636',10),
     encryption:val('encryption'),ssl_skip_verify:val('ssl_skip_verify')==='true',
     root_ca_cert:val('root_ca_cert').trim()||null,bind_dn:val('bind_dn').trim(),
     bind_password:val('bind_password'),search_base_dns:val('search_base_dns'),
     search_filter:val('search_filter').trim()||'(sAMAccountName=%s)',
     group_search_base_dns:val('group_search_base_dns').trim()||null,group_mappings:readMaps(),
     sync_enabled:val('sync_enabled')==='true',sync_dry_run:val('sync_dry_run')==='true',
     sync_deprovision:val('sync_deprovision'),
     grafana_url:val('grafana_url').trim()||'http://127.0.0.1:3000',
     grafana_token:val('grafana_token'),
     grafana_admin_user:val('grafana_admin_user').trim()||null,
     grafana_admin_password:val('grafana_admin_password')};
 }
 function renderSync(s){
   document.getElementById('gtokset').innerHTML=s.grafana_token_set?'<span class="badge on">set</span>':'<span class="badge warn">not set</span>';
   document.getElementById('gpwset').innerHTML=s.grafana_admin_password_set?'<span class="badge on">set</span>':'';
   const el=document.getElementById('syncstat');
   if(!s.last_sync_at){el.innerHTML='never run';return;}
   const r=s.last_sync_result||{},when=esc(s.last_sync_at.replace('T',' ').slice(0,19));
   let t=when+' \\u2014 '+(r.dry_run?'<span class="badge warn">dry run</span> ':'')
     +esc(r.seen||0)+' in AD, '+esc(r.created||0)+' created, '+esc(r.role_set||0)+' roles set, '
     +esc(r.admin_set||0)+' admin flags, '+esc(r.deprovisioned||0)+' deprovisioned';
   if(r.errors)t+=' <span class="badge off">'+esc(r.errors)+' errors</span>';
   if(s.last_sync_error)t+='<br><span class="badge off">'+esc(s.last_sync_error)+'</span>';
   el.innerHTML=t;
 }
 async function syncNow(){
   msg('Running one sync cycle\\u2026');
   try{const r=await fetch('/api/ldap/sync_now',{method:'POST'});const j=await r.json();
     if(!j.ok)throw new Error(j.error||'sync failed');
     await load();
     const rr=(j.settings&&j.settings.last_sync_result)||{};
     msg((rr.dry_run?'Dry run complete (nothing changed). ':'Sync complete. ')
       +(rr.seen||0)+' users in AD, '+(rr.created||0)+' created, '+(rr.role_set||0)+' roles set, '
       +(rr.deprovisioned||0)+' deprovisioned, '+(rr.errors||0)+' errors.',(rr.errors?'err':'ok'));}
   catch(e){msg('Sync failed: '+e.message,'err');}
 }
 async function load(){
   try{const r=await fetch('/api/ldap/status');const j=await r.json();
     if(!j.ok)throw new Error(j.error||'failed');
     const s=j.status.settings,l=j.status.live;
     setVal('host',s.host);setVal('port',s.port);setVal('encryption',s.encryption);
     setVal('ssl_skip_verify',String(s.ssl_skip_verify));setVal('root_ca_cert',s.root_ca_cert);
     setVal('bind_dn',s.bind_dn);setVal('search_base_dns',s.search_base_dns);
     setVal('search_filter',s.search_filter);setVal('group_search_base_dns',s.group_search_base_dns);
     setVal('enabled',String(s.enabled));portWarn();
     document.getElementById('pwset').innerHTML=s.bind_password_set?'<span class="badge on">set</span>':'<span class="badge warn">not set</span>';
     document.getElementById('maps').innerHTML='';(s.group_mappings||[]).forEach(m=>addMap(m.group_dn,m.org_role,m.grafana_admin));
     setVal('sync_enabled',String(s.sync_enabled));setVal('sync_dry_run',String(s.sync_dry_run));
     setVal('sync_deprovision',s.sync_deprovision||'none');setVal('grafana_url',s.grafana_url);
     setVal('grafana_admin_user',s.grafana_admin_user);renderSync(s);
     document.getElementById('live').innerHTML=
       '<tr><th>LDAP in Grafana</th><td><span class="badge '+(l.ldap_enabled_in_ini?'on':'off')+'">'
       +(l.ldap_enabled_in_ini?'ACTIVE':'not active')+'</span>'
       +(s.applied_at?' &nbsp;last applied '+esc(s.applied_at.replace('T',' ').slice(0,19)):'')
       +'</td></tr>'
       +'<tr><th>Grafana service</th><td>'+esc(l.service)+' &mdash; <span class="badge '
       +(l.service_state==='running'?'on':'off')+'">'+esc(l.service_state)+'</span></td></tr>'
       +'<tr><th>Config files</th><td><code>'+esc(l.ini)+'</code>'+(l.ini_exists?'':' <span class="badge off">missing</span>')
       +'<br><code>'+esc(l.toml)+'</code>'+(l.toml_exists?'':' <span class="badge warn">not written yet</span>')+'</td></tr>';
   }catch(e){msg('Load failed: '+e.message,'err');}
 }
 async function save(alsoTest){
   msg('Saving\\u2026');
   try{const r=await fetch('/api/ldap/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload())});
     const j=await r.json();if(!j.ok)throw new Error(j.error||'save failed');
     setVal('bind_password','');setVal('grafana_token','');setVal('grafana_admin_password','');await load();
     if(alsoTest){await test();}else{msg('Saved. Use Test to verify, then Apply to activate.','ok');}}
   catch(e){msg('Save failed: '+e.message,'err');}
 }
 async function test(){
   msg('Testing against the directory\\u2026');
   try{const r=await fetch('/api/ldap/test',{method:'POST',headers:{'Content-Type':'application/json'},
       body:JSON.stringify({test_username:val('test_user').trim()||null,test_password:val('test_pw')||null})});
     const j=await r.json();if(!j.ok)throw new Error(j.error||'test failed');
     let t='Service-account bind: OK ('+esc(j.result.host)+':'+j.result.port+', '+esc(j.result.encryption)+')';
     if(j.result.user){const u=j.result.user;
       t+='\\nUser found: '+u.dn+(u.email?'\\nEmail: '+u.email:'');
       t+='\\nGroups: '+(u.groups.length?u.groups.join('; '):'(none)');
       t+='\\nMapped role: '+(typeof u.mapped_role==='string'?u.mapped_role:JSON.stringify(u.mapped_role));
       if(u.password_check)t+='\\nPassword check: '+u.password_check;}
     msg(t,'ok');}
   catch(e){msg('Test failed: '+e.message,'err');}
 }
 async function applyCfg(){
   if(!confirm('Apply the saved LDAP settings and restart the DBDOME Grafana service?\\nActive UI sessions may see a ~10s interruption.'))return;
   msg('Applying and restarting Grafana\\u2026');
   try{const r=await fetch('/api/ldap/apply',{method:'POST'});const j=await r.json();
     if(!j.ok)throw new Error(j.error||'apply failed');
     msg('Applied. LDAP is now '+(j.result.enabled?'ENABLED':'DISABLED')+'; Grafana restarted.','ok');load();}
   catch(e){msg('Apply failed: '+e.message,'err');}
 }
 load();
</script></body></html>
"""


# ---------------------------------------------------------------------------
# Login authorisation guard: metrics.login_authorizations config UI.
# Each row is a login LIKE pattern + server + mode (white/black) + the set of
# operations the rule covers. See sql_scripts/7470_login_authorization_guard.sql
# for the semantics; the rule engine itself is metrics.is_login_authorized() so
# this page never re-implements it.
# ---------------------------------------------------------------------------
_LA_OPS = ("select", "insert", "update", "delete", "drop", "truncate")


def _la_rows():
    conn = psycopg2.connect(get_connection_string())
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT row_id, login_name, COALESCE(server,'%'), mode, "
            "       op_select, op_insert, op_update, op_delete, op_drop, op_truncate, "
            "       is_active, COALESCE(description,''), entry_date "
            "FROM metrics.login_authorizations ORDER BY mode, login_name")
        out = []
        for r in cur.fetchall():
            out.append({"row_id": r[0], "login_name": r[1], "server": r[2], "mode": r[3],
                        "ops": {op: r[4 + i] for i, op in enumerate(_LA_OPS)},
                        "is_active": r[10], "description": r[11],
                        "entry_date": r[12].isoformat() if r[12] else None})
        return out
    finally:
        conn.close()


@app.get("/api/login-authorizations")
def api_login_auth_list():
    try:
        return JSONResponse({"ok": True, "rows": _la_rows()})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/login-authorizations/add")
async def api_login_auth_add(request: Request):
    b = await request.json()
    login = str(b.get("login_name", "")).strip()
    mode = str(b.get("mode", "white")).strip().lower()
    if not login:
        return JSONResponse({"ok": False, "error": "login_name is required"}, status_code=400)
    if mode not in ("white", "black"):
        return JSONResponse({"ok": False, "error": "mode must be white or black"}, status_code=400)
    ops = b.get("ops") or {}
    if not any(bool(ops.get(op)) for op in _LA_OPS):
        return JSONResponse({"ok": False, "error": "tick at least one operation"}, status_code=400)
    try:
        conn = psycopg2.connect(get_connection_string()); conn.autocommit = True
        try:
            conn.cursor().execute(
                "INSERT INTO metrics.login_authorizations "
                "(login_name, server, mode, op_select, op_insert, op_update, "
                " op_delete, op_drop, op_truncate, description) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) "
                "ON CONFLICT (login_name, server, mode) DO UPDATE SET "
                "  op_select=EXCLUDED.op_select, op_insert=EXCLUDED.op_insert, "
                "  op_update=EXCLUDED.op_update, op_delete=EXCLUDED.op_delete, "
                "  op_drop=EXCLUDED.op_drop, op_truncate=EXCLUDED.op_truncate, "
                "  description=EXCLUDED.description, is_active=true",
                (login, str(b.get("server", "")).strip() or "%", mode,
                 *[bool(ops.get(op)) for op in _LA_OPS],
                 str(b.get("description", "")).strip() or None))
        finally:
            conn.close()
        db_write_log(f"login_authorizations add {mode} {login}", 0, "api_login_auth_add", "")
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/login-authorizations/set")
async def api_login_auth_set(request: Request):
    b = await request.json()
    try:
        conn = psycopg2.connect(get_connection_string()); conn.autocommit = True
        try:
            conn.cursor().execute(
                "UPDATE metrics.login_authorizations SET is_active=%s WHERE row_id=%s",
                (bool(b.get("is_active", True)), int(b.get("row_id"))))
        finally:
            conn.close()
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/login-authorizations/delete")
async def api_login_auth_delete(request: Request):
    b = await request.json()
    try:
        conn = psycopg2.connect(get_connection_string()); conn.autocommit = True
        try:
            conn.cursor().execute("DELETE FROM metrics.login_authorizations WHERE row_id=%s",
                                  (int(b.get("row_id")),))
        finally:
            conn.close()
        return JSONResponse({"ok": True})
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.post("/api/login-authorizations/test")
async def api_login_auth_test(request: Request):
    """Answer 'would this be allowed?' using the DB rule engine itself, so the
    preview can never drift from what the detection actually does."""
    b = await request.json()
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            cur = conn.cursor()
            cur.execute("SELECT metrics.is_login_authorized(%s,%s,%s)",
                        (str(b.get("login_name", "")).strip(),
                         str(b.get("server", "")).strip() or "%",
                         str(b.get("command", "")).strip().lower()))
            return JSONResponse({"ok": True, "authorized": cur.fetchone()[0]})
        finally:
            conn.close()
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.get("/api/login-authorizations/violations")
def api_login_auth_violations():
    """Current unauthorised statements — the same view the root cause reads."""
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT servername, server, login_name, program_name, database_name, "
                "       command, left(query, 300), entry_date "
                "FROM monitoring.v_sec_sql_aud_011_rc06 ORDER BY entry_date DESC LIMIT 200")
            return JSONResponse({"ok": True, "rows": [
                {"servername": r[0], "server": r[1], "login_name": r[2], "program_name": r[3],
                 "database_name": r[4], "command": r[5], "query": r[6],
                 "entry_date": r[7].isoformat() if r[7] else None} for r in cur.fetchall()]})
        finally:
            conn.close()
    except Exception as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)


@app.get("/api/version")
def api_version(request: Request):
    """Version of the running binary plus what the DB has on record.

    The two can legitimately differ for a moment after an upgrade (the binary
    registers itself on startup), and a lasting mismatch is the signal that a
    bin was overlaid without the service being restarted."""
    from utils import version as _version
    out = {"ok": True, "running": _version.as_dict()}
    try:
        with psycopg2.connect(get_connection_string()) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT config.get_version('service'), "
                            "       config.get_version_label('service')")
                row = cur.fetchone()
        out["registered"] = {"version": row[0], "label": row[1]}
        out["in_sync"] = (row[0] == out["running"]["version"])
    except Exception as e:
        out["registered"] = None
        out["error"] = str(e)
    return JSONResponse(out)


@app.get("/api/ldap/status")
def api_ldap_status(request: Request):
    try:
        from utils.ldap_settings import get_status
        return JSONResponse({"ok": True, "status": get_status()})
    except Exception as e:
        db_write_log(f"ldap status failed: {e}", "ERROR", "api_ldap_status", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


@app.post("/api/ldap/save")
async def api_ldap_save(request: Request):
    try:
        from utils.ldap_settings import save_settings
        payload = await request.json()
        settings = save_settings(payload)
        db_write_log("ldap settings saved", "INFO", "api_ldap_save", "")
        return JSONResponse({"ok": True, "settings": settings})
    except ValueError as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)
    except Exception as e:
        db_write_log(f"ldap save failed: {e}", "ERROR", "api_ldap_save", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


@app.post("/api/ldap/test")
async def api_ldap_test(request: Request):
    try:
        from utils.ldap_settings import test_connection
        payload = await request.json()
        # Blocking socket work with 10s timeouts (plus transport probing on
        # failure) - keep it off the event loop or the whole UI stalls with it.
        result = await asyncio.to_thread(
            test_connection, payload.get("test_username"), payload.get("test_password"))
        return JSONResponse({"ok": True, "result": result})
    except Exception as e:
        # bind/search failures are expected outcomes of a test — 200 with ok:false
        return JSONResponse({"ok": False, "error": str(e)})


@app.post("/api/ldap/sync_now")
async def api_ldap_sync_now(request: Request):
    """Run one AD->Grafana reconcile immediately, instead of waiting for the
    scheduler. Same function the scheduled process calls, so dry-run and the
    protected-account rules apply identically."""
    try:
        from utils.ldap_settings import sync_now
        # LDAP paged search + a call per user to Grafana: seconds to minutes on a
        # large directory. Off the event loop, exactly like /api/ldap/test.
        settings = await asyncio.to_thread(sync_now)
        db_write_log("ldap sync_now requested from the UI", "INFO", "api_ldap_sync_now", "")
        return JSONResponse({"ok": True, "settings": settings})
    except Exception as e:
        db_write_log(f"ldap sync_now failed: {e}", "ERROR", "api_ldap_sync_now", "")
        return JSONResponse({"ok": False, "error": str(e)})


@app.post("/api/ldap/apply")
def api_ldap_apply(request: Request):
    try:
        from utils.ldap_settings import apply_settings
        result = apply_settings()
        db_write_log(f"ldap settings applied (enabled={result['enabled']})",
                     "INFO", "api_ldap_apply", "")
        return JSONResponse({"ok": True, "result": result})
    except ValueError as e:
        return JSONResponse({"ok": False, "error": str(e)}, status_code=400)
    except Exception as e:
        db_write_log(f"ldap apply failed: {e}", "ERROR", "api_ldap_apply", "")
        return JSONResponse({"ok": False, "error": str(e)}, status_code=500)


@app.get("/rbac_provision", response_class=HTMLResponse)
def rbac_provision(request: Request):
    """RBAC provisioning: for the selected SQL Server + database, back up the
    database (original name + unix time) then create the standard role set with
    least-privilege grants (db_readonly/db_dataentry/db_manager/db_report_viewer)
    and the server role srv_dba (GRANT ALTER ANY CONNECTION). Each step is audited
    in metrics.rbac_log. Triggered from a dashboard link: ?server=&db=&referer="""
    q = request.query_params
    server   = q.get("server", "").strip()
    db       = q.get("db", "").strip()
    password = q.get("password", "").strip()       # given password for the created logins
    referer  = q.get("referer", "").strip()
    try:
        from processes.rbac_provisioning import provision_rbac
        res = provision_rbac(server, db, login_password=(password or None))
        db_write_log(
            f"rbac_provision {server}/{db}: backup={res.get('backup')} "
            f"roles={res.get('db_roles')}+{res.get('server_role')} errors={res.get('errors')}",
            "", "rbac_provision", server)
    except Exception as e:
        print("Error in rbac_provision:", e)
        db_write_log(f"rbac_provision {server}/{db} failed: {e}", "", "rbac_provision", server)
    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/adpiicol/sensitive-columns-explorer", status_code=302)


@app.get("/dp_dynamic_mask", response_class=HTMLResponse)
def dp_dynamic_mask(request: Request):
    """Data protection - Dynamic Data Masking. Caller selects server, database,
    table, column and the mask function (default()/email()/random(a,b)/
    partial(p,"pad",s)); the column is masked on display. Audited in metrics.dp_log.
    <table> carries the schema (e.g. 'dbo.Cards'); no separate schema param.
    Dashboard link: ?server=&db=&table=&column=&function=&referer="""
    q = request.query_params
    server   = q.get("server", "").strip()
    db       = q.get("db", "").strip()
    table    = q.get("table", "").strip()
    column   = q.get("column", "").strip()
    function = q.get("function", "default()").strip() or "default()"
    referer  = q.get("referer", "").strip()
    try:
        from processes.data_protection import apply_dynamic_mask
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = apply_dynamic_mask(server, db, "dbo", table, column, function)
        db_write_log(f"dp_dynamic_mask {server}/{db}/{table}.{column} "
                     f"fn={function} -> {res.get('status')}", "", "dp_dynamic_mask", server)
    except Exception as e:
        print("Error in dp_dynamic_mask:", e)
        db_write_log(f"dp_dynamic_mask {server}/{db} failed: {e}", "", "dp_dynamic_mask", server)
    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/adpiicol/sensitive-columns-explorer", status_code=302)


def _dp_back(referer, default="d/adpiicol/sensitive-columns-explorer"):
    from urllib.parse import urlparse
    ip = get_public_or_ip()
    referer = (referer or "").strip()
    # Full-URL referer (e.g. the :8000 reverse proxy in front of Grafana): honor it
    # verbatim, but only when it points at our own host -- never an open redirect.
    if referer.startswith(("http://", "https://")):
        if urlparse(referer).hostname == ip:
            return RedirectResponse(url=referer, status_code=302)
    elif referer:
        return RedirectResponse(url=f"http://{ip}:3000/{referer}", status_code=302)
    return RedirectResponse(url=f"http://{ip}:3000/{default}", status_code=302)


@app.get("/dp_static_mask", response_class=HTMLResponse)
def dp_static_mask(request: Request):
    """Static masking (non-prod, DESTRUCTIVE). Caller selects column + function:
    null | default | fixed:<v> | shuffle | partial(p,"pad",s). <table> carries the
    schema (e.g. 'dbo.Cards'); no separate schema param.
    ?server=&db=&table=&column=&function=&referer="""
    q = request.query_params
    try:
        from processes.data_protection import static_mask
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = static_mask(q.get("server","").strip(), q.get("db","").strip(),
                          "dbo", q.get("table","").strip(),
                          q.get("column","").strip(), q.get("function","null").strip() or "null")
        db_write_log(f"dp_static_mask {res.get('object')} -> {res.get('status')}", "", "dp_static_mask", q.get("server",""))
    except Exception as e:
        print("Error in dp_static_mask:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_anonymize", response_class=HTMLResponse)
def dp_anonymize(request: Request):
    """Anonymization (non-prod, IRREVERSIBLE). technique: suppress | substitute |
    generalize | shuffle | hash | realistic. If 'column' is omitted, EVERY big character
    column (varchar/nvarchar/char/nchar >= min_len chars, or MAX) in the table is
    anonymized. <table> carries the schema (e.g. 'dbo.Cards'); no separate schema param.
    ?server=&db=&table=&[column=]&[technique=]&[min_len=]&referer="""
    q = request.query_params
    try:
        from processes.data_protection import anonymize
        try:
            min_len = int(q.get("min_len", 100))
        except (TypeError, ValueError):
            min_len = 100
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = anonymize(q.get("server","").strip(), q.get("db","").strip(),
                        "dbo", q.get("table","").strip(),
                        q.get("column","").strip(), q.get("technique","suppress").strip() or "suppress",
                        min_len)
        db_write_log(f"dp_anonymize {res.get('object')} -> {res.get('status')}", "", "dp_anonymize", q.get("server",""))
    except Exception as e:
        print("Error in dp_anonymize:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_anonymize_pre", response_class=HTMLResponse)
def dp_anonymize_pre(request: Request):
    """Staged anonymization phase 1: copy <schema>.<table> to <table>_<datetime> and
    anonymize the COPY (all big varchars; original untouched).
    ?server=&db=&schema=&table=&[technique=]&[min_len=]&referer=  (table may be 'schema.table')"""
    q = request.query_params
    try:
        from processes.data_protection import anonymize_pre
        try:
            min_len = int(q.get("min_len", 100))
        except (TypeError, ValueError):
            min_len = 100
        res = anonymize_pre(q.get("server","").strip(), q.get("db","").strip(),
                            q.get("schema","dbo").strip() or "dbo", q.get("table","").strip(),
                            q.get("technique","realistic").strip() or "realistic", min_len)
        db_write_log(f"dp_anonymize_pre {res.get('object')} -> {res.get('status')} copy={res.get('copy')}",
                     "", "dp_anonymize_pre", q.get("server",""))
    except Exception as e:
        print("Error in dp_anonymize_pre:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_anonymize_actual", response_class=HTMLResponse)
def dp_anonymize_actual(request: Request):
    """Staged anonymization phase 2: switch the live table with its latest pre-copy.
    ?server=&db=&schema=&table=&referer=  (table may be 'schema.table')"""
    q = request.query_params
    try:
        from processes.data_protection import anonymize_actual
        res = anonymize_actual(q.get("server","").strip(), q.get("db","").strip(),
                               q.get("schema","dbo").strip() or "dbo", q.get("table","").strip())
        db_write_log(f"dp_anonymize_actual {res.get('object')} -> {res.get('status')} {res.get('switched_with')}",
                     "", "dp_anonymize_actual", q.get("server",""))
    except Exception as e:
        print("Error in dp_anonymize_actual:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_anonymize_confirm", response_class=HTMLResponse)
def dp_anonymize_confirm(request: Request):
    """Staged anonymization phase 3: create the backup schema (default dbdome_backup)
    if missing and move the original (dated copy) into it.
    ?server=&db=&schema=&table=&[backup_schema=]&referer=  (table may be 'schema.table')"""
    q = request.query_params
    try:
        from processes.data_protection import anonymize_confirm
        res = anonymize_confirm(q.get("server","").strip(), q.get("db","").strip(),
                                q.get("schema","dbo").strip() or "dbo", q.get("table","").strip(),
                                q.get("backup_schema","dbdome_backup").strip() or "dbdome_backup")
        db_write_log(f"dp_anonymize_confirm {res.get('object')} -> {res.get('status')} archived={res.get('archived')}",
                     "", "dp_anonymize_confirm", q.get("server",""))
    except Exception as e:
        print("Error in dp_anonymize_confirm:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_anonymize_preview", response_class=HTMLResponse)
def dp_anonymize_preview(request: Request):
    """Preview the anonymized dry-run copy (latest <table>_<datetime>, or ?copy=).
    Read-only SELECT TOP <rows> *, rendered as an HTML table.
    ?server=&db=&table=&[copy=]&[rows=50]  (table may be '<schema>.<table>')"""
    import html as _html
    q = request.query_params
    try:
        from processes.data_protection import preview_copy
        res = preview_copy(q.get("server","").strip(), q.get("db","").strip(),
                           q.get("schema","dbo").strip() or "dbo", q.get("table","").strip(),
                           q.get("rows","50").strip() or "50", q.get("copy","").strip() or None)
    except Exception as e:
        return HTMLResponse(f"<pre>preview error: {_html.escape(str(e))}</pre>", status_code=500)
    if res.get("status") != "ok":
        return HTMLResponse(f"<pre>{_html.escape(str(res.get('detail')))}</pre>", status_code=400)

    def _td(v):
        s = "" if v is None else str(v)
        if len(s) > 200:
            s = s[:200] + "…"
        return f"<td>{_html.escape(s)}</td>"
    thead = "".join(f"<th>{_html.escape(c)}</th>" for c in res["columns"])
    tbody = "".join("<tr>" + "".join(_td(v) for v in r) + "</tr>" for r in res["rows"])
    style = ("<style>body{font:13px/1.45 Segoe UI,Arial,sans-serif;margin:16px;color:#222}"
             "h2{color:#0B5394;margin:0 0 2px} .meta{color:#666;margin:0 0 12px;font-size:12px}"
             "table{border-collapse:collapse;width:100%}"
             "th,td{border:1px solid #B7C7DA;padding:4px 8px;text-align:left;vertical-align:top}"
             "th{background:#0B5394;color:#fff;position:sticky;top:0}"
             "tr:nth-child(even) td{background:#E8F0FA}</style>")
    page = (f"<!doctype html><html><head><meta charset='utf-8'><title>Anonymize preview</title>{style}"
            f"</head><body><h2>Anonymized dry-run preview</h2>"
            f"<p class='meta'>{_html.escape(res.get('copy') or '')} &mdash; {res['count']} row(s)</p>"
            f"<table><thead><tr>{thead}</tr></thead><tbody>{tbody}</tbody></table></body></html>")
    return HTMLResponse(page)


@app.get("/dp_tokenize", response_class=HTMLResponse)
def dp_tokenize(request: Request):
    """Tokenization (production, §4.2). Caller selects column + encryption type:
    passphrase | aes256. Real value -> encrypted TokenVault; column holds a token.
    <table> carries the schema (e.g. 'dbo.Cards'); no separate schema param.
    ?server=&db=&table=&column=&encryption=&referer="""
    q = request.query_params
    try:
        from processes.data_protection import tokenize
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = tokenize(q.get("server","").strip(), q.get("db","").strip(),
                       "dbo", q.get("table","").strip(),
                       q.get("column","").strip(), q.get("encryption","passphrase").strip() or "passphrase")
        db_write_log(f"dp_tokenize {res.get('object')} -> {res.get('status')}", "", "dp_tokenize", q.get("server",""))
    except Exception as e:
        print("Error in dp_tokenize:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_tokenize_pre", response_class=HTMLResponse)
def dp_tokenize_pre(request: Request):
    """Staged tokenization phase 1: copy <table> to <table>_<datetime> and tokenize
    <column> on the COPY (original untouched); copy mirrored to Postgres.
    <table> carries the schema (e.g. 'dbo.Cards'); no separate schema param.
    ?server=&db=&table=&column=&[encryption=]&referer="""
    q = request.query_params
    try:
        from processes.data_protection import tokenize_pre
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = tokenize_pre(q.get("server","").strip(), q.get("db","").strip(),
                           "dbo", q.get("table","").strip(),
                           q.get("column","").strip(), q.get("encryption","passphrase").strip() or "passphrase")
        db_write_log(f"dp_tokenize_pre {res.get('object')} -> {res.get('status')} copy={res.get('copy')}",
                     "", "dp_tokenize_pre", q.get("server",""))
    except Exception as e:
        print("Error in dp_tokenize_pre:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_tokenize_actual", response_class=HTMLResponse)
def dp_tokenize_actual(request: Request):
    """Staged tokenization phase 2: switch the live table with its latest tokenize_pre
    copy. <table> carries the schema (e.g. 'dbo.Cards'); no separate schema param.
    ?server=&db=&table=&referer="""
    q = request.query_params
    try:
        from processes.data_protection import tokenize_actual
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = tokenize_actual(q.get("server","").strip(), q.get("db","").strip(),
                              "dbo", q.get("table","").strip())
        db_write_log(f"dp_tokenize_actual {res.get('object')} -> {res.get('status')} {res.get('switched_with')}",
                     "", "dp_tokenize_actual", q.get("server",""))
    except Exception as e:
        print("Error in dp_tokenize_actual:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_revert_mask", response_class=HTMLResponse)
def dp_revert_mask(request: Request):
    """Revert Dynamic Data Masking on a column (DROP MASKED). <table> carries the
    schema (e.g. 'dbo.Cards'); no separate schema param. ?server=&db=&table=&column=&referer="""
    q = request.query_params
    try:
        from processes.data_protection import revert_dynamic_mask
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = revert_dynamic_mask(q.get("server","").strip(), q.get("db","").strip(),
                                  "dbo", q.get("table","").strip(),
                                  q.get("column","").strip())
        db_write_log(f"dp_revert_mask {res.get('object')} -> {res.get('status')}", "", "dp_revert_mask", q.get("server",""))
    except Exception as e:
        print("Error in dp_revert_mask:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/dp_revert_tokenize", response_class=HTMLResponse)
def dp_revert_tokenize(request: Request):
    """Revert tokenization: de-tokenize a column from the vault. <table> carries the
    schema (e.g. 'dbo.Cards'); no separate schema param. ?server=&db=&table=&column=&referer="""
    q = request.query_params
    try:
        from processes.data_protection import revert_tokenize
        # schema defaults to dbo but is overridden by any schema embedded in <table>
        res = revert_tokenize(q.get("server","").strip(), q.get("db","").strip(),
                              "dbo", q.get("table","").strip(),
                              q.get("column","").strip())
        db_write_log(f"dp_revert_tokenize {res.get('object')} -> {res.get('status')}", "", "dp_revert_tokenize", q.get("server",""))
    except Exception as e:
        print("Error in dp_revert_tokenize:", e)
    return _dp_back(q.get("referer","").strip())


@app.get("/db_restore", response_class=HTMLResponse)
def db_restore(request: Request):
    """Revert ALL changes by restoring the database from its backup (reverts static
    masking / anonymization, and everything else). ?server=&db=&backup=&referer=
    backup optional - latest full backup of the DB is used when omitted."""
    q = request.query_params
    try:
        from processes.rbac_provisioning import restore_database
        res = restore_database(q.get("server","").strip(), q.get("db","").strip(),
                               (q.get("backup","").strip() or None))
        db_write_log(f"db_restore {q.get('server','')}/{q.get('db','')} -> {res.get('status')} "
                     f"({res.get('detail')})", "", "db_restore", q.get("server",""))
    except Exception as e:
        print("Error in db_restore:", e)
    return _dp_back(q.get("referer","").strip(), default="d/adpiicol/sensitive-columns-explorer")


@app.get("/root_cause_active", response_class=HTMLResponse)
def root_cause_active(request: Request):
    """Enable/disable a root cause (rootcause.resolution_paths.is_active) via
    rootcause.set_root_cause_active, then redirect back to the referring
    dashboard (same pattern as /webook_alert_set)."""
    referer = request.query_params.get("referer", "").strip()
    rc_id   = request.query_params.get("root_cause_id", "").strip()
    active  = request.query_params.get("active", "").strip()
    try:
        p_active = str(active).strip().lower() in ("true", "t", "1", "yes", "on")
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("SELECT rootcause.set_root_cause_active(:p_id, :p_active)"),
                {"p_id": rc_id or None, "p_active": p_active},
            )
        db_write_log(f"set_root_cause_active {rc_id}={p_active} succeeded", "", "set_root_cause_active", "")
    except Exception as e:
        print("Error calling set_root_cause_active:", e)
        db_write_log(f"set_root_cause_active {rc_id}={active} failed: {e}", "", "set_root_cause_active", "")

    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/rootcauses/rootcauses", status_code=302)


@app.get("/root_cause_risk", response_class=HTMLResponse)
def root_cause_risk(request: Request):
    """Set a root cause's risk level (rootcause.resolution_paths.risk_level) via
    rootcause.set_root_cause_risk (validates low/medium/high/critical), then
    redirect back to the referring dashboard (same pattern as /webook_alert_set)."""
    referer = request.query_params.get("referer", "").strip()
    rc_id   = request.query_params.get("root_cause_id", "").strip()
    risk    = request.query_params.get("risk", "").strip()
    try:
        engine = create_engine(get_connection_string())
        with engine.begin() as conn:
            conn.execute(
                text("SELECT rootcause.set_root_cause_risk(:p_id, :p_risk)"),
                {"p_id": rc_id or None, "p_risk": risk or None},
            )
        db_write_log(f"set_root_cause_risk {rc_id}={risk} succeeded", "", "set_root_cause_risk", "")
    except Exception as e:
        print("Error calling set_root_cause_risk:", e)
        db_write_log(f"set_root_cause_risk {rc_id}={risk} failed: {e}", "", "set_root_cause_risk", "")

    base_url = f"http://{get_public_or_ip()}:3000"
    if referer and not referer.startswith("http"):
        return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
    return RedirectResponse(url=f"{base_url}/d/rootcauses/rootcauses", status_code=302)


def _mask_log(server, db, schema, table, column, fn, action, detail):
    """Audit a mask attempt to metrics.masking_log."""
    try:
        eng = create_engine(get_connection_string())
        with eng.begin() as conn:
            conn.execute(text(
                "INSERT INTO metrics.masking_log (server, db_name, schema_name, table_name, column_name, mask_function, action, detail) "
                "VALUES (:s,:d,:sc,:t,:c,:fn,:a,:de)"),
                {"s": server, "d": db, "sc": schema, "t": table, "c": column,
                 "fn": fn, "a": action, "de": (detail or "")[:500]})
    except Exception as _e:
        print("mask_log failed:", _e)


MASK_TEST_USER = "dbdome_mask_test"


def _fetch_col_sample(cur, schema, table, column, impersonate):
    """TOP 10 sample of a column, optionally read while impersonating the
    unprivileged test user (so DDM returns masked values). Identifiers quoted
    server-side via QUOTENAME."""
    if impersonate:
        cur.execute(f"EXECUTE AS USER = N'{MASK_TEST_USER}'")
    try:
        # select the column RAW (no CONVERT) so the column's own DDM function is
        # rendered; wrapping a masked column in an expression makes SQL Server
        # fall back to the default() mask, hiding the real (e.g. email()) format.
        cur.execute(
            "DECLARE @s sysname=?, @t sysname=?, @c sysname=?;"
            "DECLARE @q nvarchar(max)=N'SELECT TOP 10 '+QUOTENAME(@c)+"
            "N' FROM '+QUOTENAME(@s)+N'.'+QUOTENAME(@t);"
            "EXEC sys.sp_executesql @q;", (schema, table, column))
        return ["" if r[0] is None else str(r[0]) for r in cur.fetchall()]
    finally:
        if impersonate:
            cur.execute("REVERT")


def _mask_and_preview(server, port, db, username, password, schema, table, column, fn):
    """Apply DDM on the column, create/grant the unprivileged test user, then
    capture a real-vs-masked sample. Returns (action, detail, previews)."""
    import pyodbc, os as _os
    password = decrypt_secret(password)   # metrics.servers password is stored encrypted; idempotent on plaintext
    drivers = pyodbc.drivers()
    drv = next((d for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
                            "SQL Server") if d in drivers), None)
    if not drv:
        return "error", "no suitable ODBC driver", []
    server_str = f"{server},{port}" if port else server
    enc = _os.environ.get("DBEXPERT_MSSQL_ENCRYPT", "yes")
    cs = (f"DRIVER={{{drv}}};SERVER={server_str};DATABASE={db or 'master'};"
          f"UID={username};PWD={password};Encrypt={enc};TrustServerCertificate=yes;Connection Timeout=20;")
    conn = pyodbc.connect(cs, timeout=20)
    conn.autocommit = True
    try:
        cur = conn.cursor()
        # 1. apply the mask (idempotent)
        action = "masked"
        try:
            cur.execute(
                "DECLARE @s sysname=?, @t sysname=?, @c sysname=?, @fn nvarchar(100)=?;"
                "DECLARE @sql nvarchar(max)=N'ALTER TABLE '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+"
                "N' ALTER COLUMN '+QUOTENAME(@c)+N' ADD MASKED WITH (FUNCTION = '+QUOTENAME(@fn,'''')+N')';"
                "EXEC sys.sp_executesql @sql;", (schema, table, column, fn))
        except Exception as e:
            msg = str(e)
            if not ("already" in msg.lower() and "mask" in msg.lower()):
                return "error", msg[:300], []
            action = "already-masked"

        # 2. create the unprivileged test user (no LOGIN, no UNMASK) + grant SELECT
        cur.execute(
            f"IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'{MASK_TEST_USER}') "
            f"EXEC('CREATE USER [{MASK_TEST_USER}] WITHOUT LOGIN')")
        cur.execute(
            "DECLARE @s sysname=?, @t sysname=?;"
            "DECLARE @g nvarchar(max)=N'GRANT SELECT ON '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+"
            f"N' TO [{MASK_TEST_USER}]'; EXEC sys.sp_executesql @g;", (schema, table))
        try:
            cur.execute(f"REVOKE UNMASK FROM [{MASK_TEST_USER}]")
        except Exception:
            pass

        # 3. capture real (privileged) vs masked (impersonated) samples
        real = _fetch_col_sample(cur, schema, table, column, impersonate=False)
        masked = _fetch_col_sample(cur, schema, table, column, impersonate=True)
        previews = []
        for i in range(max(len(real), len(masked))):
            previews.append({"row_no": i + 1,
                             "real": real[i] if i < len(real) else None,
                             "masked": masked[i] if i < len(masked) else None})
        return action, f"{action}; test user ready; {len(previews)} preview row(s)", previews
    except Exception as e:
        return "error", str(e)[:300], []
    finally:
        try: conn.close()
        except Exception: pass


def _store_mask_preview(server, db, schema, table, column, previews):
    """Replace stored preview rows for this column."""
    try:
        eng = create_engine(get_connection_string())
        with eng.begin() as conn:
            conn.execute(text(
                "DELETE FROM metrics.mask_preview WHERE server=:s AND db_name=:d "
                "AND schema_name=:sc AND table_name=:t AND column_name=:c"),
                {"s": server, "d": db, "sc": schema, "t": table, "c": column})
            for p in previews:
                conn.execute(text(
                    "INSERT INTO metrics.mask_preview (server, db_name, schema_name, table_name, column_name, row_no, real_value, masked_value) "
                    "VALUES (:s,:d,:sc,:t,:c,:rn,:rv,:mv)"),
                    {"s": server, "d": db, "sc": schema, "t": table, "c": column,
                     "rn": p["row_no"], "rv": p["real"], "mv": p["masked"]})
    except Exception as _e:
        print("store_mask_preview failed:", _e)


@app.get("/mask_column", response_class=HTMLResponse)
def mask_column(request: Request):
    """Create SQL Server Dynamic Data Masking on a discovered sensitive column,
    then redirect back to the Sensitive Columns Explorer (same pattern as
    /sensitive_column_add). Authorisation: the (server,db,schema,table,column)
    must be a column DBDOME flagged as sensitive. Gated by the
    config.global_params 'masking_dry_run' switch (default true = log only)."""
    q = request.query_params
    referer = q.get("referer", "").strip()
    server  = q.get("server", "").strip()
    db      = q.get("db", "").strip()
    schema  = q.get("schema", "").strip()
    table   = q.get("table", "").strip()
    column  = q.get("column", "").strip()
    pii     = q.get("pii", "").strip()
    base_url = f"http://{get_public_or_ip()}:3000"

    def back():
        if referer and not referer.startswith("http"):
            return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
        return RedirectResponse(url=f"{base_url}/d/adpiicol/sensitive-columns-explorer", status_code=302)

    fn = "email()" if "email" in pii.lower() else "default()"
    try:
        eng = create_engine(get_connection_string())
        with eng.connect() as conn:
            authorised = conn.execute(text(
                "SELECT 1 FROM monitoring.v_sec_sql_pri_001_rc12 "
                "WHERE server=:s AND db_name=:d AND schema_name=:sc AND table_name=:t AND column_name=:c LIMIT 1"),
                {"s": server, "d": db, "sc": schema, "t": table, "c": column}).fetchone()
            dry_row = conn.execute(text("SELECT value FROM config.global_params WHERE key='masking_dry_run' ORDER BY row_id DESC LIMIT 1")).fetchone()
            # an IP can host several engines in metrics.servers; masking is SQL
            # Server-only, so pick the active MSSQL instance for this host.
            srow = conn.execute(text(
                "SELECT db_vendor, port, username, password FROM metrics.servers "
                "WHERE server=:s AND is_active=true AND lower(db_vendor) IN ('mssql','sqlserver') "
                "ORDER BY row_id LIMIT 1"), {"s": server}).fetchone()
        if not authorised:
            _mask_log(server, db, schema, table, column, fn, "skipped", "not a discovered sensitive column")
            return back()
        dry = True if (not dry_row or dry_row[0] is None) else str(dry_row[0]).strip().lower() in ("true", "t", "1", "yes", "on")
        if not srow:
            _mask_log(server, db, schema, table, column, fn, "skipped", "no active MSSQL instance for this server in metrics.servers")
            return back()
        vendor, port, username, password = srow
        if (vendor or "").strip().lower() not in ("mssql", "sqlserver"):
            _mask_log(server, db, schema, table, column, fn, "skipped", f"vendor '{vendor}' not supported for masking")
            return back()
        if dry:
            _mask_log(server, db, schema, table, column, fn, "dry-run",
                      f"would run ALTER TABLE [{schema}].[{table}] ALTER COLUMN [{column}] ADD MASKED WITH (FUNCTION = '{fn}')")
            return back()
        action, detail, previews = _mask_and_preview(server, port, db, username, password, schema, table, column, fn)
        _mask_log(server, db, schema, table, column, fn, action, detail)
        if previews:
            _store_mask_preview(server, db, schema, table, column, previews)
        db_write_log(f"mask_column {server}/{db}/{schema}.{table}.{column} -> {action}", "", "mask_column", server)
    except Exception as e:
        print("Error in mask_column:", e)
        _mask_log(server, db, schema, table, column, fn, "error", str(e)[:300])
    return back()


# ---------------------------------------------------------------------------
# Column tokenization ("encryption") + revert
# ---------------------------------------------------------------------------
def _enc_log(server, db, schema, table, column, action, detail):
    try:
        eng = create_engine(get_connection_string())
        with eng.begin() as conn:
            conn.execute(text(
                "INSERT INTO metrics.encryption_log (server, db_name, schema_name, table_name, column_name, action, detail) "
                "VALUES (:s,:d,:sc,:t,:c,:a,:de)"),
                {"s": server, "d": db, "sc": schema, "t": table, "c": column, "a": action, "de": (detail or "")[:500]})
    except Exception as _e:
        print("enc_log failed:", _e)


def _enc_preview_store(server, db, schema, table, column, previews):
    try:
        eng = create_engine(get_connection_string())
        with eng.begin() as conn:
            conn.execute(text("DELETE FROM metrics.encryption_preview WHERE server=:s AND db_name=:d "
                              "AND schema_name=:sc AND table_name=:t AND column_name=:c"),
                         {"s": server, "d": db, "sc": schema, "t": table, "c": column})
            for p in previews:
                conn.execute(text(
                    "INSERT INTO metrics.encryption_preview (server,db_name,schema_name,table_name,column_name,row_no,original_value,token_value) "
                    "VALUES (:s,:d,:sc,:t,:c,:rn,:ov,:tv)"),
                    {"s": server, "d": db, "sc": schema, "t": table, "c": column,
                     "rn": p["row_no"], "ov": p["original"], "tv": p["token"]})
    except Exception as _e:
        print("enc_preview_store failed:", _e)


def _mssql_conn(server, port, db, username, password, timeout=30):
    import pyodbc, os as _os
    password = decrypt_secret(password)   # metrics.servers password is stored encrypted; idempotent on plaintext
    drivers = pyodbc.drivers()
    drv = next((d for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
                            "SQL Server") if d in drivers), None)
    if not drv:
        raise RuntimeError("no suitable ODBC driver")
    server_str = f"{server},{port}" if port else server
    enc = _os.environ.get("DBEXPERT_MSSQL_ENCRYPT", "yes")
    cs = (f"DRIVER={{{drv}}};SERVER={server_str};DATABASE={db or 'master'};UID={username};PWD={password};"
          f"Encrypt={enc};TrustServerCertificate=yes;Connection Timeout=20;")
    c = pyodbc.connect(cs, timeout=timeout)
    c.autocommit = True
    c.timeout = timeout
    return c


def _encrypt_column_mssql(server, port, db, username, password, schema, table, column):
    """Backup table to [unencrypted] (once, pristine), tokenize the column in
    place with a SHA2_256 token fit to the column, and return (action, detail,
    previews of original-vs-token read from the backup)."""
    conn = _mssql_conn(server, port, db, username, password, timeout=120)
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT ty.name, CASE WHEN ty.name IN ('nvarchar','nchar') AND c.max_length>0 THEN c.max_length/2 "
            "WHEN c.max_length<0 THEN 64 ELSE c.max_length END "
            "FROM sys.columns c JOIN sys.types ty ON ty.user_type_id=c.user_type_id "
            "WHERE c.object_id=OBJECT_ID(?) AND c.name=?", (f"{schema}.{table}", column))
        row = cur.fetchone()
        if not row:
            return "error", "column not found on target", []
        tyname = row[0]; cap = int(row[1] or 64)
        if tyname not in ("varchar", "nvarchar", "char", "nchar"):
            return "skipped", f"column type '{tyname}' not supported for in-place tokenization", []
        if cap <= 0 or cap > 64:
            cap = 64
        cur.execute("IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='unencrypted') EXEC('CREATE SCHEMA [unencrypted]')")
        backed = False
        cur.execute("SELECT OBJECT_ID(?)", (f"unencrypted.{table}",))
        if cur.fetchone()[0] is None:
            # Structure-preserving backup: MOVE the original table (preserves the
            # whole object - indexes, PK, identity, constraints) into
            # [unencrypted], then recreate a working copy in the original schema
            # to tokenize. Revert moves the pristine original back, restoring full
            # structure. (Only the transient working copy is a plain SELECT INTO.)
            cur.execute(
                "DECLARE @s sysname=?, @t sysname=?;"
                "DECLARE @q nvarchar(max)="
                "N'ALTER SCHEMA [unencrypted] TRANSFER '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+N'; '+"
                "N'SELECT * INTO '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+N' FROM [unencrypted].'+QUOTENAME(@t)+N';';"
                "EXEC sys.sp_executesql @q;", (schema, table))
            backed = True
        cur.execute(
            "DECLARE @s sysname=?, @t sysname=?, @c sysname=?, @cap int=?;"
            "DECLARE @q nvarchar(max)=N'UPDATE '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+"
            "N' SET '+QUOTENAME(@c)+N' = LEFT(CONVERT(varchar(64), HASHBYTES(''SHA2_256'', CONVERT(nvarchar(4000), '+QUOTENAME(@c)+"
            "N')), 2), '+CONVERT(varchar(10),@cap)+N') WHERE '+QUOTENAME(@c)+N' IS NOT NULL';"
            "EXEC sys.sp_executesql @q;", (schema, table, column, cap))
        n = cur.rowcount
        cur.execute(
            "DECLARE @c sysname=?, @t sysname=?, @cap int=?;"
            "DECLARE @q nvarchar(max)=N'SELECT TOP 10 CONVERT(nvarchar(200),'+QUOTENAME(@c)+N') AS orig, "
            "LEFT(CONVERT(varchar(64), HASHBYTES(''SHA2_256'', CONVERT(nvarchar(4000), '+QUOTENAME(@c)+"
            "N')), 2), '+CONVERT(varchar(10),@cap)+N') AS tok FROM [unencrypted].'+QUOTENAME(@t);"
            "EXEC sys.sp_executesql @q;", (column, table, cap))
        previews = [{"row_no": i + 1,
                     "original": ("" if r[0] is None else str(r[0])),
                     "token": ("" if r[1] is None else str(r[1]))} for i, r in enumerate(cur.fetchall())]
        action = "tokenized" + ("; backed-up" if backed else "")
        return action, f"tokenized {n} row(s) cap {cap}; backup {'created' if backed else 'existing'}", previews
    finally:
        try: conn.close()
        except Exception: pass


def _revert_encryption_mssql(server, port, db, username, password, schema, table):
    conn = _mssql_conn(server, port, db, username, password, timeout=120)
    try:
        cur = conn.cursor()
        cur.execute("SELECT OBJECT_ID(?)", (f"unencrypted.{table}",))
        if cur.fetchone()[0] is None:
            return "skipped", "no [unencrypted] backup for this table"
        cur.execute(
            "DECLARE @s sysname=?, @t sysname=?;"
            "DECLARE @q nvarchar(max)=N'DROP TABLE '+QUOTENAME(@s)+N'.'+QUOTENAME(@t)+N'; "
            "ALTER SCHEMA '+QUOTENAME(@s)+N' TRANSFER [unencrypted].'+QUOTENAME(@t)+N';';"
            "EXEC sys.sp_executesql @q;", (schema, table))
        return "reverted", f"dropped {schema}.{table}; restored backup from [unencrypted]"
    finally:
        try: conn.close()
        except Exception: pass


@app.get("/encrypt_column", response_class=HTMLResponse)
def encrypt_column(request: Request):
    """Backup the table to [unencrypted] and tokenize the column. Authorisation +
    masking-style dry-run gate (config.global_params 'encryption_dry_run')."""
    q = request.query_params
    referer = q.get("referer", "").strip(); server = q.get("server", "").strip(); db = q.get("db", "").strip()
    schema = q.get("schema", "").strip(); table = q.get("table", "").strip(); column = q.get("column", "").strip()
    base_url = f"http://{get_public_or_ip()}:3000"

    def back():
        if referer and not referer.startswith("http"):
            return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
        return RedirectResponse(url=f"{base_url}/d/adpiicol/sensitive-columns-explorer", status_code=302)

    try:
        eng = create_engine(get_connection_string())
        with eng.connect() as conn:
            authorised = conn.execute(text(
                "SELECT 1 FROM monitoring.v_sec_sql_pri_001_rc12 "
                "WHERE server=:s AND db_name=:d AND schema_name=:sc AND table_name=:t AND column_name=:c LIMIT 1"),
                {"s": server, "d": db, "sc": schema, "t": table, "c": column}).fetchone()
            dry_row = conn.execute(text("SELECT value FROM config.global_params WHERE key='encryption_dry_run' ORDER BY row_id DESC LIMIT 1")).fetchone()
            srow = conn.execute(text(
                "SELECT port, username, password FROM metrics.servers WHERE server=:s AND is_active=true "
                "AND lower(db_vendor) IN ('mssql','sqlserver') ORDER BY row_id LIMIT 1"), {"s": server}).fetchone()
        if not authorised:
            _enc_log(server, db, schema, table, column, "skipped", "not a discovered sensitive column"); return back()
        dry = True if (not dry_row or dry_row[0] is None) else str(dry_row[0]).strip().lower() in ("true", "t", "1", "yes", "on")
        if not srow:
            _enc_log(server, db, schema, table, column, "skipped", "no active MSSQL instance for this server"); return back()
        port, username, password = srow
        if dry:
            _enc_log(server, db, schema, table, column, "dry-run",
                     f"would back up [{schema}].[{table}] to [unencrypted] and tokenize [{column}]"); return back()
        action, detail, previews = _encrypt_column_mssql(server, port, db, username, password, schema, table, column)
        _enc_log(server, db, schema, table, column, action, detail)
        if previews:
            _enc_preview_store(server, db, schema, table, column, previews)
        db_write_log(f"encrypt_column {server}/{db}/{schema}.{table}.{column} -> {action}", "", "encrypt_column", server)
    except Exception as e:
        print("Error in encrypt_column:", e)
        _enc_log(server, db, schema, table, column, "error", str(e)[:300])
    return back()


@app.get("/revert_encryption", response_class=HTMLResponse)
def revert_encryption(request: Request):
    """Drop the tokenized table and restore its [unencrypted] backup to the
    original schema/name."""
    q = request.query_params
    referer = q.get("referer", "").strip(); server = q.get("server", "").strip(); db = q.get("db", "").strip()
    schema = q.get("schema", "").strip(); table = q.get("table", "").strip()
    base_url = f"http://{get_public_or_ip()}:3000"

    def back():
        if referer and not referer.startswith("http"):
            return RedirectResponse(url=f"{base_url}/{referer}", status_code=302)
        return RedirectResponse(url=f"{base_url}/d/adpiicol/sensitive-columns-explorer", status_code=302)

    try:
        eng = create_engine(get_connection_string())
        with eng.connect() as conn:
            authorised = conn.execute(text(
                "SELECT 1 FROM monitoring.v_sec_sql_pri_001_rc12 "
                "WHERE server=:s AND db_name=:d AND schema_name=:sc AND table_name=:t LIMIT 1"),
                {"s": server, "d": db, "sc": schema, "t": table}).fetchone()
            srow = conn.execute(text(
                "SELECT port, username, password FROM metrics.servers WHERE server=:s AND is_active=true "
                "AND lower(db_vendor) IN ('mssql','sqlserver') ORDER BY row_id LIMIT 1"), {"s": server}).fetchone()
        if not authorised:
            _enc_log(server, db, schema, table, "", "skipped", "not a discovered sensitive table"); return back()
        if not srow:
            _enc_log(server, db, schema, table, "", "skipped", "no active MSSQL instance for this server"); return back()
        port, username, password = srow
        action, detail = _revert_encryption_mssql(server, port, db, username, password, schema, table)
        _enc_log(server, db, schema, table, "", action, detail)
        try:
            with create_engine(get_connection_string()).begin() as conn:
                conn.execute(text("DELETE FROM metrics.encryption_preview WHERE server=:s AND db_name=:d AND schema_name=:sc AND table_name=:t"),
                             {"s": server, "d": db, "sc": schema, "t": table})
        except Exception:
            pass
        db_write_log(f"revert_encryption {server}/{db}/{schema}.{table} -> {action}", "", "revert_encryption", server)
    except Exception as e:
        print("Error in revert_encryption:", e)
        _enc_log(server, db, schema, table, "", "error", str(e)[:300])
    return back()


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
            conn = _oracle_connect(user, password, ipAddress, port, service_name)
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

        elif dbVendor.lower() in ('clickhouse',):
            # ClickHouse HTTP interface (default port 8123); no driver needed.
            import requests
            host = str(ipAddress).split(':')[0]
            base_url = f"http://{host}:{int(port or 8123)}/"
            headers = {"X-ClickHouse-User": user or "default"}
            if password:
                headers["X-ClickHouse-Key"] = password
            resp = requests.post(base_url, data=b"SELECT version()", headers=headers, timeout=10)
            resp.raise_for_status()
            version = resp.text.strip()
            return JSONResponse({"success": True, "message": f"Connected: ClickHouse {version[:80]}"})

        elif dbVendor.lower() in ('mongodb', 'mongo'):
            # service_name carries authSource here: Mongo users are scoped to the database
            # they were created in (usually admin), and a wrong value fails as
            # "Authentication failed" and gets mistaken for a bad password.
            from processes.mongo_shim import connect_mongodb
            client = connect_mongodb(ipAddress, None, user, password, port,
                                     auth_source=service_name or None)
            try:
                try:
                    version = str(client.server_info().get("version", ""))
                except Exception:
                    # buildInfo can be denied to a narrowly-scoped monitoring user;
                    # a successful ping still proves the credentials work.
                    client.admin.command("ping")
                    version = ""
            finally:
                client.close()
            msg = f"Connected: MongoDB {version}".strip() if version else "Connected: MongoDB"
            return JSONResponse({"success": True, "message": msg[:100]})

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
    # Store the target-DB password encrypted (enc:v1:...). encrypt_secret is
    # idempotent (blank / already-encrypted values pass through), so this is
    # safe for both the upsert below and the server_data.json copy.
    password = encrypt_secret(password)

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
            "p_port": str(port) if port is not None else None,
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
    secret: str = Form(default=""),
    cs_mode: str = Form(default="logscale"),   # crowdstrike only: logscale | syslog
    cs_port: str = Form(default=""),           # crowdstrike syslog only
    wz_proto: str = Form(default="syslog"),    # wazuh only: syslog (tcp) | udp
    wz_port: str = Form(default="514"),        # wazuh only
    gen_format: str = Form(default=""),        # generic vendors: cef|leef|rfc5424|rfc3164|json
    gen_transport: str = Form(default=""),     # generic vendors: udp|tcp|tls|http
    gen_port: str = Form(default="514")        # generic vendors
):
    pg_home_connection_string = get_connection_string()
    pg_postgres_home_engine = create_engine(pg_home_connection_string )
    try:
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("""
            CALL siem_config.update_siem_config(
                :p_siem_vendor ,
                :p_siem_url  ,
                :p_siem_api_key
            )
        """), {
            "p_siem_vendor": select_vendor,
            "p_siem_url": url,
            "p_siem_api_key": secret
        })

    except Exception as e:
                        db_write_log(f"update_siem_config failed with error:{e}"   ,0,"submit_siem_configuration","" )

    if select_vendor == "crowdstrike":
        # The crowdstrike sender (siem.crowdstrike.crowdstrike_sender) reads its
        # config from config.siem (service_type='crowdstrike', service_name=mode)
        # plus config.global_params crowdstrike_* keys — keep those in sync here.
        mode = (cs_mode or "logscale").lower()
        port = int(cs_port) if str(cs_port).strip().isdigit() else None
        try:
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("DELETE FROM config.siem WHERE service_type = 'crowdstrike'"))
                conn.execute(text("""
                    INSERT INTO config.siem (service_type, service_name, service_ip, service_port)
                    VALUES ('crowdstrike', :mode, :ip, :port)
                """), {"mode": mode, "ip": url, "port": port})
                # global_params has no unique key on "key" -> manual upsert
                params = {"crowdstrike_logscale_url": url} if mode == "logscale" else {}
                if secret:
                    params["crowdstrike_ingest_token"] = secret
                for k, v in params.items():
                    updated = conn.execute(
                        text("UPDATE config.global_params SET value = :v WHERE key = :k"),
                        {"k": k, "v": v}).rowcount
                    if not updated:
                        conn.execute(
                            text("INSERT INTO config.global_params (key, value) VALUES (:k, :v)"),
                            {"k": k, "v": v})
        except Exception as e:
            db_write_log(f"crowdstrike siem config store failed with error:{e}", 0, "submit_siem_configuration", "")

    if select_vendor == "wazuh":
        # The wazuh sender (siem.wazuh.wazuh_sender) reads config.siem
        # (service_type='wazuh'); service_name carries the protocol.
        proto = "udp" if (wz_proto or "").lower() == "udp" else "syslog"
        port = int(wz_port) if str(wz_port).strip().isdigit() else 514
        try:
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("DELETE FROM config.siem WHERE service_type = 'wazuh'"))
                conn.execute(text("""
                    INSERT INTO config.siem (service_type, service_name, service_ip, service_port)
                    VALUES ('wazuh', :proto, :ip, :port)
                """), {"proto": proto, "ip": url, "port": port})
        except Exception as e:
            db_write_log(f"wazuh siem config store failed with error:{e}", 0, "submit_siem_configuration", "")

    if select_vendor in ("splunk", "qradar", "sentinel", "arcsight", "elastic", "sumo", "syslog"):
        # siem.generic.syslog_sender reads config.siem; service_name carries
        # "<format>:<transport>" (either half may be blank = vendor default).
        spec = f"{(gen_format or '').lower()}:{(gen_transport or '').lower()}"
        port = int(gen_port) if str(gen_port).strip().isdigit() else 514
        try:
            with pg_postgres_home_engine.begin() as conn:
                conn.execute(text("DELETE FROM config.siem WHERE service_type = :v"),
                             {"v": select_vendor})
                conn.execute(text("""
                    INSERT INTO config.siem (service_type, service_name, service_ip, service_port)
                    VALUES (:v, :spec, :ip, :port)
                """), {"v": select_vendor, "spec": spec, "ip": url, "port": port})
                # token (HTTPS ingest) -> config.global_params <vendor>_token
                if secret:
                    key = f"{select_vendor}_token"
                    updated = conn.execute(
                        text("UPDATE config.global_params SET value = :v WHERE key = :k"),
                        {"k": key, "v": secret}).rowcount
                    if not updated:
                        conn.execute(
                            text("INSERT INTO config.global_params (key, value) VALUES (:k, :v)"),
                            {"k": key, "v": secret})
        except Exception as e:
            db_write_log(f"{select_vendor} siem config store failed with error:{e}", 0, "submit_siem_configuration", "")
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
            pdf_file, html_file, csv_file = generator.generate()

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
# Server Fleet Dashboard
# ---------------------------------------------------------------------------

FLEET_SQL = """
    SELECT DISTINCT ON (s.server)
           s.server,
           s.db_vendor,
           s.servername      AS ip_address,
           s.port,
           s.db_version,
           s.is_active,
           s.service_name,
           s.server_id::text  AS server_id,
           COALESCE(a.alert_count, 0)                      AS alert_count,
           to_char(a.last_alert, 'YYYY-MM-DD HH24:MI')     AS last_alert
    FROM metrics.servers s
    LEFT JOIN (
        SELECT server,
               COUNT(*)        AS alert_count,
               MAX(entry_date) AS last_alert
        FROM alerts.mail_alert_log
        WHERE entry_date >= NOW() - make_interval(days => %s)
        GROUP BY server
    ) a ON a.server = s.server
    WHERE s.server IS NOT NULL
    ORDER BY s.server, s.is_active DESC
"""


@app.get("/fleet", response_class=HTMLResponse)
async def fleet_dashboard(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "fleet.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/api/fleet")
async def api_fleet(days: int = 7):
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(FLEET_SQL, [days])
        columns = [desc[0] for desc in cur.description]
        servers = [dict(zip(columns, row)) for row in cur.fetchall()]

        vendors = sorted({s["db_vendor"] for s in servers if s.get("db_vendor")})
        active = sum(1 for s in servers if s.get("is_active"))
        with_alerts = sum(1 for s in servers if (s.get("alert_count") or 0) > 0)
        total_alerts = sum((s.get("alert_count") or 0) for s in servers)

        return JSONResponse({
            "stats": {
                "total": len(servers),
                "active": active,
                "inactive": len(servers) - active,
                "vendors": len(vendors),
                "with_alerts": with_alerts,
                "alerts": total_alerts,
            },
            "vendors": vendors,
            "servers": servers,
        })
    except Exception as e:
        return JSONResponse({
            "error": str(e),
            "stats": {"total": 0, "active": 0, "inactive": 0,
                      "vendors": 0, "with_alerts": 0, "alerts": 0},
            "vendors": [],
            "servers": [],
        }, status_code=500)
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
        cur.execute("SELECT row_id, report_name, is_active, report_url, server_name FROM config.reports ORDER BY row_id")
        reports = [{"row_id": r[0], "report_name": r[1], "is_active": r[2], "report_url": r[3], "server_name": r[4]} for r in cur.fetchall()]

        # Scheduled reports with job info
        cur.execute("""
            SELECT r.row_id AS report_id, r.report_name, r.is_active, r.report_url,
                   j.occurance, j.occurs_at::text,
                   mg.recipients, r.server_name
            FROM config.reports r
            LEFT JOIN config.reports_jobs rj ON rj.report_id = r.row_id
            LEFT JOIN jobs.jobs j ON j.row_id = rj.job_id
            LEFT JOIN config.mail_groups mg ON mg.mail_config_id = 1 AND mg.is_active = true
            ORDER BY r.row_id
        """)
        columns = [desc[0] for desc in cur.description]
        schedules = [dict(zip(columns, row)) for row in cur.fetchall()]

        # Servers for the filter dropdown
        cur.execute("SELECT DISTINCT server FROM metrics.servers WHERE server IS NOT NULL ORDER BY server")
        servers = [r[0] for r in cur.fetchall()]

        return JSONResponse({"reports": reports, "schedules": schedules, "servers": servers})
    except Exception as e:
        return JSONResponse({"error": str(e), "reports": [], "schedules": [], "servers": []}, status_code=500)
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
    server_name: str = Form(None),
):
    """Create or update a report schedule."""
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = False
    cur = conn.cursor()
    try:
        active = is_active == "true"
        # Empty selection ("All servers") is stored as NULL = no server filter.
        server = (server_name or "").strip() or None

        # Create new report or use existing
        if report_id == "new" or not report_id:
            if not report_name:
                return JSONResponse({"message": "Report name is required"}, status_code=400)
            query = report_query or "JSON-based report - see report_url for template"
            cur.execute(
                "INSERT INTO config.reports (report_name, report_query, is_active, report_url, server_name) VALUES (%s, %s, %s, %s, %s) RETURNING row_id",
                (report_name, query, active, report_url, server)
            )
            rid = cur.fetchone()[0]
        else:
            rid = int(report_id)
            # Update existing report
            updates = ["is_active = %s", "server_name = %s"]
            params = [active, server]
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

        # Link job to a mail config — monitoring.v_job_scheduler INNER JOINs
        # config.mail_jobs, so without this row the schedule never runs.
        cur.execute("SELECT row_id FROM config.mail_jobs WHERE job_id = %s", (job_id,))
        if not cur.fetchone():
            cur.execute(
                "INSERT INTO config.mail_jobs (job_id, mail_id) SELECT %s, row_id FROM config.mail_config ORDER BY row_id LIMIT 1",
                (job_id,)
            )

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


def _utc_tstz_literal(dt):
    """Render a datetime as a UTC `timestamptz` SQL literal.

    Grafana's from/to (and the `now`-based defaults here) are UTC instants, and
    Grafana's own $__timeFrom()/$__timeTo() macros expand to a time-zone-aware
    value. We must reproduce that: several panels are authored as
    `col >= $__timeFrom() AT TIME ZONE current_setting('TimeZone')`, which only
    behaves correctly when the macro is a timestamptz. Emitting a bare naive
    literal instead made PostgreSQL treat the UTC instant as local wall-clock
    (and, for the AT-TIME-ZONE panels, convert the wrong way), shifting every
    window by the UTC offset (~3h on Asia/Jerusalem) — hiding the most recent
    rows and returning nothing for a narrow recent window. A naive input is
    assumed to be UTC (Grafana epochs are)."""
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return "TIMESTAMPTZ '" + dt.strftime("%Y-%m-%d %H:%M:%S") + "+00'"


def _substitute_grafana_time_macros(sql, time_from, time_to):
    """Replace $__timeFrom(), $__timeTo(), and $__timeFilter(col) with
    SQL-literal timestamps so the panel SQL is executable outside Grafana.
    The literals are UTC timestamptz values (see _utc_tstz_literal) so panels
    compare against the correct absolute instant regardless of the column's
    storage timezone."""
    from_lit = _utc_tstz_literal(time_from)
    to_lit   = _utc_tstz_literal(time_to)
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


def _run_panel_query(dashboard_uid, panel_id, params, from_param, to_param):
    """Resolve the panel's SQL, run it, and return (columns, rows, title).
    Raises ValueError for missing panels/dashboards; other exceptions
    propagate."""
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
    return columns, rows, title


def _panel_output_path(title, panel_id, ext):
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    output_dir = os.path.join(os.getcwd(), "reports")
    os.makedirs(output_dir, exist_ok=True)
    safe = re.sub(r'[^\w\-]+', '_', title or f"panel{panel_id}")[:80] or "panel"
    filename = f"{safe}_{timestamp}.{ext}"
    return os.path.join(output_dir, filename), filename


def _build_panel_pdf(dashboard_uid, panel_id, params, from_param, to_param):
    """Resolve the panel's SQL, run it, render a PDF, and return
    (pdf_path, pdf_filename, title). Raises ValueError for missing
    panels/dashboards; other exceptions propagate."""
    columns, rows, title = _run_panel_query(
        dashboard_uid, panel_id, params, from_param, to_param)

    pdf_path, pdf_filename = _panel_output_path(title, panel_id, "pdf")
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    export_to_pdf_once(
        columns, rows, pdf_path,
        now_str, now_str,
        logo_path=LOGO_PATH,
        _header=title or f"Panel {panel_id}",
    )
    return pdf_path, pdf_filename, title


def _build_panel_csv(dashboard_uid, panel_id, params, from_param, to_param):
    """Same as _build_panel_pdf but writes the panel resultset as CSV
    (utf-8-sig so Excel opens it with the right encoding)."""
    import csv as _csv
    columns, rows, title = _run_panel_query(
        dashboard_uid, panel_id, params, from_param, to_param)

    csv_path, csv_filename = _panel_output_path(title, panel_id, "csv")
    with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
        w = _csv.writer(f)
        w.writerow(columns)
        for row in rows:
            w.writerow(["" if v is None else v for v in row])
    return csv_path, csv_filename, title


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
        # smtp_password is stored encrypted (enc:v1:) by the secret-encryption
        # migration; decrypt before handing it to smtplib.login(), otherwise the
        # ciphertext is sent as the password and the server returns 535 BadCredentials.
        # decrypt_secret() passes legacy plaintext through unchanged.
        "smtp_password": decrypt_secret(row[3]),
        "tls":           row[4],
        "smtp_server":   row[5],
    }


def _send_pdf_email(pdf_path, pdf_filename, recipients, subject, body, mc):
    """Send `pdf_path` as an attachment to `recipients` (list[str]) using
    the SMTP details in `mc` (dict from _load_mail_config). Despite the
    name it also handles CSV attachments (mime chosen by extension)."""
    import smtplib
    from email.message import EmailMessage
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"]    = mc["mail_sender"]
    msg["To"]      = ", ".join(recipients)
    msg.set_content(body or subject)
    if pdf_filename.lower().endswith(".csv"):
        maintype, subtype = "text", "csv"
    else:
        maintype, subtype = "application", "pdf"
    with open(pdf_path, "rb") as f:
        msg.add_attachment(
            f.read(),
            maintype=maintype,
            subtype=subtype,
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
    # format=csv returns the panel resultset as CSV instead of a PDF.
    out_format    = (params.pop("format", "pdf") or "pdf").lower()
    if not dashboard_uid or not panel_id:
        raise HTTPException(status_code=400,
                            detail="dashboard and panel query params are required")
    try:
        if out_format == "csv":
            csv_path, csv_filename, _title = _build_panel_csv(
                dashboard_uid, panel_id, params, from_param, to_param,
            )
            return FileResponse(
                csv_path,
                media_type="text/csv",
                filename=csv_filename,
            )
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
        raise HTTPException(status_code=500, detail=f"{out_format.upper()} generation failed: {e}")


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

    # format=csv renders/sends the panel as CSV; kept as a hidden input so the
    # POST to /api/email-panel carries it through.
    fmt = "CSV" if (qp.get("format", "pdf") or "pdf").lower() == "csv" else "PDF"

    hidden_inputs = "\n".join(
        f'<input type="hidden" name="{_html.escape(k)}" value="{_html.escape(v)}">'
        for k, v in qp.items()
    )
    default_subject = f"DBDOME report: {title}"
    page = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Email {fmt} — {_html.escape(title)}</title>
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
  <h2>Send {fmt} by email</h2>
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
    out_format    = (params.pop("format", "pdf") or "pdf").lower()
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
        build = _build_panel_csv if out_format == "csv" else _build_panel_pdf
        pdf_path, pdf_filename, title = build(
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
# Resolve an open alert incident from the Grafana "Open Alerts" dashboard.
# GET renders a small form (resolved_by prefilled from the Grafana ${__user.login},
# a resolution-type choice, and a required description); POST flips the incident to
# resolved via alerts.resolve_incident_ui (migration 6610). The gate is Grafana
# authentication — the resolver name is the Grafana username, not a web.users email.
# ---------------------------------------------------------------------------
_RESOLUTION_TYPES = ["Fixed", "False Positive", "Mitigated", "Acknowledged", "Other"]


@app.get("/api/resolve-incident-form", response_class=HTMLResponse)
def resolve_incident_form(request: Request):
    import html as _html
    qp = dict(request.query_params)
    incident_id = (qp.get("incident_id", "") or "").strip()
    resolved_by = (qp.get("resolved_by", "") or "").strip()
    # Grafana leaves the variable literal if the user is unknown / not substituted.
    if resolved_by.startswith("${") or resolved_by == "":
        resolved_by = ""
    if not incident_id or not incident_id.isdigit():
        raise HTTPException(status_code=400, detail="a numeric incident_id query param is required")

    server = root_cause = risk = status = opened = ""
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            cur = conn.cursor()
            cur.execute("""SELECT server, root_cause_id, risk_level, status, opened_at::text
                           FROM alerts.alert_incidents WHERE incident_id = %s""", (int(incident_id),))
            row = cur.fetchone()
        finally:
            conn.close()
        if row:
            server, root_cause, risk, status, opened = [x if x is not None else "" for x in row]
    except Exception as e:
        db_write_log(f"resolve-form lookup failed: {e}", 0, "resolve_incident_form", "")

    if row and status != "open":
        return HTMLResponse(content=f"""<!doctype html><html><head><meta charset="utf-8">
<title>Already resolved</title><style>body{{font-family:Arial,sans-serif;background:#f4f6f8;margin:0;
display:flex;align-items:center;justify-content:center;min-height:100vh;}}.box{{background:#fff;padding:28px 32px;
border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);text-align:center;max-width:480px;}}</style></head>
<body><div class="box"><h2 style="color:#b26a00;">Incident {_html.escape(incident_id)} is not open</h2>
<div style="color:#555;">Current status: <b>{_html.escape(status or 'unknown')}</b></div>
<button onclick="window.close()" style="margin-top:18px;padding:8px 18px;border:none;border-radius:4px;
background:#1f4e79;color:#fff;cursor:pointer;">Close</button></div></body></html>""")

    ro = "readonly" if resolved_by else ""
    now_str = datetime.now().strftime("%Y-%m-%dT%H:%M")
    options = "".join(f'<option value="{_html.escape(t)}">{_html.escape(t)}</option>' for t in _RESOLUTION_TYPES)
    page = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Resolve alert #{_html.escape(incident_id)}</title>
<style>
 body {{ font-family: Arial, sans-serif; background:#f4f6f8; margin:0;
        display:flex; align-items:center; justify-content:center; min-height:100vh; }}
 .dialog {{ background:#fff; border-radius:8px; padding:24px 28px; width:480px;
           box-shadow:0 6px 24px rgba(0,0,0,0.12); }}
 h2 {{ margin:0 0 8px; color:#1f4e79; font-size:18px; }}
 .meta {{ font-size:13px; color:#555; margin-bottom:8px; }}
 .meta b {{ color:#333; }}
 label {{ display:block; margin:12px 0 4px; font-size:13px; color:#333; }}
 input[type=text], input[type=datetime-local], textarea, select {{
     width:100%; padding:8px 10px; border:1px solid #ccc; border-radius:4px;
     font-size:14px; box-sizing:border-box; font-family:inherit; }}
 input[readonly] {{ background:#f0f0f0; color:#555; }}
 textarea {{ min-height:72px; resize:vertical; }}
 .hint {{ font-size:11px; color:#888; margin-top:4px; }}
 .actions {{ margin-top:20px; display:flex; gap:8px; justify-content:flex-end; }}
 button {{ padding:8px 16px; border:none; border-radius:4px; font-size:14px; cursor:pointer; }}
 .send {{ background:#2e7d32; color:#fff; }} .send:hover {{ background:#256428; }}
 .cancel {{ background:#e0e0e0; color:#333; }}
</style></head>
<body>
<div class="dialog">
  <h2>Resolve alert #{_html.escape(incident_id)}</h2>
  <div class="meta">Server: <b>{_html.escape(server)}</b> &nbsp;|&nbsp; Risk: <b>{_html.escape(risk)}</b></div>
  <div class="meta">Root cause: <b>{_html.escape(root_cause)}</b> &nbsp;|&nbsp; Opened: {_html.escape(opened)}</div>
  <form method="post" action="/api/resolve-incident">
    <input type="hidden" name="incident_id" value="{_html.escape(incident_id)}">

    <label for="resolved_by">Resolved by</label>
    <input id="resolved_by" name="resolved_by" type="text" required {ro}
           value="{_html.escape(resolved_by)}" placeholder="your name">
    <div class="hint">Grafana username (auto-filled from your login).</div>

    <label for="resolution_type">Resolution type</label>
    <select id="resolution_type" name="resolution_type">{options}</select>

    <label for="resolved_at">Resolved at</label>
    <input id="resolved_at" name="resolved_at" type="datetime-local" value="{now_str}">
    <div class="hint">When the alert was resolved (defaults to now; you can change it).</div>

    <label for="resolution_description">Description</label>
    <textarea id="resolution_description" name="resolution_description" required
              placeholder="What was done / why this is resolved…"></textarea>

    <div class="actions">
      <button type="button" class="cancel" onclick="window.close()">Cancel</button>
      <button type="submit" class="send">Resolve</button>
    </div>
  </form>
</div>
</body></html>"""
    return HTMLResponse(content=page)


@app.post("/api/resolve-incident", response_class=HTMLResponse)
async def resolve_incident_submit(request: Request):
    import html as _html
    form = await request.form()
    incident_id = (form.get("incident_id", "") or "").strip()
    resolved_by = (form.get("resolved_by", "") or "").strip()
    rtype       = (form.get("resolution_type", "") or "").strip()
    descr       = (form.get("resolution_description", "") or "").strip()
    # datetime-local -> 'YYYY-MM-DDTHH:MM'; hand it to PG as a timestamp literal.
    # Empty means "use now" (the function COALESCEs a NULL to LOCALTIMESTAMP).
    resolved_at = (form.get("resolved_at", "") or "").strip().replace("T", " ") or None

    if not incident_id or not incident_id.isdigit():
        raise HTTPException(status_code=400, detail="a numeric incident_id is required")
    if not resolved_by:
        raise HTTPException(status_code=400, detail="resolved_by is required")
    if not descr:
        raise HTTPException(status_code=400, detail="a resolution description is required")

    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        try:
            cur = conn.cursor()
            cur.execute("SELECT (alerts.resolve_incident_ui(%s, %s, %s, %s, %s::timestamp)).incident_id",
                        (int(incident_id), resolved_by, rtype, descr, resolved_at))
            rid = cur.fetchone()[0]
        finally:
            conn.close()
        db_write_log(f"incident {rid} resolved by {resolved_by} ({rtype})",
                     0, "resolve_incident_submit", "")
        return HTMLResponse(content=f"""<!doctype html><html><head><meta charset="utf-8">
<title>Resolved</title><style>body{{font-family:Arial,sans-serif;background:#f4f6f8;margin:0;
display:flex;align-items:center;justify-content:center;min-height:100vh;}}.box{{background:#fff;padding:28px 32px;
border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);text-align:center;max-width:480px;}}
h2{{color:#2e7d32;margin:0 0 12px;}}button{{margin-top:18px;padding:8px 18px;border:none;border-radius:4px;
background:#1f4e79;color:#fff;cursor:pointer;}}</style></head><body><div class="box">
<h2>✅ Alert #{_html.escape(incident_id)} resolved</h2>
<div style="font-size:13px;color:#555;">By <b>{_html.escape(resolved_by)}</b> — {_html.escape(rtype or 'manual')}</div>
<button onclick="window.close()">Close</button></div></body></html>""")
    except HTTPException:
        raise
    except Exception as e:
        msg = str(e).splitlines()[0]
        db_write_log(f"resolve-incident failed: {msg}", 0, "resolve_incident_submit", "")
        return HTMLResponse(status_code=400, content=f"""<!doctype html><html><head><meta charset="utf-8">
<title>Could not resolve</title><style>body{{font-family:Arial,sans-serif;background:#f4f6f8;margin:0;
display:flex;align-items:center;justify-content:center;min-height:100vh;}}.box{{background:#fff;padding:28px 32px;
border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);text-align:center;max-width:520px;}}
h2{{color:#c62828;margin:0 0 12px;}}button{{margin-top:18px;padding:8px 18px;border:none;border-radius:4px;
background:#1f4e79;color:#fff;cursor:pointer;}}</style></head><body><div class="box">
<h2>Could not resolve alert #{_html.escape(incident_id)}</h2>
<div style="font-size:13px;color:#555;word-break:break-word;">{_html.escape(msg)}</div>
<button onclick="history.back()">Back</button></div></body></html>""")


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


# ── Alert incident lifecycle API ─────────────────────────────────────────────
# open -> resolved (manual, by a customer user, with a description) or auto after
# a configurable timeout. Backed by alerts.alert_incidents + the SQL functions in
# migration 6550. See processes/alert_auto_resolve.py for the timer.

@app.get("/api/alerts/incidents")
async def api_alert_incidents(status: str = None, risk_level: str = None,
                              server: str = None, limit: int = 500):
    """List alert incidents. Filter by status (open|resolved), risk_level, server."""
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        where, params = ["1=1"], []
        if status:
            where.append("status = %s"); params.append(status)
        if risk_level:
            where.append("lower(risk_level) = lower(%s)"); params.append(risk_level)
        if server:
            where.append("server = %s"); params.append(server)
        params.append(int(limit))
        cur.execute(f"""
            SELECT incident_id, server, root_cause_id, risk_level, status, issue_name,
                   area_name, domain_name, opened_at::text, last_seen_at::text, occurrences,
                   resolved_at::text, resolved_by, resolution_type, resolution_description,
                   auto_resolve_at::text, round(age_hours::numeric, 1)::float8 AS age_hours
            FROM alerts.v_alert_incidents
            WHERE {' AND '.join(where)}
            ORDER BY (status='open') DESC,
                     CASE lower(risk_level) WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                          WHEN 'medium' THEN 3 ELSE 4 END,
                     last_seen_at DESC
            LIMIT %s""", params)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        cur.execute("""SELECT status, COUNT(*) FROM alerts.alert_incidents GROUP BY 1""")
        counts = {k: v for k, v in cur.fetchall()}
        return JSONResponse({"incidents": rows,
                             "open": counts.get("open", 0),
                             "resolved": counts.get("resolved", 0)})
    except Exception as e:
        db_write_log(f"api_alert_incidents failed: {e}", 0, "api_alert_incidents", "")
        return JSONResponse({"error": str(e), "incidents": []}, status_code=500)
    finally:
        cur.close(); conn.close()


def _alert_time_bound(col, val, op):
    """Build a (sql, param) time-bound clause for the alert read endpoints.
    Accepts `val` as Grafana-style epoch milliseconds (e.g. 1784020822440) or an
    ISO / 'YYYY-MM-DD HH:MM[:SS]' string. Epoch is converted to the repository's
    local wall-clock the same way the dashboards do
    (to_timestamp(ms/1000) AT TIME ZONE current_setting('TimeZone')), because the
    alert timestamp columns store local naive time. Returns (None, None) when unset."""
    if val is None or str(val).strip() == "":
        return (None, None)
    s = str(val).strip()
    if s.lstrip("-").isdigit():
        return (f"{col} {op} to_timestamp(%s/1000.0) AT TIME ZONE current_setting('TimeZone')",
                int(s))
    return (f"{col} {op} %s::timestamp", s.replace("T", " "))


def _json_safe(v):
    """Make a raw DB value JSON-serialisable for JSONResponse (used by SELECT *
    endpoints where columns aren't cast to text in SQL)."""
    import datetime, decimal
    if isinstance(v, (datetime.datetime, datetime.date, datetime.time)):
        return v.isoformat(sep=" ")
    if isinstance(v, decimal.Decimal):
        return float(v)
    return v


def _entry_clause(col, p, default_days=None):
    """Build a time-window WHERE fragment on `col` from the request's from/to query
    params (epoch-ms or ISO local; see _alert_time_bound). Returns (clauses_list,
    params_list). When neither bound is given and default_days is set, falls back to
    'col > now() - interval N days' (the equivalent of a Grafana $__timeFilter default)."""
    fc, fp = _alert_time_bound(col, p.get("from"), ">=")
    tc, tp = _alert_time_bound(col, p.get("to"), "<=")
    cl, pr = [], []
    if fc: cl.append(fc); pr.append(fp)
    if tc: cl.append(tc); pr.append(tp)
    if not cl and default_days:
        cl.append(f"{col} > now() - interval '{int(default_days)} days'")
    return cl, pr


def _api_query(sql, params, key):
    """Run a read query and return {key: [rows...], count: N} as JSON, with every
    value passed through _json_safe. Errors are logged and returned as a 500."""
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(sql, params)
        cols = [d[0] for d in cur.description]
        rows = [{k: _json_safe(v) for k, v in zip(cols, r)} for r in cur.fetchall()]
        return JSONResponse({key: rows, "count": len(rows)})
    except Exception as e:
        db_write_log(f"api_query failed: {e}", 0, "api_query", "")
        return JSONResponse({"error": str(e), key: []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/alerts/summary")
async def api_alerts_summary(request: Request):
    """Open Alerts dashboard header counts as JSON (panels 456/101/102/105/104/103).
    Query params: from, to (Grafana epoch-ms or ISO local; both optional).
    Returns open total + per-severity open counts (SEC-* root causes) and the
    number of monitored servers."""
    p = request.query_params
    fc, fp = _alert_time_bound("updated_at", p.get("from"), ">=")
    tc, tp = _alert_time_bound("updated_at", p.get("to"), "<=")
    where, params = ["root_cause_id LIKE 'SEC-%%'"], []
    if fc: where.append(fc); params.append(fp)
    if tc: where.append(tc); params.append(tp)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(f"""
            SELECT count(*)                                                   AS total,
                   count(*) FILTER (WHERE status='open')                      AS open,
                   count(*) FILTER (WHERE status='open' AND lower(risk_level)='critical') AS critical,
                   count(*) FILTER (WHERE status='open' AND lower(risk_level)='high')     AS high,
                   count(*) FILTER (WHERE status='open' AND lower(risk_level)='medium')   AS medium,
                   count(*) FILTER (WHERE status='open' AND lower(risk_level)='low')      AS low
            FROM alerts.alert_incidents
            WHERE {' AND '.join(where)}""", params)
        cols = [d[0] for d in cur.description]
        summary = dict(zip(cols, cur.fetchone()))
        cur.execute("SELECT count(DISTINCT server_id) FROM monitoring.general_metric_metadata_results")
        summary["servers"] = cur.fetchone()[0]
        return JSONResponse({"summary": summary})
    except Exception as e:
        db_write_log(f"api_alerts_summary failed: {e}", 0, "api_alerts_summary", "")
        return JSONResponse({"error": str(e), "summary": {}}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/alerts/open")
async def api_alerts_open(request: Request):
    """The Open Alerts feed (dashboard panel 120) as JSON — one row per
    server+root_cause (latest), joined to server name and root-cause metadata,
    with mail-sent and blocked timestamps.
    Query params (all optional): from, to (Grafana epoch-ms or ISO local),
    risk_level (critical|high|medium|low), server, root_cause_id, status
    (open|resolved), limit (default 500)."""
    p = request.query_params
    fc, fp = _alert_time_bound("occured_at", p.get("from"), ">=")
    tc, tp = _alert_time_bound("occured_at", p.get("to"), "<=")
    outer, params = ["seq = 1", "root_cause_id LIKE 'SEC%%'"], []
    rl = (p.get("risk_level") or "").strip()
    if rl and rl.lower() != "all":
        outer.append("lower(risk_level) = lower(%s)"); params.append(rl)
    if (p.get("server") or "").strip():
        outer.append("server = %s"); params.append(p.get("server").strip())
    if (p.get("root_cause_id") or "").strip():
        outer.append("root_cause_id = %s"); params.append(p.get("root_cause_id").strip())
    if (p.get("status") or "").strip():
        outer.append("status = %s"); params.append(p.get("status").strip())
    if fc: outer.append(fc); params.append(fp)
    if tc: outer.append(tc); params.append(tp)
    try:
        limit = max(1, min(int(p.get("limit", 500)), 5000))
    except (TypeError, ValueError):
        limit = 500
    params.append(limit)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(f"""
            SELECT row_id, incident_id, server, servername, risk_level, status,
                   area, issue, root_cause_id, root_cause_name, recipients,
                   occured_at::text, sent_at::text, blocked_at::text
            FROM (
              SELECT ROW_NUMBER() OVER (PARTITION BY l.server, l.root_cause_id
                                        ORDER BY l.updated_at DESC) AS seq,
                     l.alert_id AS row_id, l.incident_id, l.server, s.servername,
                     l.risk_level, l.status,
                     COALESCE(rc.area_name,'')  AS area,
                     COALESCE(rc.issue_name,'') AS issue,
                     l.root_cause_id, rc.root_cause_name, mal.recipients,
                     l.updated_at AS occured_at, mal.entry_date AS sent_at,
                     blc.entry_date AS blocked_at
              FROM alerts.alert_incidents l
              JOIN (SELECT server_id, servername, server, db_vendor
                      FROM metrics.servers WHERE is_active IS TRUE) s ON s.server = l.server
              LEFT JOIN alerts.mail_alert_log mal
                     ON mal.server = l.server AND mal.metric_name = l.root_cause_id
                    AND mal.entry_date = l.updated_at
              LEFT JOIN alerts.blocks blc
                     ON blc.server = l.server AND blc.metric_name = l.root_cause_id
                    AND blc.entry_date = l.updated_at
              JOIN rootcause.v_rootcauses rc
                     ON rc.root_cause_id = l.root_cause_id
                    AND (rc.vendor_name = s.db_vendor OR rc.vendor_name = 'sqlserver')
            ) q
            WHERE {' AND '.join(outer)}
            ORDER BY occured_at DESC
            LIMIT %s""", params)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"alerts": rows, "count": len(rows)})
    except Exception as e:
        db_write_log(f"api_alerts_open failed: {e}", 0, "api_alerts_open", "")
        return JSONResponse({"error": str(e), "alerts": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/alerts/log/{alert_id}")
async def api_alert_log_detail(alert_id: str, request: Request):
    """Active Detection Findings for one alert (dashboard panel 455) as JSON —
    i.e. SELECT * FROM monitoring.get_alert_log_resultset_byid(alert_id), with an
    optional entry_date window. Each finding's `result` json is expanded to a
    dict (matching the dashboard's field extraction).
    Path: alert_id (the alert_log row/alert_id). Query params: from, to
    (Grafana epoch-ms or ISO local; both optional)."""
    try:
        rid = int(str(alert_id).strip())
    except (TypeError, ValueError):
        return JSONResponse({"detail": "alert_id must be an integer", "findings": []},
                            status_code=400)
    p = request.query_params
    fc, fp = _alert_time_bound("entry_date", p.get("from"), ">=")
    tc, tp = _alert_time_bound("entry_date", p.get("to"), "<=")
    where, params = ["TRUE"], [rid]
    if fc: where.append(fc); params.append(fp)
    if tc: where.append(tc); params.append(tp)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(f"""
            SELECT result, entry_date::text
            FROM monitoring.get_alert_log_resultset_byid(%s)
            WHERE {' AND '.join(where)}
            ORDER BY entry_date DESC""", params)
        findings = [{"result": res, "entry_date": ed} for res, ed in cur.fetchall()]
        return JSONResponse({"alert_id": rid, "findings": findings, "count": len(findings)})
    except Exception as e:
        db_write_log(f"api_alert_log_detail failed: {e}", 0, "api_alert_log_detail", "")
        return JSONResponse({"error": str(e), "findings": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/alerts/ransomware")
async def api_alerts_ransomware(request: Request):
    """Ransomware Guard feed (dashboard 'ransomware-guard' panel 20) as JSON:
    SEC-SQL-AUD-031-* alerts with server, risk, login, session id, the root-cause
    description and a truncated sql_text.
    Query params (all optional): from, to (Grafana epoch-ms or ISO local; when
    neither is given, defaults to the last 30 days), server, risk_level,
    root_cause_id (defaults to the SEC-SQL-AUD-031-% family), limit (default 500)."""
    p = request.query_params
    fc, fp = _alert_time_bound("al.entry_date", p.get("from"), ">=")
    tc, tp = _alert_time_bound("al.entry_date", p.get("to"), "<=")
    where, params = [], []
    rcid = (p.get("root_cause_id") or "").strip()
    if rcid:
        where.append("al.root_cause_id = %s"); params.append(rcid)
    else:
        where.append("al.root_cause_id LIKE 'SEC-SQL-AUD-031-%%'")
    if fc or tc:
        if fc: where.append(fc); params.append(fp)
        if tc: where.append(tc); params.append(tp)
    else:
        where.append("al.entry_date > now() - interval '30 days'")
    if (p.get("server") or "").strip():
        where.append("al.server = %s"); params.append(p.get("server").strip())
    if (p.get("risk_level") or "").strip():
        where.append("lower(al.risk_level) = lower(%s)"); params.append(p.get("risk_level").strip())
    try:
        limit = max(1, min(int(p.get("limit", 500)), 5000))
    except (TypeError, ValueError):
        limit = 500
    params.append(limit)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(f"""
            SELECT al.entry_date::text AS "time", al.server, al.root_cause_id, al.risk_level,
                   al.login_name,
                   al.metadata->0->>'session_id' AS session_id,
                   rc.description AS description,
                   left(al.metadata->0->>'sql_text', 200) AS sql_text,
                   al.metric_result_row_id
            FROM alerts.alert_log al
            LEFT JOIN rootcause.root_causes rc ON rc.root_cause_id = al.root_cause_id
            WHERE {' AND '.join(where)}
            ORDER BY al.entry_date DESC
            LIMIT %s""", params)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"alerts": rows, "count": len(rows)})
    except Exception as e:
        db_write_log(f"api_alerts_ransomware failed: {e}", 0, "api_alerts_ransomware", "")
        return JSONResponse({"error": str(e), "alerts": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/policy-enforcement-and-protection")
async def api_policy_enforcement(request: Request):
    """Policy Enforcement & Protection catalog as JSON: distinct SEC-domain root
    causes (id, name, description) from rootcause.v_rootcauses.
    Query params: root_cause_id (optional exact match), vendor_name (default sqlserver).
    Note: this returns only the customer-facing name/description of each detection,
    not the underlying detection logic."""
    p = request.query_params
    rcid = (p.get("root_cause_id") or "").strip()
    vendor = (p.get("vendor_name") or "sqlserver").strip()
    where, params = ["domain_code = 'SEC'", "vendor_name = %s"], [vendor]
    if rcid:
        where.append("root_cause_id = %s"); params.append(rcid)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(f"""
            SELECT DISTINCT root_cause_id, root_cause_name, root_cause_desc
            FROM rootcause.v_rootcauses
            WHERE {' AND '.join(where)}
            ORDER BY root_cause_id""", params)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"root_causes": rows, "count": len(rows)})
    except Exception as e:
        db_write_log(f"api_policy_enforcement failed: {e}", 0, "api_policy_enforcement", "")
        return JSONResponse({"error": str(e), "root_causes": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/data-protection/unmasked")
async def api_data_protection_unmasked(request: Request):
    """Data Protection - Unmasked sensitive data as JSON: the contents of
    monitoring.v_SEC_SQL_PRI_001_RC10 (SEC-SQL-PRI-001-RC10 detection view).
    Query params: server (optional exact match, applied only if the view exposes a
    'server' column), limit (default 500)."""
    p = request.query_params
    try:
        limit = max(1, min(int(p.get("limit", 500)), 5000))
    except (TypeError, ValueError):
        limit = 500
    server = (p.get("server") or "").strip()
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        where, params = [], []
        if server:
            cur.execute("""SELECT 1 FROM information_schema.columns
                           WHERE table_schema='monitoring'
                             AND table_name='v_sec_sql_pri_001_rc10'
                             AND column_name='server' LIMIT 1""")
            if cur.fetchone():
                where.append("server = %s"); params.append(server)
        params.append(limit)
        clause = ("WHERE " + " AND ".join(where)) if where else ""
        cur.execute(f"SELECT * FROM monitoring.v_SEC_SQL_PRI_001_RC10 {clause} LIMIT %s", params)
        cols = [d[0] for d in cur.description]
        rows = [{k: _json_safe(v) for k, v in zip(cols, r)} for r in cur.fetchall()]
        return JSONResponse({"unmasked": rows, "count": len(rows)})
    except Exception as e:
        db_write_log(f"api_data_protection_unmasked failed: {e}", 0, "api_data_protection_unmasked", "")
        return JSONResponse({"error": str(e), "unmasked": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/database-restore")
async def api_database_restore(request: Request):
    """Database restore catalog as JSON: SEC-domain root causes in the AZ/CFG/ENC/VS
    areas (area, issue, id, name, description) from rootcause.v_rootcauses.
    Query params: area_code (optional CSV; default 'AZ,CFG,ENC,VS'),
    root_cause_id (optional exact match)."""
    p = request.query_params
    areas = p.get("area_code") or "AZ,CFG,ENC,VS"
    area_list = [a.strip() for a in areas.split(",") if a.strip()]
    where, params = ["domain_code = 'SEC'", "area_code = ANY(%s)"], [area_list]
    rcid = (p.get("root_cause_id") or "").strip()
    if rcid:
        where.append("root_cause_id = %s"); params.append(rcid)
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute(f"""
            SELECT DISTINCT area_name, issue_name, root_cause_id, root_cause_name, root_cause_desc
            FROM rootcause.v_rootcauses
            WHERE {' AND '.join(where)}
            ORDER BY area_name, root_cause_id""", params)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"root_causes": rows, "count": len(rows)})
    except Exception as e:
        db_write_log(f"api_database_restore failed: {e}", 0, "api_database_restore", "")
        return JSONResponse({"error": str(e), "root_causes": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# =============================================================================
# IPS Report (dashboard 'ips-fortianalyzer') — one endpoint per panel.
# All accept optional from/to (epoch-ms or ISO local); aggregations default to
# the last 7 days when no window is given.
# =============================================================================
@app.get("/api/ips/summary")
async def api_ips_summary(request: Request):
    """IPS header stats: total / critical / high / medium intrusion events,
    blocked (FortiAnalyzer IPS), and monitored (mailed) — panels 1-6."""
    p = request.query_params
    cl, pr = _entry_clause("entry_date", p, default_days=7)
    win = " AND ".join(cl) if cl else "TRUE"
    mcl, mpr = _entry_clause("entry_date", p, default_days=7)
    mwin = " AND ".join(mcl) if mcl else "TRUE"
    conn = psycopg2.connect(get_connection_string()); cur = conn.cursor()
    try:
        cur.execute(f"""SELECT count(*) AS total,
                          count(*) FILTER (WHERE risk_level='critical') AS critical,
                          count(*) FILTER (WHERE risk_level='high')     AS high,
                          count(*) FILTER (WHERE risk_level='medium')   AS medium
                       FROM alerts.alert_log WHERE {win}""", pr)
        s = dict(zip([d[0] for d in cur.description], cur.fetchone()))
        cur.execute("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events WHERE action='blocked'")
        s["blocked"] = cur.fetchone()[0]
        cur.execute(f"SELECT count(*) FROM alerts.mail_alert_log WHERE recipients IS NOT NULL AND {mwin}", mpr)
        s["monitored"] = cur.fetchone()[0]
        return JSONResponse({"summary": {k: _json_safe(v) for k, v in s.items()}})
    except Exception as e:
        db_write_log(f"api_ips_summary failed: {e}", 0, "api_ips_summary", "")
        return JSONResponse({"error": str(e), "summary": {}}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/ips/by-severity")
async def api_ips_by_severity(request: Request):
    """Intrusions by severity (panel 7)."""
    cl, pr = _entry_clause("entry_date", request.query_params)
    where = ("WHERE " + " AND ".join(cl)) if cl else ""
    return _api_query(f"""SELECT risk_level AS severity, count(*) AS count
                          FROM alerts.alert_log {where}
                          GROUP BY risk_level
                          ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                                        WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END""", pr, "by_severity")


@app.get("/api/ips/by-type")
async def api_ips_by_type(request: Request):
    """Intrusions by type (panel 8)."""
    cl, pr = _entry_clause("al.entry_date", request.query_params, default_days=7)
    where = "WHERE " + " AND ".join(cl)
    return _api_query(f"""SELECT rc.issue_name AS type, count(*) AS count
                          FROM alerts.alert_log al
                          JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = al.root_cause_id
                          {where}
                          GROUP BY al.root_cause_id, issue_name
                          ORDER BY count(*) DESC LIMIT 20""", pr, "by_type")


@app.get("/api/ips/timeline")
async def api_ips_timeline(request: Request):
    """Intrusion events timeline, hourly buckets by severity (panel 9)."""
    cl, pr = _entry_clause("entry_date", request.query_params, default_days=7)
    where = "WHERE " + " AND ".join(cl)
    return _api_query(f"""SELECT date_trunc('hour', entry_date)::timestamp AS time,
                                 count(*) AS count, risk_level AS severity
                          FROM alerts.alert_log {where}
                          GROUP BY risk_level, date_trunc('hour', entry_date)
                          ORDER BY time""", pr, "timeline")


@app.get("/api/ips/monitored")
async def api_ips_monitored(request: Request):
    """Monitored intrusions by attack/type (panel 11)."""
    cl, pr = _entry_clause("al.entry_date", request.query_params, default_days=7)
    where = "WHERE " + " AND ".join(cl)
    return _api_query(f"""SELECT root_cause_name AS attack, issue_name AS type, count(*) AS count
                          FROM alerts.alert_log al
                          JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = al.root_cause_id
                          {where}
                          GROUP BY root_cause_name, issue_name""", pr, "monitored")


@app.get("/api/ips/blocked")
async def api_ips_blocked(request: Request):
    """Blocked intrusions by attack/type/severity (panel 10)."""
    cl, pr = _entry_clause("ma.entry_date", request.query_params, default_days=7)
    where = "WHERE " + " AND ".join(cl)
    return _api_query(f"""SELECT root_cause_name AS attack, issue_name AS type,
                                 risk_level AS severity, count(*) AS count
                          FROM alerts.mail_alert_log ma
                          JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = ma.metric_name
                          {where}
                          GROUP BY root_cause_name, issue_name, risk_level
                          ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                                        WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT 20""", pr, "blocked")


@app.get("/api/ips/top-victims")
async def api_ips_top_victims(request: Request):
    """Top victims (servers) by attack/type (panel 13)."""
    cl, pr = _entry_clause("al.entry_date", request.query_params)
    where = ("WHERE " + " AND ".join(cl)) if cl else ""
    return _api_query(f"""SELECT server, root_cause_name AS attack, issue_name AS type, count(*) AS count
                          FROM alerts.mail_alert_log al
                          JOIN rootcause.v_rootcauses rc ON rc.root_cause_id = al.metric_name
                          {where}
                          GROUP BY root_cause_name, issue_name, server
                          ORDER BY count(*) DESC""", pr, "top_victims")


@app.get("/api/ips/top-sources")
async def api_ips_top_sources(request: Request):
    """Top attack sources as % of total, with the matched metric metadata (panel 12)."""
    p = request.query_params
    cl, pr = _entry_clause("al.entry_date", p, default_days=7)
    win = " AND ".join(cl)
    scl, spr = _entry_clause("al1.entry_date", p, default_days=7)
    swin = " AND ".join(scl)
    sql = f"""SELECT count(*) * 100.0 / NULLIF((SELECT count(*) FROM alerts.alert_log al1 WHERE {swin}), 0)
                     AS pct_of_total,
                     gmmr.metric_metadata::text AS metric_metadata, al.risk_level
              FROM alerts.alert_log al
              JOIN monitoring.general_metric_metadata_results gmmr
                ON gmmr.server = al.server AND al.root_cause_id = gmmr.metric_name
               AND al.entry_date BETWEEN gmmr.entry_date - interval '1 second'
                                     AND gmmr.entry_date + interval '1 second'
              WHERE {win}
              GROUP BY al.risk_level, metric_metadata
              ORDER BY pct_of_total DESC"""
    return _api_query(sql, spr + pr, "top_sources")


# =============================================================================
# Retention (dashboard 'adretn001') — read views.
# =============================================================================
@app.get("/api/retention/overview")
async def api_retention_overview():
    """Retention overview per category/item with size, row count and configured
    dump retention months (panel 2)."""
    return _api_query("""SELECT ro.category, ro.item, rc.root_cause_name, ro.data_size, ro.data_bytes,
                                ro.row_count, ro.space_free, dm.retention_months
                         FROM metrics.retention_overview() ro
                         LEFT JOIN (SELECT DISTINCT root_cause_id, root_cause_name
                                    FROM rootcause.v_rootcauses) rc ON rc.root_cause_id = ro.item
                         LEFT JOIN config.dump_metrics dm ON dm.metric_name = ro.item
                         ORDER BY ro.category, ro.item""", [], "retention")


@app.get("/api/retention/dump-metrics")
async def api_retention_dump_metrics():
    """Configured per-metric dump retention (config.dump_metrics, panel 5)."""
    return _api_query("""SELECT row_id, metric_name, retention_months, entry_date
                         FROM config.dump_metrics ORDER BY metric_name""", [], "dump_metrics")


@app.get("/api/retention/dumps")
async def api_retention_dumps():
    """Archived dumps catalog (config.dumps, panel 8)."""
    return _api_query("""SELECT row_id, metric_name, month, year, row_count, dump_location, entry_date
                         FROM config.dumps ORDER BY year DESC, month DESC, metric_name""", [], "dumps")


@app.get("/api/retention/dump-location")
async def api_retention_dump_location():
    """Current dump/archive location (panel 4)."""
    return _api_query("SELECT config.get_dump_location() AS dump_location", [], "dump_location")


# =============================================================================
# Blocker Activity (dashboard 'adblkact').
# =============================================================================
@app.get("/api/blocker/summary")
async def api_blocker_summary(request: Request):
    """Blocker action counts (killed/dry-run/skipped/errors) + current dry-run mode
    (panels 3-7)."""
    cl, pr = _entry_clause("entry_date", request.query_params, default_days=7)
    win = " AND ".join(cl) if cl else "TRUE"
    conn = psycopg2.connect(get_connection_string()); cur = conn.cursor()
    try:
        cur.execute(f"""SELECT count(*) FILTER (WHERE action='killed')  AS killed,
                               count(*) FILTER (WHERE action='dry-run') AS dry_run,
                               count(*) FILTER (WHERE action='skipped') AS skipped,
                               count(*) FILTER (WHERE action='error')   AS errors
                        FROM alerts.blocker_log WHERE {win}""", pr)
        s = dict(zip([d[0] for d in cur.description], cur.fetchone()))
        cur.execute("""SELECT value FROM config.global_params WHERE key='blocker_dry_run'
                       ORDER BY row_id DESC LIMIT 1""")
        row = cur.fetchone()
        s["dry_run_mode"] = row[0] if row else None
        return JSONResponse({"summary": {k: _json_safe(v) for k, v in s.items()}})
    except Exception as e:
        db_write_log(f"api_blocker_summary failed: {e}", 0, "api_blocker_summary", "")
        return JSONResponse({"error": str(e), "summary": {}}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.get("/api/blocker/log")
async def api_blocker_log(request: Request):
    """Blocker activity log (alerts.blocker_log, panel 10)."""
    p = request.query_params
    cl, pr = _entry_clause("entry_date", p, default_days=7)
    where = "WHERE " + " AND ".join(cl)
    try:
        limit = max(1, min(int(p.get("limit", 500)), 5000))
    except (TypeError, ValueError):
        limit = 500
    return _api_query(f"""SELECT entry_date, server, db_vendor, root_cause_id, session_id, action, detail
                          FROM alerts.blocker_log {where}
                          ORDER BY entry_date DESC LIMIT %s""", pr + [limit], "blocker_log")


@app.get("/api/blocker/blocks")
async def api_blocker_blocks(request: Request):
    """Executed blocks (alerts.blocks, panel 11)."""
    p = request.query_params
    try:
        limit = max(1, min(int(p.get("limit", 200)), 5000))
    except (TypeError, ValueError):
        limit = 200
    return _api_query("""SELECT entry_date, server, metric_name, subject, body
                         FROM alerts.blocks ORDER BY entry_date DESC LIMIT %s""", [limit], "blocks")


# =============================================================================
# Same login active from multiple hosts (dashboard 'adlvvwg').
# =============================================================================
@app.get("/api/same-login-multihost/findings")
async def api_same_login_findings(request: Request):
    """Detailed findings for the same-login-from-multiple-hosts detection
    (monitoring.v_sec_sql_acc_010_rc10, panel 12)."""
    cl, pr = _entry_clause("entry_date", request.query_params, default_days=7)
    where = "WHERE " + " AND ".join(cl) + " AND login_name <> 'dbdome_mon_usr'"
    return _api_query(f"SELECT * FROM monitoring.v_sec_sql_acc_010_rc10 {where}", pr, "findings")


@app.get("/api/same-login-multihost/root-causes")
async def api_same_login_root_causes():
    """Root cause(s) behind the same-login-multi-host detection (panel 16)."""
    return _api_query("""SELECT root_cause_id, step_name, root_cause_desc, risk_level
                         FROM (
                           SELECT DISTINCT rc.root_cause_id, rc.step_name, rc.root_cause_desc, al.risk_level
                           FROM rootcause.v_rootcauses rc
                           JOIN alerts.alert_log al ON al.root_cause_id = rc.root_cause_id
                           WHERE rc.root_cause_id LIKE 'SEC-SQL-ACC-010-RC10'
                             AND vendor_name = 'sqlserver'
                         ) q
                         ORDER BY CASE risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                                       WHEN 'medium' THEN 3 ELSE 4 END DESC LIMIT 20""", [], "root_causes")


@app.get("/api/performance/stored-proc-slow")
async def api_stored_proc_slow(request: Request):
    """Stored procedures running slower than their historical average
    (SEC-SQL-QE-001-RC01; monitoring.v_sec_sql_qe_001_rc01): procedure, database,
    login, avg vs actual duration.
    Query params: from, to (epoch-ms or ISO local; default last 7 days),
    server (optional), limit (default 500)."""
    p = request.query_params
    cl, pr = _entry_clause("entry_date", p, default_days=7)
    where, params = list(cl), list(pr)
    if (p.get("server") or "").strip():
        where.append("server = %s"); params.append(p.get("server").strip())
    try:
        limit = max(1, min(int(p.get("limit", 500)), 5000))
    except (TypeError, ValueError):
        limit = 500
    params.append(limit)
    return _api_query(
        f"""SELECT * FROM monitoring.v_sec_sql_qe_001_rc01
            WHERE {' AND '.join(where)}
            ORDER BY entry_date DESC LIMIT %s""", params, "slow_procedures")


@app.post("/api/alerts/incidents/{incident_id}/resolve")
async def api_resolve_incident(incident_id: int, request: Request):
    """Manually resolve an open incident. ONLY a valid, active customer user may
    do this, and a description is required — both enforced in alerts.resolve_incident().
    Body: {"resolved_by": "user@customer.com", "description": "what was done"}."""
    data = await request.json()
    resolved_by = str(data.get("resolved_by", "")).strip()
    description = str(data.get("description", "")).strip()
    if not resolved_by or not description:
        return JSONResponse(
            {"detail": "resolved_by (customer user email) and description are both required"},
            status_code=400)
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = False
    cur = conn.cursor()
    try:
        cur.execute("SELECT (alerts.resolve_incident(%s, %s, %s)).incident_id",
                    (incident_id, resolved_by, description))
        rid = cur.fetchone()[0]
        conn.commit()
        db_write_log(f"incident {rid} resolved by {resolved_by}", 0, "api_resolve_incident", "")
        return JSONResponse({"message": f"Incident {rid} resolved", "incident_id": rid})
    except Exception as e:
        conn.rollback()
        # the SQL function RAISEs a clear message for bad user / missing description /
        # already-resolved — surface it as a 400, not a 500.
        msg = str(e).split("\n")[0].replace("CONTEXT:", "").strip()
        return JSONResponse({"detail": msg}, status_code=400)
    finally:
        cur.close(); conn.close()


@app.post("/api/alerts/incidents/{incident_id}/resolve-ui")
async def api_resolve_incident_ui(incident_id: int, request: Request):
    """Resolve an open incident with resolver name, resolution type, an optional
    resolved-at timestamp, and a description — the same capability as the Open Alerts
    dashboard resolve form, exposed as JSON. resolved_by is stored as-is (e.g. the
    Grafana username); the gate is the caller's own authentication, not web.users.
    Body: {"resolved_by": "...", "resolution_type": "Fixed",
           "resolved_at": "2026-07-15T14:30"   (optional; ISO or 'YYYY-MM-DD HH:MM'; default now),
           "resolution_description": "..."}. Calls alerts.resolve_incident_ui (migration 6620)."""
    data = await request.json()
    resolved_by = str(data.get("resolved_by", "")).strip()
    rtype       = str(data.get("resolution_type", "")).strip()
    descr       = str(data.get("resolution_description", data.get("description", ""))).strip()
    resolved_at = str(data.get("resolved_at", "")).strip().replace("T", " ") or None
    if not resolved_by or not descr:
        return JSONResponse(
            {"detail": "resolved_by and resolution_description are both required"},
            status_code=400)
    conn = psycopg2.connect(get_connection_string())
    conn.autocommit = False
    cur = conn.cursor()
    try:
        cur.execute("SELECT (alerts.resolve_incident_ui(%s, %s, %s, %s, %s::timestamp)).incident_id",
                    (incident_id, resolved_by, rtype, descr, resolved_at))
        rid = cur.fetchone()[0]
        conn.commit()
        db_write_log(f"incident {rid} resolved (ui-api) by {resolved_by} ({rtype})",
                     0, "api_resolve_incident_ui", "")
        return JSONResponse({"message": f"Incident {rid} resolved", "incident_id": rid,
                             "resolved_by": resolved_by, "resolution_type": rtype or "manual"})
    except Exception as e:
        conn.rollback()
        msg = str(e).split("\n")[0].replace("CONTEXT:", "").strip()
        return JSONResponse({"detail": msg}, status_code=400)
    finally:
        cur.close(); conn.close()


@app.get("/api/alerts/lifecycle-config")
async def api_get_lifecycle_config():
    """Auto-resolve timeouts per severity (the 'time configured' the customer sets)."""
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("""SELECT risk_level, auto_resolve_enabled, auto_resolve_after_hours,
                              updated_at::text
                       FROM alerts.alert_lifecycle_config
                       ORDER BY CASE risk_level WHEN 'default' THEN 0 WHEN 'critical' THEN 1
                                     WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END""")
        cols = [d[0] for d in cur.description]
        return JSONResponse({"config": [dict(zip(cols, r)) for r in cur.fetchall()]})
    except Exception as e:
        return JSONResponse({"error": str(e), "config": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/alerts/lifecycle-config")
async def api_set_lifecycle_config(request: Request):
    """Update the auto-resolve timeout for a severity.
    Body: {"risk_level": "high", "auto_resolve_enabled": true, "auto_resolve_after_hours": 48}."""
    data = await request.json()
    rl = str(data.get("risk_level", "")).strip().lower()
    if rl not in ("default", "critical", "high", "medium", "low"):
        return JSONResponse({"detail": "risk_level must be default|critical|high|medium|low"},
                            status_code=400)
    try:
        hours = int(data.get("auto_resolve_after_hours", 72))
        if hours <= 0:
            raise ValueError()
    except (TypeError, ValueError):
        return JSONResponse({"detail": "auto_resolve_after_hours must be a positive integer"},
                            status_code=400)
    enabled = bool(data.get("auto_resolve_enabled", True))
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("""INSERT INTO alerts.alert_lifecycle_config
                          (risk_level, auto_resolve_enabled, auto_resolve_after_hours, updated_at)
                       VALUES (%s, %s, %s, LOCALTIMESTAMP)
                       ON CONFLICT (risk_level) DO UPDATE
                         SET auto_resolve_enabled = EXCLUDED.auto_resolve_enabled,
                             auto_resolve_after_hours = EXCLUDED.auto_resolve_after_hours,
                             updated_at = LOCALTIMESTAMP""",
                    (rl, enabled, hours))
        conn.commit()
        return JSONResponse({"message": f"Lifecycle config for '{rl}' updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# Generated reports live next to the EXE (APP_DIR), not BASE_DIR (_internal when
# frozen): the reportlab compliance reports write to reports/compliance and the
# JSON-template reports (e.g. DAM, rpt_8_compliance_dam_compliance) write to
# reports/. Scan both so every generated report is listed/downloadable.
_REPORT_DIRS = [
    os.path.join(APP_DIR, "reports", "compliance"),
    os.path.join(APP_DIR, "reports"),
]
_REPORT_REGS = ("PCI-DSS", "HIPAA", "GDPR", "SOC2", "DAM")


@app.get("/api/compliance-reports")
async def api_list_reports():
    """List generated compliance PDFs from both the reportlab (reports/compliance)
    and JSON-template (reports/) output directories."""
    from pathlib import Path
    try:
        seen, reports = set(), []
        for report_dir in _REPORT_DIRS:
            if not os.path.isdir(report_dir):
                continue
            for p in Path(report_dir).glob("*.pdf"):
                if p.name in seen:
                    continue
                seen.add(p.name)
                nm  = p.name.lower()
                reg = "UNKNOWN"
                for r in _REPORT_REGS:
                    if r.lower().replace("-", "_") in nm or r in p.name.upper():
                        reg = r; break
                reports.append({
                    "filename": p.name,
                    "regulation": reg,
                    "generated_at": datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M"),
                    "size_kb": round(p.stat().st_size / 1024, 1),
                })
        reports.sort(key=lambda r: r["generated_at"], reverse=True)
        return JSONResponse({"reports": reports})
    except Exception as e:
        db_write_log(f"api_list_reports failed: {e}", 0, "api_list_reports", "")
        return JSONResponse({"error": str(e), "reports": []}, status_code=500)


@app.get("/api/compliance-reports/download/{filename}")
async def api_download_report(filename: str):
    safe_name = os.path.basename(filename)
    for report_dir in _REPORT_DIRS:
        path = os.path.join(report_dir, safe_name)
        if os.path.isfile(path):
            return FileResponse(path, media_type="application/pdf", filename=safe_name)
    raise HTTPException(status_code=404, detail="Report not found")


def _build_dam_pdf():
    """Render the DAM Compliance report and write the STABLE-named copy
    (reports/rpt_8_compliance_dam_compliance.pdf, overwritten each run). Returns
    (pdf_path, pdf_filename) - the same shape as _build_panel_pdf()."""
    import shutil
    from processes.compliance_report_generator import run_compliance_report_on_demand
    pdf_path = run_compliance_report_on_demand("DAM", 30, "")   # email handled by caller
    stable_pdf = os.path.join(APP_DIR, "reports", "rpt_8_compliance_dam_compliance.pdf")
    try:
        os.makedirs(os.path.dirname(stable_pdf), exist_ok=True)
        shutil.copy2(pdf_path, stable_pdf)
        html_src = os.path.splitext(pdf_path)[0] + ".html"
        if os.path.isfile(html_src):
            shutil.copy2(html_src, os.path.splitext(stable_pdf)[0] + ".html")
        pdf_path = stable_pdf
    except Exception:
        pass  # fall back to the timestamped file
    return pdf_path, "rpt_8_compliance_dam_compliance.pdf"


@app.get("/dam_report", response_class=HTMLResponse)
def dam_report_page(request: Request):
    """DAM Compliance Report button -> options: Print PDF or Send by mail.
    Mirrors the panel print/email pattern (/api/print-panel + /api/email-panel-form)."""
    return """
<html lang="en"><head><meta charset="UTF-8"><title>DAM Compliance Report</title>
<style>
 body{background:#111217;color:#d8d9da;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;margin:0;padding:16px;}
 .panel{max-width:560px;margin:40px auto;background:#181b1f;border:1px solid #2c3235;border-radius:6px;padding:28px;}
 h1{font-size:20px;color:#fff;margin:0 0 6px;} .sub{font-size:13px;color:#9aa0a6;margin-bottom:20px;}
 .file{font-size:12px;color:#9aa0a6;margin-bottom:22px;} code{background:#0d0e12;padding:2px 6px;border-radius:3px;}
 button{background:#3d71d9;color:#fff;border:none;border-radius:4px;padding:11px 20px;font-size:14px;cursor:pointer;margin-right:10px;}
 button:hover{background:#345fb4;}
 .note{font-size:12px;color:#9aa0a6;margin-top:16px;}
</style></head><body>
 <div class="panel">
   <h1>DAM Compliance Report</h1>
   <div class="sub">Database Activity Monitoring compliance report with per-control and per-regulation scores (PCI-DSS, HIPAA, SOX, GDPR, SOC 2).</div>
   <div class="file">Produces <code>rpt_8_compliance_dam_compliance.pdf</code>.</div>

   <button onclick="window.open('/api/print-dam','_blank')">&#128438; Print PDF</button>
   <button onclick="window.open('/api/email-dam-form','dbdome_email','width=540,height=520')">&#9993; Send by mail</button>
   <div class="note">Print opens the PDF in a new tab; Send by mail opens the recipient dialog. Generating the report can take up to a minute.</div>
 </div>
</body></html>
"""


@app.get("/api/print-dam")
def print_dam(request: Request):
    """Generate the DAM report and return the PDF inline (mirrors /api/print-panel)."""
    try:
        pdf_path, filename = _build_dam_pdf()
        db_write_log(f"DAM report generated ({filename})", 0, "print_dam", "")
        return FileResponse(pdf_path, media_type="application/pdf", filename=filename,
                            content_disposition_type="inline")
    except Exception as e:
        db_write_log(f"print-dam failed: {e}", 0, "print_dam", "")
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {e}")


@app.get("/api/email-dam-form", response_class=HTMLResponse)
def email_dam_form(request: Request):
    """Recipient dialog for the DAM report (same form as /api/email-panel-form)."""
    default_subject = "DBDOME DAM Compliance Report"
    page = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Email DAM Compliance Report</title>
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
 button {{ padding:8px 16px; border:none; border-radius:4px; font-size:14px; cursor:pointer; }}
 .send {{ background:#1f4e79; color:#fff; }} .send:hover {{ background:#163e63; }}
 .cancel {{ background:#e0e0e0; color:#333; }}
</style></head>
<body>
<div class="dialog">
  <h2>Email DAM Compliance Report</h2>
  <div style="font-size:13px;color:#555;">Report: <b>rpt_8_compliance_dam_compliance.pdf</b></div>
  <form method="post" action="/api/email-dam">
    <label for="recipients">Recipients</label>
    <input id="recipients" name="recipients" type="text" required
           placeholder="alice@example.com, bob@example.com">
    <div class="hint">Comma- or semicolon-separated email addresses.</div>
    <label for="subject">Subject</label>
    <input id="subject" name="subject" type="text" value="{default_subject}">
    <label for="body">Message (optional)</label>
    <textarea id="body" name="body" placeholder="Optional note to include in the email body…"></textarea>
    <div class="actions">
      <button type="button" class="cancel" onclick="window.close()">Cancel</button>
      <button type="submit" class="send">Send</button>
    </div>
  </form>
</div>
</body></html>"""
    return HTMLResponse(content=page)


@app.post("/api/email-dam", response_class=HTMLResponse)
async def email_dam(request: Request):
    """Generate the DAM report and email it (mirrors /api/email-panel: uses
    _load_mail_config + _send_pdf_email)."""
    import html as _html
    form = await request.form()
    recipients_raw = (form.get("recipients", "") or "").strip()
    subject = (form.get("subject", "") or "").strip() or "DBDOME DAM Compliance Report"
    body    = (form.get("body", "") or "").strip()
    if not recipients_raw:
        raise HTTPException(status_code=400, detail="recipients is required")
    recipients = [r.strip() for r in re.split(r'[,;]', recipients_raw) if r.strip()]
    if not recipients:
        raise HTTPException(status_code=400, detail="no valid recipients")
    try:
        pdf_path, filename = _build_dam_pdf()
        mc = _load_mail_config()
        if mc is None:
            raise HTTPException(status_code=500,
                                detail="config.mail_config has no rows — SMTP not configured")
        _send_pdf_email(pdf_path, filename, recipients, subject, body, mc)
        db_write_log(f"email-dam sent to {recipients}", 0, "email_dam", "")
        ok_html = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Email sent</title>
<style>body{{font-family:Arial,sans-serif;background:#f4f6f8;margin:0;
display:flex;align-items:center;justify-content:center;min-height:100vh;}}
.box{{background:#fff;padding:28px 32px;border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);
text-align:center;max-width:480px;}} h2{{color:#2e7d32;margin:0 0 12px;}}
.recipients{{font-size:13px;color:#555;word-break:break-word;}}
button{{margin-top:18px;padding:8px 18px;border:none;border-radius:4px;
background:#1f4e79;color:#fff;font-size:14px;cursor:pointer;}}</style></head><body>
<div class="box"><h2>&#9989; Email sent</h2>
  <div>Report: <b>rpt_8_compliance_dam_compliance.pdf</b></div>
  <div class="recipients">To: {_html.escape(', '.join(recipients))}</div>
  <button onclick="window.close()">Close</button>
</div></body></html>"""
        return HTMLResponse(content=ok_html)
    except HTTPException:
        raise
    except Exception as e:
        db_write_log(f"email-dam failed: {e}", 0, "email_dam", "")
        raise HTTPException(status_code=500, detail=f"Email send failed: {e}")


@app.post("/api/compliance-reports/run")
async def api_run_report(request: Request):
    data       = await request.json()
    regulation = data.get("regulation", "")
    days       = int(data.get("lookback_days", 7))
    recipients = data.get("recipients", "")
    try:
        from processes.compliance_report_generator import (
            run_compliance_report_on_demand, _REGULATION_BUILDERS, _TEMPLATE_REPORTS,
        )
        # Valid regulations = reportlab builders + JSON-template reports (e.g. DAM),
        # derived from the generator so new report types need no change here.
        valid = set(_REGULATION_BUILDERS) | set(_TEMPLATE_REPORTS)
        if regulation not in valid:
            return JSONResponse(
                {"detail": f"Unknown regulation: {regulation}. Valid: {sorted(valid)}"},
                status_code=400)
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


# ---------------------------------------------------------------------------
# GRC Phase 6: Automated Threat Response UI
# ---------------------------------------------------------------------------

@app.get("/grc/threat-response", response_class=HTMLResponse)
async def grc_threat_response_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "threat_response.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


# ── Security Incidents ───────────────────────────────────────────────────────

@app.get("/api/threat-response/incidents")
async def api_get_incidents(status: str = None, severity: str = None):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if status:
            conditions.append("status=%s"); params.append(status)
        else:
            conditions.append("status IN ('OPEN','ACKNOWLEDGED')")
        if severity:
            conditions.append("severity=%s"); params.append(severity)
        cur.execute(
            f"""SELECT incident_id, title, severity, regulation, server_name,
                       db_user, client_ip, description, status, created_at, updated_at
                FROM log.security_incidents
                WHERE {' AND '.join(conditions)}
                ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                         WHEN 'MEDIUM' THEN 3 ELSE 4 END, created_at DESC
                LIMIT 200""",
            params,
        )
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            for k in ("created_at", "updated_at"):
                if d.get(k): d[k] = d[k].isoformat()
            rows.append(d)
        return JSONResponse({"incidents": rows})
    except Exception as e:
        db_write_log(f"api_get_incidents failed: {e}", 0, "api_get_incidents", "")
        return JSONResponse({"error": str(e), "incidents": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/threat-response/incidents")
async def api_create_incident(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO log.security_incidents
                (title, severity, regulation, server_name, db_user, client_ip, description, status)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
               RETURNING incident_id""",
            (
                data["title"], data.get("severity", "HIGH"), data.get("regulation"),
                data.get("server_name"), data.get("db_user"), data.get("client_ip"),
                data.get("description"), data.get("status", "OPEN"),
            ),
        )
        incident_id = cur.fetchone()[0]
        conn.commit()
        db_write_log(f"Incident created: #{incident_id} {data['title']}", 0, "api_create_incident", "")
        return JSONResponse({"message": "Incident created", "incident_id": incident_id})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_create_incident failed: {e}", 0, "api_create_incident", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.put("/api/threat-response/incidents/{incident_id}")
async def api_update_incident(incident_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("title", "severity", "regulation", "server_name", "db_user",
                    "client_ip", "description", "status"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        sets.append("updated_at=NOW()")
        if data.get("status") == "RESOLVED":
            sets.append("resolved_at=NOW()")
        params.append(incident_id)
        cur.execute(f"UPDATE log.security_incidents SET {', '.join(sets)} WHERE incident_id=%s", params)
        conn.commit()
        db_write_log(f"Incident #{incident_id} updated", 0, "api_update_incident", "")
        return JSONResponse({"message": "Incident updated"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_update_incident failed: {e}", 0, "api_update_incident", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Blocked IPs ──────────────────────────────────────────────────────────────

@app.get("/api/threat-response/blocked-ips")
async def api_get_blocked_ips():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """SELECT block_id, ip_address::text, reason, blocked_by, blocked_at, expires_at
               FROM config.blocked_ips
               WHERE is_active=TRUE AND (expires_at IS NULL OR expires_at > NOW())
               ORDER BY blocked_at DESC"""
        )
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            for k in ("blocked_at", "expires_at"):
                if d.get(k): d[k] = d[k].isoformat()
            rows.append(d)
        return JSONResponse({"blocked_ips": rows})
    except Exception as e:
        db_write_log(f"api_get_blocked_ips failed: {e}", 0, "api_get_blocked_ips", "")
        return JSONResponse({"error": str(e), "blocked_ips": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/threat-response/blocked-ips")
async def api_block_ip(request: Request):
    data = await request.json()
    ip   = data.get("ip_address", "").strip()
    if not ip:
        return JSONResponse({"detail": "ip_address is required"}, status_code=400)
    duration = data.get("duration_mins")
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        expires_expr = f"NOW() + INTERVAL '{int(duration)} minutes'" if duration else "NULL"
        cur.execute(
            f"""INSERT INTO config.blocked_ips (ip_address, reason, blocked_by, expires_at)
                VALUES (%s,%s,'manual',{expires_expr})
                ON CONFLICT (ip_address) DO UPDATE
                  SET reason=EXCLUDED.reason, blocked_at=NOW(), is_active=TRUE,
                      expires_at={'EXCLUDED.expires_at' if duration else 'NULL'}""",
            (ip, data.get("reason", "Manual block")),
        )
        conn.commit()
        from processes.threat_response_engine import reload_entity_cache
        reload_entity_cache()
        db_write_log(f"IP blocked: {ip}", 0, "api_block_ip", "")
        return JSONResponse({"message": f"IP {ip} blocked"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_block_ip failed: {e}", 0, "api_block_ip", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.delete("/api/threat-response/blocked-ips/{block_id}")
async def api_release_ip(block_id: int):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("UPDATE config.blocked_ips SET is_active=FALSE WHERE block_id=%s", (block_id,))
        conn.commit()
        from processes.threat_response_engine import reload_entity_cache
        reload_entity_cache()
        db_write_log(f"IP block released id={block_id}", 0, "api_release_ip", "")
        return JSONResponse({"message": "IP released"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_release_ip failed: {e}", 0, "api_release_ip", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Suspended Users ──────────────────────────────────────────────────────────

@app.get("/api/threat-response/suspended-users")
async def api_get_suspended_users():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """SELECT suspension_id, server_name, login_name, reason,
                      suspended_by, suspended_at, expires_at
               FROM config.suspended_users
               WHERE is_active=TRUE AND (expires_at IS NULL OR expires_at > NOW())
               ORDER BY suspended_at DESC"""
        )
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            for k in ("suspended_at", "expires_at"):
                if d.get(k): d[k] = d[k].isoformat()
            rows.append(d)
        return JSONResponse({"suspended_users": rows})
    except Exception as e:
        db_write_log(f"api_get_suspended_users failed: {e}", 0, "api_get_suspended_users", "")
        return JSONResponse({"error": str(e), "suspended_users": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/threat-response/suspended-users")
async def api_suspend_user(request: Request):
    data     = await request.json()
    server   = data.get("server_name", "").strip()
    login    = data.get("login_name", "").strip()
    if not server or not login:
        return JSONResponse({"detail": "server_name and login_name are required"}, status_code=400)
    duration = data.get("duration_mins")
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        expires_expr = f"NOW() + INTERVAL '{int(duration)} minutes'" if duration else "NULL"
        cur.execute(
            f"""INSERT INTO config.suspended_users (server_name, login_name, reason, suspended_by, expires_at)
                VALUES (%s,%s,%s,'manual',{expires_expr})
                ON CONFLICT (server_name, login_name) DO UPDATE
                  SET reason=EXCLUDED.reason, suspended_at=NOW(), is_active=TRUE,
                      expires_at={'EXCLUDED.expires_at' if duration else 'NULL'}""",
            (server, login, data.get("reason", "Manual suspension")),
        )
        conn.commit()
        from processes.threat_response_engine import reload_entity_cache
        reload_entity_cache()
        db_write_log(f"User suspended: {login}@{server}", 0, "api_suspend_user", "")
        return JSONResponse({"message": f"User {login}@{server} suspended"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_suspend_user failed: {e}", 0, "api_suspend_user", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.delete("/api/threat-response/suspended-users/{suspension_id}")
async def api_release_user(suspension_id: int):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("UPDATE config.suspended_users SET is_active=FALSE WHERE suspension_id=%s", (suspension_id,))
        conn.commit()
        from processes.threat_response_engine import reload_entity_cache
        reload_entity_cache()
        db_write_log(f"User suspension released id={suspension_id}", 0, "api_release_user", "")
        return JSONResponse({"message": "User released"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_release_user failed: {e}", 0, "api_release_user", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Playbooks ────────────────────────────────────────────────────────────────

@app.get("/api/threat-response/playbooks")
async def api_get_playbooks():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """SELECT playbook_id, playbook_name, description, trigger_type,
                      trigger_threshold, trigger_regulation, response_type,
                      response_params, cooldown_mins, is_active
               FROM config.threat_response_playbooks
               ORDER BY playbook_id"""
        )
        cols = [d[0] for d in cur.description]
        return JSONResponse({"playbooks": [dict(zip(cols, r)) for r in cur.fetchall()]})
    except Exception as e:
        db_write_log(f"api_get_playbooks failed: {e}", 0, "api_get_playbooks", "")
        return JSONResponse({"error": str(e), "playbooks": []}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/threat-response/playbooks")
async def api_create_playbook(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        import json as _json
        cur.execute(
            """INSERT INTO config.threat_response_playbooks
                (playbook_name, description, trigger_type, trigger_threshold,
                 trigger_regulation, response_type, response_params, cooldown_mins)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
               RETURNING playbook_id""",
            (
                data["playbook_name"], data.get("description"),
                data["trigger_type"], data.get("trigger_threshold", 70),
                data.get("trigger_regulation"),
                data["response_type"],
                _json.dumps(data.get("response_params") or {}),
                data.get("cooldown_mins", 60),
            ),
        )
        pb_id = cur.fetchone()[0]
        conn.commit()
        db_write_log(f"Playbook created id={pb_id}", 0, "api_create_playbook", "")
        return JSONResponse({"message": "Playbook created", "playbook_id": pb_id})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_create_playbook failed: {e}", 0, "api_create_playbook", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.put("/api/threat-response/playbooks/{playbook_id}")
async def api_update_playbook(playbook_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        import json as _json
        sets, params = [], []
        for key in ("playbook_name", "description", "trigger_type", "trigger_threshold",
                    "trigger_regulation", "response_type", "cooldown_mins", "is_active"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if "response_params" in data:
            sets.append("response_params=%s")
            params.append(_json.dumps(data["response_params"]))
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(playbook_id)
        cur.execute(f"UPDATE config.threat_response_playbooks SET {', '.join(sets)} WHERE playbook_id=%s", params)
        conn.commit()
        db_write_log(f"Playbook updated id={playbook_id}", 0, "api_update_playbook", "")
        return JSONResponse({"message": "Playbook updated"})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_update_playbook failed: {e}", 0, "api_update_playbook", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ── Response Log ─────────────────────────────────────────────────────────────

@app.get("/api/threat-response/response-log")
async def api_get_response_log():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """SELECT response_id, triggered_at, playbook_name, trigger_type,
                      subject, response_type, response_detail, success, error_message
               FROM log.threat_response_log
               ORDER BY triggered_at DESC
               LIMIT 200"""
        )
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            if d.get("triggered_at"): d["triggered_at"] = d["triggered_at"].isoformat()
            rows.append(d)
        return JSONResponse({"rows": rows})
    except Exception as e:
        db_write_log(f"api_get_response_log failed: {e}", 0, "api_get_response_log", "")
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 7: DDL Audit
# ---------------------------------------------------------------------------

@app.get("/grc/ddl-audit", response_class=HTMLResponse)
async def grc_ddl_audit_page():
    with open(os.path.join(TEMPLATE_DIR, "ddl_audit.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/ddl-audit/logs")
async def api_ddl_audit_logs(ddl_command: str = None, risk_level: str = None, regulation: str = None):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if ddl_command:
            conditions.append("ddl_command=%s"); params.append(ddl_command)
        if risk_level:
            conditions.append("risk_level=%s"); params.append(risk_level)
        if regulation:
            conditions.append("regulation=%s"); params.append(regulation)
        cur.execute(
            f"""SELECT event_time, server_name, db_user, ddl_command, object_name,
                       ddl_statement, risk_level, regulation
                FROM log.ddl_audit_log
                WHERE {' AND '.join(conditions)}
                ORDER BY event_time DESC LIMIT 500""",
            params,
        )
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("event_time"): r["event_time"] = r["event_time"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/ddl-audit/summary")
async def api_ddl_audit_summary():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT event_time::date AS event_date, server_name,
                   COUNT(*) AS total_events,
                   COUNT(*) FILTER (WHERE ddl_command IN ('DROP','TRUNCATE')) AS destructive_events,
                   COUNT(*) FILTER (WHERE risk_level='HIGH') AS high_risk_events
            FROM log.ddl_audit_log
            WHERE event_time >= NOW() - INTERVAL '30 days'
            GROUP BY 1,2 ORDER BY 1 DESC, 3 DESC LIMIT 200
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("event_date"): r["event_date"] = str(r["event_date"])
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 7: Privilege Changes
# ---------------------------------------------------------------------------

@app.get("/grc/privilege-changes", response_class=HTMLResponse)
async def grc_privilege_changes_page():
    with open(os.path.join(TEMPLATE_DIR, "privilege_changes.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/privilege-changes")
async def api_privilege_changes(operation: str = None, regulation: str = None):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if operation:
            conditions.append("operation=%s"); params.append(operation)
        if regulation:
            conditions.append("regulation=%s"); params.append(regulation)
        cur.execute(
            f"""SELECT event_time, server_name, grantor_user, grantee_user, operation,
                       privilege_type, object_name, with_grant, regulation
                FROM log.privilege_change_log
                WHERE {' AND '.join(conditions)}
                ORDER BY event_time DESC LIMIT 500""",
            params,
        )
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("event_time"): r["event_time"] = r["event_time"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/privilege-changes/recent-summary")
async def api_privilege_recent_summary():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT server_name, grantee_user,
                   COUNT(*) FILTER (WHERE operation='GRANT') AS grant_count,
                   COUNT(*) FILTER (WHERE with_grant=TRUE) AS admin_option_count,
                   MAX(event_time) AS last_event
            FROM log.privilege_change_log
            WHERE event_time >= NOW() - INTERVAL '7 days' AND operation='GRANT'
            GROUP BY 1,2 ORDER BY 3 DESC LIMIT 100
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("last_event"): r["last_event"] = r["last_event"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 7: SoD Violations
# ---------------------------------------------------------------------------

@app.get("/grc/sod-violations", response_class=HTMLResponse)
async def grc_sod_violations_page():
    with open(os.path.join(TEMPLATE_DIR, "sod_violations.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/sod/violations")
async def api_sod_violations():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT violation_id, detected_at, server_name, db_user, rule_name,
                   severity, regulation, is_acknowledged
            FROM log.sod_violations
            WHERE detected_at >= NOW() - INTERVAL '30 days'
            ORDER BY detected_at DESC LIMIT 500
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("detected_at"): r["detected_at"] = r["detected_at"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/sod/violations/{violation_id}/acknowledge")
async def api_sod_acknowledge(violation_id: int):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            "UPDATE log.sod_violations SET is_acknowledged=TRUE, acknowledged_at=NOW() WHERE violation_id=%s",
            (violation_id,),
        )
        conn.commit()
        return JSONResponse({"message": "Violation acknowledged"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/sod/rules")
async def api_sod_rules():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("SELECT * FROM config.sod_rules ORDER BY rule_id")
        cols = [d[0] for d in cur.description]
        rules = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"rules": rules})
    except Exception as e:
        return JSONResponse({"error": str(e), "rules": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/sod/rules")
async def api_sod_create_rule(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.sod_rules
                (rule_name, description, severity, regulation, role_a_patterns, role_b_patterns)
               VALUES (%s,%s,%s,%s,%s,%s) RETURNING rule_id""",
            (data["rule_name"], data.get("description"), data.get("severity", "HIGH"),
             data.get("regulation"), data.get("role_a_patterns", []), data.get("role_b_patterns", [])),
        )
        rule_id = cur.fetchone()[0]
        conn.commit()
        return JSONResponse({"message": "Rule created", "rule_id": rule_id})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/sod/rules/{rule_id}")
async def api_sod_update_rule(rule_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("rule_name", "description", "severity", "regulation", "role_a_patterns", "role_b_patterns", "is_active"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(rule_id)
        cur.execute(f"UPDATE config.sod_rules SET {', '.join(sets)} WHERE rule_id=%s", params)
        conn.commit()
        return JSONResponse({"message": "Rule updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 8: Alert Channels
# ---------------------------------------------------------------------------

@app.get("/grc/alert-channels", response_class=HTMLResponse)
async def grc_alert_channels_page():
    with open(os.path.join(TEMPLATE_DIR, "grc_alert_channels.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/grc-alerts/channels")
async def api_get_alert_channels():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("SELECT * FROM config.grc_alert_channels ORDER BY channel_id")
        cols = [d[0] for d in cur.description]
        channels = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"channels": channels})
    except Exception as e:
        return JSONResponse({"error": str(e), "channels": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/grc-alerts/channels")
async def api_create_alert_channel(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.grc_alert_channels
                (channel_name, channel_type, min_severity, regulations, feature_sources, config)
               VALUES (%s,%s,%s,%s,%s,%s) RETURNING channel_id""",
            (data.get("channel_name", data["channel_type"]), data["channel_type"],
             data.get("min_severity", "MEDIUM"), data.get("regulations", []),
             data.get("feature_sources", []), json.dumps(data.get("config", {}))),
        )
        channel_id = cur.fetchone()[0]
        conn.commit()
        return JSONResponse({"message": "Channel created", "channel_id": channel_id})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/grc-alerts/channels/{channel_id}")
async def api_update_alert_channel(channel_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("channel_name", "channel_type", "min_severity", "regulations", "feature_sources", "is_active"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if "config" in data:
            sets.append("config=%s"); params.append(json.dumps(data["config"]))
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(channel_id)
        cur.execute(f"UPDATE config.grc_alert_channels SET {', '.join(sets)} WHERE channel_id=%s", params)
        conn.commit()
        return JSONResponse({"message": "Channel updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.delete("/api/grc-alerts/channels/{channel_id}")
async def api_delete_alert_channel(channel_id: int):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("DELETE FROM config.grc_alert_channels WHERE channel_id=%s", (channel_id,))
        conn.commit()
        return JSONResponse({"message": "Channel deleted"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/grc-alerts/delivery-log")
async def api_grc_alert_delivery_log():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT sent_at, channel_type, source_feature, severity, server_name,
                   event_summary, success, error_message
            FROM log.grc_alert_delivery_log
            ORDER BY sent_at DESC LIMIT 200
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("sent_at"): r["sent_at"] = r["sent_at"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 8: Policy Exceptions
# ---------------------------------------------------------------------------

@app.get("/grc/policy-exceptions", response_class=HTMLResponse)
async def grc_policy_exceptions_page():
    with open(os.path.join(TEMPLATE_DIR, "policy_exceptions.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/policy-exceptions")
async def api_get_policy_exceptions(status: str = None):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if status:
            conditions.append("approval_status=%s"); params.append(status)
        else:
            conditions.append("approval_status IN ('PENDING','APPROVED')")
        cur.execute(
            f"""SELECT exception_id, policy_id, server_name, db_user, client_ip_cidr,
                       approval_status, requested_by, approved_by, business_justification,
                       expires_at, created_at
                FROM config.policy_exceptions
                WHERE {' AND '.join(conditions)}
                ORDER BY created_at DESC LIMIT 200""",
            params,
        )
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            for k in ("expires_at", "created_at"):
                if r.get(k): r[k] = r[k].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/policy-exceptions")
async def api_create_policy_exception(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.policy_exceptions
                (policy_id, server_name, db_user, client_ip_cidr, expires_at,
                 business_justification, requested_by)
               VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING exception_id""",
            (data["policy_id"], data.get("server_name"), data.get("db_user"),
             data.get("client_ip_cidr"), data["expires_at"],
             data["business_justification"], data.get("requested_by")),
        )
        exception_id = cur.fetchone()[0]
        conn.commit()
        return JSONResponse({"message": "Exception request submitted", "exception_id": exception_id})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/policy-exceptions/{exception_id}")
async def api_update_policy_exception(exception_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("approval_status", "approved_by", "expires_at", "business_justification"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(exception_id)
        cur.execute(f"UPDATE config.policy_exceptions SET {', '.join(sets)} WHERE exception_id=%s", params)
        conn.commit()
        if data.get("approval_status") == "APPROVED":
            try:
                from processes.firewall_policy_engine import reload_policy_cache
                reload_policy_cache()
            except Exception:
                pass
        return JSONResponse({"message": "Exception updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 8: Regulation Controls
# ---------------------------------------------------------------------------

@app.get("/grc/regulation-controls", response_class=HTMLResponse)
async def grc_regulation_controls_page():
    with open(os.path.join(TEMPLATE_DIR, "regulation_controls.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/regulation-controls")
async def api_regulation_controls(regulation: str = None, status: str = None):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        conditions = ["1=1"]
        params = []
        if regulation:
            conditions.append("regulation=%s"); params.append(regulation)
        cur.execute(
            f"""SELECT control_id, regulation, clause_number, control_name, control_type,
                       policy_ids, feature_refs,
                       CASE WHEN array_length(policy_ids,1)>0 OR array_length(feature_refs,1)>0
                            THEN 'COVERED' ELSE 'GAP' END AS coverage_status
                FROM config.regulation_controls
                WHERE {' AND '.join(conditions)}
                ORDER BY regulation, clause_number""",
            params,
        )
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        if status:
            rows = [r for r in rows if r.get("coverage_status") == status]
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 9: Access Review
# ---------------------------------------------------------------------------

@app.get("/grc/access-review", response_class=HTMLResponse)
async def grc_access_review_page():
    with open(os.path.join(TEMPLATE_DIR, "access_review.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/access-review/instances")
async def api_access_review_instances():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT i.instance_id, c.cycle_name,
                   array_to_string(c.scope_regulations, ', ') AS regulation,
                   c.reviewer_email,
                   i.period_start, i.period_end, i.status, i.created_at
            FROM log.access_review_instances i
            JOIN config.access_review_cycles c ON c.cycle_id = i.cycle_id
            WHERE i.status IN ('OPEN','IN_PROGRESS')
            ORDER BY i.period_end ASC LIMIT 200
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            for k in ("period_start", "period_end", "created_at"):
                if r.get(k): r[k] = r[k].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/access-review/cycles")
async def api_access_review_cycles():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("SELECT * FROM config.access_review_cycles ORDER BY cycle_id")
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("next_cycle_due_at"): r["next_cycle_due_at"] = r["next_cycle_due_at"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/access-review/cycles")
async def api_create_access_review_cycle(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.access_review_cycles
                (cycle_name, reviewer_email, frequency, regulation, next_cycle_due_at)
               VALUES (%s,%s,%s,%s,%s) RETURNING cycle_id""",
            (data["cycle_name"], data["reviewer_email"], data.get("frequency", "QUARTERLY"),
             data.get("regulation"), data.get("next_cycle_due_at")),
        )
        cycle_id = cur.fetchone()[0]
        conn.commit()
        return JSONResponse({"message": "Cycle created", "cycle_id": cycle_id})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 9: TLS Enforcement
# ---------------------------------------------------------------------------

@app.get("/grc/tls-enforcement", response_class=HTMLResponse)
async def grc_tls_enforcement_page():
    with open(os.path.join(TEMPLATE_DIR, "tls_enforcement.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/tls/violations")
async def api_tls_violations():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT violation_id, detected_at, server_name, db_user, client_ip,
                   ssl_mode, risk_level, regulation, action_taken
            FROM log.tls_violations
            WHERE detected_at >= NOW() - INTERVAL '24 hours'
            ORDER BY detected_at DESC LIMIT 500
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("detected_at"): r["detected_at"] = r["detected_at"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/tls/policies")
async def api_tls_policies():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("SELECT * FROM config.tls_enforcement_policies WHERE is_active=TRUE ORDER BY server_name")
        cols = [d[0] for d in cur.description]
        policies = [dict(zip(cols, r)) for r in cur.fetchall()]
        return JSONResponse({"policies": policies})
    except Exception as e:
        return JSONResponse({"error": str(e), "policies": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/tls/policies")
async def api_create_tls_policy(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.tls_enforcement_policies
                (server_name, require_ssl, action, min_tls_version, regulation)
               VALUES (%s,%s,%s,%s,%s) RETURNING tls_policy_id""",
            (data["server_name"], data.get("require_ssl", True), data.get("action", "ALERT"),
             data.get("min_tls_version"), data.get("regulation", "PCI-DSS")),
        )
        policy_id = cur.fetchone()[0]
        conn.commit()
        return JSONResponse({"message": "TLS policy created", "tls_policy_id": policy_id})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/tls/policies/{tls_policy_id}")
async def api_update_tls_policy(tls_policy_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("server_name", "require_ssl", "action", "min_tls_version", "regulation", "is_active"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(tls_policy_id)
        cur.execute(f"UPDATE config.tls_enforcement_policies SET {', '.join(sets)} WHERE tls_policy_id=%s", params)
        conn.commit()
        return JSONResponse({"message": "TLS policy updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 9: Vulnerability Assessment
# ---------------------------------------------------------------------------

@app.get("/grc/vulnerability-assessment", response_class=HTMLResponse)
async def grc_vulnerability_page():
    with open(os.path.join(TEMPLATE_DIR, "vulnerability_assessment.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/vulnerability/findings")
async def api_vulnerability_findings():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT finding_id, detected_at, server_name, vendor, db_version,
                   cve_id, cvss_score, severity, patch_status, regulation
            FROM log.vulnerability_findings
            ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                     WHEN 'MEDIUM' THEN 3 ELSE 4 END, detected_at DESC
            LIMIT 500
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("detected_at"): r["detected_at"] = r["detected_at"].isoformat()
            if r.get("cvss_score"): r["cvss_score"] = float(r["cvss_score"])
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/vulnerability/cve-watchlist")
async def api_cve_watchlist():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("SELECT * FROM config.cve_watchlist ORDER BY cve_id")
        cols = [d[0] for d in cur.description]
        cves = [dict(zip(cols, r)) for r in cur.fetchall()]
        for c in cves:
            if c.get("cvss_score"): c["cvss_score"] = float(c["cvss_score"])
        return JSONResponse({"cves": cves})
    except Exception as e:
        return JSONResponse({"error": str(e), "cves": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/vulnerability/cve-watchlist")
async def api_create_cve(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.cve_watchlist
                (cve_id, title, cvss_score, severity, affected_vendors, affected_versions, description)
               VALUES (%s,%s,%s,%s,%s,%s,%s)
               ON CONFLICT (cve_id) DO UPDATE
                 SET title=EXCLUDED.title, cvss_score=EXCLUDED.cvss_score,
                     severity=EXCLUDED.severity, affected_vendors=EXCLUDED.affected_vendors,
                     affected_versions=EXCLUDED.affected_versions""",
            (data["cve_id"], data.get("title"), data.get("cvss_score"),
             data.get("severity", "HIGH"), data.get("affected_vendors", []),
             data.get("affected_versions", []), data.get("description")),
        )
        conn.commit()
        return JSONResponse({"message": "CVE saved"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/vulnerability/cve-watchlist/{cve_id}")
async def api_update_cve(cve_id: str, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("title", "cvss_score", "severity", "affected_vendors", "affected_versions", "description"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(cve_id)
        cur.execute(f"UPDATE config.cve_watchlist SET {', '.join(sets)} WHERE cve_id=%s", params)
        conn.commit()
        return JSONResponse({"message": "CVE updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/vulnerability/scan")
async def api_trigger_vulnerability_scan():
    try:
        import threading
        from processes.vulnerability_scanner import run_vulnerability_scan
        threading.Thread(target=run_vulnerability_scan, daemon=True).start()
        return JSONResponse({"message": "Vulnerability scan started"})
    except Exception as e:
        return JSONResponse({"detail": str(e)}, status_code=500)


# ---------------------------------------------------------------------------
# GRC Phase 9: Sensitive Data Discovery
# ---------------------------------------------------------------------------

@app.get("/api/discovery-candidates")
async def api_discovery_candidates():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT candidate_id, server_name, db_name, table_schema, table_name, column_name,
                   data_type, pii_type, detection_method, confidence_score, sample_matches,
                   review_status, discovered_at
            FROM log.discovery_candidates
            WHERE review_status='PENDING'
            ORDER BY confidence_score DESC, discovered_at DESC LIMIT 500
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("discovered_at"): r["discovered_at"] = r["discovered_at"].isoformat()
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/discovery-candidates/{candidate_id}")
async def api_update_discovery_candidate(candidate_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        status = data.get("review_status", "DISMISSED")
        cur.execute(
            "UPDATE log.discovery_candidates SET review_status=%s WHERE candidate_id=%s",
            (status, candidate_id),
        )
        conn.commit()
        return JSONResponse({"message": f"Candidate {status.lower()}"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 10: Data Retention
# ---------------------------------------------------------------------------

@app.get("/grc/data-retention", response_class=HTMLResponse)
async def grc_data_retention_page():
    with open(os.path.join(TEMPLATE_DIR, "data_retention.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/retention/policies")
async def api_retention_policies():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("SELECT * FROM config.retention_policies ORDER BY retention_id")
        cols = [d[0] for d in cur.description]
        policies = [dict(zip(cols, r)) for r in cur.fetchall()]
        for p in policies:
            if p.get("last_run_at"): p["last_run_at"] = p["last_run_at"].isoformat()
        return JSONResponse({"policies": policies})
    except Exception as e:
        return JSONResponse({"error": str(e), "policies": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/retention/policies")
async def api_create_retention_policy(request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            """INSERT INTO config.retention_policies
                (policy_name, target_schema, target_table, retention_days, min_retain_days,
                 timestamp_column, purge_mode, regulation)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING retention_id""",
            (data["policy_name"], data.get("target_schema", "log"), data["target_table"],
             data["retention_days"], data.get("min_retain_days", 0),
             data.get("timestamp_column", "event_time"), data.get("purge_mode", "DELETE"),
             data.get("regulation")),
        )
        retention_id = cur.fetchone()[0]
        conn.commit()
        return JSONResponse({"message": "Policy created", "retention_id": retention_id})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.put("/api/retention/policies/{retention_id}")
async def api_update_retention_policy(retention_id: int, request: Request):
    data = await request.json()
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        sets, params = [], []
        for key in ("policy_name", "target_schema", "target_table", "retention_days",
                    "min_retain_days", "timestamp_column", "purge_mode", "regulation", "is_active"):
            if key in data:
                sets.append(f"{key}=%s"); params.append(data[key])
        if not sets:
            return JSONResponse({"detail": "Nothing to update"}, status_code=400)
        params.append(retention_id)
        cur.execute(f"UPDATE config.retention_policies SET {', '.join(sets)} WHERE retention_id=%s", params)
        conn.commit()
        return JSONResponse({"message": "Policy updated"})
    except Exception as e:
        conn.rollback()
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.get("/api/retention/executions")
async def api_retention_executions():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT execution_id, executed_at, retention_id, policy_name, target_table,
                   cutoff_date, rows_deleted, purge_mode, regulation, success, error_message, sha256_manifest
            FROM log.retention_executions
            ORDER BY executed_at DESC LIMIT 200
        """)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        for r in rows:
            if r.get("executed_at"): r["executed_at"] = r["executed_at"].isoformat()
            if r.get("cutoff_date"): r["cutoff_date"] = str(r["cutoff_date"])
        return JSONResponse({"rows": rows})
    except Exception as e:
        return JSONResponse({"error": str(e), "rows": []}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# GRC Phase 10: Evidence Packages
# ---------------------------------------------------------------------------

@app.get("/grc/evidence-packages", response_class=HTMLResponse)
async def grc_evidence_packages_page():
    with open(os.path.join(TEMPLATE_DIR, "evidence_packages.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())

@app.get("/api/evidence-packages")
async def api_get_evidence_packages():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT package_id, package_name, regulation, period_start, period_end,
                   generated_by, status, file_size_bytes, sha256_pdf, sha256_csv,
                   pdf_path, csv_zip_path, created_at
            FROM log.evidence_packages
            ORDER BY created_at DESC LIMIT 100
        """)
        cols = [d[0] for d in cur.description]
        pkgs = [dict(zip(cols, r)) for r in cur.fetchall()]
        for p in pkgs:
            for k in ("period_start", "period_end"):
                if p.get(k): p[k] = str(p[k])
            if p.get("created_at"): p["created_at"] = p["created_at"].isoformat()
        return JSONResponse({"packages": pkgs})
    except Exception as e:
        return JSONResponse({"error": str(e), "packages": []}, status_code=500)
    finally:
        cur.close(); conn.close()

@app.post("/api/evidence-packages/generate")
async def api_generate_evidence_package(request: Request):
    data = await request.json()
    try:
        import threading
        from datetime import date as _date
        from processes.evidence_package_generator import generate_evidence_package
        period_start = _date.fromisoformat(data["period_start"]) if data.get("period_start") else None
        period_end   = _date.fromisoformat(data["period_end"])   if data.get("period_end")   else None
        threading.Thread(
            target=generate_evidence_package,
            kwargs={
                "regulation":   data.get("regulation"),
                "period_start": period_start,
                "period_end":   period_end,
                "generated_by": data.get("generated_by", "ui-user"),
            },
            daemon=True,
        ).start()
        return JSONResponse({"message": "Evidence package generation started"})
    except Exception as e:
        return JSONResponse({"detail": str(e)}, status_code=500)

@app.get("/api/evidence-packages/{package_id}/download/{file_type}")
async def api_download_evidence_package(package_id: int, file_type: str):
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute(
            "SELECT pdf_path, csv_zip_path, status FROM log.evidence_packages WHERE package_id=%s",
            (package_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Package not found")
        pdf_path, csv_path, status = row
        if status != "COMPLETE":
            raise HTTPException(status_code=409, detail=f"Package status is {status}")
        if file_type == "txt":
            if not pdf_path or not os.path.exists(pdf_path):
                raise HTTPException(status_code=404, detail="Text file not found")
            return FileResponse(pdf_path, media_type="text/plain",
                                filename=f"evidence_{package_id}.txt")
        elif file_type == "zip":
            if not csv_path or not os.path.exists(csv_path):
                raise HTTPException(status_code=404, detail="ZIP file not found")
            return FileResponse(csv_path, media_type="application/zip",
                                filename=f"evidence_{package_id}.zip")
        else:
            raise HTTPException(status_code=400, detail="file_type must be txt or zip")
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# SIEM: IPS Dashboard (FortiAnalyzer)
# ---------------------------------------------------------------------------

@app.get("/siem/ips-dashboard", response_class=HTMLResponse)
async def siem_ips_dashboard_page(request: Request):
    with open(os.path.join(TEMPLATE_DIR, "ips_dashboard.html"), "r", encoding="utf-8") as f:
        return HTMLResponse(content=f.read())


@app.get("/api/siem/ips-dashboard")
async def api_siem_ips_dashboard():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        def qrows(sql):
            cur.execute(sql)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

        def qone(sql):
            cur.execute(sql)
            r = cur.fetchone()
            return r[0] if r else 0

        stats = {
            "total":     qone("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events"),
            "critical":  qone("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events WHERE severity='critical'"),
            "high":      qone("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events WHERE severity='high'"),
            "medium":    qone("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events WHERE severity='medium'"),
            "blocked":   qone("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events WHERE action='blocked'"),
            "monitored": qone("SELECT COALESCE(SUM(count),0) FROM siem.fortianalyzer_ips_events WHERE action='monitored'"),
        }

        severity = qrows(
            "SELECT severity, total::bigint AS total, pct::float AS pct "
            "FROM siem.v_ips_severity_summary"
        )

        timeline = qrows(
            "SELECT to_char(hour_bucket,'MM-DD HH24:MI') AS time, "
            "       COALESCE(critical,0)::bigint AS critical, "
            "       COALESCE(high,0)::bigint AS high, "
            "       COALESCE(medium,0)::bigint AS medium "
            "FROM siem.v_ips_timeline "
            "WHERE hour_bucket >= NOW() - INTERVAL '7 days' ORDER BY hour_bucket"
        )

        types = qrows(
            "SELECT intrusion_type, total::bigint AS total FROM siem.v_ips_type_summary LIMIT 15"
        )

        blocked = qrows(
            "SELECT attack_name, intrusion_type, severity, total::bigint AS total "
            "FROM siem.v_ips_blocked LIMIT 15"
        )

        sources = qrows(
            "SELECT source_ip, critical::bigint AS critical, high::bigint AS high, "
            "       medium::bigint AS medium, total::bigint AS total, pct_of_total::text AS pct "
            "FROM siem.v_ips_sources LIMIT 10"
        )

        victims = qrows(
            "SELECT victim_ip, critical::bigint AS critical, high::bigint AS high, "
            "       medium::bigint AS medium, total::bigint AS total, pct_of_total::text AS pct "
            "FROM siem.v_ips_victims LIMIT 10"
        )

        http_attacks = qrows(
            "SELECT attack_name, severity, total::bigint AS total FROM siem.v_ips_http_attacks LIMIT 20"
        )

        monitored = qrows(
            "SELECT attack_name, intrusion_type, severity, total::bigint AS total "
            "FROM siem.v_ips_monitored LIMIT 20"
        )

        return JSONResponse({
            "stats": stats, "severity": severity, "timeline": timeline,
            "types": types, "blocked": blocked, "sources": sources,
            "victims": victims, "http_attacks": http_attacks, "monitored": monitored,
        })
    except Exception as e:
        db_write_log(f"api_siem_ips_dashboard failed: {e}", 0, "api_siem_ips_dashboard", "")
        return JSONResponse({"error": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


@app.post("/api/siem/ips-report/email")
async def api_siem_ips_email(request: Request):
    data       = await request.json()
    recipients = (data.get("recipients") or "").strip()
    subject    = (data.get("subject") or "IPS Report — dbdome").strip()
    if not recipients:
        return JSONResponse({"detail": "recipients is required"}, status_code=400)

    report_template = os.path.join(APP_DIR, "templates", "rpt_ips_fortianalyzer_ips_report.json")
    if not os.path.isfile(report_template):
        return JSONResponse({"detail": "Report template not found"}, status_code=500)
    try:
        generator                      = JSONReportGenerator(report_template)
        pdf_file, html_file, csv_file  = generator.generate()

        conn = psycopg2.connect(get_connection_string())
        cur  = conn.cursor()
        cur.execute(
            "SELECT mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server "
            "FROM config.mail_config LIMIT 1"
        )
        row = cur.fetchone()
        cur.close(); conn.close()

        if not row:
            return JSONResponse({"detail": "No SMTP configuration found"}, status_code=500)

        mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server = row
        # Email the files JSONReportGenerator actually wrote to disk. (The old
        # send_mail_with_html_attachment expected the report in DB tables and was
        # passed conn=None, so it crashed silently and nothing was ever sent.)
        send_report_files_email(
            subject, recipients, [html_file, pdf_file, csv_file],
            mail_sender, smtp_user, smtp_server, smtp_port, smtp_password, tls
        )
        db_write_log(f"IPS report emailed to {recipients}", 0, "api_siem_ips_email", "")
        return JSONResponse({"message": "Report sent"})
    except Exception as e:
        db_write_log(f"api_siem_ips_email failed: {e}", 0, "api_siem_ips_email", "")
        return JSONResponse({"detail": str(e)}, status_code=500)


@app.get("/api/siem/ips-report/download")
async def api_siem_ips_download():
    report_template = os.path.join(APP_DIR, "templates", "rpt_ips_fortianalyzer_ips_report.json")
    if not os.path.isfile(report_template):
        raise HTTPException(status_code=500, detail="Report template not found")
    try:
        generator                     = JSONReportGenerator(report_template)
        pdf_file, html_file, csv_file = generator.generate()
        filename = f"IPS_Report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
        return FileResponse(pdf_file, media_type="application/pdf", filename=filename)
    except Exception as e:
        db_write_log(f"api_siem_ips_download failed: {e}", 0, "api_siem_ips_download", "")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/siem/ips-report/schedule")
async def api_siem_ips_schedule_get():
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        cur.execute("""
            SELECT r.is_active,
                   j.occurance, j.occurs_at::text,
                   EXTRACT(isodow FROM js.next_run)::int AS day_of_week,
                   js.next_run::text,
                   mg.recipients
              FROM config.reports r
              JOIN config.reports_jobs rj  ON rj.report_id = r.row_id
              JOIN jobs.jobs           j   ON j.row_id     = rj.job_id
              JOIN jobs.job_schedules  js  ON js.report_id = r.row_id
              LEFT JOIN config.mail_groups mg
                     ON mg.group_name = 'ips_weekly' AND mg.is_active = true
             WHERE r.report_name = 'IPS Report - dbdome'
             LIMIT 1
        """)
        row = cur.fetchone()
        if not row:
            return JSONResponse({"is_active": False})
        is_active, occurance, occurs_at, day_of_week, next_run, recipients = row
        return JSONResponse({
            "is_active":   bool(is_active),
            "occurance":   occurance,
            "occurs_at":   (occurs_at or "")[:5],
            "day_of_week": day_of_week,
            "next_run":    next_run,
            "recipients":  recipients or "",
        })
    except Exception as e:
        db_write_log(f"api_siem_ips_schedule_get failed: {e}", 0, "api_siem_ips_schedule_get", "")
        return JSONResponse({"is_active": False, "error": str(e)})
    finally:
        cur.close(); conn.close()


@app.post("/api/siem/ips-report/schedule")
async def api_siem_ips_schedule_post(request: Request):
    data        = await request.json()
    recipients  = (data.get("recipients") or "").strip()
    day_of_week = int(data.get("day_of_week", 1))
    occurs_at   = (data.get("occurs_at") or "06:00:00")
    is_active   = bool(data.get("is_active", True))

    report_template = os.path.join(APP_DIR, "templates", "rpt_ips_fortianalyzer_ips_report.json")
    conn = psycopg2.connect(get_connection_string())
    cur  = conn.cursor()
    try:
        # 1. Upsert config.reports
        cur.execute(
            "SELECT row_id FROM config.reports WHERE report_name = 'IPS Report - dbdome'"
        )
        row = cur.fetchone()
        if row:
            report_id = row[0]
            cur.execute(
                "UPDATE config.reports SET is_active=%s, report_url=%s WHERE row_id=%s",
                (is_active, report_template, report_id)
            )
        else:
            cur.execute(
                "INSERT INTO config.reports (report_name, report_query, is_active, report_url) "
                "VALUES ('IPS Report - dbdome', 'JSON-based report', %s, %s) RETURNING row_id",
                (is_active, report_template)
            )
            report_id = cur.fetchone()[0]

        # 2. Upsert jobs.jobs (weekly)
        cur.execute(
            "SELECT row_id FROM jobs.jobs WHERE occurance='weekly' AND occurs_at=%s LIMIT 1",
            (occurs_at,)
        )
        row = cur.fetchone()
        if row:
            job_id = row[0]
        else:
            cur.execute(
                "INSERT INTO jobs.jobs (schedule_type, occurance, occurs_at) VALUES (1,'weekly',%s) RETURNING row_id",
                (occurs_at,)
            )
            job_id = cur.fetchone()[0]

        # 3. Upsert config.reports_jobs
        cur.execute("SELECT 1 FROM config.reports_jobs WHERE report_id=%s", (report_id,))
        if cur.fetchone():
            cur.execute("UPDATE config.reports_jobs SET job_id=%s WHERE report_id=%s", (job_id, report_id))
        else:
            cur.execute("INSERT INTO config.reports_jobs (report_id, job_id) VALUES (%s,%s)", (report_id, job_id))

        # 4. Compute next run
        cur.execute("""
            SELECT (date_trunc('day', NOW())
                    + make_interval(days => ((%(dow)s - EXTRACT(isodow FROM NOW())::int + 7) %% 7))
                    + %(oc)s::time) AS next_run
        """, {"dow": day_of_week, "oc": occurs_at})
        next_run = cur.fetchone()[0]
        # bump by a week if it's already past
        cur.execute("SELECT CASE WHEN %s <= NOW() THEN %s + INTERVAL '7 days' ELSE %s END", (next_run, next_run, next_run))
        next_run = cur.fetchone()[0]

        # 5. Upsert jobs.job_schedules
        cur.execute("SELECT 1 FROM jobs.job_schedules WHERE report_id=%s", (report_id,))
        if cur.fetchone():
            cur.execute(
                "UPDATE jobs.job_schedules SET schedule_id=%s, next_run=%s WHERE report_id=%s",
                (job_id, next_run, report_id)
            )
        else:
            cur.execute(
                "INSERT INTO jobs.job_schedules (report_id, schedule_id, next_run) VALUES (%s,%s,%s)",
                (report_id, job_id, next_run)
            )

        # 6. Upsert config.mail_groups for ips_weekly
        if recipients:
            cur.execute(
                "SELECT row_id FROM config.mail_groups WHERE group_name='ips_weekly' LIMIT 1"
            )
            row = cur.fetchone()
            if row:
                cur.execute(
                    "UPDATE config.mail_groups SET recipients=%s, is_active=%s WHERE group_name='ips_weekly'",
                    (recipients, is_active)
                )
            else:
                cur.execute(
                    "INSERT INTO config.mail_groups (mail_config_id, group_name, recipients, is_active) "
                    "VALUES (1, 'ips_weekly', %s, %s)",
                    (recipients, is_active)
                )

        conn.commit()
        db_write_log(
            f"IPS weekly schedule saved: day={day_of_week} time={occurs_at} recipients={recipients}",
            0, "api_siem_ips_schedule_post", ""
        )
        return JSONResponse({"message": "Schedule saved", "next_run": str(next_run)})
    except Exception as e:
        conn.rollback()
        db_write_log(f"api_siem_ips_schedule_post failed: {e}", 0, "api_siem_ips_schedule_post", "")
        return JSONResponse({"detail": str(e)}, status_code=500)
    finally:
        cur.close(); conn.close()


# ---------------------------------------------------------------------------
# Versioned API (/api/v1) + OpenAPI documentation.
# The read / data-extraction endpoints defined above are re-exposed under a
# stable /api/v1 prefix and grouped under the 'v1' tag in the OpenAPI schema
# (/openapi.json; Swagger UI at /docs; ReDoc at /redoc). The legacy /api/...
# paths are kept for backward compatibility.
# ---------------------------------------------------------------------------
from fastapi import APIRouter as _APIRouter

# Human-readable API functionality docs (HTML at /api/v1 and /api/V1; PDF download).
# The catalog + renderers live in api_docs.py so this page and the PDF never drift.
import api_docs as _api_docs


@app.get("/api/v1", response_class=HTMLResponse, include_in_schema=False)
@app.get("/api/V1", response_class=HTMLResponse, include_in_schema=False)
async def api_v1_docs_page():
    """DBDOME HTTP API functionality reference, rendered as an HTML page."""
    return HTMLResponse(_api_docs.render_html(app))


@app.get("/api/v1/functionality.pdf", include_in_schema=False)
async def api_v1_docs_pdf():
    """Download the API functionality reference as a PDF (generated on demand from
    the same catalog that backs the /api/v1 HTML page)."""
    import tempfile
    out = os.path.join(tempfile.gettempdir(), "DBDOME_HTTP_API_Functionality.pdf")
    _api_docs.render_pdf(out, app)
    return FileResponse(out, media_type="application/pdf",
                        filename="DBDOME_HTTP_API_Functionality.pdf")


_v1 = _APIRouter(prefix="/api/v1", tags=["v1"])
_V1_ROUTES = [
    ("/alerts/summary",                     api_alerts_summary),
    ("/alerts/open",                        api_alerts_open),
    ("/alerts/incidents",                   api_alert_incidents),
    ("/alerts/log/{alert_id}",              api_alert_log_detail),
    ("/alerts/ransomware",                  api_alerts_ransomware),
    ("/policy-enforcement-and-protection",  api_policy_enforcement),
    ("/database-restore",                   api_database_restore),
    ("/data-protection/unmasked",           api_data_protection_unmasked),
    ("/ips/summary",                        api_ips_summary),
    ("/ips/by-severity",                    api_ips_by_severity),
    ("/ips/by-type",                        api_ips_by_type),
    ("/ips/timeline",                       api_ips_timeline),
    ("/ips/monitored",                      api_ips_monitored),
    ("/ips/blocked",                        api_ips_blocked),
    ("/ips/top-victims",                    api_ips_top_victims),
    ("/ips/top-sources",                    api_ips_top_sources),
    ("/retention/overview",                 api_retention_overview),
    ("/retention/dump-metrics",             api_retention_dump_metrics),
    ("/retention/dumps",                    api_retention_dumps),
    ("/retention/dump-location",            api_retention_dump_location),
    ("/blocker/summary",                    api_blocker_summary),
    ("/blocker/log",                        api_blocker_log),
    ("/blocker/blocks",                     api_blocker_blocks),
    ("/same-login-multihost/findings",      api_same_login_findings),
    ("/same-login-multihost/root-causes",   api_same_login_root_causes),
    ("/performance/stored-proc-slow",       api_stored_proc_slow),
]
for _path, _fn in _V1_ROUTES:
    _summary = (_fn.__doc__ or "").strip().split("\n")[0].strip() or None
    _v1.add_api_route(_path, _fn, methods=["GET"], name="v1_" + _fn.__name__, summary=_summary)
app.include_router(_v1)


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