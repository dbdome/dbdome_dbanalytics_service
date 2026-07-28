r"""Execution-plan analysis agent (PERF-SQL-TX-010-RC02).

Triggered on capture rows in monitoring.general_metric_metadata_results with
metric_name = 'PERF-SQL-TX-010-RC02' whose metric_metadata carries an
execution_plan_xml. Each row's plan is parsed with
monitoring.parse_execution_plan(p_row_id bigint) (one row per plan operator),
then analysed on the axes that matter most:

  physical_op, estimate_rows, estimate_cpu, estimate_io, subtree_cost,
  statement_type, compile_time_ms, missing-index summary (count/impact/table),
  operator warnings (spills, plan-affecting converts) and the object touched.

Per plan it ranks the operators by EstimatedTotalSubtreeCost and reports the
ones that dominate the query's cost (cost share vs the plan root), plus any
missing-index recommendation carried in the plan.

The analysis is written back onto the capture row itself: merged into
monitoring.general_metric_metadata_results.metric_metadata_vs_expected under
a 'plan_analysis' key (the collector's original comparison JSON is preserved).
Rows already carrying 'plan_analysis' are skipped on the next run, so
scheduling this agent makes it trigger once per new capture. **Writing is
gated: dry-run by default; pass --commit to store.**

An optional Claude triage (`--explain`, claude -p, same pattern as
analysis/rootcause_explainer.py) turns the top offenders into a DBA-facing
tuning narrative.

CLI:
    python -m analysis.execution_plan_agent                     # analyse + print (no writes)
    python -m analysis.execution_plan_agent --hours 24 --top 5
    python -m analysis.execution_plan_agent --commit            # store findings
    python -m analysis.execution_plan_agent --commit --explain  # + Claude narrative

Environment:
    CLAUDE_BIN    path to claude.exe (default C:\Users\yoram\.local\bin\claude.exe)
    CLAUDE_MODEL  model alias/id (default: opus)
"""
import argparse
import json
import os
import re
import subprocess
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

import psycopg2

from utils.config_dotenv import get_connection_string

METRIC_NAME = "PERF-SQL-TX-010-RC02"
CLAUDE_BIN = os.environ.get("CLAUDE_BIN", r"C:\Users\yoram\.local\bin\claude.exe")
MODEL = os.environ.get("CLAUDE_MODEL", "opus")

def _connect():
    return psycopg2.connect(get_connection_string())


def fetch_candidates(conn, hours, skip_processed=True):
    """Capture rows with at least one execution plan, newest first."""
    skip = """AND NOT (jsonb_typeof(r.metric_metadata_vs_expected) = 'object'
                       AND r.metric_metadata_vs_expected ? 'plan_analysis')""" if skip_processed else ""
    cur = conn.cursor()
    cur.execute(f"""
        SELECT r.id, r.server, r.entry_date
        FROM monitoring.general_metric_metadata_results r
        WHERE r.metric_name = %s
          AND r.entry_date >= now() - (%s || ' hours')::interval
          AND EXISTS (SELECT 1 FROM jsonb_array_elements(r.metric_metadata) e
                      WHERE e->>'execution_plan_xml' IS NOT NULL)
          {skip}
        ORDER BY r.entry_date DESC
    """, (METRIC_NAME, str(hours)))
    rows = cur.fetchall()
    cur.close()
    return rows


def analyse_capture(conn, capture_id, top_n):
    """Parse one capture row's plan(s) and rank the operators that drive cost.

    Returns a list of per-statement findings: statement context, total cost,
    the top-N operators by subtree_cost with their cost share, and the issue
    flags (missing index, warnings, implicit converts, expensive scans).
    """
    cur = conn.cursor()
    cur.execute("""
        SELECT query_plan_hash, statement_type, statement_text,
               compile_time_ms, compile_cpu_ms, degree_of_parallelism,
               missing_index_count, missing_index_impact, missing_index_table,
               convert_warning_count, convert_issue,
               node_id, physical_op, logical_op, estimate_rows, est_rows_read,
               estimate_cpu, estimate_io, subtree_cost, table_cardinality,
               object_schema, object_table, object_index, index_kind,
               predicate, has_warning, warning_detail
        FROM monitoring.parse_execution_plan(%s::bigint)
    """, (capture_id,))
    cols = [d[0] for d in cur.description]
    ops = [dict(zip(cols, r)) for r in cur.fetchall()]
    cur.close()
    if not ops:
        return []

    findings = []
    # group operators per statement (a capture row may hold several plans)
    by_stmt = {}
    for op in ops:
        by_stmt.setdefault((op["query_plan_hash"], op["statement_text"]), []).append(op)

    for (_plan_hash, stmt_text), stmt_ops in by_stmt.items():
        total_cost = max((o["subtree_cost"] or 0) for o in stmt_ops)
        head = stmt_ops[0]
        ranked = sorted(stmt_ops, key=lambda o: o["subtree_cost"] or 0, reverse=True)

        top_ops, issues = [], []
        for o in ranked[:top_n]:
            cost = float(o["subtree_cost"] or 0)
            share = round(100.0 * cost / float(total_cost), 1) if total_cost else 0.0
            top_ops.append({
                "node_id": o["node_id"],
                "physical_op": o["physical_op"],
                "logical_op": o["logical_op"],
                "table": ".".join(x for x in (o["object_schema"], o["object_table"]) if x) or None,
                "index": o["object_index"], "index_kind": o["index_kind"],
                "estimate_rows": float(o["estimate_rows"] or 0),
                "est_rows_read": float(o["est_rows_read"]) if o["est_rows_read"] is not None else None,
                "estimate_cpu": float(o["estimate_cpu"] or 0),
                "estimate_io": float(o["estimate_io"] or 0),
                "subtree_cost": cost, "cost_share_pct": share,
                "predicate": (o["predicate"] or "")[:300] or None,
                "warning": o["warning_detail"] if o["has_warning"] else None,
            })

        # issue flags -- the "most important issues" checklist
        if head["missing_index_count"]:
            issues.append({
                "issue": "missing_index",
                "count": head["missing_index_count"],
                "impact_pct": float(head["missing_index_impact"] or 0),
                "table": head["missing_index_table"],
            })
        if head["convert_warning_count"]:
            issues.append({"issue": "plan_affecting_convert",
                           "count": head["convert_warning_count"],
                           "detail": head["convert_issue"]})
        if (head["compile_time_ms"] or 0) > 1000:
            issues.append({"issue": "high_compile_time",
                           "compile_time_ms": head["compile_time_ms"],
                           "compile_cpu_ms": head["compile_cpu_ms"]})
        for o in stmt_ops:
            if o["has_warning"]:
                issues.append({"issue": "operator_warning", "node_id": o["node_id"],
                               "physical_op": o["physical_op"], "detail": o["warning_detail"]})
            if (o["physical_op"] or "") in ("Table Scan", "Clustered Index Scan") \
                    and float(o["est_rows_read"] or o["estimate_rows"] or 0) > 10000:
                issues.append({"issue": "expensive_scan", "node_id": o["node_id"],
                               "physical_op": o["physical_op"],
                               "table": ".".join(x for x in (o["object_schema"], o["object_table"]) if x),
                               "est_rows_read": float(o["est_rows_read"] or o["estimate_rows"] or 0)})

        findings.append({
            "statement_type": head["statement_type"],
            "statement_text": (stmt_text or "")[:500],
            "total_subtree_cost": float(total_cost),
            "compile_time_ms": head["compile_time_ms"],
            "degree_of_parallelism": head["degree_of_parallelism"],
            "operator_count": len(stmt_ops),
            "top_cost_operators": top_ops,
            "issues": issues,
        })
    return findings


def _run_claude(prompt):
    cmd = [CLAUDE_BIN, "-p", prompt, "--output-format", "json",
           "--max-turns", "1", "--model", MODEL]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          stdin=subprocess.DEVNULL, timeout=600)
    if proc.returncode != 0 or not proc.stdout.strip():
        raise RuntimeError(f"claude failed: {proc.stderr or proc.stdout}")
    env = json.loads(proc.stdout)
    if env.get("is_error"):
        raise RuntimeError(f"claude error: {env.get('subtype')}")
    return env.get("result", ""), env


def _extract_json_obj(text):
    cleaned = re.sub(r"```(?:json)?", "", text).strip()
    m = re.search(r"\{[\s\S]*\}\s*$", cleaned)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except json.JSONDecodeError:
        return None


def triage(server, findings):
    """Claude tuning narrative for one capture's findings (DBA audience)."""
    prompt = (
        "You are a SQL Server performance expert. Below is the parsed execution-plan "
        f"analysis of a slow active transaction captured on server {server} "
        "(operators ranked by EstimatedTotalSubtreeCost, plus issue flags). "
        "Respond with ONLY a JSON object (no prose before/after):\n"
        '{"bottleneck": "one sentence - the single operation dominating cost", '
        '"root_cause": "why the plan is expensive, grounded in the operators/issues", '
        '"recommendations": ["concrete tuning step", ...], '
        '"expected_gain": "rough expected improvement"}\n\n'
        "ANALYSIS:\n" + json.dumps(findings, ensure_ascii=False, indent=1, default=str)
    )
    text, env = _run_claude(prompt)
    return _extract_json_obj(text) or {"raw": text.strip()}, env


def store(conn, capture_id, findings, narrative):
    """Merge the analysis into the capture row's metric_metadata_vs_expected
    under 'plan_analysis', preserving the collector's original comparison JSON
    (non-object values are wrapped under 'original' rather than clobbered)."""
    analysis = {"statements": findings}
    if narrative:
        analysis["narrative"] = narrative
    cur = conn.cursor()
    cur.execute("""
        UPDATE monitoring.general_metric_metadata_results
        SET metric_metadata_vs_expected =
            CASE
                WHEN metric_metadata_vs_expected IS NULL THEN jsonb_build_object('plan_analysis', %(a)s::jsonb)
                WHEN jsonb_typeof(metric_metadata_vs_expected) = 'object'
                    THEN metric_metadata_vs_expected || jsonb_build_object('plan_analysis', %(a)s::jsonb)
                ELSE jsonb_build_object('original', metric_metadata_vs_expected,
                                        'plan_analysis', %(a)s::jsonb)
            END
        WHERE id = %(id)s
    """, {"a": json.dumps(analysis, ensure_ascii=False, default=str), "id": capture_id})
    cur.close()


def _print_capture(capture_id, server, entry_date, findings):
    print(f"\n=== capture id={capture_id}  server={server}  {entry_date} ===")
    for f in findings:
        print(f"  [{f['statement_type']}] cost={f['total_subtree_cost']:.4f} "
              f"ops={f['operator_count']} compile={f['compile_time_ms']}ms "
              f"dop={f['degree_of_parallelism']}")
        print(f"  sql: {f['statement_text'][:160]}")
        print("  top cost operators:")
        for o in f["top_cost_operators"]:
            tbl = f" on {o['table']}" if o["table"] else ""
            warn = f"  !{o['warning']}" if o["warning"] else ""
            print(f"    {o['cost_share_pct']:5.1f}%  {o['physical_op']}{tbl}  "
                  f"rows={o['estimate_rows']:.0f} cpu={o['estimate_cpu']:.4f} "
                  f"io={o['estimate_io']:.4f} cost={o['subtree_cost']:.4f}{warn}")
        for i in f["issues"]:
            print(f"    ISSUE: {json.dumps(i, default=str)}")


def main():
    ap = argparse.ArgumentParser(description="dbexpertai execution-plan agent (PERF-SQL-TX-010-RC02)")
    ap.add_argument("--hours", type=int, default=24, help="lookback window (default 24)")
    ap.add_argument("--top", type=int, default=5, help="top operators per statement (default 5)")
    ap.add_argument("--commit", action="store_true", help="store findings (default: dry-run)")
    ap.add_argument("--explain", action="store_true", help="add Claude tuning narrative")
    ap.add_argument("--all", action="store_true", help="re-analyse rows already stored")
    args = ap.parse_args()

    conn = _connect()
    candidates = fetch_candidates(conn, args.hours, skip_processed=not args.all)
    print(f"{len(candidates)} capture row(s) with execution plans "
          f"(last {args.hours}h{', unprocessed only' if not args.all else ''})")

    stored = 0
    for capture_id, server, entry_date in candidates:
        try:
            findings = analyse_capture(conn, capture_id, args.top)
        except Exception as e:
            print(f"  capture {capture_id}: plan parse failed: {e}")
            continue
        if not findings:
            continue
        _print_capture(capture_id, server, entry_date, findings)

        narrative = None
        if args.explain:
            try:
                narrative, env = triage(server, findings)
                print(f"  --- Claude triage (cost ${env.get('total_cost_usd', 0):.4f}) ---")
                print(f"  bottleneck: {narrative.get('bottleneck')}")
                print(f"  root cause: {narrative.get('root_cause')}")
                for i, r in enumerate(narrative.get("recommendations", []), 1):
                    print(f"    {i}. {r}")
            except Exception as e:
                print(f"  Claude triage failed: {e}")

        if args.commit:
            store(conn, capture_id, findings, narrative)
            stored += 1

    if args.commit:
        conn.commit()
        print(f"\nCommitted {stored} finding(s) into metric_metadata_vs_expected (plan_analysis).")
    else:
        conn.rollback()
        print("\nDRY-RUN - nothing written. Re-run with --commit to store findings.")
    conn.close()


if __name__ == "__main__":
    main()
