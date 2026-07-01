#!/usr/bin/env python3
"""
oracle_rootcause_tester.py  -- on-site Oracle root-cause query tester.

What it does
------------
1. Reads the DBDOME home connection from .env (utils.config_dotenv, decrypts
   PG_PASSWORD) and connects to the dbanalytics catalog (PostgreSQL).
2. Loads the monitored ORACLE servers from metrics.servers (db_vendor='oracle';
   the per-server password is decrypted with utils.secrets_crypto).
3. Loads every ORACLE root-cause detection query from rootcause.v_rootcauses
   (vendor_name='oracle'); content->>'sql' is the query to run.
4. For each Oracle server it connects with utils.oracle_client.oracle_connect
   (the same connector production uses) and FIRES each root-cause query,
   reporting per query: rows returned, elapsed ms, condition met, or the error.

Usage (run with the DBDOME venv, e.g. on the appliance):
    /opt/dbdome/venv/bin/python scripts/oracle_rootcause_tester.py
    python scripts/oracle_rootcause_tester.py --rc SEC-SQL-ACC-011-RC02
    python scripts/oracle_rootcause_tester.py --server PRODORA --limit 20 --sample 3
    python scripts/oracle_rootcause_tester.py --list-servers

Generate-then-run workflow:
    # 1) build the per-root-cause query file (params substituted) from the catalog
    python scripts/oracle_rootcause_tester.py --export-queries oracle_rootcause_queries.json
    # 2) run those queries on every oracle server; results stream to the out file
    python scripts/oracle_rootcause_tester.py --queries-file oracle_rootcause_queries.json

Simulation (no Oracle connection):
    Instead of running `df = pd.read_sql_query(oracle_sql, ora_conn)` against a real
    DB, --simulate fabricates a result per rule and runs the SAME comparison the
    collector uses (_build_comparison), then exercises the matched-True / matched-False
    alert decision. The .env flag SAFE (true/false; default true) drives it:
        SAFE=true  -> simulate CLEAN results (matched=False) -> no alerts
        SAFE=false -> simulate BAD results  (matched=True)  -> alerts WOULD fire
    By default alerts are DRY-RUN ONLY: logged as [SIM-ALERT], never sent (no
    email/SIEM, no alerts.alert_log, no inserts). --safe / --unsafe override .env.
        python scripts/oracle_rootcause_tester.py --simulate                 # uses .env SAFE
        python scripts/oracle_rootcause_tester.py --simulate --unsafe        # show what WOULD alert
        python scripts/oracle_rootcause_tester.py --simulate --safe --rc TX-010

    Real side effects (opt-in; require --unsafe so a rule actually matches):
        --create-alert   INSERT each matched rule into alerts.alert_log (real rows,
                         mirrors the collector: one per server+root_cause per hour).
        --send-mail      SEND a real alert email per matched rule via config.mail_config
                         / config.mail_groups and log it to alerts.mail_alert_log.
        --mail-to ADDR   override recipients for --send-mail (so test mail goes to you,
                         not the production group). Comma-separated for several.
        --alert-server N attribute the simulated alert to server name N (default SIM-ORACLE).
    The data is SIMULATED, so these prove the alert/mail pipeline end-to-end without a
    live Oracle hit. --send-mail bypasses the config.webook_alerts authorisation gate
    (it is a delivery test). Examples:
        # fire one rule, email only to yourself, also write the alert row:
        oracle_rootcause_tester --simulate --unsafe --rc TX-010 \
            --create-alert --send-mail --mail-to you@corp.com --alert-server PRODORA
        # create alert_log rows for every oracle rule (no mail):
        oracle_rootcause_tester --simulate --unsafe --create-alert

Options:
    --rc <ID|substring>   only root causes whose root_cause_id matches (e.g. ACC-011-RC02)
    --server <name|ip>    only this server (matches servername or server/ip)
    --limit <N>           cap number of root causes tested (default: all)
    --sample <N>          sample rows to display per query (default 2)
    --fetch-cap <N>       max rows fetched to count (default 5000)
    --timeout <sec>       per-query soft note only (Oracle call timeout if driver supports)
    --list-servers        list discovered Oracle servers and exit
    --include-inactive    include servers where is_active = false
Exit code: 0 if no query errored, 1 if any query raised an error.
"""
import argparse
import json
import os
import re
import sys
import time
import uuid
from datetime import datetime

# Make the repo root importable whether run from repo root or scripts/.
_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
for p in (_ROOT, _HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import psycopg2
    from utils.config_dotenv import get_connection_string   # decrypts PG_PASSWORD
    from utils.secrets_crypto import decrypt_secret          # per-server password
    from utils.oracle_client import oracle_connect           # the production connector
except Exception as e:  # pragma: no cover
    print(f"FATAL: cannot import DBDOME modules / drivers ({e}).")
    print("Run with the DBDOME venv from inside the dbdome_dbanalytics_service tree.")
    sys.exit(2)


# Per-root-cause logging to the DBDOME monitoring log. utils.log4dbexpert is light
# (psycopg2 + config_dotenv only), so this does NOT pull the heavy alert stack.
# Falls back to a no-op if unavailable so the tester still runs fully standalone.
try:
    from utils.log4dbexpert import db_write_log as _db_log
except Exception:
    def _db_log(*_a, **_k):
        return None


def _c(txt, code):
    return f"\033[{code}m{txt}\033[0m" if sys.stdout.isatty() else txt


def _mask(pw):
    if pw is None:
        return None
    s = str(pw)
    return "*" * len(s) if len(s) <= 4 else s[:2] + "*" * (len(s) - 4) + s[-2:]


def safe_decrypt(val):
    """Decrypt a stored secret; never raise. Returns (plaintext_or_None, was_encrypted, error).
    Also treats a no-op decrypt (ciphertext returned unchanged -> key mismatch) as a failure."""
    was_enc = isinstance(val, str) and val.startswith("enc:v1:")
    try:
        out = decrypt_secret(val)
    except Exception as e:
        return None, was_enc, str(e).splitlines()[0][:200]
    if was_enc and isinstance(out, str) and out.startswith("enc:v1:"):
        return None, was_enc, "decryption returned ciphertext (DBDOME_SECRET_KEY mismatch?)"
    return out, was_enc, None


# Match a real :name bind only: name must start with a letter/underscore, and the
# colon must NOT follow a word char or another colon. This protects Oracle format
# masks ('HH24:MI:SS') and time literals ('12:30:00') while still catching binds in
# string literals (INTERVAL ':days_back' DAY) and bare binds (> :threshold_batch).
_PARAM_RE = re.compile(r"(?<![\w:]):([A-Za-z_]\w*)")


def _coerce_param(v):
    """Render a parameter value for inline substitution (numbers bare, strings quoted)."""
    if isinstance(v, dict):
        v = v.get("default", v.get("value"))
    if v is None:
        return None
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def substitute_params(sql, params, default="1"):
    """Inline-substitute :name placeholders, like the collector. Provided RC params
    win; any remaining placeholder gets `default` (1). This mirrors production and
    also fixes placeholders embedded in string literals (e.g. INTERVAL ':days_back' DAY)."""
    if isinstance(params, str):
        try:
            params = json.loads(params)
        except Exception:
            params = None
    pmap = params if isinstance(params, dict) else {}

    def repl(m):
        name = m.group(1)
        if name in pmap:
            c = _coerce_param(pmap[name])
            if c is not None:
                return c
        return str(default)

    return _PARAM_RE.sub(repl, sql)


class ResultsWriter:
    """Stream test results one-by-one to a JSON file, flushing after each so a crash
    mid-run leaves the completed results on disk. Produces valid JSON:
        {"meta": {...}, "results": [ {...}, {...} ], "summary": {...}}"""

    def __init__(self, path, meta):
        self.path = path
        self.n = 0
        self.fh = open(path, "w", encoding="utf-8")
        self.fh.write("{\n")
        self.fh.write('  "meta": ' + json.dumps(meta, ensure_ascii=False, default=str) + ",\n")
        self.fh.write('  "results": [')
        self.fh.flush()

    def add(self, obj):
        self.fh.write(("\n    " if self.n == 0 else ",\n    ")
                      + json.dumps(obj, ensure_ascii=False, default=str))
        self.fh.flush()
        self.n += 1

    def close(self, summary):
        self.fh.write("\n  ],\n")
        self.fh.write('  "summary": ' + json.dumps(summary, ensure_ascii=False, default=str) + "\n}\n")
        self.fh.close()


def load_queries_file(path):
    """Load {root_cause_id, query} pairs produced by --export-queries (or hand-authored).
    Accepts a bare list or an object with a 'queries' list."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    items = data.get("queries", []) if isinstance(data, dict) else data
    out = []
    for it in items:
        rcid = it.get("root_cause_id") or it.get("rootcause")
        q = it.get("query") or it.get("sql")
        if rcid and q:
            out.append({"root_cause_id": rcid, "query": q,
                        "parameters": it.get("parameters"), "expected": it.get("expected")})
    return out


# --- Results table: persist (root_cause_id, query sent, results) per run -----------
RESULTS_TABLE = "monitoring.oracle_verification_results"


def ensure_results_table(pg):
    """Create the results table if it does not exist (self-provisioning so the
    on-site tester works standalone). If the connected user lacks CREATE
    privilege (the read-only dbdome_mon_usr on-site), fall back to verifying the
    table already exists — it is provisioned by migration 6380 and INSERT is
    granted to the mon user there."""
    ddl = """
            CREATE TABLE IF NOT EXISTS monitoring.oracle_verification_results (
                row_id        BIGSERIAL PRIMARY KEY,
                run_id        TEXT,
                entry_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
                server        TEXT,
                root_cause_id TEXT,
                query         TEXT,
                status        TEXT,
                rows          TEXT,
                elapsed_ms    NUMERIC,
                result_sample JSONB,
                error         TEXT
            )
    """
    try:
        with pg.cursor() as cur:
            cur.execute("CREATE SCHEMA IF NOT EXISTS monitoring")
            cur.execute(ddl)
        pg.commit()
    except Exception:
        pg.rollback()
        with pg.cursor() as cur:
            cur.execute("SELECT to_regclass('monitoring.oracle_verification_results')")
            exists = cur.fetchone()[0] is not None
        pg.commit()
        if not exists:
            raise


def insert_result(pg, run_id, server, rcid, query, status, rows, elapsed_ms, sample, error):
    """Insert one (root_cause_id, query sent, results) row. Never raises."""
    try:
        with pg.cursor() as cur:
            cur.execute(
                """INSERT INTO monitoring.oracle_verification_results
                   (run_id, server, root_cause_id, query, status, rows, elapsed_ms, result_sample, error)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,CAST(%s AS jsonb),%s)""",
                (run_id, server, rcid, query, status,
                 None if rows is None else str(rows), elapsed_ms,
                 None if sample is None else json.dumps(sample, default=str), error))
        pg.commit()
    except Exception as e:
        try:
            pg.rollback()
        except Exception:
            pass
        db_write_log(f"insert_result failed: {e}", 0, "oracle_rootcause_tester", server or "")


def load_oracle_servers(pg, only_server=None, include_inactive=False):
    sql = """
        SELECT servername, server, port, username, password, service_name, dsn, db_version
        FROM metrics.servers
        WHERE lower(db_vendor) = 'oracle'
        {active}
        ORDER BY servername
    """.format(active="" if include_inactive else "AND is_active = true")
    with pg.cursor() as cur:
        cur.execute(sql)
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    if only_server:
        s = only_server.lower()
        rows = [r for r in rows
                if s in str(r["servername"] or "").lower() or s in str(r["server"] or "").lower()]
    return rows


def load_oracle_rootcauses(pg, rc_filter=None, limit=None):
    sql = """
        SELECT DISTINCT ON (root_cause_id)
               root_cause_id, root_cause_name,
               content->>'sql' AS query,
               expected, parameters,
               domain_name, area_name, issue_name, root_cause_desc, risk_level
        FROM rootcause.v_rootcauses
        WHERE vendor_name = 'oracle'
          AND content->>'sql' IS NOT NULL
          {flt}
        ORDER BY root_cause_id
    """.format(flt="AND root_cause_id ILIKE %s" if rc_filter else "")
    with pg.cursor() as cur:
        cur.execute(sql, (f"%{rc_filter}%",) if rc_filter else None)
        cols = [d[0] for d in cur.description]
        rcs = [dict(zip(cols, r)) for r in cur.fetchall()]
    if limit:
        rcs = rcs[:limit]
    return rcs


def run_query(ora_conn, sql, sample, fetch_cap):
    """Execute one query; return (status, rowcount, elapsed_ms, sample_rows, error)."""
    t0 = time.time()
    try:
        cur = ora_conn.cursor()
        cur.execute(sql)
        if cur.description is None:          # non-SELECT (shouldn't happen for detections)
            return ("ok", 0, (time.time() - t0) * 1000, [], None)
        colnames = [d[0] for d in cur.description]
        rows = cur.fetchmany(fetch_cap)
        n = len(rows)
        sample_rows = [dict(zip(colnames, r)) for r in rows[:sample]]
        more = ">=" if n >= fetch_cap else ""
        cur.close()
        return ("ok", f"{more}{n}", (time.time() - t0) * 1000, sample_rows, None)
    except Exception as e:
        return ("error", None, (time.time() - t0) * 1000, [], str(e).splitlines()[0][:300])


# ---------------------------------------------------------------------------
# Copied VERBATIM from collection/oracle/monitoring_metrics_oracle_generic_query.py
# so the simulated matched-logic is byte-for-byte identical to the collector,
# WITHOUT importing that module (which pulls in the whole email/SSRS/SIEM alert
# stack and its heavy deps). Keep in sync if the collector's comparison changes.
# ---------------------------------------------------------------------------
def _substitute_parameters(sql, parameters):
    """Replace :param_name placeholders with literal values from parameters dict."""
    if not parameters or not isinstance(parameters, dict):
        return sql
    for key, value in parameters.items():
        if isinstance(value, str):
            sql = sql.replace(f":{key}", f"'{value}'")
        else:
            sql = sql.replace(f":{key}", str(value))
    return sql


def _build_comparison(metric_metadata_json, expected_raw, step_params=None):
    """Build a metric_metadata_vs_expected JSON comparing actual results to expected."""
    actual_rows = json.loads(metric_metadata_json) if metric_metadata_json else []
    row_count = len(actual_rows)

    if expected_raw is None:
        expected = {}
    elif isinstance(expected_raw, str):
        try:
            expected = json.loads(expected_raw)
        except (json.JSONDecodeError, ValueError):
            expected = {}
    else:
        expected = expected_raw if isinstance(expected_raw, dict) else {}

    condition = expected.get("condition", "")
    if condition and isinstance(step_params, dict) and step_params:
        condition = _substitute_parameters(condition, step_params)
    matched = None

    if condition:
        m = re.match(r"^\s*row_count\s*([><=!]+)\s*(\d+)\s*$", condition, re.IGNORECASE)
        if m:
            op, val = m.group(1), int(m.group(2))
            if op == ">":    matched = row_count > val
            elif op == ">=":  matched = row_count >= val
            elif op == "<":   matched = row_count < val
            elif op == "<=":  matched = row_count <= val
            elif op in ("=", "=="): matched = row_count == val
            elif op in ("!=", "<>"): matched = row_count != val
        elif row_count == 0 and re.match(r"^\s*row_count\s*>", condition, re.IGNORECASE):
            matched = False
    else:
        matched = row_count > 0

    if matched is None:
        matched = False

    return json.dumps({
        "row_count": row_count,
        "sample_rows": actual_rows[:5],
        "expected": expected,
        "condition": condition,
        "matched": matched,
        "severity": expected.get("severity"),
    })


def _resolve_safe(args):
    """SAFE flag: CLI --safe/--unsafe wins, else .env SAFE (default: true).
    safe=True  -> simulate CLEAN results (matched=False) -> no alerts.
    safe=False -> simulate BAD results (matched=True)    -> alerts WOULD fire (dry-run)."""
    if getattr(args, "safe", None) is not None:
        return args.safe
    val = os.getenv("SAFE")
    if val is None:
        return True
    return str(val).strip().lower() in ("1", "true", "yes", "on")


def _simulate_for(expected, step_params, want_matched, build_comparison):
    """Fabricate a result (a JSON array of N rows) whose row_count makes the real
    _build_comparison() return matched == want_matched. We reuse the production
    comparison so the matched logic is identical to the collector. Candidate row
    counts are derived from the integer in the condition (row_count <op> N), so
    this works for >, >=, <, <=, =, != and the default (row_count > 0).
    Returns (metric_metadata_json, comparison_dict, n_rows)."""
    exp = expected
    if isinstance(exp, str):
        try:
            exp = json.loads(exp)
        except Exception:
            exp = {}
    cond = exp.get("condition", "") if isinstance(exp, dict) else ""
    nums = [int(x) for x in re.findall(r"\d+", cond or "")]
    base = nums[0] if nums else 0
    seen, candidates = set(), []
    for c in (0, 1, 2, base - 1, base, base + 1, base + 2, 10, 100):
        if c is None or c < 0 or c in seen:
            continue
        seen.add(c)
        candidates.append(c)
    first = None
    for c in candidates:
        mj = json.dumps([{"_sim": True, "i": k} for k in range(c)])
        comp = json.loads(build_comparison(mj, expected, step_params))
        if first is None:
            first = (mj, comp, c)
        if comp.get("matched") is want_matched:
            return mj, comp, c
    return first  # desired outcome unreachable for this condition; return first try


# ---------------------------------------------------------------------------
# Real side effects (opt-in). These mirror the production collector's alert path
# byte-for-byte but are written SELF-CONTAINED (psycopg2 + smtplib only) so the
# frozen .exe does NOT have to import collection/.../*generic_query.py or
# email_utils.smtp_email_sender (which pulls ssrs -> requests_ntlm, absent in the
# build). Keep in sync if the collector's alert_log / mail logic changes.
# ---------------------------------------------------------------------------
def _create_alert(pg, server, rcid, risk, metadata_rows):
    """Insert one row into alerts.alert_log for a matched rule, mirroring the
    collector: drop any earlier alert for this (server, root_cause_id) in the
    current hour, then insert. pg.autocommit is True so this commits at once."""
    meta_json = json.dumps(metadata_rows, default=str)
    login_name = None
    if isinstance(metadata_rows, list):
        login_name = next((r.get("login_name") for r in metadata_rows if isinstance(r, dict)), None)
    with pg.cursor() as cur:
        cur.execute(
            """DELETE FROM alerts.alert_log
               WHERE server = %s AND root_cause_id = %s
                 AND date_trunc('hour', entry_date) = date_trunc('hour', LOCALTIMESTAMP)""",
            (server, rcid),
        )
        cur.execute(
            """INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name)
               VALUES (%s, %s, %s, CAST(%s AS jsonb), %s)""",
            (server, rcid, risk, meta_json, login_name),
        )


def _send_alert_mail(pg, rc, server, risk, comparison, metadata_rows, override_to=None):
    """Send a real alert email for a matched rule and log it to alerts.mail_alert_log.
    Reads SMTP settings from config.mail_config JOIN config.mail_groups (the same
    source production uses) and decrypts smtp_password with the shared key. Returns
    (sent_bool, detail). NOTE: this is a delivery test — it intentionally does NOT
    apply the config.webook_alerts domain/risk authorisation gate, so you can prove
    SMTP works regardless of routing config. --mail-to overrides the recipients."""
    import smtplib
    from email.message import EmailMessage

    with pg.cursor() as cur:
        cur.execute(
            """SELECT c.mail_sender, c.smtp_port, c.smtp_user, c.smtp_password,
                      c.tls, c.smtp_server, mg.recipients
               FROM config.mail_config c
               JOIN config.mail_groups mg ON mg.mail_config_id = c.row_id
               LIMIT 1"""
        )
        row = cur.fetchone()
    if not row:
        return False, "no config.mail_config / config.mail_groups row"
    mail_sender, smtp_port, smtp_user, smtp_password, tls, smtp_server, recipients = row
    to = (override_to or recipients or "").strip()
    if not to:
        return False, "no recipients (and no --mail-to given)"

    rcid = rc["root_cause_id"]
    subject = (f"[DBDOME TEST ALERT] {server} - Risk: {risk} - "
               f"domain: {rc.get('domain_name') or ''} - {rcid}")
    body_html = f"""<html><body style="font-family:Arial,sans-serif;background:#f4f6f8;padding:20px;">
    <div style="background:#fff;border-radius:8px;padding:20px;max-width:700px;border-left:6px solid #e74c3c;">
      <h2 style="color:#e74c3c;">&#128680; DBDOME Test Alert</h2>
      <p style="color:#888;font-size:12px;">Generated by oracle_rootcause_tester (simulated data — delivery test).</p>
      <table style="border-collapse:collapse;width:100%;font-size:14px;">
        <tr><td style="padding:8px;"><b>Risk Level</b></td><td style="padding:8px;color:#e74c3c;"><b>{risk}</b></td></tr>
        <tr style="background:#f8f9fa;"><td style="padding:8px;"><b>Server</b></td><td style="padding:8px;">{server}</td></tr>
        <tr><td style="padding:8px;"><b>Domain</b></td><td style="padding:8px;">{rc.get('domain_name') or ''}</td></tr>
        <tr style="background:#f8f9fa;"><td style="padding:8px;"><b>Area</b></td><td style="padding:8px;">{rc.get('area_name') or ''}</td></tr>
        <tr><td style="padding:8px;"><b>Issue</b></td><td style="padding:8px;">{rc.get('issue_name') or ''}</td></tr>
        <tr style="background:#f8f9fa;"><td style="padding:8px;"><b>Root Cause</b></td><td style="padding:8px;">{rc.get('root_cause_name') or rcid} ({rcid})</td></tr>
        <tr><td style="padding:8px;"><b>Description</b></td><td style="padding:8px;">{rc.get('root_cause_desc') or ''}</td></tr>
        <tr style="background:#f8f9fa;"><td style="padding:8px;"><b>Comparison</b></td><td style="padding:8px;"><pre style="margin:0;white-space:pre-wrap;">{json.dumps(comparison, default=str)}</pre></td></tr>
      </table>
    </div></body></html>"""

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = mail_sender
    msg["To"] = to
    msg.set_content(f"DBDOME test alert: {rcid} on {server} (risk {risk}). Please view this email in HTML.")
    msg.add_alternative(body_html, subtype="html")

    s = smtplib.SMTP(smtp_server, int(smtp_port), timeout=20)
    try:
        s.ehlo()
        if tls:
            s.starttls(); s.ehlo()
        if smtp_user and str(smtp_user).strip():
            s.login(smtp_user, decrypt_secret(smtp_password))
        s.send_message(msg)
    finally:
        try:
            s.quit()
        except Exception:
            pass

    with pg.cursor() as cur:
        cur.execute(
            """INSERT INTO alerts.mail_alert_log
               (server, metric_name, transaction_type, body, recipients, subject,
                login_name, metric_metadata_json)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
            (server, rcid, "security_alert", rc.get("root_cause_desc") or "",
             to, subject, None, json.dumps(metadata_rows, default=str)),
        )
    return True, to


def run_simulation(pg, rcs, safe, args):
    """Exercise the collector's comparison + alert decision for every Oracle rule
    WITHOUT touching Oracle: instead of `df = pd.read_sql_query(oracle_sql, ora_conn)`
    we inject a fabricated result. SAFE drives the simulated outcome and alerts are
    DRY-RUN ONLY (logged, never sent): no email/SIEM dispatch, no alerts.alert_log,
    no metric inserts."""
    want_matched = not safe  # safe -> clean (False); unsafe -> bad (True)
    do_alert = bool(getattr(args, "create_alert", False))
    do_mail  = bool(getattr(args, "send_mail", False))
    alert_server = getattr(args, "alert_server", None) or "SIM-ORACLE"
    mail_to = getattr(args, "mail_to", None)
    live = do_alert or do_mail
    actions = []
    if do_alert: actions.append("INSERT alerts.alert_log")
    if do_mail:  actions.append("SEND email + INSERT alerts.mail_alert_log")
    alert_action = ("REAL: " + " ; ".join(actions)) if live else \
                   "dry-run (log only; no email/SIEM, no alert_log, no inserts)"
    writer = ResultsWriter(args.out, {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "mode": "simulate",
        "safe": safe,
        "alert_action": alert_action,
        "alert_server": alert_server if live else None,
        "mail_to": mail_to if do_mail else None,
        "root_causes": len(rcs),
    })
    headline = ("CLEAN results — expect NO alerts" if safe
                else ("BAD results — REAL alerts will be created" if live
                      else "BAD results — alerts WOULD fire (dry-run, nothing is sent)"))
    print(f"\n== SIMULATION (SAFE={safe}) :: {headline} ==")
    if live and not safe:
        print(_c(f"  !! LIVE MODE: {alert_action}", 31))
        print(_c(f"  !! using SIMULATED data; alerts attributed to server '{alert_server}'"
                 + (f"; mail -> {mail_to}" if mail_to else "; mail -> configured group"), 33))
    n_alert = n_clean = n_forced = n_created = n_mailed = 0
    try:
        for rc in rcs:
            expected = rc.get("expected")
            sp = rc.get("parameters")
            if isinstance(sp, str):
                try:
                    sp = json.loads(sp)
                except Exception:
                    sp = None
            mj, comp, nrows = _simulate_for(expected, sp, want_matched, _build_comparison)
            matched = comp.get("matched")
            rcid = rc["root_cause_id"]
            risk = comp.get("severity") or "medium"

            alert_created = mail_sent = False
            mail_detail = None
            if matched is True and not safe:
                # bad result -> production fires alerts here.
                n_alert += 1
                if not live:
                    action = "WOULD_FIRE_ALERT (dry-run: no email/SIEM, no alert_log)"
                    tag = _c("[SIM-ALERT ]", 31)
                else:
                    sim_rows = json.loads(mj) if mj else []
                    parts = []
                    if do_alert:
                        try:
                            _create_alert(pg, alert_server, rcid, risk, sim_rows)
                            alert_created = True; parts.append("alert_log")
                        except Exception as ae:
                            parts.append(f"alert_log FAILED:{str(ae).splitlines()[0][:120]}")
                    if do_mail:
                        try:
                            ok_mail, mail_detail = _send_alert_mail(
                                pg, rc, alert_server, risk, comp, sim_rows, mail_to)
                            mail_sent = ok_mail
                            parts.append(f"mail->{mail_detail}" if ok_mail else f"mail SKIPPED:{mail_detail}")
                        except Exception as me:
                            parts.append(f"mail FAILED:{str(me).splitlines()[0][:120]}")
                    action = "FIRED_ALERT (" + "; ".join(parts) + ")"
                    tag = _c("[SIM-FIRED ]", 31)
                    _db_log(f"FIRED rc={rcid} server={alert_server} risk={risk} -> {action}",
                            0, "oracle_rootcause_tester", alert_server)
            elif matched is True and safe:
                # wanted clean but the condition makes matched always-true (e.g. row_count >= 0);
                # SAFE still suppresses, so no alert — flagged so you can spot such rules.
                n_forced += 1
                action = "no_alert (condition forces matched=True; SAFE suppresses)"
                tag = _c("[SIM-FORCED]", 33)
            else:
                n_clean += 1
                action = "no_alert (matched=False)"
                tag = _c("[SIM-CLEAN ]", 32)

            if alert_created: n_created += 1
            if mail_sent:     n_mailed += 1
            print(f"  {tag} {rcid:<26} rows={nrows} matched={matched} risk={risk}  -> {action}")
            # monitor (stdout above) AND log: one monitoring-log row per root cause.
            _db_log(f"SIM rc={rcid} safe={safe} matched={matched} risk={risk} -> {action}",
                    0, "oracle_rootcause_tester", "simulate")
            writer.add({
                "rootcause": rcid,
                "safe": safe,
                "simulated_rows": nrows,
                "matched": matched,
                "risk_level": risk,
                "condition": comp.get("condition"),
                "action": action,
                "alert_created": alert_created,
                "mail_sent": mail_sent,
                "mail_detail": mail_detail,
            })
    finally:
        writer.close({"total": writer.n, "would_alert": n_alert,
                      "clean": n_clean, "forced": n_forced,
                      "alerts_created": n_created, "mails_sent": n_mailed})

    label = "fired" if live else "would_alert"
    print(f"\nsimulation: {label}={n_alert}, clean={n_clean}, forced={n_forced} "
          f"-> {os.path.abspath(args.out)}")
    if live:
        print(_c(f"LIVE: alerts.alert_log rows created={n_created}, emails sent={n_mailed}.", 32))
    else:
        print("NOTE: dry-run only — no real email/SIEM sent, no alerts.alert_log written, no inserts.")
    return 0


def main():
    ap = argparse.ArgumentParser(description="DBDOME on-site Oracle root-cause query tester")
    ap.add_argument("--rc")
    ap.add_argument("--server")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--sample", type=int, default=2)
    ap.add_argument("--fetch-cap", type=int, default=5000)
    ap.add_argument("--list-servers", action="store_true")
    ap.add_argument("--include-inactive", action="store_true")
    ap.add_argument("--out", default="oracle_rootcause_test_results.json",
                    help="JSON results file (default: oracle_rootcause_test_results.json)")
    ap.add_argument("--dry-run", action="store_true",
                    help="show per-server connection params (user, host, masked password, "
                         "decrypt status) and exit; no connect, no queries")
    ap.add_argument("--env", help="path to the .env to load (default: ./.env then <exe-dir>/.env)")
    ap.add_argument("--default-param", default="1",
                    help="value substituted for any query :placeholder not supplied by the root "
                         "cause's parameters (default: 1)")
    ap.add_argument("--export-queries", nargs="?", const="oracle_rootcause_queries.json", default=None,
                    metavar="FILE",
                    help="generate a JSON file of {root_cause_id, query} for the oracle root causes "
                         "(params already substituted) and exit; optional path "
                         "(default: oracle_rootcause_queries.json)")
    ap.add_argument("--queries-file", metavar="FILE",
                    help="run the queries loaded from this JSON file (produced by --export-queries) "
                         "instead of reading them from the catalog")
    ap.add_argument("--simulate", action="store_true",
                    help="do NOT connect to Oracle; fabricate a result per rule and exercise the "
                         "collector's comparison + (dry-run) alert decision. SAFE drives the outcome.")
    ap.add_argument("--safe", dest="safe", action="store_true", default=None,
                    help="simulation: force SAFE=true (clean results, matched=False, no alerts). "
                         "Overrides .env SAFE.")
    ap.add_argument("--unsafe", dest="safe", action="store_false",
                    help="simulation: force SAFE=false (bad results, matched=True -> alerts WOULD "
                         "fire). Overrides .env SAFE.")
    ap.add_argument("--create-alert", dest="create_alert", action="store_true",
                    help="simulation + --unsafe: actually INSERT each matched rule into "
                         "alerts.alert_log (real rows; mirrors the collector). Off by default.")
    ap.add_argument("--send-mail", dest="send_mail", action="store_true",
                    help="simulation + --unsafe: actually SEND an alert email per matched rule "
                         "(config.mail_config/mail_groups) and log it to alerts.mail_alert_log. "
                         "Off by default.")
    ap.add_argument("--mail-to", dest="mail_to", metavar="ADDR",
                    help="override recipients for --send-mail (comma-separated) so the test mail "
                         "does not hit the production group.")
    ap.add_argument("--alert-server", dest="alert_server", metavar="NAME", default="SIM-ORACLE",
                    help="server name to attribute simulated alerts to (default: SIM-ORACLE).")
    ap.add_argument("--no-db-results", dest="no_db_results", action="store_true",
                    help="do NOT persist per-query results (root_cause_id, query, results) to "
                         f"{RESULTS_TABLE}; results are written there by default on a --queries-file run.")
    args = ap.parse_args()

    # Standalone-build support: load .env so PG_* and DBDOME_SECRET_KEY are present
    # even when frozen (config_dotenv reads os.getenv). Existing env wins (override=False).
    try:
        from dotenv import load_dotenv
        candidates = [args.env] if args.env else [
            os.path.join(os.getcwd(), ".env"),
            os.path.join(os.path.dirname(os.path.abspath(sys.executable)), ".env"),
        ]
        for envp in candidates:
            if envp and os.path.exists(envp):
                load_dotenv(envp, override=False)
                print(f"loaded env: {envp}")
                break
    except Exception as _e:
        print(f"(warning: could not load .env: {_e})")

    print("== DBDOME Oracle root-cause tester ==")
    print(f"home: connecting to dbanalytics catalog from .env ...")
    try:
        pg = psycopg2.connect(get_connection_string())
        pg.autocommit = True
    except Exception as e:
        print(f"FATAL: cannot connect to the home dbanalytics catalog: {e}")
        return 2

    # --export-queries: build the per-root-cause query file from the catalog and exit.
    if args.export_queries is not None:
        rcs = load_oracle_rootcauses(pg, args.rc, args.limit)
        pg.close()
        items = [{
            "root_cause_id": rc["root_cause_id"],
            "root_cause_name": rc.get("root_cause_name"),
            "query": substitute_params(rc["query"], rc.get("parameters"), args.default_param),
            "expected": rc.get("expected"),
        } for rc in rcs]
        try:
            with open(args.export_queries, "w", encoding="utf-8") as f:
                json.dump({"generated_at": datetime.now().isoformat(timespec="seconds"),
                           "vendor": "oracle", "count": len(items), "queries": items},
                          f, indent=2, ensure_ascii=False, default=str)
            print(f"exported {len(items)} oracle root-cause queries -> {os.path.abspath(args.export_queries)}")
        except Exception as e:
            print(f"FATAL: could not write queries file {args.export_queries}: {e}")
            return 2
        return 0

    # --simulate: fabricate results, no Oracle connection. SAFE (env/CLI) drives the
    # matched outcome; alerts are DRY-RUN ONLY (logged, never dispatched).
    if args.simulate:
        safe = _resolve_safe(args)
        rcs = load_oracle_rootcauses(pg, args.rc, args.limit)
        print(f"oracle root causes to simulate: {len(rcs)}  (SAFE={safe}"
              + (f", filter: {args.rc}" if args.rc else "") + ")")
        if (args.create_alert or args.send_mail) and safe:
            print(_c("NOTE: --create-alert/--send-mail need --unsafe to do anything "
                     "(SAFE=true keeps all rules clean, so nothing matches/fires).", 33))
        if not rcs:
            pg.close()
            print("  (no oracle root causes found)")
            return 0
        try:
            return run_simulation(pg, rcs, safe, args)
        finally:
            pg.close()

    servers = load_oracle_servers(pg, args.server, args.include_inactive)
    print(f"oracle servers discovered: {len(servers)}")
    if args.list_servers:
        for s in servers:
            print(f"  - {s['servername']}  {s['server']}:{s['port']}  service={s['service_name']}  v={s['db_version']}")
        if not servers:
            print("  (no matching oracle servers in metrics.servers)")
        pg.close()
        return 0
    if not servers:
        print("  (no matching oracle servers in metrics.servers)")

    if args.dry_run:
        dry = []
        print("\n-- dry run: connection parameters per oracle server (no connect) --")
        for s in servers:
            pw, enc, derr = safe_decrypt(s["password"])
            host = str(s["server"]).split(":")[0] if s["server"] else s["server"]
            rec = {
                "server": s["servername"], "host": host, "port": s["port"],
                "service_name": s["service_name"], "dsn": s.get("dsn"),
                "username": s["username"],
                "password_encrypted": enc,
                "password_decrypt_ok": derr is None,
                "password_masked": _mask(pw),
                "password_len": (len(pw) if pw else None),
                "decrypt_error": derr,
                "status": "dry-run",
            }
            dry.append(rec)
            flag = _c("decrypt OK", 32) if derr is None else _c(f"DECRYPT FAILED: {derr}", 31)
            print(f"  {str(s['servername']):<22} user={s['username']} "
                  f"{host}:{s['port']}/{s['service_name']} "
                  f"pw[{rec['password_len']}]={rec['password_masked']} enc={enc}  {flag}")
        try:
            with open(args.out, "w", encoding="utf-8") as f:
                json.dump({"generated_at": datetime.now().isoformat(timespec="seconds"),
                           "mode": "dry-run", "servers": len(dry), "results": dry},
                          f, indent=2, ensure_ascii=False, default=str)
            print(f"\ndry-run written -> {os.path.abspath(args.out)}")
        except Exception as e:
            print(f"\nWARNING: could not write JSON to {args.out}: {e}")
        pg.close()
        return 0

    # Query source: a previously exported queries file, or the live catalog.
    if args.queries_file:
        rcs = load_queries_file(args.queries_file)
        source = os.path.abspath(args.queries_file)
        print(f"loaded {len(rcs)} oracle queries from file: {source}")
    else:
        rcs = load_oracle_rootcauses(pg, args.rc, args.limit)
        source = "catalog:rootcause.v_rootcauses"
        print(f"oracle root-cause queries to fire: {len(rcs)}"
              + (f"  (filter: {args.rc})" if args.rc else ""))
    pg.close()
    if not rcs:
        print("  (no oracle root-cause queries to run)")
        return 0

    # Persist per-query results (root_cause_id, query sent, results) to the DB results
    # table. Default ON for a --queries-file run; disable with --no-db-results.
    pg_res = None
    run_id = datetime.now().strftime("%Y%m%d%H%M%S") + "-" + uuid.uuid4().hex[:6]
    if bool(args.queries_file) and not args.no_db_results:
        try:
            pg_res = psycopg2.connect(get_connection_string())
            ensure_results_table(pg_res)
            print(f"persisting results to {RESULTS_TABLE} (run_id={run_id})")
        except Exception as e:
            print(_c(f"WARNING: results table unavailable, DB persistence off: {e}", 33))
            pg_res = None

    writer = ResultsWriter(args.out, {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "source": source,
        "servers": len(servers),
        "root_causes": len(rcs),
    })
    any_error = False
    n_succ = n_fail = 0
    try:
        for s in servers:
            host = str(s["server"]).split(":")[0] if s["server"] else s["server"]
            pwd, _enc, _derr = safe_decrypt(s["password"])
            hdr = f"SERVER {s['servername']} ({host}:{s['port']} / {s['service_name']})"
            print("\n" + "=" * len(hdr)); print(hdr); print("=" * len(hdr))
            if _derr:
                any_error = True; n_fail += 1
                print(_c(f"  PASSWORD DECRYPT FAILED: {_derr}", 31))
                writer.add({"server": s["servername"], "rootcause": None, "query": None,
                            "status": "failed", "error": f"password decrypt failed: {_derr}",
                            "rows": None, "elapsed_ms": None})
                if pg_res:
                    insert_result(pg_res, run_id, s["servername"], None, None,
                                  "failed", None, None, None, f"password decrypt failed: {_derr}")
                continue
            try:
                ora = oracle_connect(s["username"], pwd, host, s["port"], s["service_name"])
            except Exception as e:
                any_error = True; n_fail += 1
                err1 = str(e).splitlines()[0][:300]
                print(_c(f"  CONNECT FAILED: {err1}", 31))
                writer.add({"server": s["servername"], "rootcause": None, "query": None,
                            "status": "failed", "error": f"connect failed: {err1}",
                            "rows": None, "elapsed_ms": None})
                if pg_res:
                    insert_result(pg_res, run_id, s["servername"], None, None,
                                  "failed", None, None, None, f"connect failed: {err1}")
                continue
            with ora as conn:
                ok = empty = err = 0
                for rc in rcs:
                    final_sql = substitute_params(rc["query"], rc.get("parameters"), args.default_param)
                    status, rowcount, ms, sample, error = run_query(
                        conn, final_sql, args.sample, args.fetch_cap)
                    writer.add({
                        "server": s["servername"],
                        "rootcause": rc["root_cause_id"],
                        "query": final_sql,
                        "status": "failed" if status == "error" else "success",
                        "error": error,
                        "rows": rowcount,
                        "elapsed_ms": round(ms, 1),
                    })
                    if pg_res:
                        insert_result(pg_res, run_id, s["servername"], rc["root_cause_id"],
                                      final_sql, "failed" if status == "error" else "success",
                                      rowcount, round(ms, 1), sample, error)
                    # monitor (stdout below) AND log: one monitoring-log row per root cause.
                    _db_log(f"rc={rc['root_cause_id']} server={s['servername']} "
                            f"status={'failed' if status == 'error' else 'success'} rows={rowcount}"
                            + (f" err={error}" if error else ""),
                            0, "oracle_rootcause_tester", s["servername"])
                    if status == "error":
                        any_error = True; err += 1; n_fail += 1
                        print(_c(f"  [ERROR ] {rc['root_cause_id']:<24} {ms:6.0f}ms  {error}", 31))
                    else:
                        n_succ += 1
                        rc_n = rowcount
                        is_empty = str(rc_n) in ("0", ">=0")
                        if is_empty:
                            empty += 1
                            print(_c(f"  [EMPTY ] {rc['root_cause_id']:<24} {ms:6.0f}ms  rows={rc_n}", 33))
                        else:
                            ok += 1
                            print(_c(f"  [ROWS  ] {rc['root_cause_id']:<24} {ms:6.0f}ms  rows={rc_n}", 32))
                            for srow in sample:
                                print(f"             {srow}")
                print(f"  --- {s['servername']}: {ok} with-rows, {empty} empty, {err} error ---")
    finally:
        writer.close({"total": writer.n, "success": n_succ, "failed": n_fail})
        if pg_res:
            try:
                pg_res.close()
            except Exception:
                pass

    if pg_res is not None or (bool(args.queries_file) and not args.no_db_results):
        print(f"results persisted to {RESULTS_TABLE} (run_id={run_id})")
    print(f"\nresults: {n_succ} success, {n_fail} failed -> {os.path.abspath(args.out)}")
    print("== DONE ==")
    return 1 if any_error else 0


if __name__ == "__main__":
    sys.exit(main())
