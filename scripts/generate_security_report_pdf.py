"""Generate Security Domain Report PDF for customer delivery."""
import psycopg2
import json
import sys
import os
sys.path.insert(0, r"C:\dev\dbanalytics")

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.lib import colors
from datetime import datetime
from utils.config_dotenv import get_connection_string

OUTPUT = r"C:\install\DBDOME_Security_Detection_Catalog.pdf"

# Colors
DARK_BLUE = HexColor("#1a3c6e")
MEDIUM_BLUE = HexColor("#2c5aa0")
LIGHT_BLUE = HexColor("#e8f0fe")
BORDER_BLUE = HexColor("#4a86c8")
DARK_GRAY = HexColor("#333333")
LIGHT_GRAY = HexColor("#f5f5f5")
RED = HexColor("#c0392b")
ORANGE = HexColor("#e67e22")
GREEN = HexColor("#27ae60")

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='DocTitle', parent=styles['Title'], fontSize=22, textColor=DARK_BLUE, spaceAfter=6, alignment=TA_CENTER, fontName='Helvetica-Bold'))
styles.add(ParagraphStyle(name='DocSubtitle', parent=styles['Normal'], fontSize=13, textColor=MEDIUM_BLUE, spaceAfter=12, alignment=TA_CENTER))
styles.add(ParagraphStyle(name='IssueTitle', parent=styles['Heading2'], fontSize=13, textColor=DARK_BLUE, spaceBefore=16, spaceAfter=6, fontName='Helvetica-Bold'))
styles.add(ParagraphStyle(name='RCTitle', parent=styles['Heading3'], fontSize=11, textColor=MEDIUM_BLUE, spaceBefore=10, spaceAfter=4, fontName='Helvetica-Bold'))
styles.add(ParagraphStyle(name='Body', parent=styles['Normal'], fontSize=9, textColor=DARK_GRAY, spaceAfter=4, alignment=TA_JUSTIFY, leading=12))
styles.add(ParagraphStyle(name='SQL', parent=styles['Normal'], fontSize=7.5, textColor=HexColor("#1a1a2e"), spaceAfter=4, fontName='Courier', leading=9, leftIndent=10, backColor=LIGHT_GRAY))
styles.add(ParagraphStyle(name='Expected', parent=styles['Normal'], fontSize=9, textColor=HexColor("#6b3a00"), spaceAfter=4, fontName='Helvetica-Oblique', leftIndent=10))
styles.add(ParagraphStyle(name='AreaHeader', parent=styles['Heading1'], fontSize=15, textColor=HexColor("#ffffff"), spaceBefore=20, spaceAfter=10, fontName='Helvetica-Bold', backColor=DARK_BLUE, borderPadding=8))


def escape(text):
    if not text:
        return ''
    return str(text).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def add_header_footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(BORDER_BLUE)
    canvas.setLineWidth(0.5)
    canvas.line(1.5*cm, A4[1]-1.3*cm, A4[0]-1.5*cm, A4[1]-1.3*cm)
    canvas.setFont('Helvetica', 7)
    canvas.setFillColor(HexColor("#888888"))
    canvas.drawString(1.5*cm, A4[1]-1.1*cm, "DBDOME - Security Detection Catalog")
    canvas.drawRightString(A4[0]-1.5*cm, A4[1]-1.1*cm, "CONFIDENTIAL")
    canvas.line(1.5*cm, 1.3*cm, A4[0]-1.5*cm, 1.3*cm)
    canvas.drawString(1.5*cm, 0.8*cm, f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    canvas.drawRightString(A4[0]-1.5*cm, 0.8*cm, f"Page {doc.page}")
    canvas.restoreState()


def main():
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()

    # Fetch all security detection data grouped by area, issue, root_cause
    cur.execute("""
        SELECT DISTINCT
            a.name AS area_name,
            i.name AS issue_name,
            i.issue_id,
            rc.root_cause_id,
            rc.name AS root_cause_name,
            rc.description AS root_cause_desc,
            dp.vendor_slug,
            ds.content->>'sql' AS content_sql,
            ds.expected
        FROM rootcause.issues i
        JOIN rootcause.areas a ON a.code = i.area_code
        JOIN rootcause.root_causes rc ON rc.issue_id = i.issue_id
        JOIN rootcause.detection_paths dp ON dp.root_cause_id = rc.root_cause_id AND dp.is_active = true
        JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id AND dps.sequence = 1
        JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
        WHERE i.domain_code = 'SEC'
        ORDER BY a.name, i.name, rc.root_cause_id, dp.vendor_slug
    """)

    rows = cur.fetchall()
    conn.close()

    print(f"Fetched {len(rows)} detection entries")

    # Group by area -> issue -> root_cause
    from collections import OrderedDict
    areas = OrderedDict()
    for r in rows:
        area = r[0]
        issue = r[1]
        issue_id = r[2]
        rc_id = r[3]
        rc_name = r[4]
        rc_desc = r[5]
        vendor = r[6]
        sql = r[7]
        expected = r[8]

        if area not in areas:
            areas[area] = OrderedDict()
        if issue_id not in areas[area]:
            areas[area][issue_id] = {'name': issue, 'root_causes': OrderedDict()}
        if rc_id not in areas[area][issue_id]['root_causes']:
            areas[area][issue_id]['root_causes'][rc_id] = {
                'name': rc_name, 'desc': rc_desc, 'vendors': []
            }
        areas[area][issue_id]['root_causes'][rc_id]['vendors'].append({
            'vendor': vendor, 'sql': sql, 'expected': expected
        })

    # Build PDF
    doc = SimpleDocTemplate(OUTPUT, pagesize=A4, leftMargin=1.5*cm, rightMargin=1.5*cm, topMargin=1.8*cm, bottomMargin=1.8*cm)
    elements = []

    # Cover page
    elements.append(Spacer(1, 3*cm))
    elements.append(Paragraph("DBDOME", styles['DocTitle']))
    elements.append(Paragraph("Security Detection Catalog", styles['DocTitle']))
    elements.append(Spacer(1, 0.8*cm))
    elements.append(HRFlowable(width="50%", thickness=2, color=BORDER_BLUE))
    elements.append(Spacer(1, 0.8*cm))
    elements.append(Paragraph("Complete Security Domain Detection Coverage", styles['DocSubtitle']))
    elements.append(Paragraph(f"Generated: {datetime.now().strftime('%B %d, %Y')}", styles['DocSubtitle']))
    elements.append(Spacer(1, 1.5*cm))

    # Summary table
    total_issues = sum(len(issues) for issues in areas.values())
    total_rcs = sum(len(issue['root_causes']) for issues in areas.values() for issue in issues.values())

    summary_data = [
        [Paragraph("<b>Metric</b>", styles['Body']), Paragraph("<b>Count</b>", styles['Body'])],
        ["Security Areas", str(len(areas))],
        ["Issues", str(total_issues)],
        ["Root Causes", str(total_rcs)],
        ["Detection Steps", str(len(rows))],
        ["Database Vendors", "SQL Server, PostgreSQL, Oracle, MySQL"],
    ]
    t = Table(summary_data, colWidths=[8*cm, 9*cm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), MEDIUM_BLUE),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER_BLUE),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, LIGHT_GRAY]),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
    ]))
    elements.append(t)
    elements.append(PageBreak())

    # Table of Contents
    elements.append(Paragraph("Table of Contents", styles['DocTitle']))
    elements.append(Spacer(1, 0.5*cm))
    for area_name, issues in areas.items():
        elements.append(Paragraph(f"<b>{escape(area_name)}</b> ({len(issues)} issues)", styles['Body']))
        for issue_id, issue_data in issues.items():
            rc_count = len(issue_data['root_causes'])
            elements.append(Paragraph(f"&nbsp;&nbsp;&nbsp;&nbsp;{escape(issue_id)} - {escape(issue_data['name'])} ({rc_count} root causes)", styles['Body']))
    elements.append(PageBreak())

    # Detail pages
    for area_name, issues in areas.items():
        # Area header
        elements.append(Paragraph(f"Security Area: {escape(area_name)}", styles['AreaHeader']))
        elements.append(Spacer(1, 0.3*cm))

        for issue_id, issue_data in issues.items():
            elements.append(Paragraph(f"{escape(issue_id)} - {escape(issue_data['name'])}", styles['IssueTitle']))

            for rc_id, rc_data in issue_data['root_causes'].items():
                rc_elements = []
                rc_elements.append(Paragraph(f"{escape(rc_id)}: {escape(rc_data['name'])}", styles['RCTitle']))

                if rc_data['desc']:
                    rc_elements.append(Paragraph(escape(rc_data['desc'][:300]), styles['Body']))

                for v in rc_data['vendors']:
                    vendor = v['vendor']
                    sql = v['sql'] or ''
                    expected = v['expected'] or {}

                    # Vendor label
                    vendor_colors = {'sqlserver': RED, 'postgresql': MEDIUM_BLUE, 'oracle': ORANGE, 'mysql': GREEN}
                    vc = vendor_colors.get(vendor, DARK_GRAY)
                    rc_elements.append(Paragraph(f"<font color='{vc}'><b>[{escape(vendor.upper())}]</b></font>", styles['Body']))

                    # Expected condition
                    if isinstance(expected, dict):
                        condition = expected.get('condition', '')
                        description = expected.get('description', '')
                        severity = expected.get('severity', '')
                        exp_text = f"<b>Expected:</b> {escape(condition)}"
                        if severity:
                            exp_text += f" | Severity: {escape(severity)}"
                        if description:
                            exp_text += f"<br/>{escape(description[:200])}"
                        rc_elements.append(Paragraph(exp_text, styles['Expected']))
                    elif expected:
                        rc_elements.append(Paragraph(f"<b>Expected:</b> {escape(str(expected)[:200])}", styles['Expected']))

                    # SQL content
                    if sql:
                        sql_display = escape(sql[:500])
                        rc_elements.append(Paragraph(sql_display, styles['SQL']))

                    rc_elements.append(Spacer(1, 2))

                try:
                    elements.append(KeepTogether(rc_elements))
                except:
                    elements.extend(rc_elements)

            elements.append(Spacer(1, 6))

        elements.append(PageBreak())

    # Build
    doc.build(elements, onFirstPage=add_header_footer, onLaterPages=add_header_footer)
    print(f"PDF generated: {OUTPUT}")


if __name__ == "__main__":
    main()
