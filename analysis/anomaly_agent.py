r"""Transaction / behaviour anomaly agent.

Flags anomalous database transactions captured in
monitoring.general_metric_metadata_results ("Active transactions" and the
PERF-SQL-TX / PERF-SQL-QE metrics) on three axes, then feeds each finding back
into the DBDOME pipeline:

  1. DETECT   - CPU (cpu_time), DURATION (total_elapsed_time) and AFTER_HOURS
                (start_time outside business hours / weekends), by z-score.
  2. MATCH    - select the closest existing root cause for the anomaly:
                  AFTER_HOURS -> SEC-SQL-ACC-010-RC07 (After-hours transaction activity)
                  CPU         -> HLTH-SQL-AD-003-RC04  (Insufficient hardware resources)
                  DURATION    -> HLTH-SQL-AD-001-RC02  (Slow / long-running queries)
                (precedence AFTER_HOURS > CPU > DURATION; verified per vendor,
                 with a fallback), .
  3. STORE    - insert a finding row into monitoring.general_metric_metadata_results
                (metric_name = matched root cause; metric_metadata = the anomalous
                transaction; metric_metadata_vs_expected = a JSON carrying a
                human-readable "description" of the alert).
  4. ALERT    - insert into alerts.alert_log (one alert per server+root_cause per
                hour, matching the collectors' behaviour).

The detector is deterministic; an optional Claude triage (`--explain`, claude -p)
prioritises anomalies. **Writing is gated: dry-run by default; pass --commit to
actually store findings and raise alerts.**

CLI:
    python -m analysis.anomaly_agent                       # detect + show plan (no writes)
    python -m analysis.anomaly_agent --hours 168 --cpu-sigma 3 --dur-sigma 3
    python -m analysis.anomaly_agent --commit              # store findings + raise alerts
    python -m analysis.anomaly_agent --explain             # add Claude triage
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

CLAUDE_BIN = os.environ.get("CLAUDE_BIN", r"C:\Users\yoram\.local\bin\claude.exe")
MODEL = os.environ.get("CLAUDE_MODEL", "opus")

VENDOR_MAP = {
    "mssql": "sqlserver", "sql server": "sqlserver", "sqlserver": "sqlserver",
    "oracle": "oracle", "postgres": "postgresql", "postgresql": "postgresql",
    "mysql": "mysql", "mariadb": "mariadb", "informix": "informix",
}

# axis -> ordered candidate root causes (first one that exists for the vendor wins)
ROOT_CAUSE_MAP = {
    "AFTER_HOURS": ["SEC-SQL-ACC-010-RC07"],
    "CPU":         ["HLTH-SQL-AD-003-RC04", "HLTH-SQL-BR-001-RC04"],
    "DURATION":    ["HLTH-SQL-AD-001-RC02", "HLTH-SQL-AD-001-RC05"],
}
AXIS_PRECEDENCE = ["AFTER_HOURS", "CPU", "DURATION"]
FALLBACK_RC = "SEC-SQL-ACC-010-RC07"  # covers all vendors incl. informix

# Exact metric names that carry per-transaction arrays with cpu_time /
# total_elapsed_time / start_time. An exact IN-list uses the
# (metric_name, entry_date) index; prefix LIKEs on the large PERF-SQL-QE/TX
# families defeat it and scan millions of rows. Extend this list (not a LIKE)
# to add more transaction-capture metrics.
_METRIC_FILTER = (
    "r.metric_name IN ('Active transactions','active transactions',"
    "'PERF-SQL-TX-010-RC02','PERF-SQL-QE-001-RC04')"
)

_SQL = r"""
WITH tx AS (
    SELECT
        r.server,
        r.entry_date,
        r.server_id,
        e->>'login_name'     AS login_name,
        e->>'host_name'      AS host_name,
        e->>'database_name'  AS database_name,
        e->>'command'        AS command,
        e->>'session_id'     AS session_id,
        left(e->>'query_text', 400) AS query_text,
        CASE WHEN e->>'cpu_time'           ~ '^[0-9]+(\.[0-9]+)?$' THEN (e->>'cpu_time')::numeric END           AS cpu_ms,
        CASE WHEN e->>'total_elapsed_time' ~ '^[0-9]+(\.[0-9]+)?$' THEN (e->>'total_elapsed_time')::numeric END AS elapsed_ms,
        e->>'start_time'     AS start_time_raw,
        CASE WHEN e->>'start_time' ~ '^[0-9]{10,}$'
             THEN to_timestamp((e->>'start_time')::bigint / 1000.0)
             ELSE r.entry_date END AS start_ts
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) e
    WHERE r.entry_date >= now() - (%(hours)s || ' hours')::interval
      AND jsonb_typeof(r.metric_metadata) = 'array'
      AND {metric_filter}
      AND e ? 'cpu_time'
      AND ({include_monitoring} OR lower(coalesce(e->>'login_name','')) NOT LIKE '%%dbdome%%')
),
stats AS (
    SELECT avg(cpu_ms) AS acpu, stddev_samp(cpu_ms) AS scpu,
           avg(elapsed_ms) AS ael, stddev_samp(elapsed_ms) AS sel, count(*) AS n
    FROM tx
),
flagged AS (
    SELECT tx.*,
        CASE WHEN s.scpu > 0 AND tx.cpu_ms > greatest(s.acpu + %(cpu_sigma)s * s.scpu, %(min_cpu)s)
             THEN round((tx.cpu_ms - s.acpu) / s.scpu, 1) END AS cpu_z,
        CASE WHEN s.sel > 0 AND tx.elapsed_ms > greatest(s.ael + %(dur_sigma)s * s.sel, %(min_dur)s)
             THEN round((tx.elapsed_ms - s.ael) / s.sel, 1) END AS dur_z,
        (extract(hour FROM tx.start_ts) >= %(after_start)s
         OR extract(hour FROM tx.start_ts) < %(after_end)s
         OR (%(weekends)s AND extract(dow FROM tx.start_ts) IN (0, 6))) AS after_hours
    FROM tx CROSS JOIN stats s
)
SELECT server, server_id, login_name, host_name, database_name, command, session_id,
       cpu_ms, elapsed_ms, start_time_raw,
       to_char(start_ts, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
       cpu_z, dur_z, after_hours, query_text,
       (SELECT n FROM stats) AS sample_size
FROM flagged
WHERE cpu_z IS NOT NULL OR dur_z IS NOT NULL OR after_hours
ORDER BY coalesce(cpu_z, 0) + coalesce(dur_z, 0) + CASE WHEN after_hours THEN 2 ELSE 0 END DESC
LIMIT %(limit)s
"""


def _connect():
    if get_connection_string is None:
        raise RuntimeError("no DB connection helper available")
    import psycopg2
    return psycopg2.connect(get_connection_string())


def detect(cur, hours, cpu_sigma, dur_sigma, min_cpu, min_dur,
           after_start, after_end, weekends, include_monitoring, limit):
    sql = _SQL.replace("{metric_filter}", _METRIC_FILTER).replace(
        "{include_monitoring}", "TRUE" if include_monitoring else "FALSE")
    raw_limit = min(max(limit * 25, 500), 8000)  # over-fetch so dedup still yields ~limit uniques
    cur.execute("SET LOCAL statement_timeout = 90000")
    cur.execute(sql, {
        "hours": hours, "cpu_sigma": cpu_sigma, "dur_sigma": dur_sigma,
        "min_cpu": min_cpu, "min_dur": min_dur, "after_start": after_start,
        "after_end": after_end, "weekends": weekends, "limit": raw_limit})
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    sample = rows[0]["sample_size"] if rows else 0
    # De-duplicate: the same long-running transaction is captured in many
    # consecutive snapshots. Collapse by (server, login, session, start_time),
    # keeping the highest-ranked occurrence (rows are already score-ordered).
    seen, deduped = set(), []
    for r in rows:
        key = (r["server"], r["login_name"], r["session_id"], r["start_time_raw"])
        if key in seen:
            continue
        seen.add(key)
        deduped.append(r)
    return deduped[:limit], sample


def anomaly_types(a):
    t = []
    if a["cpu_z"] is not None:
        t.append("CPU")
    if a["dur_z"] is not None:
        t.append("DURATION")
    if a["after_hours"]:
        t.append("AFTER_HOURS")
    return t


def vendor_for_server(cur, server, _cache={}):
    if server in _cache:
        return _cache[server]
    cur.execute("SELECT db_vendor FROM metrics.servers WHERE server = %s LIMIT 1", (server,))
    row = cur.fetchone()
    v = VENDOR_MAP.get((row[0] or "").lower(), (row[0] or "").lower()) if row else None
    _cache[server] = v
    return v


def match_root_cause(cur, a, _cache={}):
    """Return (root_cause_id, risk_level, rc_name) - the closest existing RC."""
    vendor = vendor_for_server(cur, a["server"])
    types = anomaly_types(a)
    for axis in AXIS_PRECEDENCE:
        if axis not in types:
            continue
        for rc in ROOT_CAUSE_MAP[axis]:
            key = (rc, vendor)
            if key not in _cache:
                cur.execute("""SELECT root_cause_name, min(risk_level)
                               FROM rootcause.v_rootcauses
                               WHERE root_cause_id = %s
                                 AND (%s IS NULL OR lower(vendor_name) = lower(%s))
                               GROUP BY root_cause_name LIMIT 1""",
                            (rc, vendor, vendor))
                _cache[key] = cur.fetchone()
            hit = _cache[key]
            if hit:
                return rc, (hit[1] or "medium"), hit[0]
    # fallback
    cur.execute("SELECT root_cause_name, min(risk_level) FROM rootcause.v_rootcauses WHERE root_cause_id=%s GROUP BY root_cause_name LIMIT 1", (FALLBACK_RC,))
    hit = cur.fetchone()
    return FALLBACK_RC, (hit[1] if hit else "medium"), (hit[0] if hit else FALLBACK_RC)


def severity_for(a, base_risk):
    types = anomaly_types(a)
    strong = (a["cpu_z"] or 0) > 6 or (a["dur_z"] or 0) > 6
    if len(types) >= 3 or ((a["cpu_z"] or 0) > 10):
        return "critical"
    if len(types) >= 2 or strong:
        return "high"
    return base_risk or "medium"


def build_element(a):
    """The anomalous transaction as a metric_metadata element."""
    return {
        "login_name": a["login_name"], "host_name": a["host_name"],
        "database_name": a["database_name"], "command": a["command"],
        "session_id": a["session_id"], "cpu_time": a["cpu_ms"],
        "total_elapsed_time": a["elapsed_ms"], "start_time": a["start_time"],
        "query_text": a["query_text"],
    }


def build_description(a, rc_id, rc_name):
    parts = []
    if a["cpu_z"] is not None:
        parts.append(f"CPU {a['cpu_ms']}ms (z={a['cpu_z']})")
    if a["dur_z"] is not None:
        parts.append(f"duration {a['elapsed_ms']}ms (z={a['dur_z']})")
    if a["after_hours"]:
        parts.append(f"executed after-hours at {a['start_time']}")
    login = a["login_name"] or "unknown"
    return (f"Anomalous transaction by login '{login}' on {a['server']}"
            f"{('/' + a['database_name']) if a['database_name'] else ''}: "
            + ", ".join(parts)
            + f". Matched to root cause {rc_id} ({rc_name}).")


def store(cur, a, rc_id, severity, description):
    """Insert the gmmr finding row + alert_log, matching the collector pipeline."""
    element = build_element(a)
    types = anomaly_types(a)
    vs_expected = {
        "matched": True, "anomaly": True, "source": "anomaly_agent",
        "anomaly_types": types, "severity": severity, "row_count": 1,
        "description": description,
        "cpu_ms": a["cpu_ms"], "cpu_zscore": a["cpu_z"],
        "elapsed_ms": a["elapsed_ms"], "duration_zscore": a["dur_z"],
        "start_time": a["start_time"], "after_hours": bool(a["after_hours"]),
    }
    metric_config = {"source": "anomaly_agent", "query": "(statistical anomaly detection)"}

    # borrow a category_id from a recent row of this server (nullable-safe)
    cur.execute("""SELECT category_id FROM monitoring.general_metric_metadata_results
                   WHERE server = %s AND category_id IS NOT NULL
                   ORDER BY entry_date DESC LIMIT 1""", (a["server"],))
    row = cur.fetchone()
    category_id = row[0] if row else None

    cur.execute("""
        INSERT INTO monitoring.general_metric_metadata_results
            (server, category_id, metric_name, metric_config, metric_metadata,
             metric_metadata_vs_expected, server_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (a["server"], category_id, rc_id, json.dumps(metric_config),
          json.dumps([element], default=str), json.dumps(vs_expected, default=str),
          a["server_id"]))
    try:
        cur.execute("CALL rootcause.update_root_cause_result(%s, %s)", (rc_id, a["server"]))
    except Exception:
        pass  # optional pipeline hook; never block the finding on it

    # one alert per server+root_cause per hour (mirror the collectors)
    cur.execute("""DELETE FROM alerts.alert_log
                   WHERE server = %s AND root_cause_id = %s
                     AND date_trunc('hour', entry_date) = date_trunc('hour', LOCALTIMESTAMP)""",
                (a["server"], rc_id))
    cur.execute("""INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name)
                   VALUES (%s, %s, %s, %s, %s)""",
                (a["server"], rc_id, severity,
                 json.dumps({"description": description, "anomaly": element}, default=str),
                 a["login_name"]))


# ---------- optional Claude triage ----------
def _run_claude(prompt):
    cmd = [CLAUDE_BIN, "-p", prompt, "--output-format", "json", "--max-turns", "1", "--model", MODEL]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          stdin=subprocess.DEVNULL, timeout=600)
    if proc.returncode != 0 or not proc.stdout.strip():
        raise RuntimeError(f"claude failed: {proc.stderr or proc.stdout}")
    env = json.loads(proc.stdout)
    if env.get("is_error"):
        raise RuntimeError(f"claude error: {env.get('subtype')}")
    return env.get("result", ""), env


def triage(anomalies, top=15):
    payload = [{"login": a["login_name"], "server": a["server"], "database": a["database_name"],
                "cpu_ms": a["cpu_ms"], "elapsed_ms": a["elapsed_ms"], "start_time": a["start_time"],
                "types": anomaly_types(a), "cpu_z": a["cpu_z"], "dur_z": a["dur_z"],
                "query": (a["query_text"] or "")[:160]} for a in anomalies[:top]]
    prompt = ("You are a database security analyst. These transactions were flagged as "
              "anomalies (high CPU, long duration, and/or after-hours). For each, judge "
              "whether it is a genuine concern or a benign batch/ETL/reporting/backup job. "
              "Respond ONLY with a JSON array in the same order: "
              '[{"login":"...","verdict":"investigate|benign|watch","priority":"high|medium|low","reason":"1-2 sentences"}]\n\n'
              "ANOMALIES:\n" + json.dumps(payload, ensure_ascii=False, indent=1, default=str))
    text, env = _run_claude(prompt)
    m = re.search(r"\[[\s\S]*\]\s*$", re.sub(r"```(?:json)?", "", text).strip())
    try:
        return (json.loads(m.group(0)) if m else None), env
    except json.JSONDecodeError:
        return None, env


def main():
    ap = argparse.ArgumentParser(description="DBDOME transaction/behaviour anomaly agent")
    ap.add_argument("--hours", type=int, default=168, help="lookback window (default 168 = 7 days)")
    ap.add_argument("--cpu-sigma", type=float, default=3.0)
    ap.add_argument("--dur-sigma", type=float, default=3.0)
    ap.add_argument("--min-cpu", type=float, default=100, help="cpu_ms noise floor")
    ap.add_argument("--min-dur", type=float, default=1000, help="elapsed_ms noise floor")
    ap.add_argument("--after-start", type=int, default=22)
    ap.add_argument("--after-end", type=int, default=6)
    ap.add_argument("--weekends", action="store_true", default=True)
    ap.add_argument("--no-weekends", dest="weekends", action="store_false")
    ap.add_argument("--include-monitoring", action="store_true")
    ap.add_argument("--limit", type=int, default=100)
    ap.add_argument("--commit", action="store_true", help="actually store findings + raise alerts")
    ap.add_argument("--explain", action="store_true", help="Claude triage of the top anomalies")
    args = ap.parse_args()

    conn = _connect()
    conn.autocommit = False
    cur = conn.cursor()
    anomalies, sample = detect(cur, args.hours, args.cpu_sigma, args.dur_sigma,
                               args.min_cpu, args.min_dur, args.after_start, args.after_end,
                               args.weekends, args.include_monitoring, args.limit)

    print(f"Baseline: {sample} transactions / {args.hours}h. Anomalies: {len(anomalies)} "
          f"(CPU>{args.cpu_sigma}s, DUR>{args.dur_sigma}s, AFTER {args.after_start:02d}:00-{args.after_end:02d}:00"
          f"{'+wknd' if args.weekends else ''}). Mode: {'COMMIT' if args.commit else 'DRY-RUN'}\n")

    stored = 0
    for a in anomalies:
        rc_id, base_risk, rc_name = match_root_cause(cur, a)
        sev = severity_for(a, base_risk)
        desc = build_description(a, rc_id, rc_name)
        print(f"  [{'+'.join(anomaly_types(a)):22}] -> {rc_id:22} {sev:8} {str(a['login_name'] or '?'):16} {a['server']}")
        print(f"      {desc}")
        if args.commit:
            store(cur, a, rc_id, sev, desc)
            stored += 1

    if args.commit:
        conn.commit()
        print(f"\nCommitted {stored} finding(s) to monitoring.general_metric_metadata_results + alerts.alert_log.")
    else:
        conn.rollback()
        print("\nDRY-RUN - nothing written. Re-run with --commit to store findings and raise alerts.")
    cur.close(); conn.close()

    if args.explain and anomalies:
        print("\n--- Claude triage ---")
        verdicts, env = triage(anomalies)
        print(f"(session {env.get('session_id')}, cost ${env.get('total_cost_usd', 0):.4f})\n")
        for v in (verdicts or []):
            print(f"  [{v.get('verdict','?'):11} {v.get('priority','?'):6}] {v.get('login','?')}: {v.get('reason','')}")


if __name__ == "__main__":
    main()
