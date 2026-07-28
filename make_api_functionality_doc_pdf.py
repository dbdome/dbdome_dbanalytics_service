"""Generate the DBDOME 'HTTP API Functionality' reference as a branded PDF.

Reads _routes.json (produced by AST-parsing http_server.py) and renders every
FastAPI endpoint grouped by feature area, showing: HTTP method, path, purpose,
arguments (name/type/default), result type and the handler/line reference.
Same visual style as the DBDOME catalogs.
"""
import json
import datetime
from collections import OrderedDict
from fpdf import FPDF

NAVY = (23, 42, 77)
BLUE = (37, 99, 175)
LIGHT = (238, 242, 249)
GREY = (90, 90, 90)
LINE = (210, 216, 226)
BASE = "C:/dev/dbdome_dbanalytics_service"
LOGO = f"{BASE}/static/images/dbdome_logo.png"
OUT = f"{BASE}/DBDOME_HTTP_API_Functionality.pdf"
SRC = "http_server.py"

VERB_COLOR = {
    "GET": (37, 99, 175), "POST": (30, 120, 70), "PUT": (170, 110, 20),
    "PATCH": (150, 100, 20), "DELETE": (170, 45, 45),
}

# /api/<segment> -> section title (segments not listed get their own section)
GROUP = {
    "alert-rules": "Alerts, Thresholds & Webhooks",
    "alert-thresholds": "Alerts, Thresholds & Webhooks",
    "alert_dashboard": "Alerts, Thresholds & Webhooks",
    "delete-alert-rule": "Alerts, Thresholds & Webhooks",
    "delete-threshold": "Alerts, Thresholds & Webhooks",
    "delete-webhook-alert": "Alerts, Thresholds & Webhooks",
    "webhook-alerts": "Alerts, Thresholds & Webhooks",
    "grc-alerts": "Alerts, Thresholds & Webhooks",
    "global-params": "Alerts, Thresholds & Webhooks",
    "delete-global-param": "Alerts, Thresholds & Webhooks",
    "compliance-reports": "Compliance Reporting",
    "reports": "Compliance Reporting",
    "report-schedules": "Compliance Reporting",
    "toggle-report": "Compliance Reporting",
    "regulation-controls": "Compliance Reporting",
    "audit-log": "Compliance Reporting",
    "email-panel": "Email & Notifications",
    "email-panel-form": "Email & Notifications",
    "mail-config": "Email & Notifications",
    "mail-group": "Email & Notifications",
    "print-panel": "Email & Notifications",
    "masking-rules": "Data Protection & Privacy",
    "sensitive-schema": "Data Protection & Privacy",
    "retention": "Data Protection & Privacy",
    "tls": "Data Protection & Privacy",
    "risk-scores": "Governance, Risk & Compliance (GRC)",
    "risk-level": "Governance, Risk & Compliance (GRC)",
    "sod": "Governance, Risk & Compliance (GRC)",
    "access-review": "Governance, Risk & Compliance (GRC)",
    "policy-exceptions": "Governance, Risk & Compliance (GRC)",
    "privilege-changes": "Governance, Risk & Compliance (GRC)",
    "evidence-packages": "Governance, Risk & Compliance (GRC)",
    "threat-response": "Threat Response",
    "firewall-policies": "Firewall Policies",
    "siem": "SIEM Integration",
    "vulnerability": "Vulnerability Management",
    "ddl-audit": "DDL Audit",
    "discovery-candidates": "Asset Discovery",
    "fleet": "Fleet",
}


def humanize(seg):
    return seg.replace("-", " ").replace("_", " ").title()


def section_of(r):
    path = r["path"]
    if path.startswith("/api"):
        parts = [x for x in path.split("/") if x and not x.startswith("{")]
        seg = parts[1] if len(parts) > 1 else "api"
        return ("2-api", GROUP.get(seg, humanize(seg)))
    if r["verb"] == "GET":
        return ("3-pages", "Web UI Pages (HTML)")
    return ("4-actions", "Web Actions & Form Submissions")


def clean(s):
    return (s or "").replace("\r", " ").replace("\n", " ").strip()


def fmt_args(args):
    if not args:
        return "none"
    out = []
    for a in args:
        s = a["name"]
        if a["type"]:
            s += f": {a['type']}"
        if a["default"] not in (None, "None") or (a["default"] == "None"):
            if a["default"] is not None:
                dv = a["default"]
                if len(dv) > 34:
                    dv = dv[:31] + "..."
                s += f" = {dv}"
        out.append(s)
    return ";  ".join(out)


# ---------------------------------------------------------------- load + group
rows = json.load(open(f"{BASE}/_routes.json", encoding="utf-8"))

# apply authored purpose overrides (keyed by handler name) if present, so a
# plain re-extraction of _routes.json never loses the hand-written text.
try:
    _ov = json.load(open(f"{BASE}/_purpose_overrides.json", encoding="utf-8"))
    for r in rows:
        if r["handler"] in _ov:
            r["purpose"] = _ov[r["handler"]]
except FileNotFoundError:
    pass
buckets = {}
for r in rows:
    order, title = section_of(r)
    buckets.setdefault((order, title), []).append(r)

# section order: api areas alphabetical, then pages, then actions
sections = sorted(buckets.items(), key=lambda kv: (kv[0][0][0], kv[0][1]))

n_total = len(rows)
n_api = sum(1 for r in rows if r["path"].startswith("/api"))
n_pages = sum(1 for r in rows if not r["path"].startswith("/api")
              and r["verb"] == "GET")
n_actions = n_total - n_api - n_pages
gen_date = datetime.date.today().strftime("%d %b %Y")

INTRO = (
    "This document is a functional reference for the DBDOME analytics HTTP "
    "service (FastAPI, source: http_server.py). It lists every registered "
    "endpoint grouped by feature area, and for each one shows the HTTP method "
    "and path, its purpose, the accepted arguments (name, type and default), "
    "the result it returns, and the handler function and source line. "
    "Endpoints are auto-extracted from the source; purpose text uses the "
    "endpoint's docstring / OpenAPI summary where present, otherwise a "
    "readable form of the handler name.")

STATS = [(str(n_total), "Total endpoints"),
         (str(n_api), "REST / JSON API endpoints"),
         (f"{n_pages}+{n_actions}", "UI pages + form actions")]


# ---------------------------------------------------------------- pdf
class PDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        try:
            self.image(LOGO, x=self.l_margin, y=7, w=7)
        except Exception:
            pass
        self.set_xy(self.l_margin + 9, 8)
        self.set_font("Arial", "B", 9)
        self.set_text_color(*GREY)
        self.cell(0, 8, "DBDOME  -  HTTP API Functionality Reference",
                  align="L")
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font("Arial", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 10, f"Page {self.page_no()}   |   DBDOME dbanalytics  -  "
                         f"FastAPI (http_server.py)   |   Confidential",
                  align="C")


pdf = PDF()
pdf.add_font("Arial", "", "C:/Windows/Fonts/arial.ttf")
pdf.add_font("Arial", "B", "C:/Windows/Fonts/arialbd.ttf")
pdf.add_font("Arial", "I", "C:/Windows/Fonts/ariali.ttf")
pdf.add_font("Courier", "", "C:/Windows/Fonts/cour.ttf")
pdf.add_font("Courier", "B", "C:/Windows/Fonts/courbd.ttf")
pdf.set_auto_page_break(auto=True, margin=18)
pdf.add_page()

# ---- cover ----
logo_w = 38
pdf.image(LOGO, x=(pdf.w - logo_w) / 2, y=14, w=logo_w)
pdf.set_xy(0, 14 + logo_w + 2)
pdf.set_text_color(*NAVY)
pdf.set_font("Arial", "B", 24)
pdf.cell(0, 12, "DBDOME", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_text_color(*BLUE)
pdf.set_font("Arial", "", 14)
pdf.cell(0, 8, "HTTP API Functionality Reference", align="C",
         new_x="LMARGIN", new_y="NEXT")
pdf.set_text_color(*GREY)
pdf.set_font("Arial", "", 10.5)
pdf.cell(0, 7, "Service: dbanalytics   |   Framework: FastAPI   |   Source: "
               "http_server.py", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(2)
pdf.set_fill_color(*NAVY)
pdf.rect(pdf.l_margin, pdf.get_y(), pdf.w - 2 * pdf.l_margin, 1.5, style="F")
pdf.ln(7)

pdf.set_font("Arial", "", 10)
pdf.set_text_color(40, 40, 40)
pdf.multi_cell(0, 5.5, INTRO)
pdf.ln(3)
for val, label in STATS:
    pdf.set_fill_color(*LIGHT)
    pdf.set_text_color(*NAVY)
    pdf.set_font("Arial", "B", 11)
    pdf.cell(30, 9, f"  {val}", fill=True)
    pdf.set_font("Arial", "", 10)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 9, f"  {label}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1)
pdf.ln(2)
pdf.set_font("Arial", "I", 8)
pdf.set_text_color(*GREY)
pdf.cell(0, 5, f"Generated {gen_date}  -  {len(sections)} feature sections",
         new_x="LMARGIN", new_y="NEXT")


def verb_pill(verb):
    col = VERB_COLOR.get(verb, NAVY)
    pdf.set_font("Courier", "B", 8)
    w = max(pdf.get_string_width(verb) + 4, 16)
    pdf.set_fill_color(*col)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(w, 5, verb, fill=True, align="C", new_x="RIGHT", new_y="TOP")
    return w


# ---- body ----
for (order, title), items in sections:
    pdf.add_page()
    pdf.set_fill_color(*NAVY)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Arial", "B", 13)
    pdf.cell(0, 10, f"  {title}   ({len(items)})", fill=True,
             new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2.5)

    items.sort(key=lambda r: (r["path"], r["verb"]))
    for r in items:
        if pdf.get_y() > pdf.h - 34:
            pdf.add_page()
        # line 1: verb pill + path
        w = verb_pill(r["verb"])
        pdf.set_x(pdf.l_margin + w + 1)
        pdf.set_font("Courier", "B", 9)
        pdf.set_text_color(20, 20, 20)
        pdf.multi_cell(pdf.w - pdf.r_margin - (pdf.l_margin + w + 1), 5,
                       clean(r["path"]))
        # purpose
        pdf.set_x(pdf.l_margin + 2)
        pdf.set_font("Arial", "", 9)
        pdf.set_text_color(45, 45, 45)
        pdf.multi_cell(pdf.w - pdf.l_margin - pdf.r_margin - 2, 4.5,
                       clean(r["purpose"]))
        # args
        pdf.set_x(pdf.l_margin + 2)
        pdf.set_font("Arial", "B", 8)
        pdf.set_text_color(90, 90, 90)
        pdf.cell(pdf.get_string_width("Args: ") + 0.5, 4.2, "Args: ",
                 new_x="RIGHT", new_y="TOP")
        pdf.set_font("Courier", "", 8)
        pdf.multi_cell(pdf.w - pdf.r_margin - pdf.get_x(), 4.2,
                       clean(fmt_args(r["args"])))
        # returns + handler + line
        result = r["result"] or "JSON (dict / JSONResponse)"
        meta = f"Returns: {result}    |    handler {r['handler']}()  |  " \
               f"{SRC}:L{r['line']}"
        pdf.set_x(pdf.l_margin + 2)
        pdf.set_font("Arial", "I", 8)
        pdf.set_text_color(120, 120, 120)
        pdf.multi_cell(pdf.w - pdf.l_margin - pdf.r_margin - 2, 4.2,
                       clean(meta))
        pdf.set_draw_color(*LINE)
        pdf.line(pdf.l_margin, pdf.get_y() + 1.2, pdf.w - pdf.r_margin,
                 pdf.get_y() + 1.2)
        pdf.ln(2.6)

pdf.output(OUT)
print(f"WROTE {OUT}  | sections={len(sections)} endpoints={n_total}")
