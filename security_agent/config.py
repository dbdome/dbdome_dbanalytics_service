"""Configuration for the offline security-triage agent.

Knobs come from the same .env the rest of the service reads. utils.config_dotenv
here has no _ensure_env_loaded() (that is a dbdiagnostics helper), and it loads
the .env sitting next to sys.executable -- which under a venv is the venv's
python, not the repo. So we load defensively from both the exe directory and the
repo root, mirroring the note in utils/secrets_crypto about venv runs.
"""
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

_LOADED = False


def _base_dir() -> Path:
    # Frozen (PyInstaller): models live beside the exe, under _internal.
    # Source: repo root.
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


def _ensure_env_loaded() -> None:
    global _LOADED
    if _LOADED:
        return
    for cand in (Path(sys.executable).resolve().parent / ".env",
                 _base_dir() / ".env"):
        try:
            if cand.is_file():
                load_dotenv(str(cand), override=False)
        except Exception:
            pass
    _LOADED = True


def _env(key: str, default: str = "") -> str:
    _ensure_env_loaded()
    return os.getenv(key, default)


def _flag(key: str, default: str) -> bool:
    return _env(key, default).strip().lower() in ("1", "true", "yes", "on")


# ---------------------------------------------------------------- enablement
def is_enabled() -> bool:
    """Off unless explicitly switched on.

    Not a safety gate any more (see suppression_enabled below -- the agent never
    silences an alert), but it does load a ~2.3 GB model and add inference time
    to the alert path, so an upgrade must not switch that on by surprise.
    """
    return _flag("SECURITY_AGENT_ENABLED", "false")


def suppression_enabled() -> bool:
    """Whether a KNOWN_QUERY verdict may actually stop an alert.

    DEFAULT OFF, by explicit decision: the agent's job is to EXPLAIN every
    alert, not to silence any. Every alert fires exactly as it does today and
    additionally carries `reason` describing whether the query looks like known
    application traffic or a genuine security finding.

    Leaving this off means the agent cannot ever hide an intrusion, which is
    what makes it safe to run across every domain rather than security only.
    Turning it on re-introduces that risk and should not be done without first
    reviewing alerts.v_security_agent_suppressed for a while.
    """
    return _flag("SECURITY_AGENT_SUPPRESS", "false")


def fail_open() -> bool:
    """On any agent failure, should the alert still fire? Default yes."""
    return _flag("SECURITY_AGENT_FAIL_OPEN", "true")


def gated_domains() -> set:
    """Which alert domains the agent annotates. '*' = all of them.

    Annotating every domain is safe precisely because suppression is off: a
    verdict on a disk-space alert may be uninformative, but it cannot do harm,
    and it is recorded so its usefulness can be judged from data.
    """
    raw = _env("SECURITY_AGENT_DOMAINS", "*")
    return {d.strip().lower() for d in raw.split(",") if d.strip()}


def min_confidence() -> float:
    """Confidence a KNOWN_QUERY verdict needs before it could suppress anything.

    Only consulted when SECURITY_AGENT_SUPPRESS is on. Asymmetric on purpose:
    the model must be CONFIDENT to stay quiet, never to raise. Uncertainty
    always resolves toward alerting.
    """
    return float(_env("SECURITY_AGENT_MIN_CONFIDENCE", "0.75"))


# ---------------------------------------------------------------- backend
def backend_setting() -> str:
    """Raw setting: 'auto' (default), 'ollama' or 'sidecar'."""
    v = _env("SECURITY_AGENT_BACKEND", "auto").strip().lower()
    return v if v in ("auto", "sidecar", "ollama") else "auto"


def backend() -> str:
    """Which runtime to use for THIS call: 'ollama' or 'sidecar'.

    AUTO is the default and prefers Ollama when it is reachable with the model
    present, falling back to the bundled sidecar otherwise. Measured on this box
    (2026-08-21), same three cases, same prompt:

                        sidecar (GGUF)   ollama phi3:mini-128k
        warm latency        60.7s              20.8s
        cold latency       126.5s              47.8s
        JSON corruption   needed salvage       none
        mundane query     false positive       correct KNOWN_QUERY

    So Ollama is better where it exists. But it cannot be a hard requirement:
    `ollama pull` needs internet, and a customer's database server is usually
    air-gapped. The sidecar ships in the bundle with its GGUF and works with no
    network at all, so it stays as the fallback and the product keeps its
    fully-offline install story.

    The probe is cheap (a 2s call to /api/tags on loopback) and its result is
    cached, so this does not add a round trip per alert.
    """
    setting = backend_setting()
    if setting in ("sidecar", "ollama"):
        return setting
    return "ollama" if _ollama_detected() else "sidecar"


# Auto-detection is cached: the answer changes only when Ollama is installed,
# started or stopped, and re-probing per alert would add latency to the path we
# are trying to keep fast.
_DETECT_CACHE = {"at": 0.0, "value": None}


def detect_ttl() -> int:
    """Seconds before the Ollama probe is repeated. 0 disables caching."""
    return int(_env("SECURITY_AGENT_DETECT_TTL", "300"))


def _ollama_detected() -> bool:
    import time
    ttl = detect_ttl()
    now = time.time()
    if (_DETECT_CACHE["value"] is not None and ttl
            and (now - _DETECT_CACHE["at"]) < ttl):
        return _DETECT_CACHE["value"]
    ok = False
    try:
        import requests
        r = requests.get(f"{ollama_url()}/api/tags", timeout=2)
        if r.status_code == 200:
            want = ollama_model()
            stem = want.split(":")[0] + ":"
            names = [m.get("name", "") for m in (r.json().get("models") or [])]
            ok = any(n == want or n.startswith(stem) for n in names)
    except Exception:
        ok = False
    _DETECT_CACHE.update({"at": now, "value": ok})
    return ok


def invalidate_backend_cache() -> None:
    """Force the next backend() call to re-probe (used by selftest)."""
    _DETECT_CACHE.update({"at": 0.0, "value": None})


def ollama_url() -> str:
    return _env("SECURITY_AGENT_OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")


def ollama_model() -> str:
    """Ollama model tag, e.g. 'phi3:mini-128k'.

    NOTE on 128k: the long-context variant does not make anything faster. The
    agent's prompt is ~1,500 tokens, so 4k was never the binding constraint --
    latency is. Larger num_ctx costs KV-cache memory and slows prompt
    evaluation, so num_ctx below stays modest regardless of what the model
    supports.
    """
    return _env("SECURITY_AGENT_OLLAMA_MODEL", "phi3:mini-128k")


def ollama_keep_alive() -> str:
    """How long Ollama keeps the model resident between alerts.

    Was 30m; raised to 24h after production measurement. Alerts arrive in
    bursts with long gaps, so a 30m window let the model unload between them
    and every burst paid the ~62s load again: 11 timeouts averaging 135s
    against 20.8s warm in isolation. Residency is the single biggest lever on
    this latency.

    '-1' keeps it loaded indefinitely. That costs ~3.6GB of RAM permanently,
    which is the trade to make deliberately rather than by default.
    """
    return _env("SECURITY_AGENT_OLLAMA_KEEP_ALIVE", "24h")


def warm_on_start() -> bool:
    """Load the model before the first alert needs it.

    Without this the first classification after every service restart pays the
    cold load (~62s) on top of generation, which alone exceeded the budget and
    failed open for no reason but start-up cost.
    """
    return _flag("SECURITY_AGENT_WARM_ON_START", "true")


# ---------------------------------------------------------------- where triage runs
def annotate_inline() -> bool:
    """Triage inside the collector's alert path (True) or afterwards (False).

    DEFAULT FALSE, and this is the important one.

    Inline, every alert waits for a model on CPU - 20-30s at best, 135s
    observed in production - and that delay lands between the detection firing
    and the alert being dispatched. Nothing is lost (the agent fails open) but
    alerting gets slower, which is the opposite of what a security product
    should trade away.

    Off, the collector writes the alert immediately and a scheduled sweep
    annotates it seconds later with the same verdict. Latency stops being
    something to tune and becomes irrelevant.

    Set true only where alert dispatch must already carry the reason - e.g. a
    mail that must not go out unannotated.
    """
    return _flag("SECURITY_AGENT_ANNOTATE_INLINE", "false")


def annotate_lookback_minutes() -> int:
    """How far back the annotation sweep looks for untriaged alerts."""
    return int(_env("SECURITY_AGENT_ANNOTATE_LOOKBACK_MIN", "120"))


def annotate_batch_size() -> int:
    """Cap on alerts annotated per sweep.

    At ~25s each this bounds one sweep to about ten minutes of work, so a
    backlog drains over several sweeps instead of one run monopolising the
    model and starving everything else.
    """
    return int(_env("SECURITY_AGENT_ANNOTATE_BATCH", "25"))


# ---------------------------------------------------------------- model
def model_path() -> str:
    raw = _env(
        "SECURITY_AGENT_MODEL",
        "security_agent/models/Phi-3-mini-4k-instruct-q4.gguf",
    )
    p = Path(raw)
    if not p.is_absolute():
        p = _base_dir() / raw
    return str(p)


def n_ctx() -> int:
    return int(_env("SECURITY_AGENT_N_CTX", "4096"))


def n_threads() -> int:
    v = _env("SECURITY_AGENT_N_THREADS", "")
    return int(v) if v else (os.cpu_count() or 4)


def n_gpu_layers() -> int:
    return int(_env("SECURITY_AGENT_N_GPU_LAYERS", "0"))


def max_tokens() -> int:
    # A verdict is a short JSON object: verdict, confidence, one reason
    # sentence, a couple of indicators. Measured at 320 the model was still
    # generating past the timeout; generation time is roughly linear in output
    # length, so this is the cheapest lever that costs nothing real.
    return int(_env("SECURITY_AGENT_MAX_TOKENS", "160"))


def temperature() -> float:
    # Near-deterministic: this is a classification, not a writing task.
    return float(_env("SECURITY_AGENT_TEMPERATURE", "0.1"))


def timeout_secs() -> float:
    """Wall-clock budget for one classification before we give up and fail open.

    Raised from 25s after measurement: on CPU with a ~1,050-token system prompt
    plus evidence, Phi-3-mini did not finish a verdict inside 25s and EVERY
    classification failed open -- which is safe but useless, because the agent
    then contributes nothing but a "triage timed out" reason.

    90s is affordable here because this runs per raised alert, AFTER the
    collection sweep, and never blocks collection. If alert dispatch latency
    matters more than triage at a given site, lower it: the failure mode is
    graceful.
    """
    return float(_env("SECURITY_AGENT_TIMEOUT_SECS", "90"))


def load_timeout_secs() -> float:
    """Extra budget allowed on the FIRST request, which also loads the model.

    A 2.3 GB GGUF off a cold disk can take a while; charging that to the normal
    per-call timeout would make the first alert after every service restart fail
    open for no good reason.
    """
    return float(_env("SECURITY_AGENT_LOAD_TIMEOUT_SECS", "180"))


def sidecar_path() -> str:
    """Explicit override for the sidecar executable (see llm.sidecar_path)."""
    return _env("SECURITY_AGENT_SIDECAR", "")


# ---------------------------------------------------------------- retrieval
def lookback_days() -> int:
    """How far back to look for precedent in general_metric_metadata_results.

    NOTE: gmmr.entry_date is the ONSET of a state, not a freshness stamp, so a
    narrow window silently returns nothing. Default wide.
    """
    return int(_env("SECURITY_AGENT_LOOKBACK_DAYS", "90"))


def candidate_limit() -> int:
    """Rows pulled per lookup before fingerprinting/ranking (bounded scan)."""
    return int(_env("SECURITY_AGENT_CANDIDATES", "400"))


def top_k() -> int:
    """How many similar calls are shown to the model as precedent."""
    return int(_env("SECURITY_AGENT_TOP_K", "5"))


def min_similarity() -> float:
    """Cosine floor for a neighbour to count as 'similar' at all."""
    return float(_env("SECURITY_AGENT_MIN_SIMILARITY", "0.55"))


def use_embeddings() -> bool:
    """Rank neighbours with the local model's embeddings.

    Turn off to stay purely on normalized-fingerprint matching, which is far
    cheaper and needs no model at all for the retrieval half.
    """
    return _flag("SECURITY_AGENT_USE_EMBEDDINGS", "true")
