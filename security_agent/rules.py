"""Load the behaviour rules that shape the agent's system prompt.

WHY A FILE AND NOT A FINE-TUNE
    The shipped model is a quantized GGUF -- there are no gradients in it, so it
    cannot be trained in place. Teaching it a new threat shape via LoRA would
    mean the fp16 base model, a GPU, thousands of labelled examples, a merge and
    a re-quantize, repeated for every wording change. Editing a JSON file and
    having it take effect on the next alert is better in every dimension that
    matters here: latency to change, reviewability in git, and the ability to
    revert instantly when a rule makes the agent worse.

HOT RELOAD
    The file is re-read when its mtime changes, so an operator can tune wording
    on a live box without a restart. A malformed file does NOT take the agent
    down: the last good rule set stays in effect (or the built-in fallback), and
    the parse error is logged once.

SCOPE
    Rules shape JUDGEMENT, not DETECTION. Counting "4 distinct destructive
    operations within 5 minutes" is deterministic and belongs in SQL --
    sql_scripts/7610. What the model contributes is deciding whether a matched
    chain is an attack or the nightly archive job that always does exactly that.
"""
import json
import os
import threading
from pathlib import Path

from utils.log4dbexpert import db_write_log
from security_agent import config

_LOCK = threading.Lock()
_CACHE = None
_MTIME = None
_LOGGED_ERROR = None

# Used when rules.json is missing or unreadable. Deliberately minimal: the file
# is the source of truth, and a silent fallback that carried lots of behaviour
# would hide the fact that the real rules never loaded.
_FALLBACK = {
    "version": 0,
    "always_alert": {
        "text": "Precedent NEVER excuses an inherently privileged action. "
                "GRANT, REVOKE, DROP, ALTER, CREATE, TRUNCATE, BACKUP and "
                "RESTORE stay SECURITY_ALERT even if seen before."
    },
    "threats": [],
    "benign_hints": [],
    "custom": [],
}


def rules_path() -> str:
    """rules.json beside the package, or wherever SECURITY_AGENT_RULES points.

    Frozen builds keep it in _internal/security_agent/, which is writable on the
    installed box -- that is the point: an operator can edit the deployed file.
    """
    override = os.getenv("SECURITY_AGENT_RULES", "")
    if override:
        return override
    return str(Path(__file__).resolve().parent / "rules.json")


def load(force: bool = False) -> dict:
    """Current rule set, re-read only when the file changed on disk."""
    global _CACHE, _MTIME, _LOGGED_ERROR
    path = rules_path()

    try:
        mtime = os.path.getmtime(path)
    except OSError:
        if _CACHE is None:
            _CACHE = dict(_FALLBACK)
            if _LOGGED_ERROR != "missing":
                _LOGGED_ERROR = "missing"
                db_write_log(f"security_agent: rules file not found at {path} -- "
                             f"using minimal built-in rules",
                             0, "security_agent.rules", "")
        return _CACHE

    with _LOCK:
        if _CACHE is not None and not force and _MTIME == mtime:
            return _CACHE
        try:
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
            if not isinstance(data, dict):
                raise ValueError("rules.json must contain an object")
            _CACHE, _MTIME, _LOGGED_ERROR = data, mtime, None
            db_write_log(f"security_agent: loaded rules v{data.get('version')} "
                         f"({len(_enabled(data, 'threats'))} threat rules, "
                         f"{len(_enabled(data, 'custom'))} custom)",
                         0, "security_agent.rules", "")
        except Exception as e:
            # Keep serving the last good rules rather than degrading the agent
            # because someone left a trailing comma in a config file.
            if _CACHE is None:
                _CACHE = dict(_FALLBACK)
            if _LOGGED_ERROR != str(e):
                _LOGGED_ERROR = str(e)
                db_write_log(f"security_agent: rules.json is invalid ({e}) -- "
                             f"keeping the previous rule set",
                             0, "security_agent.rules", "")
        return _CACHE


def _enabled(data: dict, key: str) -> list:
    out = []
    for r in (data.get(key) or []):
        if isinstance(r, dict) and r.get("enabled") and (r.get("text") or "").strip():
            out.append(r)
    return out


def prompt_block() -> str:
    """The rules rendered as prompt text, appended to the base system prompt.

    Ordered threats-then-benign on purpose: a small model weights later
    instructions heavily, and the last thing it should read before the task is
    what would make it stay QUIET -- which is the judgement we want it to make
    carefully, since alerting is the safe default everywhere else.
    """
    data = load()
    parts = []

    aa = (data.get("always_alert") or {}).get("text", "").strip()
    if aa:
        parts.append("ABSOLUTE RULE: " + aa)

    threats = _enabled(data, "threats") + _enabled(data, "custom")
    if threats:
        parts.append("\nTHREAT SHAPES TO RECOGNISE:")
        for r in threats:
            parts.append(f"- [{r.get('id', '?')}] {r['text'].strip()}")

    benign = _enabled(data, "benign_hints")
    if benign:
        parts.append("\nWHAT IS ROUTINE (do not cry wolf):")
        for r in benign:
            parts.append(f"- [{r.get('id', '?')}] {r['text'].strip()}")

    return "\n".join(parts)


def catalog_entry(root_cause_id: str) -> dict:
    """The product's own description of the rule that fired, if we have it.

    Kept OUT of the system prompt on purpose. The catalogue can hold hundreds of
    root causes and n_ctx is 4096 tokens -- injecting all of them would crowd out
    the actual evidence and make every classification worse. The alert being
    judged already carries its root_cause_id, so exactly one entry is looked up
    and injected as grounding for that alert.
    """
    if not root_cause_id:
        return {}
    cat = (load().get("catalog") or {})
    return cat.get(root_cause_id) or {}


def catalog_size() -> int:
    return len(load().get("catalog") or {})


def summary() -> dict:
    """For selftest / the verdict record -- which rule set produced a decision."""
    data = load()
    return {
        "version": data.get("version"),
        "path": rules_path(),
        "threats": [r.get("id") for r in _enabled(data, "threats")],
        "custom": [r.get("id") for r in _enabled(data, "custom")],
        "benign": [r.get("id") for r in _enabled(data, "benign_hints")],
    }
