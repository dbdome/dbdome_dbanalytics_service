"""
Create the Excluded Logins (self-activity) dashboard in grafana.db.
UID: exclude-logins
Title: Excluded Logins - Self Activity

Shows every row of metrics.exclude_logins with a clickable "enable" column
(toggles is_active via http://<ip>:8080/exclude_login_set, same pattern as the
Webhook Alerts Config dashboard) plus a top-right button that opens the
/exclude_logins config web page (add / enable / disable / delete via the
/api/exclude-logins endpoints in http_server.py).
"""
import json, sqlite3, sys, os

# Live DB explicitly: the dev-first fallback (c:\dev\dbdome\data\grafana.db)
# silently swallowed the insert on hosts where the dev copy exists.
DB_PATH = os.environ.get("GRAFANA_DB", r"C:\ProgramData\DBDOME\data\grafana.db")
DS_UID  = "dezcmrkd94em8f"
DS_TYPE = "grafana-postgresql-datasource"
DASH_UID   = "exclude-logins"
DASH_TITLE = "Excluded Logins - Self Activity"
DASH_SLUG  = "excluded-logins-self-activity"
REFERER    = f"d/{DASH_UID}/{DASH_SLUG}"

ds = {"type": DS_TYPE, "uid": DS_UID}

table_sql = (
    'SELECT row_id, login_name, is_active AS "enable", entry_date, '
    "(NOT is_active) AS next_val "
    "FROM metrics.exclude_logins ORDER BY login_name"
)

table_panel = {
    "id": 2, "type": "table",
    "title": "Excluded logins - click the enable cell to toggle",
    "gridPos": {"h": 18, "w": 20, "x": 4, "y": 0},
    "datasource": ds,
    "targets": [{
        "datasource": ds,
        "editorMode": "code",
        "format": "table",
        "rawQuery": True,
        "rawSql": table_sql,
        "refId": "A",
        "sql": {"columns": [{"parameters": [], "type": "function"}]},
    }],
    "fieldConfig": {
        "defaults": {
            "custom": {
                "align": "auto",
                "cellOptions": {"type": "auto"},
                "filterable": True,
                "footer": {"reducers": []},
                "inspect": False,
            },
            "mappings": [],
            "thresholds": {"mode": "absolute",
                           "steps": [{"color": "green", "value": 0}]},
        },
        "overrides": [
            {"matcher": {"id": "byName", "options": "enable"},
             "properties": [
                 {"id": "custom.width", "value": 150},
                 {"id": "links", "value": [{
                     "targetBlank": False,
                     "title": "Toggle",
                     "url": ("http://${global_ip}:8080/exclude_login_set"
                             "?row_id=${__data.fields.row_id}"
                             "&value=${__data.fields.next_val}"
                             f"&referer={REFERER}"),
                 }]},
             ]},
            {"matcher": {"id": "byName", "options": "next_val"},
             "properties": [{"id": "custom.hideFrom.viz", "value": True}]},
            {"matcher": {"id": "byName", "options": "row_id"},
             "properties": [{"id": "custom.width", "value": 90}]},
        ],
    },
    "options": {"cellHeight": "sm", "showHeader": True},
    "pluginVersion": "12.2.0",
}

dashboard_links = [{
    "asDropdown": False,
    "icon": "external link",
    "includeVars": False,
    "keepTime": False,
    "tags": [],
    "targetBlank": True,
    "title": "Configure Excluded Logins",
    "tooltip": "Open the excluded-logins configuration page (add / enable / disable / delete)",
    "type": "link",
    "url": "http://${global_ip}:8080/exclude_logins",
}]

templating = {"list": [{
    "current": {"text": "", "value": ""},
    "definition": "select  config.get_local_ip()",
    "hide": 2,
    "label": "global_ip",
    "name": "global_ip",
    "options": [],
    "query": "select  config.get_local_ip()",
    "refresh": 1,
    "regex": "",
    "type": "query",
}]}

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# Reuse the standard left-hand nav panel from the Webhook Alerts Config dashboard.
nav_panel = None
cur.execute("SELECT data FROM dashboard WHERE uid='adwhcfg1'")
row = cur.fetchone()
if row:
    for p in json.loads(row["data"]).get("panels", []):
        if p.get("type") == "text" and (p.get("title") or "").strip().lower() == "dbdome - dashboards":
            nav_panel = {
                "id": 1, "type": "text", "title": "dbdome - Dashboards",
                "gridPos": {"h": 18, "w": 4, "x": 0, "y": 0},
                "options": {"content": p.get("options", {}).get("content", ""),
                            "mode": "markdown"},
                "pluginVersion": "12.2.0",
            }
            break

panels = ([nav_panel] if nav_panel else []) + [table_panel]

dashboard = {
    "__inputs": [],
    "__requires": [],
    "annotations": {"list": []},
    "description": ("metrics.exclude_logins - logins whose activity DBDOME treats as "
                    "self-activity (never stored / alerted)"),
    "editable": True,
    "fiscalYearStartMonth": 0,
    "graphTooltip": 1,
    "id": None,
    "links": dashboard_links,
    "panels": panels,
    "refresh": "5m",
    "schemaVersion": 39,
    "tags": ["configuration", "self-activity"],
    "templating": templating,
    "time": {"from": "now-6h", "to": "now"},
    "timepicker": {},
    "timezone": "",
    "title": DASH_TITLE,
    "uid": DASH_UID,
    "version": 1,
}

if not os.path.exists(DB_PATH):
    print(f"ERROR: {DB_PATH} not found", file=sys.stderr)
    sys.exit(1)

cur.execute("SELECT id, version FROM dashboard WHERE uid=?", (DASH_UID,))
existing = cur.fetchone()
data_json = json.dumps(dashboard)

if existing:
    ver = existing["version"] + 1
    cur.execute(
        "UPDATE dashboard SET title=?, slug=?, data=?, version=?, updated=datetime('now') WHERE uid=?",
        (DASH_TITLE, DASH_SLUG, data_json, ver, DASH_UID),
    )
    print(f"Updated existing dashboard uid={DASH_UID} to version {ver}")
else:
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
print("Done - Excluded Logins dashboard inserted/updated.")
