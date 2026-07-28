"""Central Oracle client initialisation and robust connection helper.

Import ``oracle_connect`` instead of calling ``oracledb.connect`` directly:

    from utils.oracle_client import oracle_connect
    conn = oracle_connect(user, password, host, port, service_name)

What this guarantees
--------------------
* Thick mode is attempted once at import time using ``ORACLE_CLIENT_LIB_DIR``
  (or Oracle Instant Client auto-discovery).  If the library is absent the
  module stays in thin mode — thin mode works for Oracle 12c+ servers that
  accept the thin-protocol handshake.
* ``oracle_connect`` tries TCP first, then TCPS (SSL), so both plain and
  SSL-only listeners work without manual DSN tuning.
* Only protocol / SSL errors advance to the next DSN.  Auth errors, wrong
  service name, network timeouts, etc. raise immediately with the original
  exception so callers see the real problem.
* ``is_thick_mode()`` lets any caller check which mode is active.
"""

import os
import sys
import oracledb

# ── Load .env so ORACLE_CLIENT_LIB_DIR is visible at import time ──────────────
# config_dotenv.load_dotenv() only runs lazily inside get_connection_string(),
# which is called at RUNTIME - long after this module is imported. So without
# loading the .env here, the thick-mode init below reads an empty
# ORACLE_CLIENT_LIB_DIR, inits with no lib_dir, falls back to PATH auto-discovery
# (the Instant Client dir is not on PATH), fails, and silently drops to THIN
# mode. Loading the .env here makes the configured client path actually take
# effect.
try:
    from dotenv import load_dotenv as _load_dotenv
    if getattr(sys, "frozen", False):
        _env_path = os.path.join(os.path.dirname(sys.executable), ".env")
    else:
        _env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    if os.path.isfile(_env_path):
        _load_dotenv(_env_path, override=False)
except Exception:
    pass

# ── One-time thick-mode initialisation ───────────────────────────────────────
# Runs at import time so it fires before any oracledb.connect() anywhere in
# the process can lock thin mode in.
_lib_dir = os.getenv("ORACLE_CLIENT_LIB_DIR", "").strip() or None
_thick_init_ok = False
_thick_reason = ""
try:
    if _lib_dir and not os.path.isdir(_lib_dir):
        # Fail loudly-in-the-log rather than silently: a wrong path is the most
        # common cause of an unexpected thin-mode fallback.
        _thick_reason = f"ORACLE_CLIENT_LIB_DIR does not exist: {_lib_dir}"
        raise FileNotFoundError(_thick_reason)
    if _lib_dir:
        oracledb.init_oracle_client(lib_dir=_lib_dir)
    else:
        oracledb.init_oracle_client()
    _thick_init_ok = True
except oracledb.ProgrammingError as _e:
    # DPY-2043: already initialised (thick is active) — still thick
    # DPY-2045: thin mode already locked in (another module connected first)
    _thick_init_ok = not oracledb.is_thin_mode()
    _thick_reason = str(_e)
except Exception as _e:
    # Instant Client library not found or path wrong → thin mode only
    _thick_init_ok = False
    _thick_reason = _thick_reason or str(_e)

if _thick_init_ok:
    # Disable Out-Of-Band breaks — required by some Oracle server configs
    oracledb.defaults.disable_oob = True  # type: ignore[attr-defined]
    try:
        print(f"[oracle_client] THICK mode active - Instant Client {oracledb.clientversion()} "
              f"(lib_dir={_lib_dir or 'auto/PATH'})", flush=True)
    except Exception:
        pass
else:
    try:
        print(f"[oracle_client] THIN mode - thick init did not engage: "
              f"{_thick_reason or 'Instant Client not found'} "
              f"(ORACLE_CLIENT_LIB_DIR={_lib_dir or 'unset'})", flush=True)
    except Exception:
        pass


# Re-exported so callers can catch Oracle exceptions without importing oracledb directly
OracleError = oracledb.Error
OracleDatabaseError = oracledb.DatabaseError


def is_thick_mode() -> bool:
    """Return True when Oracle Instant Client (thick mode) is active."""
    return not oracledb.is_thin_mode()


# ── DSN builders ──────────────────────────────────────────────────────────────

def _dsn_tcp(host: str, port: int, service_name: str) -> str:
    return (
        f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={host})(PORT={port}))"
        f"(CONNECT_DATA=(SERVICE_NAME={service_name})))"
    )


def _dsn_tcps(host: str, port: int, service_name: str) -> str:
    return (
        f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST={host})(PORT={port}))"
        f"(CONNECT_DATA=(SERVICE_NAME={service_name}))"
        f"(SECURITY=(SSL_SERVER_DN_MATCH=no)))"
    )


# ── Robust connect ────────────────────────────────────────────────────────────

# Error strings that indicate a protocol / SSL mismatch rather than a real
# application error.  Only these advance the retry to the next DSN.
_PROTOCOL_MARKERS = ("dpy-6005", "ssl", "violation of protocol", "unexpected message")


def oracle_connect(user: str, password: str, host: str, port, service_name: str):
    """Connect to Oracle, automatically trying TCP then TCPS.

    Works in both thick and thin mode:
    - Thick (Instant Client present): handles all Oracle versions including
      servers configured with Oracle-native encryption / old auth protocols.
    - Thin (no Instant Client): works for Oracle 12c+ with standard auth.

    Only protocol / SSL errors trigger the TCP → TCPS fallback.  Auth
    failures, wrong service names, and network timeouts raise immediately.

    Raises the last ``DatabaseError`` if all DSNs are exhausted.
    """
    if isinstance(host, str) and ":" in host:
        host = host.split(":")[0]
    port = int(port) if port else 1521

    last_err: Exception | None = None
    for dsn in (_dsn_tcp(host, port, service_name), _dsn_tcps(host, port, service_name)):
        try:
            _conn = oracledb.connect(user=user, password=password, dsn=dsn,
                                     tcp_connect_timeout=15)   # login timeout (seconds)
            try:
                import os as _os
                _qt = int(_os.environ.get("DBEXPERT_QUERY_TIMEOUT", "30"))
                if _qt > 0:
                    _conn.call_timeout = _qt * 1000   # per-query timeout (milliseconds)
            except Exception:
                pass
            return _conn
        except oracledb.DatabaseError as exc:
            err_lower = str(exc).lower()
            if any(m in err_lower for m in _PROTOCOL_MARKERS):
                last_err = exc
                continue   # retry with next DSN
            raise          # auth error, bad service name, timeout → surface now

    raise last_err  # type: ignore[misc]
