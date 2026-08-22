"""Prompt construction for the security-triage agent.

The model is asked for STRICT JSON -- a verdict, a confidence, and a reason --
because the reason is not decoration here: it is written into
alerts.alert_log.metadata as `reason`, so a human reviewing the alert can see
why it survived triage.

The framing is deliberately biased toward alerting. A small quantized model is
being asked to make a security call, and the asymmetry of the two mistakes is
severe: a false positive costs a DBA five minutes, a false negative hides an
intrusion. So the system prompt tells it that silence must be earned, and the
schema forces it to cite the precedent it relied on.
"""
import json

from security_agent import rules

# Base instructions. Threat-specific knowledge does NOT live here -- it lives in
# rules.json, so adding a rule is a config edit rather than a code change (and
# certainly rather than a fine-tune, which a quantized GGUF cannot accept). Use
# system_prompt() rather than SYSTEM to get the base plus the current rules.
_SYSTEM_BASE = (
    "You are a database security analyst triaging one query that tripped a "
    "detection rule. Decide whether it is a genuine SECURITY_ALERT or a "
    "KNOWN_QUERY -- part of the application's normal transaction traffic on "
    "this server.\n"
    "\n"
    "You are given the query, the rule that fired, and PRECEDENT: what this "
    "same server has actually been observed running. Use the precedent as your "
    "primary evidence. A statement whose shape this server runs routinely is "
    "normal application traffic. A statement with no precedent here is a "
    "candidate for alerting.\n"
    "\n"
    "Rules:\n"
    "(1) Silence must be EARNED. Return KNOWN_QUERY only when the precedent "
    "actually supports it. If the evidence is thin, absent, or ambiguous, "
    "return SECURITY_ALERT -- a missed intrusion is far worse than a false "
    "alarm.\n"
    "(2) Precedent NEVER excuses an inherently privileged action. GRANT, "
    "REVOKE, DROP, ALTER, CREATE, TRUNCATE, BACKUP and RESTORE stay "
    "SECURITY_ALERT even if seen before -- 'it happened yesterday too' is not "
    "an argument that it is safe.\n"
    "(3) Look for attack shape regardless of precedent: tautologies (OR 1=1), "
    "stacked statements, UNION injection, comment truncation, xp_cmdshell / "
    "OPENROWSET / sp_configure, bulk reads of credential or PII tables, "
    "privilege enumeration, or access from an unexpected login, program or "
    "host.\n"
    "(4) Ground the reason in THIS evidence. Cite the precedent counts or the "
    "specific construct you saw. Never invent facts.\n"
    "(4a) DO NOT claim precedent you were not given. If the count of identical "
    "prior statements is 0, you may NOT say the query 'matches precedent' or is "
    "'consistent with normal traffic on this server' -- say instead that no "
    "matching prior statement was found and explain your verdict from the "
    "statement itself. Observed live: a verdict was justified with 'matches the "
    "precedent of normal application traffic' when the precedent count was "
    "zero, which would mislead the reviewer reading the alert.\n"
    "(5) Return STRICT JSON only, no prose outside the JSON."
)


def system_prompt() -> str:
    """Base instructions plus the operator-editable rules from rules.json.

    Rules are appended rather than prepended: a small model weights the end of
    the system message heavily, and the rule text is the site-specific part we
    most want it to act on.
    """
    block = ""
    try:
        block = rules.prompt_block()
    except Exception:
        # rules.py already falls back internally; this guard is for the
        # unexpected. A missing rule block must not stop a classification.
        block = ""
    return _SYSTEM_BASE + ("\n\n" + block if block else "")


# Back-compat for any caller still importing the constant. Evaluated once at
# import, so it does NOT pick up hot-reloaded rules -- prefer system_prompt().
SYSTEM = system_prompt()

# A WORKED EXAMPLE, not a schema with placeholder values.
#
# The first version used "SECURITY_ALERT | KNOWN_QUERY" as the value of
# "verdict" and 0.0 as the value of "confidence". Measured against Phi-3-mini,
# the model copied those literals back verbatim in EVERY response -- so the
# parser saw "SECURITY_ALERT|KNOWN_QUERY", matched "ALERT" inside it, and
# recorded a confident-looking alert at 0.0 confidence no matter what the model
# had actually concluded. The feature would have appeared to work while making
# no decision at all.
#
# A small model imitates the shape it is shown, so show it a REAL answer with
# real values and state the choice in prose instead.
EXAMPLE_ANSWER = {
    "verdict": "SECURITY_ALERT",
    "confidence": 0.82,
    "reason": "The statement selects password_hash with a WHERE clause of 1=1, "
              "and this server has no prior call with a matching statement shape.",
    "indicators": ["selects credential column", "tautology WHERE 1=1", "no precedent"],
    "matched_precedent": False,
}

TASK_INSTRUCTIONS = (
    'Answer with ONE JSON object. "verdict" must be exactly the string '
    '"SECURITY_ALERT" or exactly the string "KNOWN_QUERY" -- choose one, never '
    'both, and never repeat the words of this instruction. "confidence" is your '
    'own number between 0 and 1. "reason" is your own sentence about the query '
    'above. Do not copy the example.\n'
    "Example of a well-formed answer (about a DIFFERENT query -- do not reuse "
    "its wording):"
)


def _clip(s, n):
    if not s:
        return ""
    s = str(s)
    return s if len(s) <= n else s[:n] + "\n...[truncated]..."


def build_user_prompt(candidate: dict, precedent: dict) -> str:
    """candidate: server, query, root_cause_id, rule_name, risk_level, context.
    precedent: output of retriever.find_precedent()."""
    p = []
    p.append(f"SERVER: {candidate.get('server')}")
    p.append(f"RULE THAT FIRED: {candidate.get('root_cause_id')}"
             + (f" -- {candidate['rule_name']}" if candidate.get("rule_name") else ""))
    if candidate.get("risk_level"):
        p.append(f"RULE RISK LEVEL: {candidate['risk_level']}")
    if candidate.get("metric_name"):
        p.append(f"METRIC: {candidate['metric_name']}")

    ctx = candidate.get("context") or {}
    if ctx:
        p.append("SESSION CONTEXT: " + ", ".join(f"{k}={v}" for k, v in sorted(ctx.items())))

    p.append("\n--- QUERY UNDER REVIEW ---\n" + _clip(candidate.get("query", ""), 2500))

    stmt_shape = candidate.get("shape")
    if stmt_shape:
        p.append(f"\nSTATEMENT CLASS: {stmt_shape}"
                 + ("   [PRIVILEGED -- rule 2 applies]" if candidate.get("privileged") else ""))

    # The precedent block is the whole point of the agent; state it numerically
    # so the model reasons from counts rather than vibes.
    p.append("\n--- PRECEDENT ON THIS SERVER ---")
    p.append(f"Prior calls examined: {precedent.get('searched', 0)}")
    p.append(f"Distinct statement shapes this server runs: {precedent.get('distinct_shapes', 0)}")
    p.append(f"Prior calls with an IDENTICAL normalized statement: {precedent.get('exact_matches', 0)}")

    neighbours = precedent.get("neighbours") or []
    if neighbours:
        p.append("\nMost similar prior statements:")
        for n in neighbours:
            p.append(f"  [similarity {n['similarity']}] {_clip(n['query'], 400)}")
    elif not precedent.get("exact_matches"):
        p.append("\nNo similar prior statement was found on this server. "
                 "Absence of precedent is evidence FOR alerting, not against it. "
                 "You must NOT claim in your reason that this query matches "
                 "precedent or normal traffic here -- there is none on record.")

    if precedent.get("error"):
        p.append(f"\n(retrieval was degraded: {precedent['error']} -- treat precedent "
                 f"counts as unreliable and lean toward SECURITY_ALERT)")

    # The product's own definition of the rule that fired, looked up by id from
    # the generated catalogue. One entry, not the whole catalogue -- see
    # rules.catalog_entry for why.
    try:
        cat = rules.catalog_entry(candidate.get("root_cause_id"))
    except Exception:
        cat = {}
    if cat:
        line = f"\n--- WHAT THIS RULE MEANS ({candidate.get('root_cause_id')}) ---"
        if cat.get("name"):
            line += f"\n{cat['name']}"
        if cat.get("desc"):
            line += f"\n{_clip(cat['desc'], 900)}"
        if cat.get("risk"):
            line += f"\n(catalogued risk level: {cat['risk']})"
        p.append(line)

    if candidate.get("detection_desc"):
        p.append("\n--- WHY THE RULE FIRED ---\n" + _clip(candidate["detection_desc"], 1200))

    p.append("\n--- YOUR TASK ---\n" + TASK_INSTRUCTIONS + "\n"
             + json.dumps(EXAMPLE_ANSWER, indent=2)
             + "\n\nNow answer for the query above:")
    return "\n".join(p)
