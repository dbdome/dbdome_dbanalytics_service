import psycopg2
from utils.config_dotenv import  get_connection_string 
from email_utils.smtp_email_sender import  send_mail_with_attachment
from playwright.async_api import async_playwright
import sys
import os
from datetime import datetime
from utils.log4dbexpert import db_write_log
import asyncio


async def capture_grafana_dashboard_pdf(dashboard_url, report_name, recipients):
    conn = None
    cur = None
    output_pdf = None

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()

            # Optional: add login headers if Grafana requires API token
            # await page.set_extra_http_headers({"Authorization": "Bearer YOUR_API_KEY"})

            await page.goto(dashboard_url)
            await page.wait_for_timeout(5000)  # Wait for panels to render

            # Prepare PDF path
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
            output_dir = os.path.join(os.getcwd(), "reports")
            os.makedirs(output_dir, exist_ok=True)
            pdf_filename = f"{report_name}_{timestamp}.pdf"
            output_pdf = os.path.join(output_dir, pdf_filename)

            await page.pdf(path=output_pdf, format="A4", print_background=True)
            await browser.close()

            # --- Connect to PostgreSQL ---
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
                    c_mc.smtp_server
                FROM config.mail_config c_mc
            """
            cur.execute(p_sqlcmd)
            row = cur.fetchone()
            if row:
                mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server = row
                # Call your email function
                await send_mail_with_attachment(
                    output_pdf,
                    report_name,
                    recipients,
                    mail_sender,
                    pdf_filename,
                    smtp_user,
                    smtp_server,
                    smtp_port,
                    smtp_password,
                    mail_sender,
                    tls
                )

    except Exception as e:
        db_write_log(f"send_alert_email_and_log failed with error: {e}", "send_alert_email_and_log", "send_alert_email_and_log", "send_alert_email_and_log")

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()