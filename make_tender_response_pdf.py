"""Render the Chemtrols DAM tender-response Markdown into a branded PDF.

reportlab-based (available in venv314). Handles the Markdown subset used by the
response: # / ## / ### headings, paragraphs, **bold** / `code`, bullet lists,
GitHub pipe tables (with cell wrapping), block-quotes and horizontal rules.
Status emoji are mapped to readable coloured tokens.

Usage:
    python make_tender_response_pdf.py [in.md] [out.pdf]
"""
import os
import re
import sys
from datetime import datetime

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.platypus import (
    BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle,
    Image, HRFlowable, PageBreak, KeepTogether,
)

SERVICE_DIR = os.path.dirname(os.path.abspath(__file__))
IN_MD = sys.argv[1] if len(sys.argv) > 1 else r"C:\tenders\dbexpertai_Chemtrols_DAM_TenderResponse.md"
OUT_PDF = sys.argv[2] if len(sys.argv) > 2 else r"C:\tenders\dbexpertai_Chemtrols_DAM_TenderResponse.pdf"
# Document subtitle used on the cover page and header band (reusable per tender).
SUBTITLE = sys.argv[3] if len(sys.argv) > 3 else "Database Activity Monitoring (DAM) Solution"
HEADER_RIGHT = sys.argv[4] if len(sys.argv) > 4 else "Database Activity Monitoring - Proposal Response"

NAVY = colors.HexColor("#1f4788")
BLUE = colors.HexColor("#2c5aa0")
SLATE = colors.HexColor("#2F4F4F")
GREEN = colors.HexColor("#1e8449")
AMBER = colors.HexColor("#b9770e")
GREY = colors.HexColor("#666666")
ROW_EVEN = colors.HexColor("#eef1f5")

styles = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=styles["Heading1"], fontSize=17, textColor=NAVY, spaceBefore=16, spaceAfter=8, keepWithNext=1)
H2 = ParagraphStyle("H2", parent=styles["Heading2"], fontSize=13, textColor=BLUE, spaceBefore=13, spaceAfter=6, keepWithNext=1)
H3 = ParagraphStyle("H3", parent=styles["Heading3"], fontSize=11, textColor=SLATE, spaceBefore=9, spaceAfter=4, keepWithNext=1)
BODY = ParagraphStyle("Body", parent=styles["Normal"], fontSize=9.5, leading=13.5, alignment=TA_JUSTIFY, spaceAfter=5)
BULLET = ParagraphStyle("Bullet", parent=BODY, leftIndent=14, bulletIndent=4, spaceAfter=2, alignment=TA_LEFT)
QUOTE = ParagraphStyle("Quote", parent=BODY, leftIndent=10, textColor=GREY, fontSize=8.8, leading=12, alignment=TA_LEFT, borderPadding=(4, 4, 4, 6))
CELL = ParagraphStyle("Cell", parent=styles["Normal"], fontSize=8, leading=10.5, alignment=TA_LEFT)
CELL_H = ParagraphStyle("CellH", parent=CELL, textColor=colors.white, fontName="Helvetica-Bold")


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(text):
    """Markdown inline -> reportlab mini-HTML. Maps status emoji to tokens."""
    text = text.replace("‑", "-")
    out, i, n = [], 0, len(text)
    # tokenise around ** ** and ` ` while escaping the rest
    parts = re.split(r"(\*\*.+?\*\*|`[^`]+`)", text)
    for p in parts:
        if p.startswith("**") and p.endswith("**"):
            out.append("<b>" + esc(p[2:-2]) + "</b>")
        elif p.startswith("`") and p.endswith("`"):
            out.append('<font face="Courier" size="8.5">' + esc(p[1:-1]) + "</font>")
        else:
            out.append(esc(p))
    # Emoji -> status tokens LAST: these insert real markup tags, so they must
    # not pass through esc() again (esc() would turn their < > into literal
    # text, which is exactly the "raw <font...>" bug seen in rendered PDFs).
    return ("".join(out)
            .replace("✅", '<font color="#1e8449"><b>&#10003; Available</b></font>')
            .replace("\U0001F7E1", '<font color="#b9770e"><b>Partial</b></font>')
            .replace("\U0001F535", '<font color="#2c5aa0"><b>Roadmap</b></font>')
            .replace("⚠️", '<b>Note:</b>').replace("⚠", '<b>Note:</b>')
            .replace("\U0001F4A1", ''))


def parse_table(rows):
    """rows: list of raw '| a | b |' lines (incl. the --- separator). -> Table flowable."""
    def cells(line):
        line = line.strip()
        if line.startswith("|"):
            line = line[1:]
        if line.endswith("|"):
            line = line[:-1]
        return [c.strip() for c in line.split("|")]

    header = cells(rows[0])
    body = [cells(r) for r in rows[2:]]  # rows[1] is the --- separator
    ncol = len(header)
    body = [(r + [""] * ncol)[:ncol] for r in body]

    # column widths by relative content length (last col gets the remainder pull)
    usable = A4[0] - 3.6 * cm
    weights = []
    for c in range(ncol):
        w = max([len(header[c])] + [len(r[c]) for r in body] or [1])
        weights.append(max(w, 4))
    tot = sum(weights)
    widths = [max(1.6 * cm, usable * w / tot) for w in weights]
    # rescale to fit usable
    scale = usable / sum(widths)
    widths = [w * scale for w in widths]

    data = [[Paragraph(inline(h), CELL_H) for h in header]]
    for r in body:
        data.append([Paragraph(inline(c), CELL) for c in r])

    t = Table(data, colWidths=widths, repeatRows=1)
    st = [
        ("BACKGROUND", (0, 0), (-1, 0), SLATE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c8d0da")),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, NAVY),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            st.append(("BACKGROUND", (0, i), (-1, i), ROW_EVEN))
    t.setStyle(TableStyle(st))
    return t


def build_story(md):
    story, i, lines = [], 0, md.split("\n")
    n = len(lines)
    while i < n:
        ln = lines[i]
        s = ln.strip()
        if not s:
            i += 1
            continue
        # table block
        if s.startswith("|") and i + 1 < n and set(lines[i + 1].strip()) <= set("|:- "):
            block = []
            while i < n and lines[i].strip().startswith("|"):
                block.append(lines[i]); i += 1
            if len(block) >= 2:
                story.append(Spacer(1, 3))
                story.append(parse_table(block))
                story.append(Spacer(1, 6))
            continue
        if s.startswith("# "):
            story.append(Paragraph(inline(s[2:]), H1))
        elif s.startswith("## "):
            story.append(Paragraph(inline(s[3:]), H2))
        elif s.startswith("### "):
            story.append(Paragraph(inline(s[4:]), H3))
        elif s.startswith("> "):
            story.append(Table([[Paragraph(inline(s[2:]), QUOTE)]], colWidths=[A4[0] - 3.6 * cm],
                               style=TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#f4f6f9")),
                                                 ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#c8d0da")),
                                                 ("LEFTPADDING", (0, 0), (-1, -1), 8), ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                                                 ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)])))
            story.append(Spacer(1, 4))
        elif set(s) <= set("-*") and len(s) >= 3:
            story.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#c8d0da"), spaceBefore=6, spaceAfter=6))
        elif s.startswith(("- ", "* ")):
            story.append(Paragraph(inline(s[2:]), BULLET, bulletText="•"))
        else:
            story.append(Paragraph(inline(s), BODY))
        i += 1
    return story


def cover(canvas, doc):
    canvas.saveState()
    # header band
    canvas.setFillColor(NAVY)
    canvas.rect(0, A4[1] - 1.5 * cm, A4[0], 1.5 * cm, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 10)
    canvas.drawString(1.8 * cm, A4[1] - 1.0 * cm, "dbexpert.ai  |  DBDOME")
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(A4[0] - 1.8 * cm, A4[1] - 1.0 * cm, HEADER_RIGHT)
    # footer
    canvas.setFillColor(GREY)
    canvas.setFont("Helvetica", 7.5)
    canvas.drawString(1.8 * cm, 1.0 * cm, "Confidential - prepared for Chemtrols Infotech")
    canvas.drawRightString(A4[0] - 1.8 * cm, 1.0 * cm, "Page %d" % doc.page)
    canvas.setStrokeColor(colors.HexColor("#c8d0da"))
    canvas.line(1.8 * cm, 1.4 * cm, A4[0] - 1.8 * cm, 1.4 * cm)
    canvas.restoreState()


def main():
    md = open(IN_MD, encoding="utf-8").read()
    doc = BaseDocTemplate(OUT_PDF, pagesize=A4,
                          leftMargin=1.8 * cm, rightMargin=1.8 * cm,
                          topMargin=2.0 * cm, bottomMargin=1.8 * cm,
                          title="dbexpert.ai - Chemtrols DAM Proposal", author="dbexpert.ai")
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")
    doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=cover)])

    story = []
    # cover block
    logo = os.path.join(SERVICE_DIR, "icons", "dbexpert.png")
    if os.path.exists(logo):
        try:
            story.append(Spacer(1, 1.5 * cm))
            img = Image(logo); img._restrictSize(6 * cm, 3 * cm)
            img.hAlign = "CENTER"
            story.append(img)
        except Exception:
            pass
    story.append(Spacer(1, 0.8 * cm))
    story.append(Paragraph("Proposal Response", ParagraphStyle("cT", parent=H1, fontSize=24, alignment=TA_CENTER, textColor=NAVY)))
    story.append(Paragraph(SUBTITLE, ParagraphStyle("cS", parent=H2, fontSize=15, alignment=TA_CENTER, textColor=BLUE, spaceBefore=4)))
    story.append(Spacer(1, 0.5 * cm))
    story.append(Paragraph("Submitted by <b>dbexpert.ai</b> &nbsp;|&nbsp; Product: <b>DBDOME</b>",
                           ParagraphStyle("cM", parent=BODY, alignment=TA_CENTER, fontSize=11)))
    tender_ref = sys.argv[6] if len(sys.argv) > 6 else "Tender: Chemtrols Infotech - Database Activity Monitoring Tool (Ref. 03072026)"
    story.append(Paragraph(tender_ref,
                           ParagraphStyle("cM2", parent=BODY, alignment=TA_CENTER, fontSize=10, textColor=GREY)))
    story.append(Paragraph(datetime.now().strftime("%d %B %Y"),
                           ParagraphStyle("cD", parent=BODY, alignment=TA_CENTER, fontSize=9, textColor=GREY)))
    story.append(PageBreak())

    # Drop the internal "Honest-fit summary" note (marked remove-before-submission)
    # and everything after it; it must never appear in the client-facing PDF.
    body_md = re.split(r"\n#{1,6}\s+Honest-fit summary", md)[0]
    story += build_story(body_md)

    doc.build(story)
    print("PDF written:", OUT_PDF, "(%d bytes)" % os.path.getsize(OUT_PDF))


if __name__ == "__main__":
    main()
