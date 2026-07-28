# -*- coding: utf-8 -*-
"""
Single source of truth for the DBDOME HTTP API functionality documentation.

Exposes:
  * API_META, API_CATALOG  - the documented endpoint catalog (v1 data API)
  * render_html()          - full self-contained HTML page (served at /api/v1)
  * render_pdf(path)        - writes DBDOME_HTTP_API_Functionality.pdf (reportlab)

Both renderers read the same catalog so the PDF and the /api/v1 page never drift.
"""

API_META = {
    "title": "DBDOME HTTP API - Functionality Reference",
    "version": "1.0.0",
    "base": "http://<host>:8080",
    "intro": (
        "The DBDOME REST API exposes the data behind the product's dashboards as "
        "JSON. Versioned endpoints live under the stable /api/v1 prefix; the "
        "unversioned /api/... paths remain for backward compatibility. Every "
        "endpoint below is a GET returning application/json."
    ),
    "conventions": [
        ("Versioning", "Stable endpoints are served under /api/v1. The same handlers are also "
                       "reachable at the legacy /api/... paths."),
        ("Time window (from / to)", "Most endpoints accept optional from and to query parameters. Each may be "
                       "Grafana-style epoch milliseconds (e.g. 1784020822440) or an ISO / "
                       "'YYYY-MM-DD HH:MM' local datetime. Aggregation endpoints that had a dashboard "
                       "time filter default to the last 7 days when no window is given."),
        ("Paging", "List endpoints accept limit (default 500, max 5000)."),
        ("Response shape", "List endpoints return {\"<key>\": [ ... ], \"count\": N}; stat endpoints return "
                       "{\"summary\": { ... }}; errors return {\"error\": \"...\"} with HTTP 500 (or "
                       "{\"detail\": \"...\"} with 400 for bad input)."),
        ("OpenAPI", "Machine-readable spec at /openapi.json. Interactive Swagger UI at /docs and "
                       "ReDoc at /redoc, served from locally bundled assets (no internet required "
                       "- works on air-gapped appliances)."),
    ],
}

# group -> list of endpoints. Each endpoint:
#   (v1_path, legacy_path, summary, [ (param, desc), ... ], sample_json_str)
API_CATALOG = [
 ("Alerts", [
   ("/api/v1/alerts/summary", "/api/alerts/summary",
    "Open Alerts header counts: open total and per-severity open counts (SEC-* root causes) plus the number of monitored servers.",
    [("from, to", "time window (optional)")],
    '{"summary": {"total": 157, "open": 150, "critical": 5, "high": 38, "medium": 23, "low": 84, "servers": 23}}'),
   ("/api/v1/alerts/open", "/api/alerts/open",
    "Open Alerts feed - one row per server+root_cause (latest), with server name, root-cause metadata, and mail-sent / blocked timestamps.",
    [("from, to", "time window"), ("risk_level", "critical|high|medium|low"),
     ("server", "exact match"), ("root_cause_id", "exact match"),
     ("status", "open|resolved"), ("limit", "default 500")],
    '{"alerts": [{"row_id": 9004142, "incident_id": 974, "server": "192.168.1.229,1433", "servername": "mssql2012-1433", "risk_level": "low", "status": "resolved", "area": "Auditing", "issue": "...", "root_cause_id": "SEC-SQL-AUD-021-RC01", "root_cause_name": "...", "recipients": null, "occured_at": "2026-07-16 10:15:31", "sent_at": null, "blocked_at": null}], "count": 1}'),
   ("/api/v1/alerts/incidents", "/api/alerts/incidents",
    "Alert incidents (open / resolved lifecycle) with resolution metadata and age.",
    [("status", "open|resolved"), ("risk_level", "severity"),
     ("server", "exact match"), ("limit", "default 500")],
    '{"incidents": [{"incident_id": 974, "server": "...", "root_cause_id": "...", "risk_level": "high", "status": "open", "opened_at": "...", "occurrences": 3, "age_hours": 12.5}], "open": 150, "resolved": 7}'),
   ("/api/v1/alerts/log/{alert_id}", "/api/alerts/log/{alert_id}",
    "Active detection findings for one alert (monitoring.get_alert_log_resultset_byid); each finding's result json is expanded.",
    [("alert_id", "path: the alert_log row / alert id"),
     ("from, to", "optional entry_date window")],
    '{"alert_id": 9004121, "findings": [{"result": {"server": "192.168.1.229:5432", "matched": true, "description": "Archive command failing...", "row_count": 4, "risk_level": "low", "sample_rows": [ ... ]}, "entry_date": "2026-07-13 08:16:02"}], "count": 1}'),
   ("/api/v1/alerts/ransomware", "/api/alerts/ransomware",
    "Ransomware Guard feed (SEC-SQL-AUD-031-*): server, risk, login, session id, root-cause description and truncated sql_text.",
    [("from, to", "window (default last 30 days)"), ("server", "exact match"),
     ("risk_level", "severity"), ("root_cause_id", "defaults to SEC-SQL-AUD-031-% family"),
     ("limit", "default 500")],
    '{"alerts": [{"time": "2026-07-16 09:12:03", "server": "...", "root_cause_id": "SEC-SQL-AUD-031-RC01", "risk_level": "critical", "login_name": "app_user", "session_id": "84", "description": "A user session is overwriting data with encrypted/binary values...", "sql_text": "UPDATE ...", "metric_result_row_id": 8123}], "count": 0}'),
 ]),
 ("Detection catalogs", [
   ("/api/v1/policy-enforcement-and-protection", "/api/policy-enforcement-and-protection",
    "Policy Enforcement & Protection catalog: distinct SEC-domain root causes (id, name, description). Customer-facing names/descriptions only, not the detection logic.",
    [("root_cause_id", "optional exact match"), ("vendor_name", "default sqlserver")],
    '{"root_causes": [{"root_cause_id": "SEC-SQL-ACC-010-RC07", "root_cause_name": "After-hours transaction activity", "root_cause_desc": "Transactions running outside business hours..."}], "count": 515}'),
   ("/api/v1/database-restore", "/api/database-restore",
    "Database restore catalog: SEC-domain root causes in the AZ / CFG / ENC / VS areas (area, issue, id, name, description).",
    [("area_code", "CSV; default AZ,CFG,ENC,VS"), ("root_cause_id", "optional exact match")],
    '{"root_causes": [{"area_name": "Authorization", "issue_name": "Excessive Administrative Privileges", "root_cause_id": "SEC-SQL-AZ-001-RC01", "root_cause_name": "...", "root_cause_desc": "..."}], "count": 280}'),
 ]),
 ("Data protection", [
   ("/api/v1/data-protection/unmasked", "/api/data-protection/unmasked",
    "Data Protection - unmasked sensitive data view (SEC-SQL-PRI-001-RC10): masking support level, encryption/master key counts and masked-column counts per server.",
    [("server", "optional exact match"), ("limit", "default 500")],
    '{"unmasked": [{"server": "181.214.214.254", "edition": "Express Edition (64-bit)", "masking_support_level": "LIMITED_FEATURES", "masked_column_count": null, "product_version": "16.0.1000.6", "entry_date": "2026-06-22 06:07:26"}], "count": 5}'),
 ]),
 ("IPS report", [
   ("/api/v1/ips/summary", "/api/ips/summary",
    "IPS header stats: total / critical / high / medium intrusion events, blocked (FortiAnalyzer IPS) and monitored (mailed).",
    [("from, to", "window (default 7 days)")],
    '{"summary": {"total": 40128, "critical": 302, "high": 2954, "medium": 3939, "blocked": 0, "monitored": 321}}'),
   ("/api/v1/ips/by-severity", "/api/ips/by-severity", "Intrusions grouped by severity.",
    [("from, to", "optional window")],
    '{"by_severity": [{"severity": "critical", "count": 302}], "count": 4}'),
   ("/api/v1/ips/by-type", "/api/ips/by-type", "Top 20 intrusion types (root-cause issue name).",
    [("from, to", "window (default 7 days)")],
    '{"by_type": [{"type": "SQL Injection attempt", "count": 812}], "count": 20}'),
   ("/api/v1/ips/timeline", "/api/ips/timeline", "Intrusion events on an hourly timeline, by severity.",
    [("from, to", "window (default 7 days)")],
    '{"timeline": [{"time": "2026-07-16 09:00:00", "count": 14, "severity": "high"}], "count": 511}'),
   ("/api/v1/ips/monitored", "/api/ips/monitored", "Monitored intrusions by attack / type.",
    [("from, to", "window (default 7 days)")],
    '{"monitored": [{"attack": "...", "type": "...", "count": 42}], "count": 729}'),
   ("/api/v1/ips/blocked", "/api/ips/blocked", "Blocked intrusions by attack / type / severity (top 20).",
    [("from, to", "window (default 7 days)")],
    '{"blocked": [{"attack": "...", "type": "...", "severity": "critical", "count": 9}], "count": 13}'),
   ("/api/v1/ips/top-victims", "/api/ips/top-victims", "Top victim servers by attack / type.",
    [("from, to", "optional window")],
    '{"top_victims": [{"server": "...", "attack": "...", "type": "...", "count": 30}], "count": 75}'),
   ("/api/v1/ips/top-sources", "/api/ips/top-sources", "Top attack sources as a percentage of total, with the matched metric metadata.",
    [("from, to", "window (default 7 days)")],
    '{"top_sources": [{"pct_of_total": 3.2, "metric_metadata": "{...}", "risk_level": "high"}], "count": 11505}'),
 ]),
 ("Retention", [
   ("/api/v1/retention/overview", "/api/retention/overview",
    "Retention overview per category / item: data size, byte size, row count, free space and configured dump-retention months.", [],
    '{"retention": [{"category": "...", "item": "SEC-SQL-...", "root_cause_name": "...", "data_size": "12 MB", "data_bytes": 12582912, "row_count": 40311, "space_free": "...", "retention_months": 12}], "count": 1669}'),
   ("/api/v1/retention/dump-metrics", "/api/retention/dump-metrics",
    "Configured per-metric dump retention (config.dump_metrics).", [],
    '{"dump_metrics": [{"row_id": 1, "metric_name": "SEC-SQL-...", "retention_months": 12, "entry_date": "..."}], "count": 1636}'),
   ("/api/v1/retention/dumps", "/api/retention/dumps",
    "Archived dumps catalog (config.dumps).", [],
    '{"dumps": [{"row_id": 1, "metric_name": "...", "month": 6, "year": 2026, "row_count": 1200, "dump_location": "...", "entry_date": "..."}], "count": 0}'),
   ("/api/v1/retention/dump-location", "/api/retention/dump-location",
    "Current dump / archive location.", [],
    '{"dump_location": [{"dump_location": "D:/dbdome/dumps"}], "count": 1}'),
 ]),
 ("Blocker activity", [
   ("/api/v1/blocker/summary", "/api/blocker/summary",
    "Blocker action counts (killed / dry-run / skipped / errors) and the current dry-run mode.",
    [("from, to", "window (default 7 days)")],
    '{"summary": {"killed": 0, "dry_run": 0, "skipped": 0, "errors": 0, "dry_run_mode": "true"}}'),
   ("/api/v1/blocker/log", "/api/blocker/log",
    "Blocker activity log (alerts.blocker_log): server, vendor, root cause, session, action, detail.",
    [("from, to", "window (default 7 days)"), ("limit", "default 500")],
    '{"blocker_log": [{"entry_date": "...", "server": "...", "db_vendor": "sqlserver", "root_cause_id": "...", "session_id": "84", "action": "killed", "detail": "..."}], "count": 0}'),
   ("/api/v1/blocker/blocks", "/api/blocker/blocks",
    "Executed blocks (alerts.blocks): server, metric, subject, body.",
    [("limit", "default 200")],
    '{"blocks": [{"entry_date": "...", "server": "...", "metric_name": "...", "subject": "...", "body": "..."}], "count": 0}'),
 ]),
 ("Same login from multiple hosts", [
   ("/api/v1/same-login-multihost/findings", "/api/same-login-multihost/findings",
    "Detailed findings for the same-login-from-multiple-hosts detection (SEC-SQL-ACC-010-RC10): login, host count, hosts, session count, queries.",
    [("from, to", "window (default 7 days)")],
    '{"findings": [{"server": "...", "host_count": 3, "hosts": "...", "login_name": "app_user", "session_count": 7, "entry_date": "...", "queries": "..."}], "count": 226}'),
   ("/api/v1/same-login-multihost/root-causes", "/api/same-login-multihost/root-causes",
    "Root cause(s) behind the same-login-multi-host detection.", [],
    '{"root_causes": [{"root_cause_id": "SEC-SQL-ACC-010-RC10", "step_name": "...", "root_cause_desc": "...", "risk_level": "high"}], "count": 1}'),
 ]),
 ("Performance", [
   ("/api/v1/performance/stored-proc-slow", "/api/performance/stored-proc-slow",
    "Stored procedures running slower than their historical average (SEC-SQL-QE-001-RC01): procedure, database, login, avg vs actual duration.",
    [("from, to", "window (default 7 days)"), ("server", "optional"), ("limit", "default 500")],
    '{"slow_procedures": [{"server": "...", "procedure_name": "usp_daily_bill", "database_name": "billing", "login_name": "svc_app", "avg_duration_ms": 120, "actual_duration_ms": 5400, "entry_date": "..."}], "count": 0}'),
 ]),
]


def _esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def endpoint_count():
    return sum(len(eps) for _, eps in API_CATALOG)


# ---------------------------------------------------------------------------
# Full-surface introspection: enumerate EVERY registered route on the live app
# and group into feature sections (same scheme as the DBDOME API reference doc).
# ---------------------------------------------------------------------------
GROUP = {
    "alert-rules": "Alerts, Thresholds & Webhooks", "alert-thresholds": "Alerts, Thresholds & Webhooks",
    "alert_dashboard": "Alerts, Thresholds & Webhooks", "delete-alert-rule": "Alerts, Thresholds & Webhooks",
    "delete-threshold": "Alerts, Thresholds & Webhooks", "delete-webhook-alert": "Alerts, Thresholds & Webhooks",
    "webhook-alerts": "Alerts, Thresholds & Webhooks", "grc-alerts": "Alerts, Thresholds & Webhooks",
    "global-params": "Alerts, Thresholds & Webhooks", "delete-global-param": "Alerts, Thresholds & Webhooks",
    "alerts": "Alerts, Thresholds & Webhooks", "alert-thresholds": "Alerts, Thresholds & Webhooks",
    "compliance-reports": "Compliance Reporting", "reports": "Compliance Reporting",
    "report-schedules": "Compliance Reporting", "toggle-report": "Compliance Reporting",
    "regulation-controls": "Compliance Reporting", "audit-log": "Compliance Reporting",
    "email-panel": "Email & Notifications", "email-panel-form": "Email & Notifications",
    "mail-config": "Email & Notifications", "mail-group": "Email & Notifications",
    "print-panel": "Email & Notifications",
    "masking-rules": "Data Protection & Privacy", "sensitive-schema": "Data Protection & Privacy",
    "retention": "Data Protection & Privacy", "tls": "Data Protection & Privacy",
    "data-protection": "Data Protection & Privacy",
    "risk-scores": "Governance, Risk & Compliance (GRC)", "risk-level": "Governance, Risk & Compliance (GRC)",
    "sod": "Governance, Risk & Compliance (GRC)", "access-review": "Governance, Risk & Compliance (GRC)",
    "policy-exceptions": "Governance, Risk & Compliance (GRC)", "privilege-changes": "Governance, Risk & Compliance (GRC)",
    "evidence-packages": "Governance, Risk & Compliance (GRC)",
    "threat-response": "Threat Response", "firewall-policies": "Firewall Policies",
    "siem": "SIEM Integration", "vulnerability": "Vulnerability Management",
    "ddl-audit": "DDL Audit", "discovery-candidates": "Asset Discovery", "fleet": "Fleet",
    "ips": "IPS Report", "blocker": "Blocker Activity", "same-login-multihost": "Detections",
    "policy-enforcement-and-protection": "Detection Catalogs", "database-restore": "Detection Catalogs",
    "performance": "Performance", "app-logins": "App Login Guard", "programs": "App Login Guard",
    "exclude-logins": "Exclusions",
}


def _humanize(seg):
    return seg.replace("-", " ").replace("_", " ").title()


def _section_of(verb, path):
    if path.startswith("/api"):
        parts = [x for x in path.split("/") if x and not x.startswith("{")]
        seg = parts[1] if len(parts) > 1 else "api"
        return ("2-api", GROUP.get(seg, _humanize(seg)))
    if verb == "GET":
        return ("3-pages", "Web UI Pages (HTML)")
    return ("4-actions", "Web Actions & Form Submissions")


def _fmt_sig(endpoint):
    import inspect
    try:
        sig = inspect.signature(endpoint)
    except (ValueError, TypeError):
        return "none"
    out = []
    for name, p in sig.parameters.items():
        if name in ("self", "request", "background_tasks"):
            continue
        ann = p.annotation
        tn = getattr(ann, "__name__", None) if ann is not inspect._empty else None
        if tn in ("Request", "BackgroundTasks"):
            continue
        s = name + (f": {tn}" if tn else "")
        if p.default is not inspect._empty:
            dv = p.default
            dv = ("None" if dv is None else (dv if isinstance(dv, str) else repr(dv)))
            if len(str(dv)) > 30:
                dv = str(dv)[:27] + "..."
            s += f" = {dv}"
        out.append(s)
    return ";  ".join(out) or "none"


def introspect_sections(app):
    """Enumerate every route on the live FastAPI app -> ordered [(title, [rows])].
    Rows carry verb/path/purpose/args/handler/line. The curated /api/v1 data
    endpoints are excluded here (they are shown in their own section with samples)."""
    import inspect
    seen, rows = set(), []
    SKIP = {"/openapi.json", "/docs", "/redoc", "/docs/oauth2-redirect", "/api/v1", "/api/V1"}
    for route in getattr(app, "routes", []):
        path = getattr(route, "path", None)
        methods = getattr(route, "methods", None)
        endpoint = getattr(route, "endpoint", None)
        if not path or not methods or endpoint is None:
            continue
        if path in SKIP or path.startswith("/api/v1") or path.startswith("/static"):
            continue
        verbs = [m for m in methods if m not in ("HEAD", "OPTIONS")]
        if not verbs:
            continue
        verb = sorted(verbs)[0]
        key = (verb, path)
        if key in seen:
            continue
        seen.add(key)
        doc = inspect.getdoc(endpoint) or ""
        purpose = " ".join(doc.split()) if doc.strip() else _humanize(getattr(endpoint, "__name__", "endpoint"))
        try:
            line = endpoint.__code__.co_firstlineno
        except Exception:
            line = 0
        rc = getattr(route, "response_class", None)
        result = getattr(rc, "__name__", "") or ("HTML" if not path.startswith("/api") else "JSON")
        rows.append({"verb": verb, "path": path, "purpose": purpose,
                     "args": _fmt_sig(endpoint), "handler": getattr(endpoint, "__name__", ""),
                     "line": line, "result": result})
    buckets = {}
    for r in rows:
        order, title = _section_of(r["verb"], r["path"])
        buckets.setdefault((order, title), []).append(r)
    ordered = sorted(buckets.items(), key=lambda kv: (kv[0][0], kv[0][1]))
    for _, items in ordered:
        items.sort(key=lambda r: (r["path"], r["verb"]))
    return [(title, items) for (order, title), items in ordered], len(rows)


def render_html(app=None):
    m = API_META
    full_sections, full_n = (introspect_sections(app) if app is not None else ([], 0))
    n = endpoint_count() + full_n
    parts = []
    parts.append(f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{_esc(m['title'])}</title>
<style>
:root{{--navy:#0E2A47;--steel:#1F4E79;--ink:#1B2733;--grey:#5A6672;--line:#D3DCE6;--bg:#F6F9FC;--code:#0b3d2e;--get:#1B7F4B;}}
*{{box-sizing:border-box}}
body{{margin:0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:var(--ink);background:#fff;line-height:1.5}}
header{{background:var(--navy);color:#fff;padding:22px 28px}}
header h1{{margin:0;font-size:20px}}
header .sub{{opacity:.85;font-size:13px;margin-top:4px}}
.wrap{{max-width:1000px;margin:0 auto;padding:24px 28px 60px}}
h2{{color:var(--steel);border-bottom:2px solid var(--line);padding-bottom:6px;margin:34px 0 14px;font-size:16px}}
h3{{margin:0 0 20px;color:var(--grey);font-weight:500;font-size:14px}}
.intro{{background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:16px 18px;margin:18px 0}}
.conv{{margin:6px 0}}.conv b{{color:var(--steel)}}
.toc{{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0}}
.toc a{{font-size:12px;background:var(--bg);border:1px solid var(--line);border-radius:14px;padding:4px 11px;color:var(--steel);text-decoration:none}}
.ep{{border:1px solid var(--line);border-radius:8px;margin:12px 0;overflow:hidden}}
.ep .top{{display:flex;align-items:center;gap:10px;padding:10px 14px;background:var(--bg);border-bottom:1px solid var(--line);flex-wrap:wrap}}
.badge{{background:var(--get);color:#fff;font-size:11px;font-weight:700;border-radius:4px;padding:2px 7px;letter-spacing:.5px}}
.path{{font-family:ui-monospace,Consolas,monospace;font-size:13px;font-weight:600;color:var(--navy)}}
.legacy{{font-family:ui-monospace,Consolas,monospace;font-size:11px;color:var(--grey)}}
.body{{padding:12px 14px}}
.desc{{margin:0 0 10px}}
table.params{{border-collapse:collapse;width:100%;margin:6px 0 12px;font-size:12.5px}}
table.params th,table.params td{{border:1px solid var(--line);padding:5px 8px;text-align:left;vertical-align:top}}
table.params th{{background:var(--bg);color:var(--steel);width:26%}}
.smpl{{font-family:ui-monospace,Consolas,monospace;font-size:12px;background:#0E2A47;color:#dbe7f3;border-radius:6px;padding:10px 12px;overflow-x:auto;white-space:pre-wrap;word-break:break-word}}
.smpl .k{{color:#7fd1b9}}
.dl{{display:inline-block;margin-top:10px;background:var(--steel);color:#fff;text-decoration:none;font-size:13px;padding:8px 14px;border-radius:6px}}
footer{{color:var(--grey);font-size:12px;border-top:1px solid var(--line);margin-top:30px;padding-top:12px}}
</style></head><body>
<header><h1>{_esc(m['title'])}</h1>
<div class="sub">Version {_esc(m['version'])} &nbsp;·&nbsp; Base URL {_esc(m['base'])} &nbsp;·&nbsp; {n} endpoints</div></header>
<div class="wrap">
<p>{_esc(m['intro'])}</p>
<a class="dl" href="/api/v1/functionality.pdf">&#x2193; Download PDF</a>
<div class="intro"><b>Conventions</b>""")
    for k, v in m["conventions"]:
        parts.append(f'<div class="conv"><b>{_esc(k)}:</b> {_esc(v)}</div>')
    parts.append("</div>")
    # TOC
    parts.append('<div class="toc">')
    parts.append('<a href="#v1-data-api" style="font-weight:700">Versioned data API (v1)</a>')
    for group, _ in API_CATALOG:
        anchor = "v1-" + group.lower().replace(" ", "-")
        parts.append(f'<a href="#{anchor}">{_esc(group)}</a>')
    if full_sections:
        parts.append('<a href="#full-reference" style="font-weight:700">Complete reference</a>')
        for title, _ in full_sections:
            anchor = "f-" + title.lower().replace(" ", "-").replace("&", "and").replace("(", "").replace(")", "").replace(",", "")
            parts.append(f'<a href="#{anchor}">{_esc(title)}</a>')
    parts.append("</div>")
    # ---- Versioned data API (curated, with samples) ----
    parts.append('<h2 id="v1-data-api" style="font-size:17px;border-bottom:2px solid #0E2A47">'
                 'Versioned data API &mdash; /api/v1 <span style="font-weight:400;font-size:13px;color:#5A6672">'
                 '(with response samples)</span></h2>')
    # groups
    for group, eps in API_CATALOG:
        anchor = "v1-" + group.lower().replace(" ", "-")
        parts.append(f'<h2 id="{anchor}">{_esc(group)}</h2>')
        for v1, legacy, summary, params, sample in eps:
            parts.append('<div class="ep"><div class="top">'
                         f'<span class="badge">GET</span>'
                         f'<span class="path">{_esc(v1)}</span>'
                         f'<span class="legacy">legacy: {_esc(legacy)}</span></div><div class="body">')
            parts.append(f'<p class="desc">{_esc(summary)}</p>')
            if params:
                parts.append('<table class="params"><tr><th>Parameter</th><th>Description</th></tr>')
                for pn, pd in params:
                    parts.append(f'<tr><td>{_esc(pn)}</td><td>{_esc(pd)}</td></tr>')
                parts.append('</table>')
            parts.append(f'<div class="smpl">{_esc(sample)}</div>')
            parts.append('</div></div>')
    # ---- Complete endpoint reference (introspected from the live app) ----
    if full_sections:
        VERB_BG = {"GET": "#1B7F4B", "POST": "#1E7846", "PUT": "#AA6E14",
                   "PATCH": "#966414", "DELETE": "#AA2D2D"}
        parts.append('<h2 id="full-reference" style="font-size:17px;border-bottom:2px solid #0E2A47">'
                     f'Complete endpoint reference <span style="font-weight:400;font-size:13px;color:#5A6672">'
                     f'({full_n} endpoints, auto-extracted from http_server.py)</span></h2>')
        for title, items in full_sections:
            anchor = "f-" + title.lower().replace(" ", "-").replace("&", "and").replace("(", "").replace(")", "").replace(",", "")
            parts.append(f'<h3 style="color:#1F4E79;font-weight:700;font-size:14px;margin:18px 0 8px" '
                         f'id="{anchor}">{_esc(title)} <span style="color:#5A6672;font-weight:400">'
                         f'({len(items)})</span></h3>')
            for r in items:
                bg = VERB_BG.get(r["verb"], "#0E2A47")
                parts.append('<div class="ep" style="margin:8px 0"><div class="top">'
                             f'<span class="badge" style="background:{bg}">{_esc(r["verb"])}</span>'
                             f'<span class="path">{_esc(r["path"])}</span>'
                             f'<span class="legacy">{_esc(r["handler"])}() · http_server.py:L{r["line"]}</span>'
                             '</div><div class="body">')
                parts.append(f'<p class="desc">{_esc(r["purpose"])}</p>')
                parts.append(f'<div style="font-size:12px;color:#5A6672"><b>Args:</b> '
                             f'<code style="font-size:11.5px">{_esc(r["args"])}</code> '
                             f'&nbsp;·&nbsp; <b>Returns:</b> {_esc(r["result"])}</div>')
                parts.append('</div></div>')
    parts.append(f'<footer>DBDOME HTTP API v{_esc(m["version"])} &nbsp;·&nbsp; OpenAPI: '
                 f'/openapi.json &nbsp;·&nbsp; Swagger UI: /docs &nbsp;·&nbsp; ReDoc: /redoc</footer>')
    parts.append("</div></body></html>")
    return "".join(parts)


def render_pdf(out_path, app=None):
    full_sections, full_n = (introspect_sections(app) if app is not None else ([], 0))
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                    HRFlowable)
    NAVY = colors.HexColor("#0E2A47"); STEEL = colors.HexColor("#1F4E79")
    GREEN = colors.HexColor("#1B7F4B"); GREY = colors.HexColor("#5A6672")
    LINE = colors.HexColor("#C9D3DD"); BG = colors.HexColor("#EEF2F6"); DARK = colors.HexColor("#0E2A47")
    ss = getSampleStyleSheet()
    def S(n, **k):
        base = k.pop("parent", ss["Normal"]); return ParagraphStyle(n, parent=base, **k)
    body = S("b", fontSize=9, leading=12.5, textColor=colors.HexColor("#1B2733"))
    small = S("s", parent=body, fontSize=7.6, leading=9.6, textColor=GREY)
    h1 = S("h1", fontName="Helvetica-Bold", fontSize=15, leading=18, textColor=NAVY)
    h2 = S("h2", fontName="Helvetica-Bold", fontSize=11.5, leading=14, textColor=STEEL,
           spaceBefore=12, spaceAfter=4)
    pathst = S("p", fontName="Courier-Bold", fontSize=9, leading=11, textColor=NAVY)
    legst = S("lg", fontName="Courier", fontSize=7, leading=9, textColor=GREY)
    desc = S("d", parent=body, fontSize=8.6, leading=11)
    cell = S("c", parent=body, fontSize=7.6, leading=9.4)
    cellb = S("cb", parent=cell, fontName="Helvetica-Bold")
    codest = S("code", fontName="Courier", fontSize=7.2, leading=9, textColor=colors.HexColor("#DBE7F3"))
    elems = []
    m = API_META
    band = Table([[Paragraph(f'<font color="#FFFFFF"><b>{_esc(m["title"])}</b></font>',
                             S("t", parent=body, fontSize=13, textColor=colors.white))]],
                 colWidths=[A4[0] - 30 * mm])
    band.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), NAVY),
                              ("TOPPADDING", (0, 0), (-1, -1), 9), ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
                              ("LEFTPADDING", (0, 0), (-1, -1), 10)]))
    elems += [band, Spacer(1, 6),
              Paragraph(f"Version {m['version']} &nbsp;·&nbsp; Base URL {_esc(m['base'])} &nbsp;·&nbsp; "
                        f"{endpoint_count()} endpoints", small),
              Spacer(1, 6), Paragraph(_esc(m["intro"]), body),
              HRFlowable(width="100%", thickness=0.8, color=LINE, spaceBefore=6, spaceAfter=6),
              Paragraph("Conventions", h2)]
    for k, v in m["conventions"]:
        elems.append(Paragraph(f"<b>{_esc(k)}:</b> {_esc(v)}", S("cv", parent=body, fontSize=8.4,
                                                                 leading=11, spaceAfter=3)))
    PW = A4[0] - 30 * mm
    for group, eps in API_CATALOG:
        elems += [Paragraph(_esc(group), h2)]
        for v1, legacy, summary, params, sample in eps:
            rows = [[Paragraph('<font color="#FFFFFF"><b>GET</b></font>',
                               S("g", parent=cell, alignment=1, textColor=colors.white)),
                     Paragraph(_esc(v1) + f'  <font size=6 color="#5A6672">(legacy {_esc(legacy)})</font>', pathst)]]
            head = Table(rows, colWidths=[12 * mm, PW - 12 * mm])
            head.setStyle(TableStyle([("BACKGROUND", (0, 0), (0, 0), GREEN),
                                      ("BACKGROUND", (1, 0), (1, 0), BG),
                                      ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                                      ("BOX", (0, 0), (-1, -1), 0.4, LINE),
                                      ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                                      ("LEFTPADDING", (0, 0), (-1, -1), 6)]))
            elems += [Spacer(1, 5), head, Spacer(1, 3), Paragraph(_esc(summary), desc)]
            if params:
                pr = [[Paragraph("<b>Parameter</b>", cellb), Paragraph("<b>Description</b>", cellb)]]
                for pn, pd in params:
                    pr.append([Paragraph(_esc(pn), cell), Paragraph(_esc(pd), cell)])
                pt = Table(pr, colWidths=[42 * mm, PW - 42 * mm])
                pt.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.4, LINE),
                                        ("BACKGROUND", (0, 0), (-1, 0), BG),
                                        ("TOPPADDING", (0, 0), (-1, -1), 2.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
                                        ("LEFTPADDING", (0, 0), (-1, -1), 5)]))
                elems += [Spacer(1, 2), pt]
            code = Table([[Paragraph(_esc(sample), codest)]], colWidths=[PW])
            code.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), DARK),
                                      ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                                      ("LEFTPADDING", (0, 0), (-1, -1), 7), ("RIGHTPADDING", (0, 0), (-1, -1), 7)]))
            elems += [Spacer(1, 3), code]

    # ---- Complete endpoint reference (introspected) ----
    if full_sections:
        from reportlab.platypus import PageBreak
        VERB_C = {"GET": GREEN, "POST": colors.HexColor("#1E7846"), "PUT": colors.HexColor("#AA6E14"),
                  "PATCH": colors.HexColor("#966414"), "DELETE": colors.HexColor("#AA2D2D")}
        meta_st = S("m2", parent=small, fontSize=7, textColor=GREY)
        elems += [PageBreak(),
                  Paragraph(f"Complete endpoint reference ({full_n} endpoints)", h1),
                  Paragraph("Auto-extracted from the live service (http_server.py), grouped by feature area.", small),
                  Spacer(1, 4)]
        for title, items in full_sections:
            elems += [Paragraph(f"{_esc(title)}  ({len(items)})", h2)]
            for r in items:
                hd = Table([[Paragraph(f'<font color="#FFFFFF"><b>{_esc(r["verb"])}</b></font>',
                                       S("v", parent=cell, alignment=1, textColor=colors.white)),
                             Paragraph(_esc(r["path"]), pathst)]],
                           colWidths=[14 * mm, PW - 14 * mm])
                hd.setStyle(TableStyle([("BACKGROUND", (0, 0), (0, 0), VERB_C.get(r["verb"], NAVY)),
                                        ("BACKGROUND", (1, 0), (1, 0), BG),
                                        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("BOX", (0, 0), (-1, -1), 0.4, LINE),
                                        ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                                        ("LEFTPADDING", (0, 0), (-1, -1), 6)]))
                elems += [Spacer(1, 3), hd, Paragraph(_esc(r["purpose"]), desc),
                          Paragraph(f'<b>Args:</b> <font face="Courier">{_esc(r["args"])}</font> &nbsp; '
                                    f'<b>Returns:</b> {_esc(r["result"])} &nbsp; '
                                    f'<font color="#8A94A0">{_esc(r["handler"])}() · L{r["line"]}</font>', meta_st)]

    doc = SimpleDocTemplate(out_path, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm,
                            topMargin=12 * mm, bottomMargin=14 * mm,
                            title=m["title"], author="dbexpert.ai")

    def footer(cv, d):
        cv.saveState(); cv.setFont("Helvetica", 7); cv.setFillColor(GREY)
        cv.drawString(15 * mm, 7 * mm, "DBDOME HTTP API - Functionality Reference · dbexpert.ai")
        cv.drawRightString(A4[0] - 15 * mm, 7 * mm, f"Page {d.page}")
        cv.restoreState()
    doc.build(elems, onFirstPage=footer, onLaterPages=footer)
    return out_path


if __name__ == "__main__":
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "DBDOME_HTTP_API_Functionality.pdf"
    render_pdf(out); print("WROTE", out, "|", endpoint_count(), "endpoints")
