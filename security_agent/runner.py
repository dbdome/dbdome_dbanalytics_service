"""Entry points.

`decide()` is the one collectors call. It is written so that adding it to a
collector is a two-line change and so that EVERY failure mode -- disabled,
wrong domain, no model, no query, timeout, database error -- returns
(True, metadata) i.e. "raise the alert exactly as you would have".

    raise_it, meta = security_agent.runner.decide(
        server=server_key,
        root_cause_id=rc,
        query_text=metric_query,
        metadata=metric_metadata_json,
        metric_name=metric_name,
        risk_level=_risk_level,
    )
    if not raise_it:
        continue                    # suppressed; already recorded
    ... INSERT INTO alerts.alert_log ... CAST(:meta AS jsonb) ...

`review_alert()` is the after-the-fact variant for alerts already in alert_log
(the analysis/* writers), annotating the row in place.
"""
import psycopg2

from utils.log4dbexpert import db_write_log
from utils.config_dotenv import get_connection_string
from security_agent import config, agent, classifier, persist


def _connect():
    return psycopg2.connect(get_connection_string())


def _domain_allowed(conn, root_cause_id, domain=None) -> bool:
    """Only judge alerts in the configured domains (Security by default)."""
    allowed = config.gated_domains()
    if not allowed or "*" in allowed:
        return True
    if domain:
        return str(domain).strip().lower() in allowed
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT lower(domain_name) FROM rootcause.v_rootcauses "
                "WHERE root_cause_id = %s LIMIT 1",
                (root_cause_id,),
            )
            row = cur.fetchone()
        return bool(row) and row[0] in allowed
    except Exception:
        # Unknown domain -> do not gate it. Never suppress what we cannot classify.
        return False


def decide(*, server, root_cause_id, query_text, metadata, metric_name=None,
           risk_level=None, domain=None, rule_name=None, detection_desc=None,
           conn=None):
    """Returns (raise_alert: bool, metadata_to_write).

    metadata_to_write carries `reason` when the alert is raised after triage.
    On every bypass path the ORIGINAL metadata is returned untouched, so a
    disabled or degraded agent leaves the payload byte-identical to today.
    """
    if not config.is_enabled():
        return True, metadata

    own_conn = conn is None
    try:
        conn = conn or _connect()
    except Exception as e:
        db_write_log(f"security_agent: no DB connection ({e}) -- failing open",
                     0, "security_agent.runner", server or "")
        return True, metadata

    try:
        if not _domain_allowed(conn, root_cause_id, domain):
            return True, metadata

        verdict = agent.classify(conn, {
            "server": server,
            "query": query_text,
            "root_cause_id": root_cause_id,
            "metric_name": metric_name,
            "risk_level": risk_level,
            "rule_name": rule_name,
            "detection_desc": detection_desc,
        })

        # The verdict is ADVISORY unless suppression was explicitly enabled.
        # By default every alert fires and simply carries the agent's reasoning,
        # so the agent can never hide a finding.
        judged_known = verdict["verdict"] == classifier.VERDICT_KNOWN
        suppress = (judged_known
                    and config.suppression_enabled()
                    and verdict["confidence"] >= config.min_confidence())

        persist.record_verdict(
            conn, server=server, root_cause_id=root_cause_id,
            metric_name=metric_name, query_text=query_text,
            verdict=verdict, raised=not suppress,
        )

        if suppress:
            db_write_log(
                f"security_agent: SUPPRESSED {root_cause_id} on {server} "
                f"(confidence {verdict['confidence']:.2f}, "
                f"{(verdict.get('precedent') or {}).get('exact_matches', 0)} exact precedent) "
                f"-- {verdict['reason'][:200]}",
                0, "security_agent.runner", server or "")
            return False, metadata

        return True, persist.merge_reason(metadata, verdict)

    except Exception as e:
        # Belt and braces: agent.classify already swallows everything, so
        # reaching here means something unexpected. Still fail open.
        db_write_log(f"security_agent: decide() failed ({e}) -- failing open",
                     0, "security_agent.runner", server or "")
        return True, metadata
    finally:
        if own_conn and conn is not None:
            try:
                conn.close()
            except Exception:
                pass


def annotate(*, server, root_cause_id, query_text, metadata, metric_name=None,
             risk_level=None, domain=None, rule_name=None, detection_desc=None):
    """Metadata enriched with the agent's `reason`. NEVER suppresses.

    This is what the collectors call. It is the annotate-only face of decide():
    the return value is a metadata payload and nothing else, so a collector
    cannot accidentally drop an alert by ignoring a boolean. Every failure path
    returns the original metadata unchanged.

    Suppression, if it is ever enabled, has to be wired through decide() at a
    call site that can actually skip the insert -- so we warn rather than
    silently ignoring the setting.
    """
    # Async by default: return immediately and let run_annotation_sweep() do the
    # triage a few seconds later. Inline, every alert waited 20-135s for a model
    # on CPU before it was dispatched - a latency cost paid by the alert path
    # itself, which is the wrong thing to slow down.
    if not config.annotate_inline():
        return metadata

    if config.is_enabled() and config.suppression_enabled():
        db_write_log(
            "security_agent: SECURITY_AGENT_SUPPRESS is on but this call site is "
            "annotate-only -- the alert will still be raised. Wire decide() if "
            "suppression is genuinely wanted.",
            0, "security_agent.runner", server or "")
    try:
        _, meta = decide(
            server=server, root_cause_id=root_cause_id, query_text=query_text,
            metadata=metadata, metric_name=metric_name, risk_level=risk_level,
            domain=domain, rule_name=rule_name, detection_desc=detection_desc,
        )
        return meta
    except Exception as e:
        db_write_log(f"security_agent: annotate failed ({e}) -- metadata unchanged",
                     0, "security_agent.runner", server or "")
        return metadata


def review_alert(*, alert_row_id, server, root_cause_id, query_text,
                 entry_date=None, metric_name=None, risk_level=None):
    """Triage an alert that is ALREADY in alerts.alert_log and annotate it.

    Used by the analysis/* writers, which insert first. Suppression is not
    possible after the fact without deleting evidence, so this path only ever
    ADDS the reason -- the verdict is still recorded either way.
    """
    if not config.is_enabled():
        return None
    conn = None
    try:
        conn = _connect()
        verdict = agent.classify(conn, {
            "server": server, "query": query_text,
            "root_cause_id": root_cause_id, "metric_name": metric_name,
            "risk_level": risk_level,
        })
        persist.record_verdict(
            conn, server=server, root_cause_id=root_cause_id,
            metric_name=metric_name, query_text=query_text,
            verdict=verdict, alert_row_id=alert_row_id, raised=True,
        )
        persist.annotate_alert_log(conn, alert_row_id, entry_date, verdict)
        return verdict
    except Exception as e:
        db_write_log(f"security_agent: review_alert failed ({e})", 0,
                     "security_agent.runner", server or "")
        return None
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


def run_annotation_sweep(server: str = None):
    """Scheduler entry point: annotate alerts that were raised untriaged.

    This is where triage happens now. The collector writes the alert and moves
    on; this sweep picks up anything without a security_agent block and adds the
    verdict a few seconds later. Alert dispatch is never delayed by a model.

    Registered in metrics.registered_processes by sql_scripts/7640 so the
    scheduler calls it on an interval. Returns the number annotated.

    Bounded on purpose: annotate_batch_size() alerts per run, so a backlog
    drains over several sweeps rather than one run holding the model for an
    hour while everything else waits.
    """
    if not config.is_enabled():
        return 0

    conn = None
    done = 0
    try:
        conn = _connect()

        # Warm the model before the first classification rather than making the
        # first alert of the sweep pay a ~62s load inside its own budget.
        if config.warm_on_start():
            try:
                from security_agent import llm
                if llm.available() and not llm.is_loaded():
                    llm.warm()
            except Exception as e:
                db_write_log(f"security_agent: warm-up skipped ({e})", 0,
                             "security_agent.runner", server or "")

        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '60s'")
            # metadata is jsonb but frequently a double-encoded string scalar, so
            # `metadata ? 'security_agent'` alone misses those rows. Normalise
            # first - the same reason monitoring.fn_metadata_object exists.
            cur.execute(
                """
                SELECT a.row_id, a.entry_date, a.server, a.root_cause_id, a.risk_level
                FROM alerts.alert_log a
                WHERE a.entry_date > LOCALTIMESTAMP - make_interval(mins => %s)
                  AND (%s IS NULL OR a.server = %s)
                  AND NOT (monitoring.fn_metadata_object(a.metadata) ? 'security_agent')
                ORDER BY a.entry_date DESC
                LIMIT %s
                """,
                (config.annotate_lookback_minutes(), server, server,
                 config.annotate_batch_size()),
            )
            pending = cur.fetchall()

        for row_id, entry_date, srv, rc_id, risk in pending:
            try:
                # The query to judge is the alert's own captured statement.
                q = _query_for_alert(conn, row_id, entry_date)
                v = agent.classify(conn, {
                    "server": srv, "query": q, "root_cause_id": rc_id,
                    "metric_name": None, "risk_level": risk,
                })
                persist.record_verdict(
                    conn, server=srv, root_cause_id=rc_id, metric_name=None,
                    query_text=q, verdict=v, alert_row_id=row_id, raised=True)
                if persist.annotate_alert_log(conn, row_id, entry_date, v):
                    done += 1
            except Exception as e:      # one bad alert must not kill the sweep
                db_write_log(f"security_agent sweep: alert {row_id} failed: {e}",
                             0, "security_agent.runner", srv or "")

        if pending:
            db_write_log(
                f"security_agent sweep: annotated {done}/{len(pending)} alerts",
                0, "security_agent.runner", server or "")
    except Exception as e:
        db_write_log(f"security_agent sweep failed: {e}", 0,
                     "security_agent.runner", server or "")
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
    return done


def _query_for_alert(conn, row_id, entry_date):
    """Best-effort statement text for one alert, from its own payload."""
    try:
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout = '20s'")
            cur.execute(
                """
                SELECT string_agg(t.v #>> '{}', ' ')
                FROM alerts.alert_log a
                CROSS JOIN LATERAL (SELECT monitoring.fn_metadata_object(a.metadata)) md(o)
                CROSS JOIN LATERAL jsonb_each(
                    CASE WHEN jsonb_typeof(md.o -> 'sample_rows') = 'array'
                          AND jsonb_array_length(md.o -> 'sample_rows') > 0
                         THEN md.o #> '{sample_rows,0}'
                         ELSE md.o
                    END) AS t(k, v)
                WHERE a.row_id = %s AND a.entry_date = %s
                  AND lower(t.k) IN ('query_text','query','sql_text','statement',
                                     'command_text','batch_text')
                """,
                (row_id, entry_date),
            )
            r = cur.fetchone()
        return (r[0] or "") if r else ""
    except Exception:
        return ""


def selftest(server=None, query=None):
    """`python -m security_agent.runner` -- prove the wiring without a collector."""
    from security_agent import llm, rules
    print("enabled          :", config.is_enabled())
    print("suppression      :", config.suppression_enabled())
    print("fail_open        :", config.fail_open())
    print("gated domains    :", sorted(config.gated_domains()))
    for k, v in llm.backend_status().items():
        print(f"{k:17}:", v)
    print("rules            :", rules.summary().get("version"),
          f"({rules.catalog_size()} catalog entries)")
    print("available        :", llm.available())
    if not server:
        return
    q = query or "SELECT name, password_hash FROM dbo.Users WHERE 1=1"
    conn = _connect()
    try:
        v = agent.classify(conn, {"server": server, "query": q,
                                  "root_cause_id": "SELFTEST", "metric_name": None})
        for k in ("verdict", "confidence", "decided_by", "elapsed_ms", "reason"):
            print(f"{k:17}:", v.get(k))
        print("precedent        :", v.get("precedent"))
    finally:
        conn.close()


if __name__ == "__main__":
    import sys
    selftest(sys.argv[1] if len(sys.argv) > 1 else None,
             sys.argv[2] if len(sys.argv) > 2 else None)
