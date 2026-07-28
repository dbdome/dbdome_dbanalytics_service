"""Generate the DBDOME POC Success / Go-Live Definition PDF (English)."""
from fpdf import FPDF

NAVY = (23, 42, 77)
BLUE = (37, 99, 175)
LIGHT = (238, 242, 249)
GREY = (90, 90, 90)
LINE = (210, 216, 226)

LOGO = "C:/dev/dbdome_dbanalytics_service/static/images/dbdome_logo.png"


class PDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        try:
            self.image(LOGO, x=self.l_margin, y=7, w=7)
        except Exception:
            pass
        self.set_xy(self.l_margin + 9, 8)
        self.set_font("Helvetica", "B", 9)
        self.set_text_color(*GREY)
        self.cell(0, 8, "DBDOME  -  POC Success & Go-Live Definition", align="L")
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 10, f"Page {self.page_no()}   |   Confidential", align="C")


def h1(pdf, text):
    pdf.set_fill_color(*NAVY)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 10, "  " + text, fill=True, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)


def h2(pdf, text):
    pdf.set_text_color(*BLUE)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 8, text, new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(*LINE)
    pdf.line(pdf.l_margin, pdf.get_y(), pdf.w - pdf.r_margin, pdf.get_y())
    pdf.ln(2)


def body(pdf, text, bold=False):
    pdf.set_text_color(40, 40, 40)
    pdf.set_font("Helvetica", "B" if bold else "", 10)
    pdf.multi_cell(0, 5.5, text)
    pdf.ln(1)


def bullet(pdf, text, bold_lead=None):
    pdf.set_text_color(40, 40, 40)
    x = pdf.get_x()
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(*BLUE)
    pdf.cell(6, 5.5, chr(149))
    pdf.set_text_color(40, 40, 40)
    if bold_lead:
        pdf.set_font("Helvetica", "B", 10)
        lead_w = pdf.get_string_width(bold_lead + " ")
        pdf.cell(lead_w, 5.5, bold_lead)
        pdf.set_font("Helvetica", "", 10)
        pdf.multi_cell(0, 5.5, text)
    else:
        pdf.set_font("Helvetica", "", 10)
        pdf.multi_cell(0, 5.5, text)
    pdf.set_x(x)
    pdf.ln(0.5)


def table(pdf, headers, rows, widths):
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_fill_color(*NAVY)
    pdf.set_text_color(255, 255, 255)
    for h, w in zip(headers, widths):
        pdf.cell(w, 8, h, border=0, align="L", fill=True)
    pdf.ln()
    pdf.set_text_color(40, 40, 40)
    fill = False
    for row in rows:
        # measure max lines needed
        pdf.set_font("Helvetica", "", 9)
        line_counts = []
        for cell, w in zip(row, widths):
            lines = pdf.multi_cell(w, 5, cell, dry_run=True, output="LINES")
            line_counts.append(len(lines))
        rh = max(line_counts) * 5 + 1
        if pdf.get_y() + rh > pdf.h - 20:
            pdf.add_page()
        pdf.set_fill_color(*(LIGHT if fill else (255, 255, 255)))
        x0, y0 = pdf.get_x(), pdf.get_y()
        for cell, w in zip(row, widths):
            x, y = pdf.get_x(), pdf.get_y()
            pdf.multi_cell(w, 5, cell, border=0, align="L", fill=True,
                           max_line_height=5)
            pdf.set_xy(x + w, y)
        pdf.set_xy(x0, y0 + rh)
        # draw bottom border
        pdf.set_draw_color(*LINE)
        pdf.line(x0, y0 + rh, x0 + sum(widths), y0 + rh)
        fill = not fill
    pdf.ln(3)


pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=18)
pdf.add_page()

# ---- Cover (logo on white + navy accent bar) ----
logo_w = 38
pdf.image(LOGO, x=(pdf.w - logo_w) / 2, y=14, w=logo_w)
pdf.set_xy(0, 14 + logo_w + 2)
pdf.set_text_color(*NAVY)
pdf.set_font("Helvetica", "B", 26)
pdf.cell(0, 12, "DBDOME", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_text_color(*BLUE)
pdf.set_font("Helvetica", "", 13)
pdf.cell(0, 8, "POC Success & Production Go-Live Definition", align="C",
         new_x="LMARGIN", new_y="NEXT")
pdf.ln(2)
pdf.set_text_color(*GREY)
pdf.set_font("Helvetica", "", 9)
pdf.cell(0, 6, "Database Analytics, Monitoring & Reporting Service", align="C",
         new_x="LMARGIN", new_y="NEXT")
pdf.ln(3)
pdf.set_fill_color(*NAVY)
pdf.rect(pdf.l_margin, pdf.get_y(), pdf.w - 2 * pdf.l_margin, 1.5, style="F")
pdf.ln(8)

body(pdf,
     "Purpose: This document defines, unambiguously, what counts as a "
     "successful and final production installation of DBDOME, the boundaries "
     "(scope) of the installation phase, and what is required from the "
     "customer. Once the KPIs below are met for the acceptance period, the "
     "installation phase is considered complete and accepted (sign-off). Any "
     "new feature or development beyond go-live is delivered under a separate "
     "work plan.")
pdf.ln(2)

# ---- Section 1 ----
h1(pdf, "1.  Definition of a Working Production System")
body(pdf, "The system is considered live and operational when ALL of the "
          "following hold together:")
bullet(pdf, "DBDOME is installed as a Windows service, starts automatically "
            "after a server reboot, and self-recovers from a crash.",
       "Active & stable service.")
bullet(pdf, "Both databases defined in the POC are connected, reachable, and "
            "metric collection from them runs successfully.",
       "Two DB connections.")
bullet(pdf, "The scheduler collects metrics at the defined interval with no "
            "recurring errors in the log.", "Continuous collection.")
bullet(pdf, "The reports defined in the POC are generated automatically and "
            "delivered to the configured targets (PDF / email).",
       "Customer reports.")
bullet(pdf, "The alerting engine is active and delivers alerts over the "
            "configured channels (email / SIEM) when a threshold is met.",
       "Alerts.")
bullet(pdf, "The HTTP server / dashboard is reachable by authorized users.",
       "Interface.")

pdf.ln(2)
# ---- Section 2 ----
h1(pdf, "2.  KPIs for a Successful Installation (Acceptance Criteria)")
table(pdf,
      ["#", "KPI", "Target", "How measured"],
      [
       ["1", "DB connectivity", "2 / 2 databases connected",
        "Successful connection log"],
       ["2", "Metric collection success", ">= 99% of collection cycles succeed",
        "Success/failure count over acceptance period"],
       ["3", "Report generation", "100% of POC reports produced on time & format",
        "Scheduled run + customer content approval"],
       ["4", "Report delivery", "Report reaches target (mail/folder), no failure",
        "Recipient delivery confirmation"],
       ["5", "Alerts", "Test alert received on every configured channel",
        "End-to-end test"],
       ["6", "Service stability", ">= 99% availability over acceptance period",
        "Uptime + auto-restart after reboot"],
       ["7", "Recovery", "Service comes up by itself after server reboot",
        "One controlled reboot"],
       ["8", "No blocking errors", "No open critical errors at end of period",
        "Log review"],
      ],
      [10, 42, 65, 65])
pdf.set_font("Helvetica", "B", 9)
pdf.set_text_color(*NAVY)
pdf.multi_cell(0, 5,
    "Final Acceptance (Sign-off): meeting all KPIs over a continuous "
    "acceptance period of 7 working days  ->  customer sign-off  ->  "
    "installation phase complete.")
pdf.ln(1)

# ---- Section 3 ----
pdf.add_page()
h1(pdf, "3.  Scope Boundaries")
h2(pdf, "In Scope (installation phase)")
for t in [
    "Installation of the service on the customer's production server.",
    "Connecting and configuring the 2 databases defined in the POC.",
    "Configuring metric collection, alerts and reports - to the POC scope only.",
    "End-to-end testing and a stabilization period until acceptance.",
    "Knowledge transfer / basic operations runbook to the customer team.",
]:
    bullet(pdf, t)
pdf.ln(1)
h2(pdf, "Out of Scope (quoted & delivered separately)")
for t in [
    "A 3rd database onward, or DB engines not included in the POC.",
    "New reports / metrics / alerts beyond the POC definition.",
    "New integrations (additional SIEM, 3rd-party systems, SSO, etc.).",
    "Feature development, UI customization, or logic changes.",
    "Infrastructure/hardware upgrades, DB licensing, or issues rooted in the "
    "customer environment.",
    "Ongoing support after acceptance (defined under a separate support/SLA).",
]:
    bullet(pdf, t)
pdf.set_font("Helvetica", "I", 9)
pdf.set_text_color(*GREY)
pdf.multi_cell(0, 5, "Each Out-of-Scope item is handled under a work plan and "
                    "scoped separately.")
pdf.ln(3)

# ---- Section 4: Readiness ----
pdf.add_page()
h1(pdf, "4.  System Readiness Requirements")
h2(pdf, "Hardware (DBDOME application server)")
table(pdf,
      ["Component", "Minimum Requirement", "Recommended"],
      [
       ["CPU", "Quad-core", "Better"],
       ["RAM", "16 GB", "24 GB"],
       ["Disk Space", "100 GB free", "-"],
       ["Network", "1 Gbps", "-"],
      ],
      [50, 70, 62])
h2(pdf, "Software & Compatibility")
bullet(pdf, "Windows Server 2016 / 2019 / 2022.",
       "Operating Systems:")
bullet(pdf, "SQL Server (2016-2019), Sybase, Oracle 23, PostgreSQL, MySQL.",
       "Supported Databases:")
bullet(pdf, "Latest versions of Chrome, Firefox, or Edge.",
       "Browsers:")
pdf.ln(3)

# ---- Section 5: Servers to supply / connection info ----
h1(pdf, "5.  Servers to Supply & Connection Information")
body(pdf, "The customer provides the full list of monitored servers in scope. "
          "For each server, supply the details below. Credentials must be "
          "delivered over a secure channel (not in clear email).")
table(pdf,
      ["#", "Server Name", "IP Address", "Vendor / DB Type", "Username",
       "Password"],
      [
       ["1", " ", " ", " ", " ", " "],
       ["2", " ", " ", " ", " ", " "],
       ["3", " ", " ", " ", " ", " "],
       ["4", " ", " ", " ", " ", " "],
       ["5", " ", " ", " ", " ", " "],
       ["6", " ", " ", " ", " ", " "],
      ],
      [10, 38, 28, 40, 30, 36])
pdf.set_font("Helvetica", "I", 9)
pdf.set_text_color(*GREY)
pdf.multi_cell(0, 5, "Vendor / DB Type = the database engine on that server "
                    "(e.g. SQL Server, Sybase, Oracle, PostgreSQL, MySQL).")
pdf.ln(3)

# ---- Section 6 ----
h1(pdf, "6.  What Is Required From the Customer (Prerequisites)")
body(pdf, "To meet the timeline, the following are required BEFORE installation "
          "begins:")
reqs = [
    "Production server ready (Windows), with admin rights to install a service.",
    "Network access from the server to both databases (ports / firewall open).",
    "A dedicated 'dbdome' DB user provisioned on each monitored server via the "
    "supplied script (see Immediate Action Items).",
    "SMTP / mail server details and recipient list for reports and alerts.",
    "SIEM / webhook target (if relevant) + connection details.",
    "POC content approved - which reports, which metrics, which alert "
    "conditions (signed).",
    "An available technical point of contact throughout installation and "
    "acceptance.",
    "Approved installation / reboot window for a controlled reboot.",
]
for i, t in enumerate(reqs, 1):
    bullet(pdf, t, bold_lead=f"{i}.")
pdf.set_font("Helvetica", "B", 9)
pdf.set_text_color(*NAVY)
pdf.multi_cell(0, 5, "Delay in providing any of the above pauses the timeline "
                    "(clock-stop) until it is supplied.")
pdf.ln(3)

# ---- Section 7: Immediate Action Items ----
h1(pdf, "7.  Immediate Action Items (Customer)")
bullet(pdf, "Confirm and provide a list of the database types currently in use.",
       "Database Inventory:")
bullet(pdf, "Create a user named 'dbdome' on each monitored server. This user "
            "must have SYSADMIN privileges and be created using the supplied "
            "script: create user (2).sql.",
       "User Creation:")
bullet(pdf, "24 hours before installation, provide a final list of monitored "
            "servers in scope - Server Name, IP Address, Username, and "
            "Password (see Section 5).",
       "Server List:")
bullet(pdf, "Provide the list of monitoring rules required, selected from the "
            "rules catalog provided.",
       "Rules Catalog:")
pdf.ln(3)

# ---- Section 8: Recommended Rules ----
pdf.add_page()
h1(pdf, "8.  Recommended Monitoring Rules (Baseline)")
body(pdf, "The recommended baseline is the set of Critical rules below - the "
          "minimum coverage activated at go-live. The customer may add further "
          "rules from the catalog and tune thresholds during configuration.")
h2(pdf, "Performance & Availability")
table(pdf,
      ["Rule", "What it detects", "Severity"],
      [
       ["Connectivity / Service Up", "A monitored database is unreachable",
        "Critical"],
       ["Active Sessions & Blocking",
        "Blocking chains / sessions blocked beyond threshold", "Critical"],
       ["Long-Running Transactions",
        "Open transactions exceeding a duration threshold", "Critical"],
       ["Database Performance",
        "Degradation in core DB performance counters", "Critical"],
       ["Query Latency", "Read/write latency above baseline", "Critical"],
       ["Ad-hoc CPU-Consuming Queries",
        "Top queries consuming excessive CPU", "Critical"],
       ["Network / TCP Connection I/O",
        "Abnormal connection volume or I/O", "Critical"],
      ],
      [55, 95, 32])
h2(pdf, "Security & Hardening")
table(pdf,
      ["Rule", "What it detects", "Severity"],
      [
       ["Privileged Logins",
        "New / unexpected sysadmin or privileged logins", "Critical"],
       ["Unmasked Users / Sensitive Data",
        "Sensitive columns exposed without masking", "Critical"],
       ["SQL Injection Indicators",
        "Patterns indicating SQL injection attempts", "Critical"],
       ["Unused / Inactive Logins",
        "Stale logins that should be disabled", "Critical"],
       ["Service Account Permissions",
        "Over-privileged service accounts", "Critical"],
       ["Schema Changes", "Unauthorized DDL / schema drift", "Critical"],
      ],
      [55, 95, 32])
h2(pdf, "Policy Enforcement & Protection")
table(pdf,
      ["Rule", "What it detects", "Severity"],
      [
       ["Database Restored",
        "A database was restored / overwritten (possible data tampering)",
        "Critical"],
       ["Same Login from Multiple Hosts",
        "Identical login active concurrently from different hosts",
        "Critical"],
       ["PII - Comprehensive Coverage",
        "Full discovery & monitoring of PII / sensitive data exposure",
        "Critical"],
      ],
      [55, 95, 32])
pdf.set_font("Helvetica", "I", 9)
pdf.set_text_color(*GREY)
pdf.multi_cell(0, 5, "Available rules vary by database engine (SQL Server, "
                    "Sybase, Oracle, PostgreSQL, MySQL). The full catalog is "
                    "provided during configuration.")
pdf.ln(3)

# ---- Section 9 ----
h1(pdf, "9.  Estimated Timeline")
body(pdf, "Assuming all prerequisites are supplied:")
table(pdf,
      ["Stage", "Description", "Estimate"],
      [
       ["Preparation", "Coordination, gather connection details, POC approval",
        "1-2 days"],
       ["Installation", "Install the service + connect 2 DBs", "1-2 days"],
       ["Configuration", "Configure metrics, reports, alerts per POC", "2-3 days"],
       ["Testing", "End-to-end tests, reboot, validation", "1-2 days"],
       ["Stabilization + Acceptance", "Production run until KPIs are met",
        "7 working days"],
      ],
      [48, 100, 34])
pdf.set_font("Helvetica", "B", 10)
pdf.set_text_color(*NAVY)
pdf.multi_cell(0, 6, "Total to Go-Live & acceptance: approx. 2-3 weeks "
                    "(subject to customer availability and maintenance windows).")
pdf.ln(3)

# ---- Section 10 ----
h1(pdf, "10.  After Acceptance")
body(pdf, "Once acceptance is signed, the installation phase is complete:")
bullet(pdf, "Any new development / feature / integration is delivered under a "
            "work plan, approved in advance.", "New work.")
bullet(pdf, "Ongoing support and maintenance is governed by a separate "
            "support / SLA agreement (to be defined).", "Support.")

out = "C:/dev/dbdome_dbanalytics_service/DBDOME_POC_Success_GoLive.pdf"
pdf.output(out)
print("WROTE", out)
