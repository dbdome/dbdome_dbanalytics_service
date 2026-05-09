"""
GRC Phase 2: Compliance Report Generator

Generates multi-section PDF compliance reports for PCI-DSS, HIPAA, GDPR, SOC2.
Runs on schedule (daily / weekly) and emails PDFs to configured recipients.

Entry points registered with APScheduler:
    run_compliance_reports_daily()   -- every 24 h
    run_compliance_reports_weekly()  -- every 7 days (Sunday 06:00)
"""

import os
import sys
import time
import psycopg2
from datetime import datetime, timedelta, date

from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib import colors
from reportlab.lib.units import cm
from reportlab.platypus import (
    SimpleDocTemplate, Table, TableStyle,
    Paragraph, Spacer, Image, PageBreak,
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from email_utils.smtp_email_sender import send_mail_with_pdf_attachment

# ── Path helpers ─────────────────────────────────────────────────────────────

def _service_dir() -> str:
    if getattr(sys, 'frozen', False):
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LOGO_PATH = os.path.join(_service_dir(), "icons", "LOGO.png")
REPORT_DIR = os.path.join(_service_dir(), "reports", "compliance")

# ── Styles ───────────────────────────────────────────────────────────────────

_styles = getSampleStyleSheet()

_TITLE_STYLE = ParagraphStyle(
    "CompTitle", parent=_styles["Heading1"],
    fontSize=18, textColor=colors.HexColor("#1f4788"),
    alignment=TA_CENTER, spaceAfter=6,
)
_SECTION_STYLE = ParagraphStyle(
    "CompSection", parent=_styles["Heading2"],
    fontSize=13, textColor=colors.HexColor("#2c5aa0"),
    spaceBefore=14, spaceAfter=6,
)
_META_STYLE = ParagraphStyle(
    "CompMeta", parent=_styles["Normal"],
    fontSize=9, textColor=colors.grey,
    alignment=TA_CENTER, spaceAfter=20,
)
_CELL_STYLE = ParagraphStyle(
    "CompCell", parent=_styles["Normal"],
    fontSize=8, leading=10, wordWrap='CJK',
)
_NO_DATA_STYLE = ParagraphStyle(
    "CompNoData", parent=_styles["Italic"],
    fontSize=9, textColor=colors.grey, spaceAfter=10,
)

_HEADER_BG   = colors.HexColor("#2F4F4F")
_ROW_ODD     = colors.whitesmoke
_ROW_EVEN    = colors.HexColor("#e8eaeb")

# Severity → colour
_SEVERITY_COLORS = {
    "CRITICAL": colors.HexColor("#c0392b"),
    "HIGH":     colors.HexColor("#e67e22"),
    "MEDIUM":   colors.HexColor("#f1c40f"),
    "LOW":      colors.HexColor("#2ecc71"),
}

# ── DB helpers ───────────────────────────────────────────────────────────────

def _conn():
    return psycopg2.connect(get_connection_string())


def _fetch(sql: str, params=()) -> tuple[list, list]:
    """Return (columns, rows). Empty lists on error."""
    try:
        con = _conn()
        cur = con.cursor()
        cur.execute(sql, params)
        rows = cur.fetchall()
        cols = [d[0].replace("_", " ").title() for d in cur.description]
        cur.close()
        con.close()
        return cols, rows
    except Exception as e:
        db_write_log(f"compliance_report _fetch error: {e}", 0, "compliance_report_generator", "")
        return [], []


def _fetch_schedules(frequency: str) -> list[dict]:
    cols, rows = _fetch(
        "SELECT schedule_id, regulation, report_name, lookback_days, recipients "
        "FROM config.compliance_report_schedules "
        "WHERE is_active = TRUE AND frequency = %s",
        (frequency,),
    )
    return [dict(zip(cols, r)) for r in rows]


def _mark_run(schedule_id: int):
    try:
        con = _conn()
        cur = con.cursor()
        cur.execute(
            "UPDATE config.compliance_report_schedules SET last_run_at = NOW() WHERE schedule_id = %s",
            (schedule_id,),
        )
        con.commit()
        cur.close()
        con.close()
    except Exception:
        pass

# ── PDF builder helpers ───────────────────────────────────────────────────────

def _cell(value) -> Paragraph:
    import html as _html
    s = "" if value is None else str(value)
    if len(s) > 300:
        s = s[:297] + "…"
    return Paragraph(_html.escape(s), _CELL_STYLE)


def _table_element(columns: list, rows: list) -> Table | None:
    if not rows:
        return None
    data = [columns] + [[_cell(v) for v in row] for row in rows]
    col_count = len(columns)
    t = Table(data, repeatRows=1, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  _HEADER_BG),
        ("TEXTCOLOR",     (0, 0), (-1, 0),  colors.whitesmoke),
        ("FONTNAME",      (0, 0), (-1, 0),  "Helvetica-Bold"),
        ("FONTSIZE",      (0, 0), (-1, 0),  8),
        ("FONTNAME",      (0, 1), (-1, -1), "Helvetica"),
        ("FONTSIZE",      (0, 1), (-1, -1), 8),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [_ROW_ODD, _ROW_EVEN]),
        ("GRID",          (0, 0), (-1, -1), 0.4, colors.grey),
        ("ALIGN",         (0, 0), (-1, -1), "LEFT"),
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING",    (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING",   (0, 0), (-1, -1), 4),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 4),
    ]))
    return t


def _page_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.grey)
    canvas.drawString(2 * cm, 1 * cm, f"DBDOME GRC Compliance Report — {datetime.now():%Y-%m-%d %H:%M}")
    canvas.drawRightString(landscape(A4)[0] - 2 * cm, 1 * cm, f"Page {doc.page}")
    canvas.restoreState()


# ── Per-regulation section definitions ───────────────────────────────────────

def _build_pci_dss_sections(since: datetime) -> list:
    sections = []

    sections.append(Paragraph("PCI-DSS Compliance Report", _TITLE_STYLE))
    sections.append(Paragraph(
        f"Period: {since:%Y-%m-%d} — {datetime.now():%Y-%m-%d} &nbsp;|&nbsp; "
        f"Standard: Payment Card Industry Data Security Standard (PCI-DSS v4.0)",
        _META_STYLE,
    ))

    defs = [
        ("Req 10.2 — Daily Event Summary",
         "SELECT DATE(event_time) AS date, action_taken, "
         "COUNT(*) AS events, COUNT(DISTINCT db_user) AS users, MAX(risk_score) AS max_risk "
         "FROM log.firewall_audit_log WHERE regulation='PCI-DSS' AND event_time>=%s "
         "GROUP BY DATE(event_time),action_taken ORDER BY date DESC"),
        ("Req 10.2 — Blocked Events Detail",
         "SELECT event_time::text, server_name, db_user, client_ip, db_name, "
         "LEFT(sql_statement,200) AS sql_preview, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='PCI-DSS' AND action_taken='BLOCKED' "
         "AND event_time>=%s ORDER BY event_time DESC LIMIT 200"),
        ("Req 8.3 — Privileged Access Events",
         "SELECT event_time::text, server_name, db_user, client_ip, action_taken, risk_score "
         "FROM log.firewall_audit_log WHERE regulation IN ('PCI-DSS','SOC2') "
         "AND action_taken IN ('ALERTED','BLOCKED') AND event_time>=%s "
         "ORDER BY risk_score DESC, event_time DESC LIMIT 200"),
        ("Req 6.4 — SQL Injection Attempts",
         "SELECT event_time::text, server_name, vendor, db_user, client_ip, "
         "LEFT(sql_statement,200) AS sql_preview, action_taken, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='PCI-DSS' "
         "AND sql_statement ~* 'UNION|xp_cmdshell|INTO OUTFILE|SLEEP\\\\(' "
         "AND event_time>=%s ORDER BY event_time DESC LIMIT 200"),
    ]
    for title, sql in defs:
        sections.append(Paragraph(title, _SECTION_STYLE))
        cols, rows = _fetch(sql, (since,))
        tbl = _table_element(cols, rows)
        if tbl:
            sections.append(tbl)
        else:
            sections.append(Paragraph("No events in this period.", _NO_DATA_STYLE))
        sections.append(Spacer(1, 8))

    return sections


def _build_hipaa_sections(since: datetime) -> list:
    sections = []

    sections.append(Paragraph("HIPAA Compliance Report", _TITLE_STYLE))
    sections.append(Paragraph(
        f"Period: {since:%Y-%m-%d} — {datetime.now():%Y-%m-%d} &nbsp;|&nbsp; "
        f"Standard: Health Insurance Portability and Accountability Act §164",
        _META_STYLE,
    ))

    defs = [
        ("§164.312(b) — PHI Access Audit Trail",
         "SELECT event_time::text, server_name, vendor, db_user, client_ip, db_name, "
         "LEFT(sql_statement,200) AS sql_preview, action_taken, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='HIPAA' AND event_time>=%s "
         "ORDER BY event_time DESC LIMIT 500"),
        ("§164.312(b) — Access Frequency by User",
         "SELECT db_user, server_name, COUNT(*) AS total_accesses, "
         "SUM(CASE WHEN action_taken='BLOCKED' THEN 1 ELSE 0 END) AS blocked, "
         "MAX(risk_score) AS max_risk, MAX(event_time)::text AS last_access "
         "FROM log.firewall_audit_log WHERE regulation='HIPAA' AND event_time>=%s "
         "GROUP BY db_user, server_name ORDER BY total_accesses DESC"),
        ("§164.312(a) — After-Hours Blocked Access",
         "SELECT event_time::text, server_name, db_user, client_ip, action_taken, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='HIPAA' AND action_taken='BLOCKED' "
         "AND EXTRACT(HOUR FROM event_time) BETWEEN 0 AND 5 "
         "AND event_time>=%s ORDER BY event_time DESC LIMIT 200"),
    ]
    for title, sql in defs:
        sections.append(Paragraph(title, _SECTION_STYLE))
        cols, rows = _fetch(sql, (since,))
        tbl = _table_element(cols, rows)
        if tbl:
            sections.append(tbl)
        else:
            sections.append(Paragraph("No events in this period.", _NO_DATA_STYLE))
        sections.append(Spacer(1, 8))

    return sections


def _build_gdpr_sections(since: datetime) -> list:
    sections = []

    sections.append(Paragraph("GDPR Compliance Report", _TITLE_STYLE))
    sections.append(Paragraph(
        f"Period: {since:%Y-%m-%d} — {datetime.now():%Y-%m-%d} &nbsp;|&nbsp; "
        f"Standard: General Data Protection Regulation (EU) 2016/679",
        _META_STYLE,
    ))

    defs = [
        ("Art.30 — Records of Processing Activities",
         "SELECT DATE(event_time) AS activity_date, server_name, db_name, db_user, "
         "action_taken, COUNT(*) AS access_count, MAX(risk_score) AS max_risk "
         "FROM log.firewall_audit_log WHERE regulation='GDPR' AND event_time>=%s "
         "GROUP BY DATE(event_time),server_name,db_name,db_user,action_taken "
         "ORDER BY activity_date DESC, access_count DESC"),
        ("Art.32 — High-Risk PII Access Events (risk ≥ 70)",
         "SELECT event_time::text, server_name, vendor, db_user, client_ip, db_name, "
         "LEFT(sql_statement,200) AS sql_preview, action_taken, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='GDPR' AND risk_score>=70 "
         "AND event_time>=%s ORDER BY risk_score DESC, event_time DESC LIMIT 200"),
        ("Art.32 — Blocked DDL on PII Structures",
         "SELECT event_time::text, server_name, db_user, client_ip, "
         "LEFT(sql_statement,300) AS sql_preview, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='GDPR' AND action_taken='BLOCKED' "
         "AND sql_statement ~* '^\\\\s*(DROP|ALTER|TRUNCATE)\\\\s+' "
         "AND event_time>=%s ORDER BY event_time DESC LIMIT 200"),
    ]
    for title, sql in defs:
        sections.append(Paragraph(title, _SECTION_STYLE))
        cols, rows = _fetch(sql, (since,))
        tbl = _table_element(cols, rows)
        if tbl:
            sections.append(tbl)
        else:
            sections.append(Paragraph("No events in this period.", _NO_DATA_STYLE))
        sections.append(Spacer(1, 8))

    return sections


def _build_soc2_sections(since: datetime) -> list:
    sections = []

    sections.append(Paragraph("SOC2 Compliance Report", _TITLE_STYLE))
    sections.append(Paragraph(
        f"Period: {since:%Y-%m-%d} — {datetime.now():%Y-%m-%d} &nbsp;|&nbsp; "
        f"Standard: Service Organization Control 2 (AICPA TSC)",
        _META_STYLE,
    ))

    defs = [
        ("CC7.2 — Policy Violation Summary",
         "SELECT fp.policy_name, fp.severity, fp.regulation, "
         "COUNT(al.audit_id) AS violations, COUNT(DISTINCT al.db_user) AS users, "
         "COUNT(DISTINCT al.server_name) AS servers, MAX(al.event_time)::text AS last_seen "
         "FROM log.firewall_audit_log al "
         "JOIN config.firewall_policies fp ON fp.policy_id = al.matched_policy "
         "WHERE al.action_taken IN ('BLOCKED','ALERTED') AND al.event_time>=%s "
         "GROUP BY fp.policy_name,fp.severity,fp.regulation ORDER BY violations DESC"),
        ("CC6.3 — Logical Access Monitoring",
         "SELECT event_time::text, server_name, vendor, db_user, client_ip, "
         "db_name, action_taken, risk_score "
         "FROM log.firewall_audit_log WHERE regulation='SOC2' AND event_time>=%s "
         "ORDER BY risk_score DESC, event_time DESC LIMIT 300"),
        ("CC6 — Privileged User Activity",
         "SELECT db_user, server_name, COUNT(*) AS total_events, "
         "SUM(CASE WHEN action_taken='BLOCKED' THEN 1 ELSE 0 END) AS blocked, "
         "MAX(risk_score) AS max_risk, MAX(event_time)::text AS last_activity "
         "FROM log.firewall_audit_log WHERE regulation='SOC2' AND event_time>=%s "
         "GROUP BY db_user, server_name ORDER BY total_events DESC"),
    ]
    for title, sql in defs:
        sections.append(Paragraph(title, _SECTION_STYLE))
        cols, rows = _fetch(sql, (since,))
        tbl = _table_element(cols, rows)
        if tbl:
            sections.append(tbl)
        else:
            sections.append(Paragraph("No events in this period.", _NO_DATA_STYLE))
        sections.append(Spacer(1, 8))

    return sections


_REGULATION_BUILDERS = {
    "PCI-DSS": _build_pci_dss_sections,
    "HIPAA":   _build_hipaa_sections,
    "GDPR":    _build_gdpr_sections,
    "SOC2":    _build_soc2_sections,
}

# ── PDF writer ────────────────────────────────────────────────────────────────

def _generate_pdf(elements: list, pdf_path: str):
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=landscape(A4),
        rightMargin=2 * cm, leftMargin=2 * cm,
        topMargin=2 * cm,   bottomMargin=1.5 * cm,
    )

    # Prepend logo header
    header_data = []
    if os.path.exists(LOGO_PATH):
        logo = Image(LOGO_PATH, width=4 * cm, height=1.5 * cm)
        header_data.append([logo, Paragraph(
            "<b>DBDOME — GRC Compliance Report</b>", _styles["Normal"]
        )])
        header_row = Table(header_data, colWidths=[5 * cm, None])
        header_row.setStyle(TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ]))
        all_elements = [header_row, Spacer(1, 12)] + elements
    else:
        all_elements = elements

    doc.build(all_elements, onFirstPage=_page_footer, onLaterPages=_page_footer)


# ── Email delivery ────────────────────────────────────────────────────────────

def _send_report(pdf_path: str, report_name: str, recipients: str):
    try:
        con = _conn()
        cur = con.cursor()
        cur.execute(
            "SELECT mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server "
            "FROM config.mail_config LIMIT 1"
        )
        row = cur.fetchone()
        cur.close()
        con.close()

        if not row:
            db_write_log("compliance_report: no mail config found", 0, "compliance_report_generator", "")
            return

        mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server = row
        send_mail_with_pdf_attachment(
            report_name, recipients, mail_sender,
            pdf_path, smtp_user, smtp_server,
            smtp_port, smtp_password, mail_sender, tls,
        )
        db_write_log(f"compliance report sent: {report_name} → {recipients}", 0,
                     "compliance_report_generator", "")
    except Exception as e:
        db_write_log(f"compliance_report _send_report error: {e}", 0,
                     "compliance_report_generator", "")


# ── Core runner ───────────────────────────────────────────────────────────────

def _run_schedule(schedule: dict):
    regulation   = schedule.get("Regulation") or schedule.get("regulation", "")
    report_name  = schedule.get("Report Name") or schedule.get("report_name", regulation)
    lookback     = int(schedule.get("Lookback Days") or schedule.get("lookback_days", 1))
    recipients   = schedule.get("Recipients") or schedule.get("recipients", "")
    schedule_id  = schedule.get("Schedule Id") or schedule.get("schedule_id")

    since = datetime.utcnow() - timedelta(days=lookback)
    builder = _REGULATION_BUILDERS.get(regulation)
    if builder is None:
        db_write_log(f"compliance_report: no builder for regulation '{regulation}'", 0,
                     "compliance_report_generator", "")
        return

    try:
        os.makedirs(REPORT_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_name = regulation.replace("-", "").replace(" ", "_").lower()
        pdf_path  = os.path.join(REPORT_DIR, f"{safe_name}_{timestamp}.pdf")

        elements = builder(since)
        _generate_pdf(elements, pdf_path)
        db_write_log(f"compliance PDF generated: {pdf_path}", 0, "compliance_report_generator", "")

        if recipients.strip():
            _send_report(pdf_path, report_name, recipients)

        if schedule_id:
            _mark_run(int(schedule_id))

    except Exception as e:
        db_write_log(f"compliance_report _run_schedule error ({regulation}): {e}", 0,
                     "compliance_report_generator", "")


# ── APScheduler entry points ──────────────────────────────────────────────────

def run_compliance_reports_daily():
    """Generate daily compliance reports (PCI-DSS, HIPAA). Registered at 86400 s."""
    db_write_log("compliance_reports_daily: starting", 0, "compliance_report_generator", "")
    for schedule in _fetch_schedules("daily"):
        _run_schedule(schedule)
    db_write_log("compliance_reports_daily: done", 0, "compliance_report_generator", "")


def run_compliance_reports_weekly():
    """Generate weekly compliance reports (GDPR, SOC2). Registered at 604800 s."""
    db_write_log("compliance_reports_weekly: starting", 0, "compliance_report_generator", "")
    for schedule in _fetch_schedules("weekly"):
        _run_schedule(schedule)
    db_write_log("compliance_reports_weekly: done", 0, "compliance_report_generator", "")


def run_compliance_report_on_demand(regulation: str, lookback_days: int = 7, recipients: str = ""):
    """
    Generate a single regulation report immediately.
    Called from the Phase 5 HTTP API endpoint.
    Returns the PDF file path.
    """
    since = datetime.utcnow() - timedelta(days=lookback_days)
    builder = _REGULATION_BUILDERS.get(regulation)
    if builder is None:
        raise ValueError(f"Unknown regulation: {regulation}")

    os.makedirs(REPORT_DIR, exist_ok=True)
    timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_name  = regulation.replace("-", "").replace(" ", "_").lower()
    pdf_path   = os.path.join(REPORT_DIR, f"{safe_name}_{timestamp}.pdf")

    elements = builder(since)
    _generate_pdf(elements, pdf_path)
    db_write_log(f"on-demand compliance PDF: {pdf_path}", 0, "compliance_report_generator", "")

    if recipients.strip():
        _send_report(pdf_path, f"DBDOME {regulation} Compliance Report", recipients)

    return pdf_path
