"""Self-activity / false-alarm suppression filter.

DBDOME's own detection queries include pure STATE inventories (e.g. "list every
non-DBMS-maintained user with their roles/privileges"). Those always return rows,
so a `row_count > 0` condition always matches and the result is stored in
monitoring.general_metric_metadata_results AND alerted every cycle - a permanent
FALSE ALARM (DBDOME reading the catalog, not real activity).

This module is the HOT-PATH enforcement point. Each vendor generic-query
collector calls `is_self_activity(metric_name, query, vendor)` right before it
stores/alerts a metric; on a match it skips both.

Design constraints:
  * NO network, NO LLM, NO new pip dependencies - safe to run per-metric.
  * FAIL-OPEN: any error -> returns False (normal collection continues). A bug
    in this filter can never break collection or hide a real finding by crashing.
  * Rules come from analysis.suppression_rules (script 6430), cached in-process
    with a short TTL so it is not a per-call DB hit. Rules are curated by an
    analyst or by analysis/self_activity_agent.py (the Claude reviewer).

The Claude LLM feature lives in self_activity_agent.py (an OFFLINE reviewer that
proposes rules); this file stays deterministic on purpose.
"""
import re
import time
import threading

try:
    # Reuse the service's own connection string helper when imported inside DBDOME.
    from utils.utils_config_dotenv import get_connection_string
except Exception:  # pragma: no cover - allows standalone import/use
    try:
        from utils.config_dotenv import get_connection_string
    except Exception:
        get_connection_string = None

_CACHE_TTL_SECONDS = 300
_lock = threading.Lock()
_cache = {"rules": None, "loaded_at": 0.0}
_logins_cache = {"logins": None, "loaded_at": 0.0}

# --- SQL normalisation (must stay identical to how the agent fingerprints) ----
_COMMENT_BLOCK = re.compile(r"/\*.*?\*/", re.DOTALL)
_COMMENT_LINE = re.compile(r"--[^\n]*")
_WS = re.compile(r"\s+")


def normalize_sql(sql):
    """Canonical form of a SQL string for fingerprinting.

    Lowercases, strips /* */ and -- comments, collapses whitespace, drops a
    trailing semicolon. String/number literals are PRESERVED (they carry meaning
    in these detections, e.g. 'N', 'USER'), so this only ignores cosmetic
    differences. Returns '' for falsy input.
    """
    if not sql:
        return ""
    s = str(sql)
    s = _COMMENT_BLOCK.sub(" ", s)
    s = _COMMENT_LINE.sub(" ", s)
    s = _WS.sub(" ", s)
    s = s.strip().rstrip(";").strip()
    return s.lower()


def _load_rules_from_db():
    """Return the active suppression rules as a list of dicts, or [] on failure."""
    if get_connection_string is None:
        return []
    import psycopg2
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.set_session(readonly=True, autocommit=True)
        cur = conn.cursor()
        cur.execute("SET LOCAL statement_timeout = 5000")
        cur.execute("""
            SELECT rule_name, match_mode, vendor_slug, metric_name, sample_query
            FROM analysis.suppression_rules
            WHERE is_active IS TRUE
        """)
        rules = []
        for rule_name, mode, vendor, metric, sample in cur.fetchall():
            rules.append({
                "rule_name": rule_name,
                "match_mode": mode,
                "vendor_slug": (vendor or "").lower() or None,
                "metric_name": metric,
                "fingerprint": normalize_sql(sample) if sample else None,
            })
        return rules
    except Exception:
        # Missing schema/table (pre-6430) or any DB error -> fail open.
        return []
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


def _load_exclude_logins_from_db():
    """Return the active excluded logins as a lowercase set, or set() on failure.

    Two sources, merged:
      * metrics.exclude_logins (is_active)   - operator-curated list (6500);
      * metrics.servers.username (is_active) - the logins DBDOME itself uses to
        connect to every monitored server: their activity IS self activity.
    Each source is queried independently so a missing table (pre-6500) never
    hides the other one.
    """
    if get_connection_string is None:
        return set()
    import psycopg2
    conn = None
    logins = set()
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.set_session(readonly=True, autocommit=True)
        for sql in (
            "SELECT login_name FROM metrics.exclude_logins WHERE is_active IS TRUE",
            "SELECT DISTINCT username FROM metrics.servers WHERE is_active IS TRUE",
        ):
            try:
                cur = conn.cursor()
                cur.execute("SET LOCAL statement_timeout = 5000")
                cur.execute(sql)
                logins |= {str(r[0]).strip().lower() for r in cur.fetchall() if r[0]}
            except Exception:
                # Missing table (pre-6500) or any DB error -> fail open per source.
                pass
        return logins
    except Exception:
        return logins
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


def get_excluded_logins(force_reload=False):
    """Cached lowercase set of logins from metrics.exclude_logins (TTL shared
    with the rule cache). Fail-open: empty set on any error."""
    now = time.time()
    with _lock:
        if (not force_reload and _logins_cache["logins"] is not None
                and now - _logins_cache["loaded_at"] < _CACHE_TTL_SECONDS):
            return _logins_cache["logins"]
    logins = _load_exclude_logins_from_db()
    with _lock:
        _logins_cache["logins"] = logins
        _logins_cache["loaded_at"] = time.time()
    return logins


def is_excluded_login(login_name):
    """True if login_name is registered in metrics.exclude_logins (is_active)."""
    try:
        if not login_name:
            return False
        return str(login_name).strip().lower() in get_excluded_logins()
    except Exception:
        return False


def filter_excluded_logins(df, login_cols=("login_name",)):
    """Drop collected transaction rows whose login is excluded.

    Collectors call this on the per-metric result DataFrame right after the
    target query returns: rows whose login (case-insensitive) is in
    metrics.exclude_logins never reach gmmr / the monitoring tables / alerting.

    The login column is `login_name` by default, but dedicated collectors whose
    result names it differently pass `login_cols` (e.g. ("username",) for the
    XE audit collector, ("loginname",) for the login-hardening collector). The
    candidates are tried in order; the first present column is used. DataFrames
    with none of the candidate columns pass through untouched. FAIL-OPEN on any
    error.
    """
    try:
        if df is None or getattr(df, "empty", True):
            return df
        wanted = tuple(str(c).lower() for c in (login_cols or ("login_name",)))
        login_col = None
        for w in wanted:
            login_col = next((c for c in df.columns if str(c).lower() == w), None)
            if login_col is not None:
                break
        if login_col is None:
            return df
        excluded = get_excluded_logins()
        if not excluded:
            return df
        mask = df[login_col].map(
            lambda v: str(v).strip().lower() in excluded if v is not None else False)
        return df[~mask]
    except Exception:
        return df


# --- row-level self-statement suppression ------------------------------------
# The destructive-DDL / DBA-activity detections read the audit trail and report
# the STATEMENTS they find. DBDOME's own collector queries build and drop temp
# tables (CREATE TABLE #sensitive_cols ... DROP TABLE #access), so DBDOME reports
# ITSELF as destructive DDL — ~20% of SEC-SQL-AUD-020 findings were DBDOME's own
# scratch tables. Suppressing the whole metric would blind a real detection, so
# instead drop only the offending ROWS.
#
# These are the scratch-table names DBDOME's own detection SQL uses. A statement
# that touches one of them cannot have come from a monitored application.
_SELF_STATEMENT_MARKERS = (
    "#sensitive_cols",
    "#access",
    "#priv",
    "#tmp_dbdome",
    "tempdb..#sensitive_cols",
)


def is_self_statement(statement):
    """True when a captured statement is DBDOME's own collector SQL.

    Matches on the scratch-table names only DBDOME's detection queries use, so a
    monitored application's DDL is never suppressed. FAIL-OPEN: False on error.
    """
    try:
        if not statement:
            return False
        s = str(statement).lower()
        return any(m in s for m in _SELF_STATEMENT_MARKERS)
    except Exception:
        return False


def filter_self_statements(df):
    """Drop captured-statement rows that are DBDOME's own collector SQL.

    Collectors call this alongside filter_excluded_logins() on the per-metric
    result DataFrame. DataFrames with no statement/query column pass through
    untouched. FAIL-OPEN: returns df unchanged on any error.
    """
    try:
        if df is None or getattr(df, "empty", True):
            return df
        col = next((c for c in df.columns
                    if str(c).lower() in ("statement", "query", "sql_text", "query_text")), None)
        if col is None:
            return df
        mask = df[col].map(is_self_statement)
        return df[~mask]
    except Exception:
        return df


def _get_rules(force_reload=False):
    now = time.time()
    with _lock:
        if (not force_reload and _cache["rules"] is not None
                and now - _cache["loaded_at"] < _CACHE_TTL_SECONDS):
            return _cache["rules"]
    # Load outside the lock to avoid holding it across a DB round-trip.
    rules = _load_rules_from_db()
    with _lock:
        _cache["rules"] = rules
        _cache["loaded_at"] = time.time()
    return rules


def is_self_activity(metric_name, query, vendor=None):
    """True if (metric_name, query) matches an active suppression rule.

    On True the caller must SKIP both the gmmr insert and the alert for this
    metric. FAIL-OPEN: any exception returns False.
    """
    try:
        rules = _get_rules()
        if not rules:
            return False
        vendor = (vendor or "").lower() or None
        fp = None  # lazily computed
        for rule in rules:
            if rule["vendor_slug"] and vendor and rule["vendor_slug"] != vendor:
                continue
            mode = rule["match_mode"]
            metric_ok = bool(rule["metric_name"]) and rule["metric_name"] == metric_name
            if mode == "metric":
                if metric_ok:
                    return True
                continue
            # query / query_and_metric need a query fingerprint
            if not rule["fingerprint"]:
                continue
            if fp is None:
                fp = normalize_sql(query)
            query_ok = fp == rule["fingerprint"]
            if mode == "query" and query_ok:
                return True
            if mode == "query_and_metric" and query_ok and metric_ok:
                return True
        return False
    except Exception:
        return False


def matching_rule(metric_name, query, vendor=None):
    """Like is_self_activity but returns the matched rule dict (or None).

    For logging / the agent; not used in the hot path.
    """
    try:
        rules = _get_rules()
        vendor = (vendor or "").lower() or None
        fp = normalize_sql(query)
        for rule in rules:
            if rule["vendor_slug"] and vendor and rule["vendor_slug"] != vendor:
                continue
            mode = rule["match_mode"]
            metric_ok = bool(rule["metric_name"]) and rule["metric_name"] == metric_name
            query_ok = bool(rule["fingerprint"]) and fp == rule["fingerprint"]
            if ((mode == "metric" and metric_ok)
                    or (mode == "query" and query_ok)
                    or (mode == "query_and_metric" and query_ok and metric_ok)):
                return rule
        return None
    except Exception:
        return None


def refresh_rules():
    """Force a reload of the rule cache (e.g. after the agent adds a rule)."""
    return _get_rules(force_reload=True)


if __name__ == "__main__":
    # Quick manual check: python -m analysis.self_activity_filter "<sql>" [metric] [vendor]
    import sys
    q = sys.argv[1] if len(sys.argv) > 1 else ""
    m = sys.argv[2] if len(sys.argv) > 2 else None
    v = sys.argv[3] if len(sys.argv) > 3 else None
    r = matching_rule(m, q, v)
    print("suppress:", is_self_activity(m, q, v))
    print("rule    :", r["rule_name"] if r else None)
    print("loaded rules:", len(_get_rules()))
