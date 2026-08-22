"""Client for the llama.cpp sidecar.

The public surface -- available(), generate(), embed(), model_name() -- is
unchanged from the in-process version, so agent.py and retriever.py did not have
to change. What moved is WHERE inference happens.

llama-cpp-python has no Python 3.14 build, and DBDOME is built with venv314, so
the model cannot live in this process. dbdome_secagent.exe is frozen separately
from venv311_agent (llama_cpp 0.3.35) and talks JSON Lines over a pipe. See
sidecar_main.py for the protocol.

The supervision rules matter more than the transport:
  * The sidecar is started lazily, on first real use, and reused thereafter --
    the 2.3 GB model load happens once per service lifetime, not per alert.
  * A dead sidecar is restarted once per call, not in a loop.
  * A missing exe or model is remembered, so a box that will never have one
    does not pay a spawn attempt per alert.
  * Every call has a deadline. A wedged sidecar is killed rather than waited on,
    because this sits in the alert path.
"""
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from utils.log4dbexpert import db_write_log
from security_agent import config

_LOCK = threading.Lock()      # guards spawn/kill
_IO_LOCK = threading.Lock()   # one request on the pipe at a time
_PROC = None
_UNAVAILABLE = None           # cached reason; None = not yet determined unusable


class LlamaUnavailable(RuntimeError):
    """Raised when the sidecar or its model cannot be used."""


def sidecar_path() -> str:
    """Where dbdome_secagent.exe is expected to live.

    It goes in a SUBFOLDER (<bin>\\secagent\\), never beside dbdome_service.exe.
    The sidecar is its own PyInstaller onedir bundle, so it carries an _internal
    directory of its own -- dropping it next to the service exe would collide
    with the service's _internal and corrupt both bundles.

    Source runs fall back to dist_secagent/ in the repo so a developer can point
    a source checkout at a locally built sidecar.
    """
    override = os.getenv("SECURITY_AGENT_SIDECAR", "")
    if override:
        return override
    if getattr(sys, "frozen", False):
        return str(Path(sys.executable).resolve().parent
                   / "secagent" / "dbdome_secagent.exe")
    return str(Path(__file__).resolve().parent.parent
               / "dist_secagent" / "dbdome_secagent" / "dbdome_secagent.exe")


# --------------------------------------------------------------------------
# Ollama backend
#
# Same public surface as the sidecar path (available/generate/embed), so agent.py
# and retriever.py are unchanged. Selected with SECURITY_AGENT_BACKEND=ollama.
# --------------------------------------------------------------------------
def _ollama_opts() -> dict:
    return {
        "temperature": config.temperature(),
        "num_predict": config.max_tokens(),
        # Deliberately NOT the model's maximum. phi3:mini-128k supports 128k, but
        # the prompt is ~1,500 tokens and a larger window only costs KV-cache
        # memory and prompt-evaluation time.
        "num_ctx": config.n_ctx(),
    }


def _ollama_available() -> bool:
    try:
        import requests
        r = requests.get(f"{config.ollama_url()}/api/tags", timeout=2)
        if r.status_code != 200:
            return False
        want = config.ollama_model()
        names = [m.get("name", "") for m in (r.json().get("models") or [])]
        # Accept an exact tag or the same model under a different tag suffix,
        # so 'phi3:mini-128k' still matches when pulled as 'phi3:mini-128k-q4'.
        return any(n == want or n.startswith(want.split(":")[0] + ":") for n in names)
    except Exception:
        return False


def _ollama_generate(system: str, user: str, timeout: float):
    import requests
    r = requests.post(
        f"{config.ollama_url()}/api/chat",
        json={
            "model": config.ollama_model(),
            "messages": [{"role": "system", "content": system},
                         {"role": "user", "content": user}],
            "stream": False,
            # Ollama's structured-output mode. Same purpose as the sidecar's
            # response_format: a quantized model otherwise emits stray tokens
            # mid-JSON and a correct verdict is lost to a parse error.
            "format": "json",
            "options": _ollama_opts(),
            "keep_alive": config.ollama_keep_alive(),
        },
        timeout=timeout,
    )
    r.raise_for_status()
    data = r.json()
    text = (data.get("message") or {}).get("content", "").strip()
    return text, int(data.get("prompt_eval_count") or 0)


def _ollama_embed(text: str, timeout: float):
    import requests
    r = requests.post(
        f"{config.ollama_url()}/api/embeddings",
        json={"model": config.ollama_model(), "prompt": text,
              "keep_alive": config.ollama_keep_alive()},
        timeout=timeout,
    )
    r.raise_for_status()
    return r.json().get("embedding") or []


def available() -> bool:
    """Cheap pre-flight -- no spawn, no model load. Called before every alert."""
    if config.backend() == "ollama":
        return _ollama_available()
    if _UNAVAILABLE is not None:
        return False
    if not os.path.isfile(sidecar_path()):
        return False
    return os.path.isfile(config.model_path())


def _spawn():
    global _PROC, _UNAVAILABLE
    if _PROC is not None and _PROC.poll() is None:
        return _PROC

    exe = sidecar_path()
    if not os.path.isfile(exe):
        _UNAVAILABLE = f"sidecar not found at {exe}"
        raise LlamaUnavailable(_UNAVAILABLE)
    if not os.path.isfile(config.model_path()):
        _UNAVAILABLE = f"GGUF model not found at {config.model_path()}"
        raise LlamaUnavailable(_UNAVAILABLE)

    env = dict(os.environ)
    env["SECURITY_AGENT_MODEL"] = config.model_path()
    try:
        _PROC = subprocess.Popen(
            [exe],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, encoding="utf-8", bufsize=1, env=env,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except Exception as e:
        _UNAVAILABLE = f"failed to start sidecar: {e}"
        raise LlamaUnavailable(_UNAVAILABLE) from e

    db_write_log(f"security_agent: sidecar started ({os.path.basename(exe)}, pid {_PROC.pid})",
                 0, "security_agent.llm", "")
    return _PROC


def _kill():
    global _PROC
    with _LOCK:
        if _PROC is not None:
            try:
                _PROC.kill()
            except Exception:
                pass
            _PROC = None


def _request(payload: dict, timeout: float) -> dict:
    """One JSON-Lines round trip, with a deadline enforced by a reader thread.

    subprocess pipes have no read timeout on Windows, so the read runs on a
    daemon thread; if it misses the deadline we kill the sidecar rather than
    block the alert path forever.
    """
    with _IO_LOCK:
        proc = None
        with _LOCK:
            proc = _spawn()

        try:
            proc.stdin.write(json.dumps(payload, ensure_ascii=False) + "\n")
            proc.stdin.flush()
        except Exception as e:
            _kill()
            raise LlamaUnavailable(f"sidecar write failed: {e}") from e

        result = {}

        def _read():
            try:
                result["line"] = proc.stdout.readline()
            except Exception as e:
                result["error"] = str(e)

        t = threading.Thread(target=_read, daemon=True)
        t.start()
        t.join(timeout)

        if t.is_alive():
            _kill()
            raise LlamaUnavailable(f"sidecar timed out after {timeout:.0f}s")
        if "error" in result:
            _kill()
            raise LlamaUnavailable(f"sidecar read failed: {result['error']}")

        line = (result.get("line") or "").strip()
        if not line:
            _kill()
            raise LlamaUnavailable("sidecar closed the pipe (died during the request)")

        try:
            resp = json.loads(line)
        except Exception as e:
            raise LlamaUnavailable(f"sidecar returned non-JSON: {e}") from e

        if not resp.get("ok"):
            raise LlamaUnavailable(f"sidecar error: {resp.get('error')}")
        return resp


def _model_cfg() -> dict:
    return {
        "model_path": config.model_path(),
        "n_ctx": config.n_ctx(),
        "n_threads": config.n_threads(),
        "n_gpu_layers": config.n_gpu_layers(),
        "temperature": config.temperature(),
        "max_tokens": config.max_tokens(),
    }


def ping(timeout: float = 10.0) -> dict:
    """Liveness check that does not trigger a model load."""
    return _request({"op": "ping"}, timeout)


def generate(system: str, user: str) -> tuple[str, int]:
    """(text, prompt_tokens). The first call also pays the model load."""
    budget = config.timeout_secs() + (0 if _loaded() else config.load_timeout_secs())
    if config.backend() == "ollama":
        return _ollama_generate(system, user, budget)
    payload = dict(_model_cfg())
    # json=True asks the sidecar for grammar-constrained JSON decoding.
    payload.update({"op": "generate", "system": system, "user": user, "json": True})
    resp = _request(payload, budget)
    return resp.get("text", ""), int(resp.get("prompt_tokens", 0))


def embed(text: str):
    budget = config.timeout_secs() + (0 if _loaded() else config.load_timeout_secs())
    if config.backend() == "ollama":
        return _ollama_embed(text, budget)
    payload = dict(_model_cfg())
    payload.update({"op": "embed", "text": text})
    return _request(payload, budget).get("vector") or []


def _loaded() -> bool:
    """Best-effort: is the model already resident?"""
    if config.backend() == "ollama":
        # Ollama keeps the model resident for keep_alive; /api/ps lists what is
        # currently loaded, so a warm model does not get charged the load budget.
        try:
            import requests
            r = requests.get(f"{config.ollama_url()}/api/ps", timeout=2)
            if r.status_code != 200:
                return False
            want = config.ollama_model().split(":")[0]
            return any((m.get("name") or "").startswith(want)
                       for m in (r.json().get("models") or []))
        except Exception:
            return False
    try:
        return bool(ping(5.0).get("loaded"))
    except Exception:
        return False


def is_loaded() -> bool:
    """Public form of _loaded(), so callers can budget for a cold load.

    A cold call is model-load (~62s here) plus generation (~40s); charging that
    to the steady-state budget made the first alert after every restart fail
    open. The agent adds load_timeout_secs when this returns False.
    """
    return _loaded()


def kill_for_timeout():
    """Kill the sidecar so an abandoned request stops occupying the worker.

    llama.cpp offers no cancellation, so a generation the agent has given up
    waiting for keeps running to completion and holds _GEN_LOCK. The next
    classification would then wait for work nobody wants. Killing the process
    releases it; _spawn() brings it back on the next call (paying the model load
    again, which is the price of not stalling the alert path).
    """
    _kill()


def warm(timeout: float = None) -> bool:
    """Load the model NOW, so the first real alert does not pay for it.

    Measured: a cold load is ~62s and generation ~40s, which together exceeded a
    90s budget and made the very first alert after every service start fail open
    for no reason other than start-up cost. Called from the service at startup.
    """
    if not available():
        return False
    try:
        payload = dict(_model_cfg())
        payload.update({"op": "generate", "system": "You are a helper.",
                        "user": "Reply with the single word: ready",
                        "max_tokens": 4})
        _request(payload, timeout or (config.load_timeout_secs() + config.timeout_secs()))
        db_write_log("security_agent: model warmed and resident", 0,
                     "security_agent.llm", "")
        return True
    except Exception as e:
        db_write_log(f"security_agent: warm-up failed ({e}) -- first alert will "
                     f"pay the model load", 0, "security_agent.llm", "")
        return False


def shutdown():
    """Stop the sidecar (service shutdown, or to free the model's memory)."""
    global _PROC
    try:
        if _PROC is not None and _PROC.poll() is None:
            _request({"op": "shutdown"}, 10.0)
    except Exception:
        pass
    finally:
        _kill()


def model_name() -> str:
    """Recorded on every verdict, so the audit trail says which model decided."""
    if config.backend() == "ollama":
        return f"ollama:{config.ollama_model()}"
    return os.path.basename(config.model_path())


def backend_status() -> dict:
    """Diagnostics for selftest and for explaining a fail-open."""
    b = config.backend()
    common = {"setting": config.backend_setting(), "resolved": b}
    if b == "ollama":
        common.update({"url": config.ollama_url(), "model": config.ollama_model(),
                       "available": _ollama_available(), "loaded": _loaded(),
                       "offline": "inference local; `ollama pull` needs internet"})
    else:
        common.update({"exe": sidecar_path(),
                       "exe_present": os.path.isfile(sidecar_path()),
                       "model": config.model_path(),
                       "model_present": os.path.isfile(config.model_path()),
                       "available": available(),
                       "offline": "fully offline incl. provisioning"})
    return common
