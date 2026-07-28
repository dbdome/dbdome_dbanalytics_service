"""Generate the DBDOME Security Root-Cause Catalog (SEC-SQL / SQL Server) PDF.

Source: rootcause.v_rootcauses (domain SEC, issue_id LIKE 'SEC-SQL-%',
vendor sqlserver). Hierarchy: Area -> Issue -> Root Cause.
"""
import datetime
from collections import OrderedDict, defaultdict
import psycopg2
from fpdf import FPDF

NAVY = (23, 42, 77)
BLUE = (37, 99, 175)
LIGHT = (238, 242, 249)
GREY = (90, 90, 90)
LINE = (210, 216, 226)
LOGO = "C:/dev/dbdome_dbanalytics_service/static/images/dbdome_logo.png"

# ---------------------------------------------------------------- fetch data
env = {}
for line in open("C:/dev/dbdome_dbanalytics_service/.env"):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        env[k] = v

conn = psycopg2.connect(host=env["PG_HOST"], port=env["PG_PORT"],
                        user=env["PG_USER"], password=env["PG_PASSWORD"],
                        dbname=env["PG_DB"])
cur = conn.cursor()
cur.execute("""
    SELECT DISTINCT v.area_code, v.area_name, v.issue_name, i.description,
           v.root_cause_id, v.root_cause_name, v.root_cause_desc
    FROM rootcause.v_rootcauses v
    JOIN rootcause.issues i ON i.issue_id = v.issue_id
    WHERE v.domain_code = 'SEC'
      AND v.issue_id LIKE 'SEC-SQL-%'
      AND v.vendor_name = 'sqlserver'
""")
raw = cur.fetchall()
cur.close()
conn.close()

# canonical (most descriptive) name per area_code
names = defaultdict(set)
for ac, an, *_ in raw:
    if an:
        names[ac].add(an)
canon = {ac: max(s, key=len) for ac, s in names.items()}

# dedupe by root_cause_id, build Area -> Issue -> [root causes]
seen = set()
tree = defaultdict(lambda: {"issues": defaultdict(lambda: {"desc": "", "rcs": []})})
for ac, an, iname, idesc, rcid, rcname, rcdesc in raw:
    if rcid in seen:
        continue
    seen.add(rcid)
    area = tree[ac]
    area["name"] = canon.get(ac, ac)
    issue = area["issues"][iname or "(unspecified)"]
    if idesc and not issue["desc"]:
        issue["desc"] = idesc
    issue["rcs"].append((rcid, rcname or "", rcdesc or ""))

# ordered structure
areas = OrderedDict(sorted(tree.items(), key=lambda kv: kv[1]["name"].lower()))
n_areas = len(areas)
n_issues = sum(len(a["issues"]) for a in areas.values())
n_rc = len(seen)
gen_date = datetime.date.today().strftime("%d %b %Y")


# ---------------------------------------------------------------- pdf helpers
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
        self.cell(0, 8, "DBDOME  -  Security Root-Cause Catalog (SQL Server)",
                  align="L")
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font("Arial", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 10, f"Page {self.page_no()}   |   Domain SEC  -  Vendor: "
                         f"SQL Server   |   Confidential", align="C")


def clean(s):
    return (s or "").replace("\r", " ").replace("\n", " ").strip()


pdf = PDF()
pdf.add_font("Arial", "", "C:/Windows/Fonts/arial.ttf")
pdf.add_font("Arial", "B", "C:/Windows/Fonts/arialbd.ttf")
pdf.add_font("Arial", "I", "C:/Windows/Fonts/ariali.ttf")
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
pdf.cell(0, 8, "Security Root-Cause Catalog", align="C",
         new_x="LMARGIN", new_y="NEXT")
pdf.set_text_color(*GREY)
pdf.set_font("Arial", "", 11)
pdf.cell(0, 7, "Domain: SEC (Security)   |   Vendor: SQL Server",
         align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(2)
pdf.set_fill_color(*NAVY)
pdf.rect(pdf.l_margin, pdf.get_y(), pdf.w - 2 * pdf.l_margin, 1.5, style="F")
pdf.ln(7)

# summary stats boxes
pdf.set_font("Arial", "", 10)
pdf.set_text_color(40, 40, 40)
pdf.multi_cell(0, 5.5,
    "This catalog lists the security root causes monitored by DBDOME for "
    "Microsoft SQL Server. Entries are organized by Area -> Issue -> Root "
    "Cause. Each root cause has a unique identifier (Error/Root-Cause ID) used "
    "by the detection and alerting engine. Source view: "
    "rootcause.v_rootcauses.")
pdf.ln(3)
for label, val in [("Areas", n_areas), ("Issues", n_issues),
                   ("Root Causes", n_rc)]:
    pdf.set_fill_color(*LIGHT)
    pdf.set_text_color(*NAVY)
    pdf.set_font("Arial", "B", 11)
    pdf.cell(40, 9, f"  {val}", fill=True)
    pdf.set_font("Arial", "", 10)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 9, f"  {label}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1)
pdf.ln(2)
pdf.set_font("Arial", "I", 8)
pdf.set_text_color(*GREY)
pdf.cell(0, 5, f"Generated {gen_date}", new_x="LMARGIN", new_y="NEXT")

# ---- body ----
for ac, area in areas.items():
    pdf.add_page()
    # area band
    pdf.set_fill_color(*NAVY)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Arial", "B", 13)
    pdf.cell(0, 10, f"  {area['name']}  ({ac})", fill=True,
             new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    issues = OrderedDict(sorted(area["issues"].items(),
                                key=lambda kv: kv[0].lower()))
    for iname, issue in issues.items():
        # keep issue header with at least its first lines on the page
        if pdf.get_y() > pdf.h - 45:
            pdf.add_page()
        pdf.set_text_color(*BLUE)
        pdf.set_font("Arial", "B", 11)
        pdf.multi_cell(0, 6, clean(iname))
        if issue["desc"]:
            pdf.set_text_color(*GREY)
            pdf.set_font("Arial", "I", 9)
            pdf.set_x(pdf.l_margin)
            pdf.multi_cell(0, 4.6, clean(issue["desc"]))
        pdf.set_draw_color(*LINE)
        pdf.line(pdf.l_margin, pdf.get_y() + 1, pdf.w - pdf.r_margin,
                 pdf.get_y() + 1)
        pdf.ln(2.5)

        for rcid, rcname, rcdesc in sorted(issue["rcs"], key=lambda r: r[0]):
            if pdf.get_y() > pdf.h - 28:
                pdf.add_page()
            # ID pill
            pdf.set_font("Courier", "B", 8.5)
            idw = pdf.get_string_width(rcid) + 4
            pdf.set_fill_color(*LIGHT)
            pdf.set_text_color(*NAVY)
            pdf.cell(idw, 5, rcid, fill=True, new_x="RIGHT", new_y="TOP")
            # name on the same line if there is room, else wrap to next line
            remaining = pdf.w - pdf.r_margin - pdf.get_x()
            if remaining < 35:
                pdf.ln(5)
                pdf.set_x(pdf.l_margin)
                remaining = pdf.w - pdf.r_margin - pdf.l_margin
            pdf.set_font("Arial", "B", 9.5)
            pdf.set_text_color(30, 30, 30)
            pdf.multi_cell(remaining, 5, " " + clean(rcname))
            # description
            if rcdesc:
                pdf.set_x(pdf.l_margin + 3)
                pdf.set_font("Arial", "", 9)
                pdf.set_text_color(70, 70, 70)
                pdf.multi_cell(pdf.w - pdf.l_margin - pdf.r_margin - 3, 4.6,
                               clean(rcdesc))
            pdf.ln(2)

out = "C:/dev/dbdome_dbanalytics_service/DBDOME_Security_RootCause_Catalog_SQLServer.pdf"
pdf.output(out)
print(f"WROTE {out}  | areas={n_areas} issues={n_issues} root_causes={n_rc}")
