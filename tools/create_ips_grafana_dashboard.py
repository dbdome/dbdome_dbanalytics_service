"""
Create native Grafana IPS Dashboard in grafana.db.
UID: ips-fortianalyzer
Title: IPS Dashboard - FortiAnalyzer
"""
import json, sqlite3, sys, time, os

_DEV = r"c:\dev\dbdome\data\grafana.db"
DB_PATH = _DEV if os.path.exists(_DEV) else r"C:\ProgramData\DBDOME\data\grafana.db"
DS_UID  = "dezcmrkd94em8f"
DS_TYPE = "grafana-postgresql-datasource"
DASH_UID   = "ips-fortianalyzer"
DASH_TITLE = "IPS Dashboard - FortiAnalyzer"
DASH_SLUG  = "ips-dashboard-fortianalyzer"

ds = {"type": DS_TYPE, "uid": DS_UID}

def target(sql, ref="A", fmt="table"):
    return {
        "datasource": ds,
        "editorMode": "code",
        "format": fmt,
        "rawQuery": True,
        "rawSql": sql,
        "refId": ref,
        "dataset": "dbdome",
        "sql": {"columns": [{"parameters": [], "type": "function"}]},
    }

def stat_panel(pid, title, sql, color, x, y, w=4, h=3):
    return {
        "id": pid, "type": "stat", "title": title,
        "gridPos": {"h": h, "w": w, "x": x, "y": y},
        "datasource": ds,
        "targets": [target(sql)],
        "fieldConfig": {
            "defaults": {
                "color": {"fixedColor": color, "mode": "fixed"},
                "mappings": [],
                "thresholds": {"mode": "absolute", "steps": [{"color": color, "value": None}]},
            },
            "overrides": [],
        },
        "options": {
            "colorMode": "background",
            "graphMode": "none",
            "justifyMode": "center",
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "textMode": "auto",
        },
        "pluginVersion": "12.2.0",
    }

panels = []
pid = 1

# ─── Row 1: 6 stat panels ────────────────────────────────────────────────────
total_sql  = "SELECT COALESCE(SUM(count),0) AS \"Total Events\" FROM siem.fortianalyzer_ips_events"
crit_sql   = "SELECT COALESCE(SUM(count),0) AS \"Critical\" FROM siem.fortianalyzer_ips_events WHERE severity='critical'"
high_sql   = "SELECT COALESCE(SUM(count),0) AS \"High\" FROM siem.fortianalyzer_ips_events WHERE severity='high'"
med_sql    = "SELECT COALESCE(SUM(count),0) AS \"Medium\" FROM siem.fortianalyzer_ips_events WHERE severity='medium'"
blocked_sql= "SELECT COALESCE(SUM(count),0) AS \"Blocked\" FROM siem.fortianalyzer_ips_events WHERE action='blocked'"
mon_sql    = "SELECT COALESCE(SUM(count),0) AS \"Monitored\" FROM siem.fortianalyzer_ips_events WHERE action='monitored'"

panels.append(stat_panel(pid,   "Total Events", total_sql,   "#6e9fff", x=0,  y=0, w=4)); pid+=1
panels.append(stat_panel(pid,   "Critical",     crit_sql,    "#e02f44", x=4,  y=0, w=4)); pid+=1
panels.append(stat_panel(pid,   "High",         high_sql,    "#ff780a", x=8,  y=0, w=4)); pid+=1
panels.append(stat_panel(pid,   "Medium",       med_sql,     "#fade2a", x=12, y=0, w=4)); pid+=1
panels.append(stat_panel(pid,   "Blocked",      blocked_sql, "#e02f44", x=16, y=0, w=4)); pid+=1
panels.append(stat_panel(pid,   "Monitored",    mon_sql,     "#37872d", x=20, y=0, w=4)); pid+=1

# ─── Row 2a: Severity Pie Chart ──────────────────────────────────────────────
pie_sql = "SELECT severity AS \"Severity\", SUM(count) AS \"Count\" FROM siem.fortianalyzer_ips_events GROUP BY severity ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END"
panels.append({
    "id": pid, "type": "piechart", "title": "Intrusions by Severity",
    "gridPos": {"h": 9, "w": 8, "x": 0, "y": 3},
    "datasource": ds,
    "targets": [target(pie_sql)],
    "fieldConfig": {
        "defaults": {"color": {"mode": "palette-classic"}, "custom": {"hideFrom": {"legend": False, "tooltip": False, "viz": False}}},
        "overrides": [
            {"matcher": {"id": "byName", "options": "critical"}, "properties": [{"id": "color", "value": {"fixedColor": "#e02f44", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "high"},     "properties": [{"id": "color", "value": {"fixedColor": "#ff780a", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "medium"},   "properties": [{"id": "color", "value": {"fixedColor": "#fade2a", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "low"},      "properties": [{"id": "color", "value": {"fixedColor": "#37872d", "mode": "fixed"}}]},
        ],
    },
    "options": {"displayLabels": ["name", "percent"], "legend": {"displayMode": "table", "placement": "right", "values": ["value", "percent"]}, "pieType": "pie"},
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Row 2b: Intrusions by Type (horizontal bar) ─────────────────────────────
type_sql = "SELECT intrusion_type AS \"Type\", SUM(count) AS \"Count\" FROM siem.fortianalyzer_ips_events GROUP BY intrusion_type ORDER BY SUM(count) DESC LIMIT 15"
panels.append({
    "id": pid, "type": "barchart", "title": "Intrusions by Type",
    "gridPos": {"h": 9, "w": 16, "x": 8, "y": 3},
    "datasource": ds,
    "targets": [target(type_sql)],
    "fieldConfig": {
        "defaults": {"color": {"mode": "palette-classic"}, "custom": {"fillOpacity": 80, "lineWidth": 0}},
        "overrides": [],
    },
    "options": {
        "barWidth": 0.7,
        "fillOpacity": 80,
        "gradientMode": "none",
        "groupWidth": 0.7,
        "legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
        "orientation": "horizontal",
        "showValue": "auto",
        "stacking": "none",
        "tooltip": {"mode": "single", "sort": "none"},
    },
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Row 3: Timeline (timeseries) ────────────────────────────────────────────
timeline_sql = """SELECT
  hour_bucket AS "time",
  COALESCE(critical,0) AS "Critical",
  COALESCE(high,0) AS "High",
  COALESCE(medium,0) AS "Medium"
FROM siem.v_ips_timeline
WHERE hour_bucket >= NOW() - INTERVAL '7 days'
ORDER BY hour_bucket"""
panels.append({
    "id": pid, "type": "timeseries", "title": "Intrusion Events Timeline (Last 7 Days)",
    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 12},
    "datasource": ds,
    "targets": [target(timeline_sql, fmt="time_series")],
    "fieldConfig": {
        "defaults": {"custom": {"fillOpacity": 20, "lineWidth": 2}},
        "overrides": [
            {"matcher": {"id": "byName", "options": "Critical"}, "properties": [{"id": "color", "value": {"fixedColor": "#e02f44", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "High"},     "properties": [{"id": "color", "value": {"fixedColor": "#ff780a", "mode": "fixed"}}]},
            {"matcher": {"id": "byName", "options": "Medium"},   "properties": [{"id": "color", "value": {"fixedColor": "#fade2a", "mode": "fixed"}}]},
        ],
    },
    "options": {
        "legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
        "tooltip": {"mode": "multi", "sort": "none"},
    },
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Row 4: Blocked + Monitored tables ───────────────────────────────────────
blocked_tbl_sql = "SELECT attack_name AS \"Attack\", intrusion_type AS \"Type\", severity AS \"Severity\", total AS \"Count\" FROM siem.v_ips_blocked ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, total DESC LIMIT 20"
panels.append({
    "id": pid, "type": "table", "title": "Blocked Intrusions",
    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20},
    "datasource": ds,
    "targets": [target(blocked_tbl_sql)],
    "fieldConfig": {
        "defaults": {},
        "overrides": [
            {"matcher": {"id": "byName", "options": "Severity"}, "properties": [
                {"id": "custom.displayMode", "value": "color-background"},
                {"id": "mappings", "value": [
                    {"options": {"critical": {"color": "#e02f44", "index": 0, "text": "Critical"}}, "type": "value"},
                    {"options": {"high":     {"color": "#ff780a", "index": 1, "text": "High"}},     "type": "value"},
                    {"options": {"medium":   {"color": "#fade2a", "index": 2, "text": "Medium"}},   "type": "value"},
                ]},
            ]},
        ],
    },
    "options": {"footer": {"show": False}, "sortBy": []},
    "pluginVersion": "12.2.0",
})
pid += 1

monitored_tbl_sql = "SELECT attack_name AS \"Attack\", intrusion_type AS \"Type\", severity AS \"Severity\", total AS \"Count\" FROM siem.v_ips_monitored ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, total DESC LIMIT 20"
panels.append({
    "id": pid, "type": "table", "title": "Monitored Intrusions",
    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20},
    "datasource": ds,
    "targets": [target(monitored_tbl_sql)],
    "fieldConfig": {
        "defaults": {},
        "overrides": [
            {"matcher": {"id": "byName", "options": "Severity"}, "properties": [
                {"id": "custom.displayMode", "value": "color-background"},
                {"id": "mappings", "value": [
                    {"options": {"critical": {"color": "#e02f44", "index": 0}}, "type": "value"},
                    {"options": {"high":     {"color": "#ff780a", "index": 1}}, "type": "value"},
                    {"options": {"medium":   {"color": "#fade2a", "index": 2}}, "type": "value"},
                ]},
            ]},
        ],
    },
    "options": {"footer": {"show": False}, "sortBy": []},
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Row 5: Sources + Victims tables ─────────────────────────────────────────
sources_sql = "SELECT source_ip AS \"Source IP\", critical AS \"Critical\", high AS \"High\", medium AS \"Medium\", total AS \"Total\", pct_of_total AS \"% of Total\" FROM siem.v_ips_sources ORDER BY total DESC LIMIT 20"
panels.append({
    "id": pid, "type": "table", "title": "Top Attack Sources",
    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 28},
    "datasource": ds,
    "targets": [target(sources_sql)],
    "fieldConfig": {"defaults": {}, "overrides": []},
    "options": {"footer": {"show": False}, "sortBy": []},
    "pluginVersion": "12.2.0",
})
pid += 1

victims_sql = "SELECT victim_ip AS \"Victim IP\", critical AS \"Critical\", high AS \"High\", medium AS \"Medium\", total AS \"Total\", pct_of_total AS \"% of Total\" FROM siem.v_ips_victims ORDER BY total DESC LIMIT 20"
panels.append({
    "id": pid, "type": "table", "title": "Top Victims",
    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 28},
    "datasource": ds,
    "targets": [target(victims_sql)],
    "fieldConfig": {"defaults": {}, "overrides": []},
    "options": {"footer": {"show": False}, "sortBy": []},
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Row 6: HTTP Attacks table ───────────────────────────────────────────────
http_sql = "SELECT attack_name AS \"Attack\", severity AS \"Severity\", total AS \"Count\" FROM siem.v_ips_http_attacks ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, total DESC LIMIT 20"
panels.append({
    "id": pid, "type": "table", "title": "HTTP / HTTPS Attacks",
    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 36},
    "datasource": ds,
    "targets": [target(http_sql)],
    "fieldConfig": {
        "defaults": {},
        "overrides": [
            {"matcher": {"id": "byName", "options": "Severity"}, "properties": [
                {"id": "custom.displayMode", "value": "color-background"},
                {"id": "mappings", "value": [
                    {"options": {"critical": {"color": "#e02f44", "index": 0}}, "type": "value"},
                    {"options": {"high":     {"color": "#ff780a", "index": 1}}, "type": "value"},
                    {"options": {"medium":   {"color": "#fade2a", "index": 2}}, "type": "value"},
                ]},
            ]},
        ],
    },
    "options": {"footer": {"show": False}, "sortBy": []},
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Row 7: dbdome - Dashboards nav panel ────────────────────────────────────
dashboards_content = """**Dashboards**

**By sequence**
- [1. Alerts](/d/ad7kkx7/alerts)
- [2. Data Discovery & Classification](/d/addpcfp/1-data-discovery-and-classification)
- [3. Activity Monitoring & Audit](/d/adbcsrw/2-activity-monitoring-and-audit)
- [4. Threat Detection & Behavioral Analytics](/d/adccmtx/3-threat-detection-and-behavioral-analytics)
- [5. Policy Enforcement & Protection](/d/adln6n5/4-policy-enforcement-and-protection)
- [6. Data Protection](/d/ad88jgn/5-data-protection)
- [7. Vulnerability Assessment](/d/adwb879/6-vulnerability-assessment)
- [8. Automation & Workflows](/d/adsddxs/7-automation-and-workflows)

**Other**
- [IPS Dashboard](http://${global_ip}:8080/siem/ips-dashboard)
- [Security Issues Explorer](/d/sec-explorer/security-issues-explorer)
- [Reports](/d/efd6p9nazfawwb/reports)
- [SQL Injection](/d/adkb745/sql-injection)"""

panels.append({
    "id": pid, "type": "text",
    "title": "dbdome - Dashboards",
    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 44},
    "options": {"content": dashboards_content, "mode": "markdown"},
    "pluginVersion": "12.2.0",
})
pid += 1

# ─── Dashboard links (top-right action buttons) ───────────────────────────────
dashboard_links = [
    {
        "asDropdown": False,
        "icon": "external link",
        "includeVars": False,
        "keepTime": False,
        "tags": [],
        "targetBlank": True,
        "title": "Download PDF",
        "tooltip": "Download IPS Report as PDF",
        "type": "link",
        "url": "http://${global_ip}:8080/api/siem/ips-report/download",
    },
    {
        "asDropdown": False,
        "icon": "external link",
        "includeVars": False,
        "keepTime": False,
        "tags": [],
        "targetBlank": True,
        "title": "Send Report",
        "tooltip": "Send IPS Report by email",
        "type": "link",
        "url": "http://${global_ip}:8080/siem/ips-dashboard",
    },
    {
        "asDropdown": False,
        "icon": "external link",
        "includeVars": False,
        "keepTime": False,
        "tags": [],
        "targetBlank": True,
        "title": "Schedule Weekly",
        "tooltip": "Configure weekly email schedule",
        "type": "link",
        "url": "http://${global_ip}:8080/siem/ips-dashboard",
    },
]

# ─── Full dashboard JSON ──────────────────────────────────────────────────────
dashboard = {
    "__inputs": [],
    "__requires": [],
    "annotations": {"list": []},
    "description": "FortiAnalyzer IPS Events - Intrusion Prevention System monitoring dashboard",
    "editable": True,
    "fiscalYearStartMonth": 0,
    "graphTooltip": 1,
    "id": None,
    "links": dashboard_links,
    "panels": panels,
    "refresh": "5m",
    "schemaVersion": 39,
    "tags": ["siem", "ips", "security"],
    "templating": {"list": []},
    "time": {"from": "now-7d", "to": "now"},
    "timepicker": {},
    "timezone": "",
    "title": DASH_TITLE,
    "uid": DASH_UID,
    "version": 1,
}

# ─── Insert into grafana.db ───────────────────────────────────────────────────
if not os.path.exists(DB_PATH):
    print(f"ERROR: {DB_PATH} not found", file=sys.stderr)
    sys.exit(1)

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# Check if already exists
cur.execute("SELECT id FROM dashboard WHERE uid=?", (DASH_UID,))
existing = cur.fetchone()

data_json = json.dumps(dashboard)

if existing:
    cur.execute("SELECT version FROM dashboard WHERE uid=?", (DASH_UID,))
    ver = cur.fetchone()["version"] + 1
    cur.execute(
        "UPDATE dashboard SET title=?, data=?, version=?, updated=datetime('now') WHERE uid=?",
        (DASH_TITLE, data_json, ver, DASH_UID),
    )
    print(f"Updated existing dashboard uid={DASH_UID} to version {ver}")
else:
    # Find max id
    cur.execute("SELECT MAX(id) AS mx FROM dashboard")
    max_id = (cur.fetchone()["mx"] or 0) + 1
    cur.execute(
        """INSERT INTO dashboard (id, uid, slug, title, data, created, updated, version, is_folder, folder_id, plugin_id, org_id)
           VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'), 1, 0, 0, '', 1)""",
        (max_id, DASH_UID, DASH_SLUG, DASH_TITLE, data_json),
    )
    print(f"Inserted new dashboard uid={DASH_UID} id={max_id}")

conn.commit()
conn.close()
print("Done - dashboard inserted/updated.")

# ─── Now update all "dbdome - Dashboards" panels to add link to IPS Dashboard ──
print("\nAdding Grafana-path IPS Dashboard link to all navigation panels...")

GRAFANA_LINK_TEXT = "- [IPS Dashboard - FortiAnalyzer](/d/ips-fortianalyzer/ips-dashboard-fortianalyzer)"
GRAFANA_LINK_URL  = "/d/ips-fortianalyzer/ips-dashboard-fortianalyzer"

conn2 = sqlite3.connect(DB_PATH)
conn2.row_factory = sqlite3.Row
cur2 = conn2.cursor()
cur2.execute("SELECT id, uid, title, data, version FROM dashboard")
all_dashes = cur2.fetchall()

updated2 = 0
patched2 = 0

for d in all_dashes:
    try:
        dash = json.loads(d["data"])
    except Exception:
        continue

    modified = False
    for panel in dash.get("panels", []):
        title = (panel.get("title") or "").strip().lower()
        if title != "dbdome - dashboards":
            continue
        opts = panel.get("options", {})
        content = opts.get("content") or panel.get("content") or ""
        if GRAFANA_LINK_URL in content:
            continue
        # Insert under **Other** section if present
        if "\n**Other**\n" in content:
            new_content = content.replace("\n**Other**\n", f"\n**Other**\n{GRAFANA_LINK_TEXT}\n", 1)
        elif content.strip():
            new_content = content.rstrip() + "\n" + GRAFANA_LINK_TEXT
        else:
            new_content = GRAFANA_LINK_TEXT
        opts["content"] = new_content
        if "content" in panel:
            panel["content"] = new_content
        modified = True
        patched2 += 1
        print(f"  [+] {d['title']} / \"{panel['title']}\" — added Grafana link")

    if modified:
        ver2 = d["version"] + 1
        cur2.execute(
            "UPDATE dashboard SET data=?, version=?, updated=datetime('now') WHERE id=?",
            (json.dumps(dash), ver2, d["id"]),
        )
        updated2 += 1

conn2.commit()
conn2.close()

print(f"\nDone — added Grafana link to {patched2} nav panel(s) across {updated2} dashboard(s).")
