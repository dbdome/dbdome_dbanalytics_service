"""Persistent llama.cpp sidecar -- the half of the agent that must run on Python 3.11.

WHY THIS PROCESS EXISTS
    llama-cpp-python publishes no build for Python 3.14, and DBDOME's whole
    bundle is built with C:\\apps\\venv314 (build.ps1 refuses anything else). So
    the model cannot be loaded inside dbdome_service.exe. This sidecar is frozen
    separately from C:\\apps\\venv311_agent, which already carries llama_cpp
    0.3.35, and the service talks to it over a pipe.

WHY IT IS PERSISTENT
    Loading a 2.3 GB GGUF takes seconds. Spawning per request -- and there is one
    request per alert, plus one per embedding during retrieval -- would be far
    slower than the alerts themselves. So the model is loaded once and the
    process serves requests until told to stop.

PROTOCOL -- JSON Lines over stdin/stdout, one object per line:
    -> {"op":"ping"}                                  <- {"ok":true,"model":"..."}
    -> {"op":"generate","system":"...","user":"..."}  <- {"ok":true,"text":"...","prompt_tokens":N}
    -> {"op":"embed","text":"..."}                    <- {"ok":true,"vector":[...]}
    -> {"op":"shutdown"}                              <- {"ok":true}
    errors:                                           <- {"ok":false,"error":"..."}

    stdout carries ONLY protocol lines. Everything human-readable goes to
    stderr, so a stray print can never corrupt a response.
"""
import json
import os
import sys
import traceback

_LLM = None
_MODEL_PATH = None


def _log(msg):
    print(f"[secagent] {msg}", file=sys.stderr, flush=True)


def _load(cfg):
    """Load the model once. cfg comes from the first request or the environment."""
    global _LLM, _MODEL_PATH
    if _LLM is not None:
        return _LLM

    from llama_cpp import Llama  # heavy native dep; only in this process

    path = cfg.get("model_path") or os.environ.get("SECURITY_AGENT_MODEL", "")
    if not path or not os.path.isfile(path):
        raise RuntimeError(f"GGUF model not found at {path!r}")

    _LLM = Llama(
        model_path=path,
        n_ctx=int(cfg.get("n_ctx", 4096)),
        n_threads=int(cfg.get("n_threads", os.cpu_count() or 4)),
        n_gpu_layers=int(cfg.get("n_gpu_layers", 0)),
        embedding=True,           # same model serves retrieval ranking
        verbose=False,
    )
    _MODEL_PATH = path
    _log(f"loaded {os.path.basename(path)}")
    return _LLM


def _handle(req):
    op = req.get("op")

    if op == "ping":
        # Deliberately does NOT load the model: the service uses ping as a cheap
        # liveness check and must not pay a 2.3 GB load to find out the pipe works.
        return {"ok": True, "model": os.path.basename(_MODEL_PATH) if _MODEL_PATH else None,
                "loaded": _LLM is not None}

    if op == "generate":
        llm = _load(req)
        kwargs = dict(
            messages=[
                {"role": "system", "content": req.get("system", "")},
                {"role": "user", "content": req.get("user", "")},
            ],
            temperature=float(req.get("temperature", 0.1)),
            max_tokens=int(req.get("max_tokens", 320)),
        )
        # Constrain the sampler to well-formed JSON when the caller wants JSON.
        #
        # Without this, the q4 quantization periodically emits a garbage token
        # mid-object -- observed live: '"confidence": 0 Cookies' and
        # '"confidence": 0.95,\nran\n\nresponse:'. The model's REASONING was
        # correct both times; the corrupted syntax alone made json.loads fail
        # and the verdict was discarded. Grammar-constrained decoding makes that
        # class of failure impossible rather than merely recoverable.
        if req.get("json"):
            kwargs["response_format"] = {"type": "json_object"}
        try:
            out = llm.create_chat_completion(**kwargs)
        except Exception:
            # Older llama_cpp builds may not accept response_format; the
            # classifier's field-level salvage covers us, so degrade instead
            # of failing the request.
            kwargs.pop("response_format", None)
            out = llm.create_chat_completion(**kwargs)
        return {
            "ok": True,
            "text": out["choices"][0]["message"]["content"].strip(),
            "prompt_tokens": int(out.get("usage", {}).get("prompt_tokens", 0)),
            "model": os.path.basename(_MODEL_PATH or ""),
        }

    if op == "embed":
        llm = _load(req)
        vec = llm.embed(req.get("text", ""))
        if vec and isinstance(vec[0], list):
            vec = vec[0]
        return {"ok": True, "vector": vec}

    if op == "shutdown":
        return {"ok": True, "bye": True}

    return {"ok": False, "error": f"unknown op {op!r}"}


def main():
    _log(f"sidecar up (python {sys.version.split()[0]})")
    for line in sys.stdin:
        # Discard anything before the opening brace. Some clients (.NET's
        # redirected stdin, e.g. PowerShell) emit a UTF-8 preamble on the first
        # write, which otherwise makes only the FIRST request of a session fail
        # to parse -- a confusing symptom to chase. Matching on '{' rather than
        # on "﻿" is deliberate: depending on the stdin encoding those bytes
        # can arrive decoded as 'ï»¿' instead, so a codepoint-specific strip
        # silently misses them.
        line = line.strip()
        brace = line.find("{")
        if brace > 0:
            line = line[brace:]
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception as e:
            sys.stdout.write(json.dumps({"ok": False, "error": f"bad request json: {e}"}) + "\n")
            sys.stdout.flush()
            continue

        try:
            resp = _handle(req)
        except Exception as e:
            _log("request failed:\n" + traceback.format_exc())
            resp = {"ok": False, "error": f"{type(e).__name__}: {e}"}

        sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
        sys.stdout.flush()

        if req.get("op") == "shutdown":
            break
    _log("sidecar exiting")


if __name__ == "__main__":
    main()
