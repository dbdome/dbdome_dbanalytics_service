"""
LDAP / Active Directory login for the DBDOME Grafana UI - config + apply logic.

DBDOME's user login IS Grafana, and Grafana OSS authenticates against
LDAP/AD natively. This module is the productization around that:

  * config lives in config.ldap_settings (single row; bind_password enc:v1:
    via utils/secrets_crypto - see 7400_ldap_settings.sql),
  * "Test connection" binds + searches with ldap3 BEFORE anything is applied,
  * "Apply" renders <conf>/ldap.toml (+ ldap_ca.crt), rewrites the
    [auth.ldap] section of custom.ini and restarts the Grafana service.

Local Grafana logins keep working (login form stays enabled), so a broken
LDAP config can never lock the customer out.

Paths/service default to the Windows install and are overridable via env:
  GRAFANA_CONF     conf dir            (default C:\\ProgramData\\DBDOME\\conf,
                                        Linux /etc/grafana)
  GRAFANA_INI      grafana custom ini  (default <conf>/custom.ini,
                                        Linux /etc/grafana/grafana.ini)
  GRAFANA_SERVICE  service to restart  (default DBDOME_Grafana,
                                        Linux grafana-server)
"""
import json
import os
import re
import subprocess
import time

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.secrets_crypto import decrypt_secret, encrypt_secret

_IS_WIN = os.name == "nt"

_ROLES = ("Viewer", "Editor", "Admin")
_ENCRYPTIONS = ("none", "ldaps", "starttls")

# Columns the UI round-trips 1:1 (bind_password handled separately).
_PLAIN_COLS = [
    "enabled", "host", "port", "encryption", "ssl_skip_verify", "root_ca_cert",
    "bind_dn", "search_base_dns", "search_filter", "group_search_base_dns",
    "attr_username", "attr_name", "attr_surname", "attr_email", "attr_member_of",
]


def _conf_dir():
    return os.environ.get("GRAFANA_CONF") or (
        r"C:\ProgramData\DBDOME\conf" if _IS_WIN else "/etc/grafana")


def _ini_path():
    return os.environ.get("GRAFANA_INI") or os.path.join(
        _conf_dir(), "custom.ini" if _IS_WIN else "grafana.ini")


def _toml_path():
    return os.path.join(_conf_dir(), "ldap.toml")


def _ca_path():
    return os.path.join(_conf_dir(), "ldap_ca.crt")


def _service_name():
    return os.environ.get("GRAFANA_SERVICE") or (
        "DBDOME_Grafana" if _IS_WIN else "grafana-server")


# ---------------------------------------------------------------------------
# Config storage
# ---------------------------------------------------------------------------

def _fetch_row():
    with psycopg2.connect(get_connection_string()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT enabled, host, port, encryption, ssl_skip_verify, root_ca_cert, "
                "       bind_dn, bind_password, search_base_dns, search_filter, "
                "       group_search_base_dns, attr_username, attr_name, attr_surname, "
                "       attr_email, attr_member_of, group_mappings, updated_at, applied_at "
                "FROM config.ldap_settings WHERE row_id = 1")
            row = cur.fetchone()
    if row is None:
        raise RuntimeError("config.ldap_settings row missing - run sql_scripts/7400_ldap_settings.sql")
    keys = ["enabled", "host", "port", "encryption", "ssl_skip_verify", "root_ca_cert",
            "bind_dn", "bind_password", "search_base_dns", "search_filter",
            "group_search_base_dns", "attr_username", "attr_name", "attr_surname",
            "attr_email", "attr_member_of", "group_mappings", "updated_at", "applied_at"]
    d = dict(zip(keys, row))
    if isinstance(d["group_mappings"], str):
        d["group_mappings"] = json.loads(d["group_mappings"])
    return d


def get_settings():
    """Settings for the UI - bind_password is never returned, only whether one is set."""
    d = _fetch_row()
    d["bind_password_set"] = bool(d.pop("bind_password"))
    d["updated_at"] = d["updated_at"].isoformat() if d["updated_at"] else None
    d["applied_at"] = d["applied_at"].isoformat() if d["applied_at"] else None
    return d


def save_settings(payload):
    """Validate + persist. bind_password: empty string = keep the stored one."""
    upd = {}
    for col in _PLAIN_COLS:
        if col in payload:
            upd[col] = payload[col]

    if "port" in upd:
        upd["port"] = int(upd["port"])
        if not (0 < upd["port"] < 65536):
            raise ValueError("port out of range")
    if "encryption" in upd and upd["encryption"] not in _ENCRYPTIONS:
        raise ValueError(f"encryption must be one of {_ENCRYPTIONS}")
    if "search_filter" in upd and "%s" not in (upd["search_filter"] or ""):
        raise ValueError("search_filter must contain %s (the login placeholder)")
    if upd.get("enabled"):
        for req in ("host", "bind_dn", "search_base_dns"):
            if not (payload.get(req) or "").strip():
                raise ValueError(f"{req} is required when LDAP is enabled")

    mappings = payload.get("group_mappings")
    if mappings is not None:
        if not isinstance(mappings, list):
            raise ValueError("group_mappings must be a list")
        clean = []
        for m in mappings:
            dn = (m.get("group_dn") or "").strip()
            role = m.get("org_role") or "Viewer"
            if not dn:
                continue
            if role not in _ROLES:
                raise ValueError(f"org_role must be one of {_ROLES}")
            clean.append({"group_dn": dn, "org_role": role,
                          "grafana_admin": bool(m.get("grafana_admin"))})
        upd["group_mappings"] = json.dumps(clean)

    pw = payload.get("bind_password")
    if pw:  # empty/None = keep existing
        upd["bind_password"] = encrypt_secret(pw)

    if not upd:
        return get_settings()

    sets = ", ".join(f"{c} = %s" for c in upd) + ", updated_at = now()"
    with psycopg2.connect(get_connection_string()) as conn:
        with conn.cursor() as cur:
            cur.execute(f"UPDATE config.ldap_settings SET {sets} WHERE row_id = 1",
                        list(upd.values()))
    return get_settings()


# ---------------------------------------------------------------------------
# Test connection (ldap3 - never touches Grafana config)
# ---------------------------------------------------------------------------

def _lines(v):
    return [ln.strip() for ln in (v or "").splitlines() if ln.strip()]


def test_connection(test_username=None, test_password=None):
    """Bind with the SAVED service account; optionally locate a test user and
    (if test_password given) verify their credentials; preview the role the
    group mappings would assign. Raises with a readable message on failure."""
    import ssl

    import ldap3  # lazy: pure-python, but keep import cost off the hot path

    s = _fetch_row()
    if not s["host"]:
        raise ValueError("no LDAP host configured - save settings first")
    bind_pw = decrypt_secret(s["bind_password"]) if s["bind_password"] else ""

    tls = None
    if s["encryption"] in ("ldaps", "starttls"):
        ca = _ca_path() if s["root_ca_cert"] else None
        if s["root_ca_cert"]:
            # ldap3 wants the CA as a file; write/refresh it beside the conf
            with open(_ca_path(), "w", encoding="utf-8") as f:
                f.write(s["root_ca_cert"])
        tls = ldap3.Tls(
            validate=ssl.CERT_NONE if s["ssl_skip_verify"] else ssl.CERT_REQUIRED,
            ca_certs_file=ca)

    server = ldap3.Server(s["host"], port=s["port"],
                          use_ssl=(s["encryption"] == "ldaps"),
                          tls=tls, get_info=None, connect_timeout=10)
    conn = ldap3.Connection(server, user=s["bind_dn"], password=bind_pw,
                            receive_timeout=10)
    if s["encryption"] == "starttls" and not conn.start_tls():
        raise RuntimeError(f"StartTLS failed: {conn.result}")
    if not conn.bind():
        raise RuntimeError(f"service-account bind failed: {conn.result.get('description')} "
                           f"{conn.result.get('message', '')}".strip())

    out = {"bind": "ok", "host": s["host"], "port": s["port"], "encryption": s["encryption"]}

    if test_username:
        flt = s["search_filter"].replace("%s", ldap3.utils.conv.escape_filter_chars(test_username))
        attrs = [a for a in (s["attr_username"], s["attr_name"], s["attr_surname"],
                             s["attr_email"], s["attr_member_of"]) if a]
        entry = None
        for base in _lines(s["search_base_dns"]):
            if conn.search(base, flt, attributes=attrs) and conn.entries:
                entry = conn.entries[0]
                break
        if entry is None:
            conn.unbind()
            raise RuntimeError(f"user '{test_username}' not found under the configured base DN(s)")

        member_of = [str(g) for g in (entry[s["attr_member_of"]].values
                                      if s["attr_member_of"] in entry else [])]
        role = None
        for m in s["group_mappings"]:
            if m["group_dn"] == "*" or m["group_dn"].lower() in (g.lower() for g in member_of):
                role = m["org_role"]
                break
        out["user"] = {
            "dn": entry.entry_dn,
            "email": str(entry[s["attr_email"]]) if s["attr_email"] in entry else "",
            "groups": member_of,
            "mapped_role": role or ("(no mapping matches - login would be denied "
                                    "unless a '*' mapping is added)" if s["group_mappings"]
                                    else "(no mappings defined - Grafana default role)"),
        }

        if test_password:
            user_conn = ldap3.Connection(server, user=entry.entry_dn,
                                         password=test_password, receive_timeout=10)
            if s["encryption"] == "starttls":
                user_conn.start_tls()
            out["user"]["password_check"] = "ok" if user_conn.bind() else "FAILED"
            user_conn.unbind()

    conn.unbind()
    return out


# ---------------------------------------------------------------------------
# Render + apply
# ---------------------------------------------------------------------------

def _q(v):
    """TOML double-quoted string."""
    return '"' + str(v or "").replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_toml(s, bind_pw):
    L = []
    L.append("# Generated by DBDOME /ldap_settings - do not edit by hand;")
    L.append("# changes here are overwritten on every Apply.")
    L.append("")
    L.append("[[servers]]")
    L.append(f"host = {_q(s['host'])}")
    L.append(f"port = {s['port']}")
    L.append(f"use_ssl = {'true' if s['encryption'] == 'ldaps' else 'false'}")
    L.append(f"start_tls = {'true' if s['encryption'] == 'starttls' else 'false'}")
    L.append(f"ssl_skip_verify = {'true' if s['ssl_skip_verify'] else 'false'}")
    if s["root_ca_cert"]:
        L.append(f"root_ca_cert = {_q(_ca_path())}")
    L.append(f"bind_dn = {_q(s['bind_dn'])}")
    # triple-quoted per Grafana docs so # and ; survive
    L.append('bind_password = """' + (bind_pw or "") + '"""')
    L.append("timeout = 10")
    L.append(f"search_filter = {_q(s['search_filter'])}")
    L.append("search_base_dns = [" + ", ".join(_q(b) for b in _lines(s["search_base_dns"])) + "]")
    gbases = _lines(s.get("group_search_base_dns"))
    if gbases:
        L.append("group_search_base_dns = [" + ", ".join(_q(b) for b in gbases) + "]")
    L.append("")
    L.append("[servers.attributes]")
    L.append(f"username = {_q(s['attr_username'])}")
    L.append(f"name = {_q(s['attr_name'])}")
    L.append(f"surname = {_q(s['attr_surname'])}")
    L.append(f"email = {_q(s['attr_email'])}")
    L.append(f"member_of = {_q(s['attr_member_of'])}")
    for m in s["group_mappings"]:
        L.append("")
        L.append("[[servers.group_mappings]]")
        L.append(f"group_dn = {_q(m['group_dn'])}")
        L.append(f"org_role = {_q(m['org_role'])}")
        if m.get("grafana_admin"):
            L.append("grafana_admin = true")
    return "\n".join(L) + "\n"


def _patch_ini(text, enabled):
    """Replace (or append) the [auth.ldap] section, preserving everything else."""
    section = "\n".join([
        "[auth.ldap]",
        f"enabled = {'true' if enabled else 'false'}",
        f"config_file = {_toml_path()}",
        "# users are auto-created in Grafana on first successful LDAP login",
        "allow_sign_up = true",
    ]) + "\n"
    pat = re.compile(r"^\[auth\.ldap\]\s*$.*?(?=^\[|\Z)", re.M | re.S)
    if pat.search(text):
        return pat.sub(section.replace("\\", "\\\\") + "\n", text, count=1)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + "\n" + section


def _restrict_acl(path):
    """Best-effort: bind password sits in ldap.toml, keep it SYSTEM/admin-only."""
    if not _IS_WIN:
        try:
            os.chmod(path, 0o600)
        except OSError:
            pass
        return
    subprocess.run(
        ["icacls", path, "/inheritance:r", "/grant:r",
         "SYSTEM:F", "BUILTIN\\Administrators:F"],
        capture_output=True, timeout=30)


def _restart_grafana():
    svc = _service_name()
    if _IS_WIN:
        subprocess.run(["sc", "stop", svc], capture_output=True, timeout=60)
        # wait for STOPPED, then start (sc is async)
        for _ in range(30):
            q = subprocess.run(["sc", "query", svc], capture_output=True, text=True, timeout=30)
            if "STOPPED" in (q.stdout or ""):
                break
            time.sleep(1)
        r = subprocess.run(["sc", "start", svc], capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            raise RuntimeError(f"could not start {svc}: {(r.stdout or r.stderr or '').strip()[:200]}")
    else:
        r = subprocess.run(["systemctl", "restart", svc], capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            raise RuntimeError(f"systemctl restart {svc} failed: {(r.stderr or '').strip()[:200]}")


def apply_settings():
    """Render ldap.toml (+CA), rewrite [auth.ldap] in the ini, restart Grafana.
    When disabled: only flips enabled=false in the ini (toml left in place)."""
    s = _fetch_row()
    ini = _ini_path()
    if not os.path.exists(ini):
        raise RuntimeError(f"Grafana ini not found at {ini} (set GRAFANA_INI)")

    if s["enabled"]:
        if not s["bind_password"]:
            raise ValueError("no bind password stored - save one before applying")
        bind_pw = decrypt_secret(s["bind_password"])
        if s["root_ca_cert"]:
            with open(_ca_path(), "w", encoding="utf-8") as f:
                f.write(s["root_ca_cert"])
        toml = render_toml(s, bind_pw)
        with open(_toml_path(), "w", encoding="utf-8") as f:
            f.write(toml)
        _restrict_acl(_toml_path())

    with open(ini, "r", encoding="utf-8") as f:
        text = f.read()
    patched = _patch_ini(text, s["enabled"])
    with open(ini + ".bak-ldap", "w", encoding="utf-8") as f:
        f.write(text)  # one-deep backup for manual recovery
    with open(ini, "w", encoding="utf-8") as f:
        f.write(patched)

    _restart_grafana()

    with psycopg2.connect(get_connection_string()) as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE config.ldap_settings SET applied_at = now() WHERE row_id = 1")
    return {"applied": True, "enabled": s["enabled"], "toml": _toml_path(), "ini": ini,
            "service": _service_name()}


def get_status():
    """Everything the page needs in one call: saved settings + what is live."""
    st = {"settings": get_settings()}
    ini = _ini_path()
    live = {"ini": ini, "ini_exists": os.path.exists(ini),
            "toml": _toml_path(), "toml_exists": os.path.exists(_toml_path()),
            "service": _service_name(), "service_state": "unknown"}
    if live["ini_exists"]:
        with open(ini, "r", encoding="utf-8") as f:
            m = re.search(r"^\[auth\.ldap\]\s*$.*?^enabled\s*=\s*(\S+)", f.read(), re.M | re.S)
        live["ldap_enabled_in_ini"] = bool(m and m.group(1).lower() == "true")
    else:
        live["ldap_enabled_in_ini"] = False
    try:
        if _IS_WIN:
            q = subprocess.run(["sc", "query", _service_name()],
                               capture_output=True, text=True, timeout=15)
            live["service_state"] = ("running" if "RUNNING" in (q.stdout or "")
                                     else "stopped" if "STOPPED" in (q.stdout or "")
                                     else "unknown")
        else:
            q = subprocess.run(["systemctl", "is-active", _service_name()],
                               capture_output=True, text=True, timeout=15)
            live["service_state"] = (q.stdout or "").strip() or "unknown"
    except Exception:
        pass
    st["live"] = live
    return st
