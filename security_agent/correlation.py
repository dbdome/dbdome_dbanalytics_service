"""Corroboration and novelty -- the second evidence arm, alongside precedent.

`retriever` answers "has this server run this STATEMENT before?". This module
answers two different questions about the FINDING:

  1. CORROBORATION  What else is firing on this server right now? A detection
     that fires alone is far weaker evidence than one arriving inside a cluster
     of related findings on the same host at the same time.

  2. NOVELTY        Has this root cause, on this server, for this login, at this
     hour, ever happened before? A rule that has fired hourly for six weeks is
     background. Its first appearance on a host is not.

Both read alerts.alert_log, which carries exactly the four dimensions asked for
-- root_cause_id, login_name, server, entry_date -- and is indexed for it:
    ix_alert_log_srv_rc_date (server, root_cause_id, entry_date)
    ix_alert_log_rc_date     (root_cause_id, entry_date)

TWO THINGS THE DATA FORCED
--------------------------
* RAW CO-OCCURRENCE COUNTS ARE MEANINGLESS. Measured on the development
  database: 1,489 distinct root causes fired on SIM-ORACLE within a single hour,
  and 660/hour on 192.168.1.229. Reporting "37 other findings in this window"
  would score literally every alert as maximally corroborated. So the count is
  always divided by that server's OWN typical density over the baseline period,
  and it is the RATIO that carries meaning.

* login_name IS ALMOST NEVER POPULATED. 1 row in 162,997 on the development
  database carries one. Asking "has this login tripped this rule before?" would
  answer "never" for every alert and manufacture a novelty signal out of a NULL.
  The login arm therefore reports available=False and contributes nothing unless
  the alert genuinely carries a login.

Everything here is best-effort. Any failure returns an empty structure with an
`error` string; correlation never blocks, delays or fails an alert.
"""
import psycopg2.extras

from security_agent import config


def _rows(conn, sql, params):
    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()]


def _one(conn, sql, params):
    r = _rows(conn, sql, params)
    return r[0] if r else {}


# ------------------------------------------------------------------ arm 1
def concurrent_findings(conn, server, at, root_cause_id=None):
    """Other root causes on this server within +/- the correlation window.

    Returns the cluster AND the server's own baseline density, because the
    absolute count is not interpretable on its own (see module docstring).
    """
    win = config.correlation_window_min()
    days = config.correlation_baseline_days()
    out = {
        "window_minutes": win,
        "distinct_root_causes": 0,
        "alerts": 0,
        "top": [],
        "baseline_distinct_per_window": None,
        "ratio_vs_baseline": None,
        "error": None,
    }
    if not server or at is None:
        return out

    try:
        cluster = _one(conn, """
            SELECT count(*)                        AS alerts,
                   count(DISTINCT root_cause_id)   AS distinct_rcs
            FROM alerts.alert_log
            WHERE server = %s
              AND entry_date BETWEEN %s::timestamp - make_interval(mins => %s)
                                 AND %s::timestamp + make_interval(mins => %s)
              AND (%s IS NULL OR root_cause_id <> %s)
        """, [server, at, win, at, win, root_cause_id, root_cause_id])

        out["alerts"] = int(cluster.get("alerts") or 0)
        out["distinct_root_causes"] = int(cluster.get("distinct_rcs") or 0)

        out["top"] = _rows(conn, """
            SELECT root_cause_id, count(*) AS n,
                   max(risk_level) AS risk_level
            FROM alerts.alert_log
            WHERE server = %s
              AND entry_date BETWEEN %s::timestamp - make_interval(mins => %s)
                                 AND %s::timestamp + make_interval(mins => %s)
              AND (%s IS NULL OR root_cause_id <> %s)
            GROUP BY root_cause_id
            ORDER BY n DESC
            LIMIT %s
        """, [server, at, win, at, win, root_cause_id, root_cause_id,
              config.correlation_top_n()])

        # Baseline: mean distinct root causes per equivalent window on this same
        # server. This is what turns a raw count into a signal.
        base = _one(conn, """
            SELECT avg(d)::numeric(10,2) AS mean_distinct
            FROM (
                SELECT count(DISTINCT root_cause_id) AS d
                FROM alerts.alert_log
                WHERE server = %s
                  AND entry_date >= now() - make_interval(days => %s)
                GROUP BY floor(extract(epoch FROM entry_date) / (%s * 60))
            ) w
        """, [server, days, win * 2])

        mean = base.get("mean_distinct")
        if mean is not None:
            out["baseline_distinct_per_window"] = float(mean)
            if float(mean) > 0:
                out["ratio_vs_baseline"] = round(
                    out["distinct_root_causes"] / float(mean), 2)
    except Exception as e:
        out["error"] = f"concurrent lookup failed: {e}"
    return out


# ------------------------------------------------------------------ arm 2
def history(conn, server, root_cause_id, login_name, at):
    """How usual is this finding, on this server, for this login, at this hour."""
    days = config.correlation_history_days()
    out = {
        "rule_on_server": {},
        "rule_fleetwide": {},
        "login": {"available": False},
        "timing": {},
        "error": None,
    }
    if not root_cause_id:
        return out

    try:
        if server:
            out["rule_on_server"] = _one(conn, """
                SELECT count(*)                      AS total,
                       min(entry_date)               AS first_seen,
                       max(entry_date)               AS last_seen,
                       count(DISTINCT entry_date::date) AS days_seen,
                       count(*) FILTER (
                           WHERE entry_date >= %s::timestamp - interval '24 hours'
                       )                             AS last_24h
                FROM alerts.alert_log
                WHERE server = %s AND root_cause_id = %s
                  AND entry_date >= now() - make_interval(days => %s)
            """, [at, server, root_cause_id, days])

        out["rule_fleetwide"] = _one(conn, """
            SELECT count(*)                    AS total,
                   count(DISTINCT server)      AS servers
            FROM alerts.alert_log
            WHERE root_cause_id = %s
              AND entry_date >= now() - make_interval(days => %s)
        """, [root_cause_id, days])

        # Login arm -- only when the alert actually carries one. See the module
        # docstring: treating a NULL login as "never seen before" would fabricate
        # a novelty signal on essentially every alert.
        if login_name and str(login_name).strip():
            row = _one(conn, """
                SELECT count(*)                        AS total_for_login,
                       min(entry_date)                 AS first_seen,
                       count(*) FILTER (WHERE root_cause_id = %s) AS this_rule,
                       count(DISTINCT root_cause_id)   AS distinct_rules
                FROM alerts.alert_log
                WHERE server = %s AND login_name = %s
                  AND entry_date >= now() - make_interval(days => %s)
            """, [root_cause_id, server, login_name, days])
            row["available"] = True
            row["login_name"] = login_name
            out["login"] = row

        # Hour-of-day: is this rule normally seen at this time on this server?
        if server and at is not None:
            out["timing"] = _one(conn, """
                SELECT extract(hour FROM %s::timestamp)::int AS hour_of_alert,
                       count(*) FILTER (
                           WHERE extract(hour FROM entry_date)
                                 = extract(hour FROM %s::timestamp)
                       )                                     AS at_this_hour,
                       count(*)                              AS total
                FROM alerts.alert_log
                WHERE server = %s AND root_cause_id = %s
                  AND entry_date >= now() - make_interval(days => %s)
            """, [at, at, server, root_cause_id, days])
    except Exception as e:
        out["error"] = f"history lookup failed: {e}"
    return out


# ------------------------------------------------------------------ verdict
def _flags(conc, hist):
    """Plain-language signals derived from the two arms.

    Deliberately conservative: every flag needs enough history to be meaningful,
    so a fresh install with no data produces no flags rather than false ones.
    """
    flags = []
    rs = hist.get("rule_on_server") or {}
    tm = hist.get("timing") or {}
    lg = hist.get("login") or {}

    total = int(rs.get("total") or 0)
    if total == 1:
        flags.append("first_occurrence_on_this_server")
    elif 0 < total <= 3:
        flags.append("rare_on_this_server")
    elif total > 200:
        flags.append("routine_on_this_server")

    last24 = int(rs.get("last_24h") or 0)
    days_seen = int(rs.get("days_seen") or 0)
    if days_seen >= 3 and last24 > 0:
        per_day = total / float(days_seen)
        if per_day > 0 and last24 >= max(5, per_day * 4):
            flags.append("burst_vs_own_history")

    ratio = conc.get("ratio_vs_baseline")
    if ratio is not None:
        if ratio >= 2.0:
            flags.append("clustered_with_other_findings")
        elif ratio <= 0.25 and conc.get("distinct_root_causes", 0) <= 2:
            flags.append("isolated_finding")
    else:
        # No baseline: the server has no alerts in the baseline period, so the
        # cluster size cannot be judged. Say so. Emitting nothing here would be
        # read as "not clustered", which is a different claim -- one server in
        # the sample had 1,488 concurrent findings and no baseline to weigh them
        # against, and silence would have understated it badly.
        flags.append("co_occurrence_baseline_unavailable")

    if total == 0:
        # The novelty arm had nothing to work with (rule never seen on this
        # server inside the history window). Distinguish that from "seen and
        # normal", which is the opposite conclusion.
        flags.append("no_history_for_rule_in_window")

    at_hour = tm.get("at_this_hour")
    tot_hour = tm.get("total")
    if at_hour is not None and tot_hour and int(tot_hour) >= 20:
        share = int(at_hour) / float(tot_hour)
        if share <= 0.02:
            flags.append("unusual_hour_for_this_rule")

    if lg.get("available"):
        if int(lg.get("this_rule") or 0) <= 1:
            flags.append("first_time_this_login_tripped_this_rule")
    else:
        flags.append("login_not_attributed")

    return flags


def gather(conn, candidate: dict) -> dict:
    """Both arms plus derived flags. Never raises."""
    if not config.correlation_enabled():
        return {"enabled": False}

    server = candidate.get("server") or ""
    rc = candidate.get("root_cause_id")
    login = candidate.get("login_name")
    at = candidate.get("entry_date")

    try:
        conc = concurrent_findings(conn, server, at, rc)
        hist = history(conn, server, rc, login, at)
        return {
            "enabled": True,
            "concurrent": conc,
            "history": hist,
            "flags": _flags(conc, hist),
        }
    except Exception as e:
        return {"enabled": True, "error": str(e), "concurrent": {},
                "history": {}, "flags": []}
