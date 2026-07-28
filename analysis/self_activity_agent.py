r"""Self-activity reviewer agent (LLM feature, powered by `claude -p`).

OFFLINE analyst tool - NOT run by the collector hot path. It finds DBDOME
detections that are permanent FALSE ALARMS (pure state inventories that always
return rows, so their row_count>0 condition always "matches" and they alert every
cycle - DBDOME reading the catalog, not a real incident) and proposes
analysis.suppression_rules entries. The deterministic hot-path filter
(self_activity_filter.py) then enforces those rules: suppressed metrics are not
stored in monitoring.general_metric_metadata_results and not alerted.

It uses claude-opus-4-8 via the Claude Code CLI (`claude -p`), so it needs no
`anthropic` pip package and no API key in .env - the CLI supplies its own auth.

Usage (run on the dev/ops box where claude.exe is installed):
    python -m analysis.self_activity_agent                 # review + report (no changes)
    python -m analysis.self_activity_agent --limit 40
    python -m analysis.self_activity_agent --apply          # insert proposed rules INACTIVE (is_active=false) for human review
    python -m analysis.self_activity_agent --apply --activate   # insert them ACTIVE (enforced immediately)
    python -m analysis.self_activity_agent --explain SEC-SQL-AUTHZ-001-RC01   # plain-English explanation of one detection

Environment:
    CLAUDE_BIN   path to claude.exe (default C:\Users\yoram\.local\bin\claude.exe)
    the DB connection comes from the service .env (utils.utils_config_dotenv).
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

try:
    from utils.utils_config_dotenv import get_connection_string
except Exception:
    try:
        from utils.config_dotenv import get_connection_string
    except Exception:
        get_connection_string = None

try:
    from analysis.self_activity_filter import matching_rule, normalize_sql
except Exception:
    from self_activity_filter import matching_rule, normalize_sql  # type: ignore

CLAUDE_BIN = os.environ.get("CLAUDE_BIN", r"C:\Users\yoram\.local\bin\claude.exe")
MODEL = os.environ.get("CLAUDE_MODEL", "opus")

VENDOR_MAP = {
    "mssql": "sqlserver", "sql server": "sqlserver", "sqlserver": "sqlserver",
    "oracle": "oracle", "postgres": "postgresql", "postgresql": "postgresql",
    "mysql": "mysql", "mariadb": "mariadb", "informix": "informix",
}

SYSTEM_PROMPT = (
    "You are a DBDOME database-security analytics reviewer. DBDOME runs detection "
    "queries against monitored databases to flag security, health and performance "
    "issues; a detection 'matches' (alerts) when its query returns rows. SOME "
    "detections are pure STATE INVENTORIES - they enumerate existing objects (all "
    "users and their roles/privileges, all logins, all roles, configuration "
    "settings) and therefore ALWAYS return rows on any real database. Those are "
    "PERMANENT FALSE ALARMS: row_count>0 always matches, so they alert every cycle "
    "even though nothing bad happened - they reflect DBDOME reading the data "
    "dictionary, not an actual incident or genuine sensitive-data usage. A GENUINE "
    "detection instead surfaces an event, anomaly, violation, or a specific unsafe "
    "condition (a failed login burst, a DROP attempt, an account that is locked, a "
    "privilege that should not exist, a query touching sensitive columns by a "
    "non-service user). Classify each detection you are given."
)


def _fetch_candidates(limit):
    if get_connection_string is None:
        print("no DB connection helper available", file=sys.stderr)
        return []
    import psycopg2
    conn = psycopg2.connect(get_connection_string())
    conn.set_session(readonly=True, autocommit=True)
    cur = conn.cursor()
    cur.execute("SET LOCAL statement_timeout = 30000")
    cur.execute("""
        SELECT DISTINCT ON (r.metric_name)
            r.metric_name,
            lower(s.db_vendor) AS vendor,
            r.metric_config->>'query' AS query,
            left(r.metric_metadata::text, 1500) AS sample_metadata
        FROM monitoring.general_metric_metadata_results r
        JOIN metrics.servers s ON s.server = r.server
        WHERE r.entry_date >= now() - interval '72 hours'
          AND r.metric_name ~ '^(SEC|HLTH|PERF)-'
          AND jsonb_typeof(r.metric_metadata) = 'array'
          AND jsonb_array_length(r.metric_metadata) > 0
          AND r.metric_config->>'query' IS NOT NULL
        ORDER BY r.metric_name, r.entry_date DESC
        LIMIT %s
    """, (limit * 3,))
    rows = cur.fetchall()
    cur.close(); conn.close()

    candidates = []
    for metric_name, vendor, query, sample in rows:
        vendor = VENDOR_MAP.get((vendor or "").lower(), (vendor or "").lower())
        if matching_rule(metric_name, query, vendor):
            continue  # already covered by an active rule
        candidates.append({
            "metric_name": metric_name, "vendor": vendor,
            "query": query, "sample_metadata": sample,
        })
        if len(candidates) >= limit:
            break
    return candidates


def _run_claude(prompt):
    cmd = [CLAUDE_BIN, "-p", prompt, "--output-format", "json",
           "--max-turns", "1", "--model", MODEL]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          stdin=subprocess.DEVNULL, timeout=900)
    if proc.returncode != 0 or not proc.stdout.strip():
        raise RuntimeError(f"claude failed: {proc.stderr or proc.stdout}")
    env = json.loads(proc.stdout)
    if env.get("is_error"):
        raise RuntimeError(f"claude error: {env.get('subtype')}")
    return env.get("result", ""), env


def _extract_json(text):
    cleaned = re.sub(r"```(?:json)?", "", text).strip()
    m = re.search(r"\[[\s\S]*\]\s*$", cleaned)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except json.JSONDecodeError:
        return None


def review(limit, apply, activate):
    candidates = _fetch_candidates(limit)
    if not candidates:
        print("No un-suppressed candidate detections found in the last 72h.")
        return
    print(f"Reviewing {len(candidates)} detection(s) with claude-{MODEL} ...\n")

    payload = [{"metric_name": c["metric_name"], "vendor": c["vendor"],
                "query": c["query"], "sample_result": c["sample_metadata"]}
               for c in candidates]
    prompt = (
        SYSTEM_PROMPT + "\n\n"
        "For each detection below, decide whether it is a benign self-introspection "
        "inventory (permanent false alarm -> should be suppressed) or a genuine "
        "finding. Respond with ONLY a JSON array, one object per detection:\n"
        '[{"metric_name": "...", "vendor": "...", '
        '"verdict": "benign_self_introspection|genuine_finding|uncertain", '
        '"confidence": "high|medium|low", "reason": "one or two sentences"}]\n'
        "No prose before or after the array.\n\nDETECTIONS:\n"
        + json.dumps(payload, ensure_ascii=False, indent=1)
    )
    result_text, env = _run_claude(prompt)
    verdicts = _extract_json(result_text)
    print(f"(claude session {env.get('session_id')}, cost ${env.get('total_cost_usd', 0):.4f})\n")
    if verdicts is None:
        print("Could not parse a JSON verdict array. Raw reply:\n")
        print(result_text)
        return

    by_metric = {c["metric_name"]: c for c in candidates}
    proposals = []
    for v in verdicts:
        mn = v.get("metric_name")
        mark = {"benign_self_introspection": "SUPPRESS", "genuine_finding": "keep",
                "uncertain": "REVIEW"}.get(v.get("verdict"), "?")
        print(f"  [{mark:8}] {v.get('confidence','?'):6} {mn}: {v.get('reason','')}")
        if v.get("verdict") == "benign_self_introspection" and mn in by_metric:
            c = by_metric[mn]
            proposals.append({
                "rule_name": f"auto-{mn.lower()}",
                "vendor": c["vendor"], "metric_name": mn, "query": c["query"],
                "reason": "Proposed by self_activity_agent (claude-" + MODEL + "): "
                          + (v.get("reason") or "benign self-introspection inventory."),
            })

    print(f"\n{len(proposals)} suppression rule(s) proposed.")
    if not apply:
        print("Dry run - re-run with --apply to insert them "
              "(--apply alone inserts INACTIVE for review; add --activate to enforce).")
        return
    if not proposals:
        return

    import psycopg2
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()
    inserted = 0
    for p in proposals:
        cur.execute("""
            INSERT INTO analysis.suppression_rules
                (rule_name, match_mode, vendor_slug, metric_name, sample_query, reason, created_by, is_active)
            VALUES (%s, 'query', %s, %s, %s, %s, 'self_activity_agent', %s)
            ON CONFLICT (rule_name) DO UPDATE SET
                sample_query = EXCLUDED.sample_query, reason = EXCLUDED.reason,
                is_active = EXCLUDED.is_active, updated_at = now()
        """, (p["rule_name"], p["vendor"], p["metric_name"], p["query"], p["reason"], bool(activate)))
        inserted += 1
    conn.commit(); cur.close(); conn.close()
    state = "ACTIVE (enforced now)" if activate else "INACTIVE (review then activate)"
    print(f"Inserted/updated {inserted} rule(s) as {state}.")


def explain(metric_name):
    """Plain-English explanation of a single detection (the root-cause 'explainer')."""
    if get_connection_string is None:
        print("no DB connection helper available", file=sys.stderr); return
    import psycopg2
    conn = psycopg2.connect(get_connection_string())
    conn.set_session(readonly=True, autocommit=True)
    cur = conn.cursor()
    cur.execute("""
        SELECT DISTINCT rc.root_cause_name, rc.root_cause_desc, rc.vendor_name,
               rc.risk_level, rc.content->>'sql' AS detection_sql
        FROM rootcause.v_rootcauses rc
        WHERE rc.root_cause_id = %s
        LIMIT 5
    """, (metric_name,))
    rows = cur.fetchall()
    cur.close(); conn.close()
    if not rows:
        print(f"No root cause {metric_name} found."); return
    ctx = [{"root_cause": r[0], "description": r[1], "vendor": r[2],
            "risk_level": r[3], "detection_sql": r[4]} for r in rows]
    prompt = (
        "You are a database security expert. Explain the following DBDOME detection "
        "to a DBA in plain English: what it looks for, why it matters, what a match "
        "means, and 2-3 concrete remediation steps. Be concise (under 200 words). "
        "Also state whether this reads as a genuine detection or a benign state "
        "inventory that would false-alarm.\n\nDETECTION:\n"
        + json.dumps(ctx, ensure_ascii=False, indent=1)
    )
    text, env = _run_claude(prompt)
    print(text)
    print(f"\n(claude session {env.get('session_id')}, cost ${env.get('total_cost_usd', 0):.4f})")


def main():
    ap = argparse.ArgumentParser(description="DBDOME self-activity reviewer (claude -p)")
    ap.add_argument("--limit", type=int, default=25, help="max detections to review")
    ap.add_argument("--apply", action="store_true", help="insert proposed rules")
    ap.add_argument("--activate", action="store_true", help="insert them as active (enforced)")
    ap.add_argument("--explain", metavar="ROOT_CAUSE_ID", help="explain one detection and exit")
    args = ap.parse_args()
    if args.explain:
        explain(args.explain)
    else:
        review(args.limit, args.apply, args.activate)


if __name__ == "__main__":
    main()
