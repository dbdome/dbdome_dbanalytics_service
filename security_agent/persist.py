"""Recording the verdict.

Two destinations, deliberately separate:

  merge_reason()   -- folds `reason` (and a compact security_agent block) into the
                      metadata jsonb that is about to be written to
                      alerts.alert_log. This is what a DBA sees on the alert.

  record_verdict() -- appends every decision, INCLUDING suppressions, to
                      alerts.security_agent_verdict. Suppressions never reach
                      alert_log by definition, so without this table a false
                      negative would be invisible forever. That table is the only
                      way to audit what the gate silenced.

merge_reason is written to be shape-safe: alert_log.metadata is NOT NULL jsonb and
different collectors write either an object or an array of result rows there, so
an array payload is wrapped rather than mutated, and the original rows are kept
under 'sample_rows' -- the key the existing object-shaped payloads already use.
"""
import json

from utils.log4dbexpert import db_write_log

REASON_KEY = "reason"
AGENT_KEY = "security_agent"


def merge_reason(metadata, verdict: dict):
    """Return a NEW metadata payload carrying the agent's reason.

    Never mutates the caller's object, so a failure here cannot corrupt the
    payload that was going to be written anyway.
    """
    block = {
        "verdict": verdict.get("verdict"),
        "confidence": verdict.get("confidence"),
        "matched_precedent": verdict.get("matched_precedent"),
        "indicators": verdict.get("indicators") or [],
        "precedent": {
            "exact_matches": (verdict.get("precedent") or {}).get("exact_matches", 0),
            "distinct_shapes": (verdict.get("precedent") or {}).get("distinct_shapes", 0),
            "searched": (verdict.get("precedent") or {}).get("searched", 0),
            "method": (verdict.get("precedent") or {}).get("method"),
        },
        "model": verdict.get("model"),
        "elapsed_ms": verdict.get("elapsed_ms"),
        "decided_by": verdict.get("decided_by"),
    }
    reason = verdict.get("reason") or ""

    try:
        if isinstance(metadata, dict):
            out = dict(metadata)
            out[REASON_KEY] = reason
            out[AGENT_KEY] = block
            return out
        if isinstance(metadata, list):
            # Array payloads have no place for a key. Wrap, preserving the rows
            # under the same key object-shaped payloads already use.
            return {"sample_rows": metadata, REASON_KEY: reason, AGENT_KEY: block}
        if metadata is None:
            return {REASON_KEY: reason, AGENT_KEY: block}
        if isinstance(metadata, str):
            # Several collectors hand us a JSON *string* rather than a parsed
            # object -- the mssql one passes _sanitize_json(to_records_json(df)).
            # Wrapping that verbatim produced
            #     {"value": "[{\"session_id\":null,...}]", "reason": ...}
            # i.e. the captured rows stringified inside a wrapper, which changed
            # the metadata shape for exactly the alerts the agent annotates and
            # made them render as one unreadable cell. Parse first, then merge
            # into the real payload.
            try:
                parsed = json.loads(metadata)
            except Exception:
                parsed = None
            if parsed is not None and isinstance(parsed, (dict, list)):
                return merge_reason(parsed, verdict)
        # Genuine scalar: keep it verbatim alongside the reason.
        return {"value": metadata, REASON_KEY: reason, AGENT_KEY: block}
    except Exception:
        # Whatever happens, the alert must still be insertable.
        return metadata


def record_verdict(conn, *, server, root_cause_id, metric_name, query_text,
                   verdict: dict, alert_row_id=None, raised: bool):
    """Append one decision to alerts.security_agent_verdict. Best-effort."""
    prec = verdict.get("precedent") or {}
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO alerts.security_agent_verdict
                    (server, root_cause_id, metric_name, query_text, query_fingerprint,
                     verdict, confidence, reason, indicators, matched_precedent,
                     exact_matches, distinct_shapes, candidates_searched,
                     retrieval_method, model, elapsed_ms, decided_by, raised,
                     alert_row_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING verdict_id
                """,
                (
                    server, root_cause_id, metric_name,
                    (query_text or "")[:20000], verdict.get("fingerprint"),
                    verdict.get("verdict"), verdict.get("confidence"),
                    verdict.get("reason"),
                    json.dumps(verdict.get("indicators") or []),
                    verdict.get("matched_precedent"),
                    prec.get("exact_matches", 0), prec.get("distinct_shapes", 0),
                    prec.get("searched", 0), prec.get("method"),
                    verdict.get("model"), verdict.get("elapsed_ms"),
                    verdict.get("decided_by"), raised, alert_row_id,
                ),
            )
            vid = cur.fetchone()[0]
        conn.commit()
        return vid
    except Exception as e:
        try:
            conn.rollback()
        except Exception:
            pass
        db_write_log(f"security_agent: verdict record failed: {e}", 0,
                     "security_agent.persist", server or "")
        return None


def annotate_alert_log(conn, alert_row_id, entry_date, verdict: dict) -> bool:
    """Fold the reason into an alert_log row that has already been inserted.

    alert_log is RANGE-partitioned on entry_date, so the update is qualified by
    entry_date as well as row_id -- without it Postgres has to touch every
    partition to find the row.
    """
    if alert_row_id is None:
        return False
    block = merge_reason({}, verdict)
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE alerts.alert_log
                SET metadata = CASE
                        WHEN jsonb_typeof(metadata) = 'object'
                            THEN metadata || %s::jsonb
                        ELSE jsonb_build_object('sample_rows', metadata) || %s::jsonb
                    END
                WHERE row_id = %s
                  AND (%s::timestamp IS NULL OR entry_date = %s::timestamp)
                """,
                (json.dumps(block), json.dumps(block), alert_row_id,
                 entry_date, entry_date),
            )
            updated = cur.rowcount
        conn.commit()
        return updated > 0
    except Exception as e:
        try:
            conn.rollback()
        except Exception:
            pass
        db_write_log(f"security_agent: alert_log annotate failed: {e}", 0,
                     "security_agent.persist", "")
        return False
