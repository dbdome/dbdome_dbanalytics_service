"""Classify one candidate alert. Never raises, never blocks forever.

This runs inside the collector's alert path, so two properties matter more than
accuracy:

  * It cannot throw. Any failure returns a fail-open SECURITY_ALERT verdict with
    a reason explaining the degradation, so collection continues exactly as it
    does today.
  * It cannot hang. Generation runs on a worker thread with a wall-clock budget
    (SECURITY_AGENT_TIMEOUT_SECS). On timeout we abandon the wait and fail open.
    The worker itself keeps running to completion -- llama.cpp offers no
    cancellation -- but it holds only the generation lock, so the damage is
    bounded to later classifications queueing behind it rather than the sweep
    stalling.
"""
import time
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeout

from utils.log4dbexpert import db_write_log
from security_agent import (config, fingerprint as fp, llm, prompts, classifier,
                            retriever, correlation)

# One shared worker: generation is serialized behind llm._GEN_LOCK anyway, so a
# bigger pool would only queue threads instead of futures.
_POOL = ThreadPoolExecutor(max_workers=1, thread_name_prefix="secagent")


def _fail_open(reason, precedent, query_text, *, decided_by, privileged=False,
               correlation_data=None):
    return {
        "verdict": classifier.VERDICT_ALERT,
        "confidence": 0.0,
        "reason": reason,
        "indicators": [],
        "matched_precedent": bool((precedent or {}).get("exact_matches")),
        "precedent": precedent or {},
        # Carried on the fail-open paths too: correlation is pure SQL and
        # succeeds even when the model is missing or timed out, so the reviewer
        # still gets the corroboration evidence on an untriaged alert.
        "correlation": correlation_data or {},
        "fingerprint": fp.fingerprint(query_text or ""),
        "model": None,
        "elapsed_ms": 0,
        "decided_by": decided_by,
        "privileged": privileged,
    }


def classify(conn, candidate: dict) -> dict:
    """candidate: {server, query, root_cause_id, metric_name, risk_level,
                   rule_name, detection_desc}. Returns a verdict dict."""
    t0 = time.time()
    server = candidate.get("server") or ""
    query_text = (candidate.get("query") or "").strip()

    # No query to judge -> nothing to suppress on. Alert as today.
    if not query_text:
        return _fail_open(
            "No query text was available for triage, so the alert was raised unchanged.",
            {}, query_text, decided_by="no_query")

    privileged = fp.is_privileged(query_text)
    candidate = dict(candidate)
    candidate["shape"] = fp.shape(query_text)
    candidate["privileged"] = privileged

    # Retrieval is useful even when the model is absent: the counts go into the
    # reason text and the verdict record either way.
    try:
        precedent = retriever.find_precedent(
            conn, server, query_text, candidate.get("metric_name"))
    except Exception as e:
        precedent = {"exact_matches": 0, "distinct_shapes": 0, "neighbours": [],
                     "searched": 0, "method": "none", "error": str(e)}

    # Second evidence arm: what else fired on this host in this window, and how
    # usual this rule / login / hour is here. Pure SQL against alerts.alert_log
    # (measured 35-335 ms), so it is gathered even when the model is absent --
    # the flags go into the deterministic reason and the verdict record too.
    try:
        corr = correlation.gather(conn, candidate)
    except Exception as e:
        corr = {"enabled": True, "error": str(e), "concurrent": {},
                "history": {}, "flags": []}

    # Rule 2 short-circuit: a privileged statement is alerted without spending
    # model time. Precedent cannot excuse GRANT/DROP/ALTER-class actions, so
    # there is no verdict the model could return that would change the outcome.
    if privileged:
        v = _fail_open(classifier.deterministic_reason(precedent, True),
                       precedent, query_text, decided_by="privileged_shape",
                       privileged=True, correlation_data=corr)
        v["elapsed_ms"] = int((time.time() - t0) * 1000)
        return v

    if not llm.available():
        v = _fail_open(classifier.deterministic_reason(precedent, False),
                       precedent, query_text, decided_by="model_unavailable",
                       correlation_data=corr)
        v["elapsed_ms"] = int((time.time() - t0) * 1000)
        return v

    user_prompt = prompts.build_user_prompt(candidate, precedent, corr)

    # A cold sidecar must load ~2.2GB before it can generate. Charging that to
    # the steady-state budget meant the first alert after every service restart
    # timed out and failed open for no reason but start-up cost.
    budget = config.timeout_secs()
    try:
        if not llm.is_loaded():
            budget += config.load_timeout_secs()
    except Exception:
        budget += config.load_timeout_secs()

    try:
        # system_prompt() re-reads rules.json when it changed on disk, so a rule
        # edit takes effect on the next alert without a restart.
        fut = _POOL.submit(llm.generate, prompts.system_prompt(), user_prompt)
        raw, prompt_tokens = fut.result(timeout=budget)
    except FutureTimeout:
        # The abandoned future still owns the single pool worker, and llama.cpp
        # cannot be cancelled -- so without this kill, the NEXT classification
        # queues behind a request nobody is waiting for any more. Measured: one
        # 102s first call made the following alert burn its full budget waiting
        # for the worker rather than for its own generation. Killing the sidecar
        # frees the worker; it is respawned lazily on the next call.
        try:
            llm.kill_for_timeout()
        except Exception:
            pass
        db_write_log(
            f"security_agent: triage timed out after {budget:.0f}s "
            f"({candidate.get('root_cause_id')}) -- sidecar killed, failing open",
            0, "security_agent.agent", server)
        v = _fail_open(
            f"Model triage exceeded its {budget:.0f}s budget, so the "
            f"alert was raised without suppression (fail-open).",
            precedent, query_text, decided_by="timeout", correlation_data=corr)
        v["elapsed_ms"] = int((time.time() - t0) * 1000)
        return v
    except Exception as e:
        v = _fail_open(f"Model triage failed ({e}), so the alert was raised "
                       f"unchanged (fail-open).",
                       precedent, query_text, decided_by="generation_error",
                       correlation_data=corr)
        v["elapsed_ms"] = int((time.time() - t0) * 1000)
        return v

    v = classifier.normalize(raw, precedent)
    v["precedent"] = precedent
    v["correlation"] = corr
    v["fingerprint"] = fp.fingerprint(query_text)
    v["model"] = llm.model_name()
    v["prompt_tokens"] = prompt_tokens
    v["elapsed_ms"] = int((time.time() - t0) * 1000)
    v["decided_by"] = "model"
    v["privileged"] = False

    # Confidence floor. Only meaningful when a KNOWN_QUERY verdict could
    # actually stop an alert; with suppression off the verdict stays the model's
    # honest opinion and the reason is not rewritten, because nothing was
    # overridden and saying otherwise would put a false statement on the alert.
    if (config.suppression_enabled()
            and v["verdict"] == classifier.VERDICT_KNOWN
            and v["confidence"] < config.min_confidence()):
        v["reason"] = (
            f"Model judged this known application traffic with confidence "
            f"{v['confidence']:.2f}, below the {config.min_confidence():.2f} "
            f"threshold required to suppress, so the alert was raised. "
            f"Model rationale: {v['reason']}"
        )
        v["verdict"] = classifier.VERDICT_ALERT
        v["decided_by"] = "low_confidence_override"

    return v
