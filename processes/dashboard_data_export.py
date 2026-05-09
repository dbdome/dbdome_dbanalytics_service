"""
Dashboard Data Export

Reads monitoring.general_metric_metadata_results and generates per-root-cause
JSON files in the DashboardData format expected by the dbExpertAI client.

Each file contains:
  - charts.Bar: findings by server (matched count per server)
  - charts.Pie: severity distribution
  - charts.Gauge: match rate percentage
  - table (first): metric_metadata_vs_expected rows
  - table2 (second): metric_metadata rows

Output path: derived from config.global_params 'categorydefinitions' parent + /DashboardData/

Registered in scheduler as 'dashboard_data_export'.
"""

import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def _get_output_dir():
    """Get DashboardData output directory from config.global_params key 'dashboarddata'."""
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    try:
        cur.execute("SELECT value FROM config.global_params WHERE key = 'dashboarddata'")
        row = cur.fetchone()
        if not row or not row[0]:
            return None
        return row[0]
    finally:
        cur.close()
        conn.close()


def _safe_json(val):
    """Parse a JSON value that may be a string, dict, list, or None."""
    if val is None:
        return None
    if isinstance(val, (dict, list)):
        return val
    if isinstance(val, str):
        try:
            return json.loads(val)
        except (json.JSONDecodeError, ValueError):
            return None
    return None


def _build_dashboard_json(metric_name, rows):
    """
    Build a DashboardData JSON file for a single root_cause_id.

    rows: list of dicts from general_metric_metadata_results
    """
    # --- Build table 1: metric_metadata_vs_expected ---
    comparison_table = []
    for r in rows:
        comp = _safe_json(r.get("metric_metadata_vs_expected"))
        if comp:
            comparison_table.append({
                "server": r["server"],
                "row_count": comp.get("row_count", 0),
                "matched": comp.get("matched"),
                "condition": comp.get("condition", ""),
                "severity": comp.get("severity", ""),
                "description": (comp.get("expected") or {}).get("description", ""),
                "entry_date": r["entry_date"].isoformat() if r.get("entry_date") else "",
            })

    # --- Build table 2: metric_metadata (sample rows from comparison) ---
    metadata_table = []
    for r in rows:
        comp = _safe_json(r.get("metric_metadata_vs_expected"))
        if comp and comp.get("sample_rows"):
            for sample_row in comp["sample_rows"]:
                row_with_server = {"server": r["server"]}
                row_with_server.update(sample_row)
                metadata_table.append(row_with_server)

    # --- Build table 3: metric_metadata (full query result data) ---
    raw_metadata_table = []
    for r in rows:
        meta = _safe_json(r.get("metric_metadata"))
        if meta and isinstance(meta, list):
            for data_row in meta:
                row_with_context = {
                    "server": r["server"],
                    "entry_date": r["entry_date"].isoformat() if r.get("entry_date") else ""
                }
                row_with_context.update(data_row)
                raw_metadata_table.append(row_with_context)

    # --- Build Bar chart: findings by server ---
    server_counts = {}
    for r in rows:
        comp = _safe_json(r.get("metric_metadata_vs_expected"))
        if comp and comp.get("matched") is True:
            srv = r["server"]
            server_counts[srv] = server_counts.get(srv, 0) + 1

    bar_categories = list(server_counts.keys()) if server_counts else ["No findings"]
    bar_data = list(server_counts.values()) if server_counts else [0]

    # --- Build Pie chart: severity distribution ---
    severity_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    for r in rows:
        comp = _safe_json(r.get("metric_metadata_vs_expected"))
        if comp and comp.get("matched") is True:
            sev = (comp.get("severity") or "medium").lower()
            if sev in severity_counts:
                severity_counts[sev] += 1

    pie_categories = [k for k, v in severity_counts.items() if v > 0]
    pie_data = [v for v in severity_counts.values() if v > 0]
    if not pie_categories:
        pie_categories = ["none"]
        pie_data = [0]

    # --- Build Gauge: match rate ---
    total = len(rows)
    matched = sum(1 for r in rows
                  if (_safe_json(r.get("metric_metadata_vs_expected")) or {}).get("matched") is True)
    match_pct = round((matched / total * 100), 1) if total > 0 else 0

    # --- Assemble ---
    dashboard = {
        "charts": {
            "Bar": {
                "series": [{"name": metric_name, "data": bar_data}],
                "categories": bar_categories,
                "text": f"Findings by server for {metric_name}"
            },
            "Pie": {
                "series": pie_data,
                "categories": pie_categories
            },
            "Gauge": {
                "value": match_pct,
                "min": 0,
                "max": 100,
                "text": f"Match rate: {match_pct}% ({matched}/{total})"
            }
        },
        "table": comparison_table,
        "table2": metadata_table,
        "table3": raw_metadata_table
    }

    return dashboard


def _build_issue_flowchart(issue_id, issue_name, server, rc_rows):
    """
    Build a FlowChart JSON for an issue showing:
    Server → Issue → foreach root_cause → Expected → matched/not matched result

    rc_rows: list of dicts with root_cause_id, root_cause_name, expected, comparison data
    """
    nodes = []
    edges = []
    node_id = 0

    # Node: Server (start)
    node_id += 1
    server_nid = str(node_id)
    nodes.append({
        "id": server_nid,
        "type": "input",
        "data": {"label": f"Server: {server}"},
        "style": {"nodeType": "start"}
    })

    # Node: Issue
    node_id += 1
    issue_nid = str(node_id)
    nodes.append({
        "id": issue_nid,
        "data": {"label": f"{issue_id}\n{issue_name}"},
        "style": {"nodeType": "process"}
    })
    edges.append({
        "id": f"e{server_nid}-{issue_nid}",
        "source": server_nid,
        "target": issue_nid,
        "animated": True
    })

    # Group rc_rows by root_cause_id (latest per RC)
    rc_map = {}
    for r in rc_rows:
        rc_id = r.get("root_cause_id") or r.get("metric_name", "")
        if rc_id not in rc_map:
            rc_map[rc_id] = r

    for rc_id, r in rc_map.items():
        rc_name = r.get("root_cause_name") or rc_id
        comp = _safe_json(r.get("metric_metadata_vs_expected"))
        expected = (comp or {}).get("expected", {})
        condition = (comp or {}).get("condition", "")
        matched = (comp or {}).get("matched")
        severity = (comp or {}).get("severity", "medium")
        row_count = (comp or {}).get("row_count", 0)

        # Node: Root Cause
        node_id += 1
        rc_nid = str(node_id)
        nodes.append({
            "id": rc_nid,
            "data": {"label": f"{rc_id}\n{rc_name}"},
            "style": {"nodeType": "process"}
        })
        edges.append({
            "id": f"e{issue_nid}-{rc_nid}",
            "source": issue_nid,
            "target": rc_nid
        })

        # Node: Expected condition (decision)
        node_id += 1
        exp_nid = str(node_id)
        exp_desc = expected.get("description", condition) if isinstance(expected, dict) else str(expected)
        if len(exp_desc) > 80:
            exp_desc = exp_desc[:77] + "..."
        nodes.append({
            "id": exp_nid,
            "data": {"label": f"Expected:\n{condition}\n{exp_desc}"},
            "style": {"nodeType": "decision"}
        })
        edges.append({
            "id": f"e{rc_nid}-{exp_nid}",
            "source": rc_nid,
            "target": exp_nid
        })

        # Node: Result (matched or not)
        node_id += 1
        res_nid = str(node_id)
        if matched is True:
            res_label = f"MATCHED\nrows: {row_count}\nseverity: {severity}"
            res_type = "error"  # red = finding confirmed
            edge_label = "Yes"
        elif matched is False:
            res_label = f"CLEAR\nrows: {row_count}"
            res_type = "end"  # green = ruled out
            edge_label = "No"
        else:
            res_label = f"UNKNOWN\nrows: {row_count}"
            res_type = "process"
            edge_label = "?"

        nodes.append({
            "id": res_nid,
            "type": "output",
            "data": {"label": res_label},
            "style": {"nodeType": res_type}
        })
        edges.append({
            "id": f"e{exp_nid}-{res_nid}",
            "source": exp_nid,
            "target": res_nid,
            "label": edge_label
        })

    return {
        "charts": {
            "FlowChart": {
                "direction": "LR",
                "nodes": nodes,
                "edges": edges
            }
        }
    }


def export_dashboard_data():
    """Main entry: export all root_cause dashboard JSON files and issue flowcharts."""
    output_dir = _get_output_dir()
    if not output_dir:
        db_write_log("DashboardData output path not configured", 0, "dashboard_data_export", "")
        return

    os.makedirs(output_dir, exist_ok=True)

    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Get all distinct metric_names that have comparison data
        cur.execute("""
            SELECT DISTINCT metric_name
            FROM monitoring.general_metric_metadata_results
            WHERE metric_metadata_vs_expected IS NOT NULL
            ORDER BY metric_name
        """)
        metric_names = [r["metric_name"] for r in cur.fetchall()]

        if not metric_names:
            db_write_log("No metrics with comparison data to export", 0, "dashboard_data_export", "")
            return

        exported = 0
        for metric_name in metric_names:
            try:
                # Fetch latest results for this metric (last 7 days)
                cur.execute("""
                    SELECT server, metric_name, metric_metadata, metric_metadata_vs_expected, entry_date
                    FROM monitoring.general_metric_metadata_results
                    WHERE metric_name = %s
                      AND metric_metadata_vs_expected IS NOT NULL
                      AND entry_date >= NOW() - INTERVAL '7 days'
                    ORDER BY entry_date DESC
                """, (metric_name,))
                rows = cur.fetchall()

                if not rows:
                    continue

                dashboard = _build_dashboard_json(metric_name, rows)

                # Write JSON file — filename is the metric_name (root_cause_id)
                filename = f"{metric_name}.json"
                filepath = os.path.join(output_dir, filename)
                with open(filepath, 'w', encoding='utf-8') as f:
                    json.dump(dashboard, f, indent=None, ensure_ascii=False)

                exported += 1

            except Exception as e:
                db_write_log(
                    f"Failed to export dashboard for {metric_name}: {e}",
                    0, "dashboard_data_export", ""
                )

        # ========== Export issue-level FlowChart JSONs ==========
        flowcharts = 0
        try:
            cur.execute("""
                SELECT DISTINCT
                    g.server,
                    i.issue_id,
                    i.name AS issue_name,
                    g.metric_name AS root_cause_id,
                    rc.name AS root_cause_name,
                    g.metric_metadata_vs_expected,
                    g.entry_date
                FROM monitoring.general_metric_metadata_results g
                JOIN rootcause.root_causes rc ON rc.root_cause_id = g.metric_name
                JOIN rootcause.issues i ON i.issue_id = rc.issue_id
                WHERE g.metric_metadata_vs_expected IS NOT NULL
                  AND g.entry_date >= NOW() - INTERVAL '7 days'
                ORDER BY g.server, i.issue_id, g.metric_name, g.entry_date DESC
            """)
            all_rows = cur.fetchall()

            # Group by server + issue_id
            issue_groups = {}
            for r in all_rows:
                key = (r["server"], r["issue_id"])
                if key not in issue_groups:
                    issue_groups[key] = {
                        "issue_name": r["issue_name"],
                        "rows": []
                    }
                issue_groups[key]["rows"].append(r)

            for (server, issue_id), group in issue_groups.items():
                try:
                    flowchart = _build_issue_flowchart(
                        issue_id, group["issue_name"], server, group["rows"]
                    )
                    filename = f"{issue_id}.json"
                    filepath = os.path.join(output_dir, filename)
                    with open(filepath, 'w', encoding='utf-8') as f:
                        json.dump(flowchart, f, indent=2, ensure_ascii=False)
                    flowcharts += 1
                except Exception as e:
                    db_write_log(
                        f"Failed to export flowchart for {issue_id}: {e}",
                        0, "dashboard_data_export", server
                    )

        except Exception as e:
            db_write_log(f"Flowchart export failed: {e}", 0, "dashboard_data_export", "")

        db_write_log(
            f"Dashboard data exported: {exported} RC files + {flowcharts} issue flowcharts to {output_dir}",
            0, "dashboard_data_export", ""
        )

    except Exception as e:
        db_write_log(f"dashboard_data_export failed: {e}", 0, "dashboard_data_export", "")

    finally:
        cur.close()
        conn.close()
