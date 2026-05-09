"""
GRC Phase 3: User Risk Scoring & Behaviour Baseline

Scheduled every 300 seconds (5 minutes).

For every active database user seen in the last 10 minutes:
  1. Pull current session and transaction data from monitoring tables.
  2. Compare against the stored baseline in monitoring.user_risk_profiles.
  3. Calculate a risk score (0-100) from weighted risk factors.
  4. Update the baseline using an Exponential Moving Average (EMA).
  5. Write a row to monitoring.user_risk_events for trend tracking.
  6. For users with risk_score >= 70, also write to log.firewall_audit_log
     so the Phase 1 audit trail captures the anomaly.

Risk factors and weights
────────────────────────
Factor                  Weight  Trigger
off_hours               +20     current hour outside [typical_hour_start, typical_hour_end]
new_user                +15     observation_count < 10 (insufficient baseline)
volume_spike            +30     queries last 5 min > 3× avg_queries_per_hour / 12
unusual_tables          +25     query touches tables not in typical_tables
blocking_session        +20     user has at least one blocking session
high_duration           +20     any query duration_secs > 5× avg_duration_secs
sqli_pattern            +50     SQL injection regex match in any active query
consecutive_high_risk   +10     consecutive_high_risk >= 3 (sustained anomaly)

Score is capped at 100.
"""

import re
import json
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
from utils.firewall_audit_writer import write_audit_event

# ── Constants ─────────────────────────────────────────────────────────────────

_EMA_ALPHA       = 0.2          # weight of new observation in EMA update
_LOOKBACK_MINS   = 10           # how far back to read active transactions
_HIGH_RISK_FLOOR = 70           # score >= this triggers firewall_audit_log entry
_MIN_BASELINE    = 10           # observation_count below this → new_user penalty

_SQLI_PATTERN = re.compile(
    r"(UNION\s+SELECT|SELECT\s+.{0,60}\s+FROM\s+.{0,60}\s+WHERE|"
    r"xp_cmdshell|INTO\s+OUTFILE|INTO\s+DUMPFILE|"
    r"SLEEP\s*\(|BENCHMARK\s*\(|WAITFOR\s+DELAY|"
    r"OR\s+1\s*=\s*1|AND\s+1\s*=\s*1|--\s*$|;\s*--)",
    re.IGNORECASE,
)

# Simple table-name extractor (FROM / JOIN / UPDATE / INTO token)
_TABLE_RE = re.compile(
    r"(?:FROM|JOIN|UPDATE|INTO)\s+([\w\[\]\"`.]+)",
    re.IGNORECASE,
)

# ── DB helper ─────────────────────────────────────────────────────────────────

def _conn():
    return psycopg2.connect(get_connection_string())

# ── Baseline helpers ──────────────────────────────────────────────────────────

def _ema(old: float, new: float) -> float:
    return round(_EMA_ALPHA * new + (1 - _EMA_ALPHA) * old, 2)


def _extract_tables(queries: list[str]) -> set[str]:
    tables = set()
    for q in queries:
        for m in _TABLE_RE.finditer(q or ""):
            name = m.group(1).strip('[]"`').lower()
            if name and len(name) < 100:
                tables.add(name)
    return tables

# ── Risk factor calculation ───────────────────────────────────────────────────

def _score_user(profile: dict, sessions: list[dict], transactions: list[dict]) -> tuple[int, dict]:
    """
    Returns (total_risk_score, factors_dict).
    profile is the current row from monitoring.user_risk_profiles (may be None for new user).
    """
    factors: dict[str, int] = {}
    queries   = [t.get("query") or "" for t in transactions]
    durations = [t.get("duration_secs") or 0 for t in transactions]
    current_hour = datetime.now().hour

    # ── new_user penalty ─────────────────────────────────────────────────────
    obs = profile.get("observation_count", 0) if profile else 0
    if obs < _MIN_BASELINE:
        factors["new_user"] = 15

    # ── off_hours ────────────────────────────────────────────────────────────
    h_start = profile.get("typical_hour_start", 7) if profile else 7
    h_end   = profile.get("typical_hour_end",  19) if profile else 19
    if not (h_start <= current_hour < h_end):
        factors["off_hours"] = 20

    # ── volume_spike ─────────────────────────────────────────────────────────
    avg_qph = profile.get("avg_queries_per_hour", 0) if profile else 0
    # avg per 5-min window = avg_qph / 12; current window count = len(transactions)
    expected_per_window = max(avg_qph / 12.0, 1)
    if len(transactions) > 3 * expected_per_window and avg_qph > 0:
        factors["volume_spike"] = 30

    # ── unusual_tables ────────────────────────────────────────────────────────
    current_tables  = _extract_tables(queries)
    typical_tables  = set(profile.get("typical_tables") or []) if profile else set()
    if typical_tables and current_tables - typical_tables:
        factors["unusual_tables"] = 25

    # ── blocking_session ─────────────────────────────────────────────────────
    if any(t.get("is_blocking") for t in transactions):
        factors["blocking_session"] = 20

    # ── high_duration ─────────────────────────────────────────────────────────
    avg_dur = profile.get("avg_duration_secs", 0) if profile else 0
    if avg_dur > 0 and durations and max(durations) > 5 * avg_dur:
        factors["high_duration"] = 20

    # ── sqli_pattern ─────────────────────────────────────────────────────────
    if any(_SQLI_PATTERN.search(q) for q in queries if q):
        factors["sqli_pattern"] = 50

    # ── consecutive_high_risk bonus ───────────────────────────────────────────
    if profile and profile.get("consecutive_high_risk", 0) >= 3:
        factors["consecutive_high_risk"] = 10

    total = min(sum(factors.values()), 100)
    return total, factors

# ── Baseline update ───────────────────────────────────────────────────────────

def _update_profile(conn, server_name: str, db_user: str,
                    profile: dict | None,
                    transactions: list[dict],
                    risk_score: int):
    queries = [t.get("query") or "" for t in transactions]
    current_tables = list(_extract_tables(queries))
    current_hour   = datetime.now().hour
    n_queries      = len(transactions)
    avg_dur        = (sum(t.get("duration_secs") or 0 for t in transactions) / max(n_queries, 1))
    avg_lr         = (sum(t.get("logical_reads") or 0 for t in transactions) / max(n_queries, 1))

    cur = conn.cursor()

    if profile is None:
        # First time — insert with raw values
        cur.execute(
            """
            INSERT INTO monitoring.user_risk_profiles
                (server_name, db_user,
                 avg_queries_per_hour, typical_hour_start, typical_hour_end,
                 typical_tables, avg_duration_secs, avg_logical_reads,
                 risk_score, observation_count, consecutive_high_risk,
                 last_seen_at, last_updated)
            VALUES (%s,%s, %s,%s,%s, %s,%s,%s, %s,1,%s, NOW(),NOW())
            """,
            (
                server_name, db_user,
                float(n_queries) * 12,          # scale to per-hour
                max(current_hour - 1, 0), min(current_hour + 2, 23),
                current_tables,
                round(avg_dur, 2), round(avg_lr, 2),
                risk_score,
                1 if risk_score >= _HIGH_RISK_FLOOR else 0,
            ),
        )
    else:
        new_qph    = _ema(profile["avg_queries_per_hour"], float(n_queries) * 12)
        new_dur    = _ema(profile["avg_duration_secs"], avg_dur)
        new_lr     = _ema(profile["avg_logical_reads"], avg_lr)

        # Widen typical hour window if current hour is just outside
        h_start = profile["typical_hour_start"]
        h_end   = profile["typical_hour_end"]
        if current_hour < h_start:
            h_start = max(h_start - 1, current_hour)
        if current_hour >= h_end:
            h_end = min(h_end + 1, 23)

        # Merge typical tables (keep union, cap at 50 entries)
        merged_tables = list(set(profile.get("typical_tables") or []) | set(current_tables))[:50]

        consec = (profile["consecutive_high_risk"] + 1) if risk_score >= _HIGH_RISK_FLOOR else 0

        cur.execute(
            """
            UPDATE monitoring.user_risk_profiles SET
                avg_queries_per_hour  = %s,
                typical_hour_start    = %s,
                typical_hour_end      = %s,
                typical_tables        = %s,
                avg_duration_secs     = %s,
                avg_logical_reads     = %s,
                risk_score            = %s,
                observation_count     = observation_count + 1,
                consecutive_high_risk = %s,
                last_seen_at          = NOW(),
                last_updated          = NOW()
            WHERE server_name = %s AND db_user = %s
            """,
            (
                new_qph, h_start, h_end, merged_tables,
                new_dur, new_lr,
                risk_score, consec,
                server_name, db_user,
            ),
        )

    cur.close()

# ── Event writer ──────────────────────────────────────────────────────────────

def _write_risk_event(conn, server_name: str, db_user: str,
                      risk_score: int, factors: dict,
                      n_sessions: int, n_queries: int):
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO monitoring.user_risk_events
            (server_name, db_user, risk_score, risk_factors, active_sessions, active_queries)
        VALUES (%s,%s,%s,%s,%s,%s)
        """,
        (server_name, db_user, risk_score,
         psycopg2.extras.Json(factors), n_sessions, n_queries),
    )
    cur.close()

# ── Main scorer ───────────────────────────────────────────────────────────────

def run_user_risk_scoring():
    """Entry point registered with APScheduler. Runs every 300 seconds."""
    since = datetime.utcnow() - timedelta(minutes=_LOOKBACK_MINS)

    try:
        conn = _conn()
        conn.autocommit = False
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        # ── Fetch recent transactions grouped by server + login_name ─────────
        cur.execute(
            """
            SELECT
                server                              AS server_name,
                login_name                          AS db_user,
                database_name,
                query,
                duration_secs,
                logical_reads,
                CASE WHEN blocking_session_id > 0 THEN TRUE ELSE FALSE END AS is_blocking
            FROM monitoring.active_transactions
            WHERE login_name IS NOT NULL
              AND login_name <> ''
              AND last_request_end_time >= %s
            """,
            (since,),
        )
        all_txns = cur.fetchall()

        # Group by (server_name, db_user)
        from collections import defaultdict
        groups: dict[tuple, list] = defaultdict(list)
        for row in all_txns:
            key = (row["server_name"], row["db_user"])
            groups[key].append(dict(row))

        if not groups:
            cur.close()
            conn.close()
            return

        # Fetch sessions (for session count)
        cur.execute(
            """
            SELECT server, login_name, COUNT(*) AS n_sessions
            FROM monitoring.active_sessions
            WHERE login_name IS NOT NULL AND login_name <> ''
              AND last_request_end_time >= %s
            GROUP BY server, login_name
            """,
            (since,),
        )
        session_counts = {(r["server"], r["login_name"]): r["n_sessions"]
                          for r in cur.fetchall()}

        # Fetch existing profiles
        servers_users = list(groups.keys())
        cur.execute(
            """
            SELECT *
            FROM monitoring.user_risk_profiles
            WHERE (server_name, db_user) = ANY(%s::text[][])
            """,
            ([list(k) for k in servers_users],),
        )
        profiles = {(r["server_name"], r["db_user"]): dict(r) for r in cur.fetchall()}
        cur.close()

        # ── Score, update, record ────────────────────────────────────────────
        for (server_name, db_user), txns in groups.items():
            profile    = profiles.get((server_name, db_user))
            n_sessions = session_counts.get((server_name, db_user), len(txns))

            risk_score, factors = _score_user(profile, [], txns)

            try:
                _update_profile(conn, server_name, db_user, profile, txns, risk_score)
                _write_risk_event(conn, server_name, db_user,
                                  risk_score, factors, n_sessions, len(txns))
                conn.commit()
            except Exception as e:
                conn.rollback()
                db_write_log(f"user_risk_scoring write error ({server_name}/{db_user}): {e}",
                             0, "analyse_user_risk", server_name)
                continue

            # Mirror high-risk events into the Phase 1 firewall audit log
            if risk_score >= _HIGH_RISK_FLOOR:
                sample_query = next((t.get("query") for t in txns if t.get("query")), "")
                write_audit_event(
                    server_name  = server_name,
                    vendor       = "",
                    db_user      = db_user,
                    client_ip    = "",
                    db_name      = txns[0].get("database_name") or "",
                    sql_statement= sample_query,
                    action_taken = "ALERTED",
                    regulation   = "SOC2",
                    risk_score   = risk_score,
                )
                db_write_log(
                    f"HIGH RISK user detected: {db_user}@{server_name} "
                    f"score={risk_score} factors={json.dumps(factors)}",
                    risk_score, "analyse_user_risk", server_name,
                )

        conn.close()
        db_write_log(f"user_risk_scoring complete — {len(groups)} users scored",
                     0, "analyse_user_risk", "")

    except Exception as e:
        db_write_log(f"run_user_risk_scoring failed: {e}", 0, "analyse_user_risk", "")
