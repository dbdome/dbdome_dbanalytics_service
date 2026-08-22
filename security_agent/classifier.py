"""Turn the model's reply into a normalized verdict dict.

Small quantized models drift out of strict JSON -- they wrap it in a code fence,
prepend a sentence, or emit the schema back. Parsing is therefore tolerant, and
crucially it is BIASED: anything we cannot confidently read as a
well-formed KNOWN_QUERY verdict resolves to SECURITY_ALERT. An unparseable reply
must never be able to silence an alert.
"""
import json
import re

VERDICT_ALERT = "SECURITY_ALERT"
VERDICT_KNOWN = "KNOWN_QUERY"


_RE_VERDICT = re.compile(r'"verdict"\s*:\s*"([^"]{1,60})"', re.I)
# "response" is accepted alongside "reason", and the surrounding quotes on the
# KEY are optional: when the model's JSON derails it has been seen both renaming
# the key and dropping its quotes, e.g.
#     "confidence": 0.95,
#     ran
#
#     response: "The query is a standard SELECT statement..."
# Requiring a quoted key lost that reason, and a KNOWN_QUERY verdict with no
# rationale is force-alerted -- so a correct judgement was thrown away over a
# missing pair of quotes.
_RE_REASON2 = re.compile(r'"?(?:reason|response)"?\s*:\s*"(.*?)"\s*[,}\n]', re.I | re.S)
_RE_CONF = re.compile(r'"confidence"\s*:\s*([01](?:\.\d+)?)', re.I)
_RE_MATCHED = re.compile(r'"matched_precedent"\s*:\s*(true|false)', re.I)


def _extract_json(text: str):
    """First balanced {...} object in the text, or None."""
    if not text:
        return None
    start = text.find("{")
    while start != -1:
        depth = 0
        for i in range(start, len(text)):
            c = text[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(text[start:i + 1])
                    except ValueError:
                        break
        start = text.find("{", start + 1)
    return None


def _salvage_fields(text: str):
    """Pull the fields out of syntactically broken JSON.

    A quantized model occasionally emits a stray token mid-object -- observed
    live: '"confidence": 0 Cookies' and '"confidence": 0.95,\\nran\\n\\nresponse:'.
    In BOTH cases the verdict and the reason were present and correct; only the
    punctuation between them was wrong, and strict parsing discarded a good
    answer. Field-level extraction recovers it.

    Returns None when there is no verdict to recover, so genuine non-answers
    still fall through to the alert-by-default path.
    """
    if not text:
        return None
    m = _RE_VERDICT.search(text)
    if not m:
        return None
    out = {"verdict": m.group(1)}
    r = _RE_REASON2.search(text)
    if r and len(r.group(1).strip()) >= 10:
        out["reason"] = r.group(1).strip()
    c = _RE_CONF.search(text)
    if c:
        try:
            out["confidence"] = float(c.group(1))
        except ValueError:
            pass
    mp = _RE_MATCHED.search(text)
    if mp:
        out["matched_precedent"] = mp.group(1).lower() == "true"
    return out


def _confidence(v) -> float:
    try:
        f = float(v)
    except (TypeError, ValueError):
        return 0.0
    if f > 1.0:            # model said 85 rather than 0.85
        f = f / 100.0
    return max(0.0, min(1.0, f))


def normalize(raw_text: str, precedent: dict) -> dict:
    """Return {verdict, confidence, reason, indicators, matched_precedent, parsed}."""
    data = _extract_json(raw_text)
    salvaged_fields = False
    if not data:
        data = _salvage_fields(raw_text)
        salvaged_fields = bool(data)
    data = data or {}

    raw_verdict = str(data.get("verdict", "")).strip().upper().replace("-", "_")

    # ECHO GUARD. A small model will happily copy the example answer back. If
    # BOTH labels appear, it reproduced the instruction rather than choosing --
    # e.g. "SECURITY_ALERT|KNOWN_QUERY". Substring matching would then find
    # "ALERT" and record a decision that was never made. Treat it as no answer.
    echoed = ("KNOWN" in raw_verdict and "ALERT" in raw_verdict) or "|" in raw_verdict
    if echoed:
        verdict = VERDICT_ALERT
    elif "KNOWN" in raw_verdict or "BENIGN" in raw_verdict or "NORMAL" in raw_verdict:
        verdict = VERDICT_KNOWN
    elif "ALERT" in raw_verdict or "SECURITY" in raw_verdict or "SUSPIC" in raw_verdict:
        verdict = VERDICT_ALERT
    else:
        # Unreadable verdict -> alert. Never let parser confusion buy silence.
        verdict = VERDICT_ALERT

    reason = (data.get("reason") or "").strip()
    if not reason:
        salvaged = _salvage(raw_text)
        reason = salvaged or "The model returned no usable rationale."
        if verdict == VERDICT_KNOWN and not salvaged:
            # A suppression with no stated reason is not auditable; refuse it.
            verdict = VERDICT_ALERT
            reason = ("Model classified this as known traffic but produced no "
                      "rationale, so the alert was raised rather than suppressed.")

    indicators = [str(i).strip() for i in (data.get("indicators") or []) if str(i).strip()]

    if echoed:
        reason = ("The model echoed the answer template instead of deciding "
                  "(verdict came back as '" + raw_verdict[:60] + "'), so the "
                  "alert was raised rather than trusted to a non-answer.")

    return {
        "verdict": verdict,
        # An echoed template carries no confidence, whatever number came with it.
        "confidence": 0.0 if echoed else _confidence(data.get("confidence")),
        "reason": reason[:2000],
        "indicators": [] if echoed else indicators[:10],
        "matched_precedent": bool(data.get("matched_precedent"))
                             or bool(precedent.get("exact_matches")),
        "parsed": bool(data) and not echoed,
        "echoed_template": echoed,
        # Recorded so the verdict table shows how often the model's JSON needed
        # repairing -- a rising rate is the signal to change model or quantization.
        "salvaged_fields": salvaged_fields,
    }


def _salvage(raw_text: str) -> str:
    """Readable prose from a non-JSON reply: drop fences and any echoed schema."""
    if not raw_text:
        return ""
    t = re.sub(r"```[a-zA-Z]*", "", raw_text).replace("```", "")
    t = re.sub(r"\{.*\}", "", t, flags=re.S)
    t = re.sub(r"[ \t]+", " ", t).strip()
    return t[:600].strip()


def deterministic_reason(precedent: dict, privileged: bool) -> str:
    """Reason text for verdicts decided without the model (fail-open paths)."""
    if privileged:
        return ("Privileged statement class -- alerted without model triage; "
                "precedent does not excuse GRANT/DROP/ALTER-class actions.")
    ex = precedent.get("exact_matches", 0)
    if ex:
        return (f"{ex} prior call(s) on this server carry an identical normalized "
                f"statement, but the alert was raised because model triage was "
                f"unavailable (fail-open).")
    return ("No precedent for this statement was found on this server and model "
            "triage was unavailable, so the alert was raised (fail-open).")
