"""
Generic SIEM sender for DBDOME
==============================
One sender for every syslog-speaking SIEM. Instead of a module per vendor, a
DBDOME event is rendered in a chosen FORMAT and shipped over a chosen TRANSPORT,
both read from config.siem — so adding a vendor is a config row, not new code.

FORMATS   cef | leef | rfc5424 | rfc3164 | json
TRANSPORTS udp | tcp | tls | http

Vendor defaults (used when the config leaves format/transport blank):

    splunk    -> cef      over tcp   (or http = HEC when a token is set)
    qradar    -> leef     over tcp
    sentinel  -> cef      over tcp   (to an AMA / CEF forwarder)
    arcsight  -> cef      over tcp
    elastic   -> json     over tcp   (ECS-ish field names)
    sumo      -> json     over http  (HTTPS collector URL)
    syslog    -> rfc5424  over tcp   (generic catch-all)

config.siem columns used:
    service_type  vendor key            e.g. 'splunk'
    service_name  "<format>:<transport>" (e.g. 'cef:tls'); either half may be
                  omitted to take the vendor default ('cef', ':tls', or '' all work)
    service_ip    host / IP  (or full URL for http transport)
    service_port  port

Optional extras from config.global_params (key -> use):
    <vendor>_token      bearer/HEC token for http transport
    <vendor>_ca_cert    path to a CA bundle for tls (verifies the server)
    <vendor>_client_cert / <vendor>_client_key   mutual-TLS client pair
"""

import json
import os
import socket
import ssl
import threading
import time
from datetime import datetime, timezone

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# Short by design: an unreachable collector must not add seconds to every alert.
# SIEM_TIMEOUT in the .env overrides (seconds).
_TIMEOUT = float(os.getenv("SIEM_TIMEOUT", "2"))
_SYSLOG_PRI = 134          # local0.info
_PROGRAM = "dbdome"

# ── circuit breaker ───────────────────────────────────────────────────────────
# A collector that is down (host not on the LAN, service stopped) would otherwise
# cost _TIMEOUT seconds and one error log line on EVERY alert, forever. After
# _CB_THRESHOLD consecutive failures a vendor is skipped for _CB_COOLDOWN seconds,
# then probed again. One log line on open, one on close — no flooding.
_CB_THRESHOLD = int(os.getenv("SIEM_BREAKER_FAILURES", "3"))
_CB_COOLDOWN = float(os.getenv("SIEM_BREAKER_COOLDOWN", "300"))
_cb_lock = threading.Lock()
_cb_state = {}   # vendor -> {"fails": int, "open_until": float}


def _breaker_is_open(vendor):
    with _cb_lock:
        st = _cb_state.get(vendor)
        if not st or not st["open_until"]:
            return False
        if time.monotonic() < st["open_until"]:
            return True
        # cooldown elapsed — let one probe through
        st["open_until"] = 0.0
        st["fails"] = 0
        return False


def _breaker_record(vendor, ok):
    with _cb_lock:
        st = _cb_state.setdefault(vendor, {"fails": 0, "open_until": 0.0})
        if ok:
            if st["fails"]:
                db_write_log(f"{vendor}: SIEM delivery recovered", 0, "siem_generic_send", "")
            st["fails"] = 0
            st["open_until"] = 0.0
            return
        st["fails"] += 1
        if st["fails"] >= _CB_THRESHOLD and not st["open_until"]:
            st["open_until"] = time.monotonic() + _CB_COOLDOWN
            db_write_log(
                f"{vendor}: SIEM unreachable after {st['fails']} tries — "
                f"pausing sends for {int(_CB_COOLDOWN)}s",
                0, "siem_generic_send", "")

# vendor -> (default_format, default_transport)
_VENDOR_DEFAULTS = {
    "splunk":   ("cef", "tcp"),
    "qradar":   ("leef", "tcp"),
    "sentinel": ("cef", "tcp"),
    "arcsight": ("cef", "tcp"),
    "elastic":  ("json", "tcp"),
    "sumo":     ("json", "http"),
    "syslog":   ("rfc5424", "tcp"),
}

_SEVERITY_NUM = {           # CEF/LEEF 0-10
    "critical": 10, "high": 8, "medium": 5,
    "low": 3, "info": 1, "informational": 1,
}
_SEVERITY_SYSLOG = {        # RFC 5424 severity -> PRI (facility local0 = 16)
    "critical": 16 * 8 + 2,   # crit
    "high":     16 * 8 + 3,   # err
    "medium":   16 * 8 + 4,   # warning
    "low":      16 * 8 + 5,   # notice
    "info":     16 * 8 + 6,   # info
}


# ── config ────────────────────────────────────────────────────────────────────

def load_generic_config(vendor):
    """Return the config for `vendor` from config.siem, or None when absent."""
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()
        cur.execute(
            """SELECT service_name, service_ip, service_port
               FROM config.siem WHERE service_type = %s LIMIT 1""",
            (vendor,),
        )
        row = cur.fetchone()
        if not row:
            conn.close()
            return None

        spec = (row[0] or "").strip().lower()
        d_fmt, d_tx = _VENDOR_DEFAULTS.get(vendor, ("rfc5424", "tcp"))
        fmt, _, transport = spec.partition(":")
        cfg = {
            "vendor": vendor,
            "format": fmt or d_fmt,
            "transport": transport or d_tx,
            "host": row[1],
            "port": int(row[2]) if row[2] else None,
        }

        cur.execute(
            "SELECT key, value FROM config.global_params WHERE key LIKE %s",
            (f"{vendor}_%",),
        )
        for key, value in cur.fetchall():
            cfg[key[len(vendor) + 1:]] = value

        conn.close()
        return cfg
    except Exception as e:
        db_write_log(f"load_generic_config({vendor}) failed: {e}", 0, "load_generic_config", "")
        return None


# ── formatters ────────────────────────────────────────────────────────────────

def _escape_cef(value, header=False):
    """CEF escaping: backslash always; '|' in headers; '=' in extensions."""
    s = str(value).replace("\\", "\\\\")
    s = s.replace("|", "\\|") if header else s.replace("=", "\\=")
    return s.replace("\n", " ").replace("\r", " ")


def _details_json(event, limit=4000):
    """Compact JSON of event['details'] (detection resultset), bounded so a
    large resultset can never blow past syslog frame limits. '' when absent."""
    details = event.get("details")
    if not details:
        return ""
    try:
        s = json.dumps(details, default=str, ensure_ascii=False)
    except Exception:
        s = str(details)
    return s[:limit]


def format_cef(event):
    sev = _SEVERITY_NUM.get(event["severity"].lower(), 5)
    header = "|".join([
        "CEF:0", "DBDOME", "DBExpertAI", "2.0",
        _escape_cef(event["root_cause_id"], header=True),
        _escape_cef(event["event_type"], header=True),
        str(sev),
    ])
    ext = (
        f"src={_escape_cef(event['server'])} "
        f"msg={_escape_cef(event['description'])} "
        f"cs1={_escape_cef(event['root_cause_id'])} cs1Label=RootCauseID "
        f"cs2={_escape_cef(event['severity'])} cs2Label=DBDOMESeverity "
        f"rt={event['timestamp']}"
    )
    _dj = _details_json(event)
    if _dj:
        ext += f" cs3={_escape_cef(_dj)} cs3Label=DetectionResults"
    return f"{header}|{ext}"


def _escape_leef(value):
    return str(value).replace("\t", " ").replace("\n", " ").replace("\r", " ")


def format_leef(event):
    """LEEF 2.0 (QRadar). Tab-delimited key=value attributes."""
    sev = _SEVERITY_NUM.get(event["severity"].lower(), 5)
    header = "|".join([
        "LEEF:2.0", "DBDOME", "DBExpertAI", "2.0",
        _escape_leef(event["root_cause_id"]),
    ])
    attrs = [
        f"devTime={event['timestamp']}",
        "devTimeFormat=yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
        f"severity={sev}",
        f"src={_escape_leef(event['server'])}",
        f"cat={_escape_leef(event['event_type'])}",
        f"rootCauseId={_escape_leef(event['root_cause_id'])}",
        f"dbdomeSeverity={_escape_leef(event['severity'])}",
        f"msg={_escape_leef(event['description'])}",
    ]
    _dj = _details_json(event)
    if _dj:
        attrs.append(f"detectionResults={_escape_leef(_dj)}")
    return f"{header}|" + "\t".join(attrs)


def format_json(event):
    """ECS-flavoured JSON (Elastic, Sumo, Datadog, generic collectors)."""
    doc = dict(event)
    doc.update({
        "@timestamp": event["timestamp"],
        "event": {
            "kind": "alert",
            "category": ["database"],
            "action": event["event_type"],
            "severity": _SEVERITY_NUM.get(event["severity"].lower(), 5),
        },
        "observer": {"vendor": "DBDOME", "product": "DB Expert AI", "version": "2.0"},
        "host": {"name": event["server"]},
        "message": event["description"],
    })
    return json.dumps(doc, default=str, ensure_ascii=False)


def format_rfc5424(event, body):
    """<PRI>1 TIMESTAMP HOST APP PROCID MSGID [SD] body"""
    pri = _SEVERITY_SYSLOG.get(event["severity"].lower(), 134)
    host = socket.gethostname().split(".")[0] or "DBDOME"
    return (
        f"<{pri}>1 {event['timestamp']} {host} {_PROGRAM} - "
        f"{event['root_cause_id']} - {body}"
    )


def format_rfc3164(event, body):
    """<PRI>Mmm dd hh:mm:ss HOST tag: body  (legacy BSD syslog)"""
    ts = datetime.now().strftime("%b %d %H:%M:%S")
    host = socket.gethostname().split(".")[0] or "DBDOME"
    return f"<{_SYSLOG_PRI}>{ts} {host} {_PROGRAM}: {body}"


def build_event(event_type, severity, server, root_cause_id, description,
                additional_data=None):
    event = {
        "integration": "dbdome",
        "event_type": event_type,
        "severity": (severity or "medium"),
        "server": server,
        "root_cause_id": root_cause_id,
        "description": description,
        "vendor": "DBDOME",
        "product": "DB Expert AI",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if additional_data and isinstance(additional_data, dict):
        event["details"] = additional_data
    return event


def render(event, fmt):
    """Render an event to the wire string for `fmt`."""
    fmt = (fmt or "rfc5424").lower()
    if fmt == "cef":
        body = format_cef(event)
    elif fmt == "leef":
        body = format_leef(event)
    elif fmt == "json":
        body = format_json(event)
    elif fmt in ("rfc5424", "rfc3164"):
        body = format_json(event)     # structured body inside the syslog frame
    else:
        raise ValueError(f"unknown SIEM format: {fmt}")

    # CEF/LEEF/JSON still travel inside a syslog frame on udp/tcp/tls; http
    # transport sends the bare body (see send_http).
    if fmt == "rfc3164":
        return format_rfc3164(event, body)
    return format_rfc5424(event, body)


# ── transports ────────────────────────────────────────────────────────────────

def _tls_context(cfg):
    ca = cfg.get("ca_cert")
    ctx = ssl.create_default_context(cafile=ca) if ca else ssl.create_default_context()
    if not ca:
        # No CA pinned: encrypt but don't fail on a self-signed collector cert.
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    if cfg.get("client_cert") and cfg.get("client_key"):
        ctx.load_cert_chain(cfg["client_cert"], cfg["client_key"])
    return ctx


def send_udp(cfg, line):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(_TIMEOUT)
        s.sendto(line.encode("utf-8"), (cfg["host"], cfg["port"]))


def send_tcp(cfg, line, tls=False):
    """Newline-framed by default — that is what plain syslog receivers (rsyslog,
    Wazuh, most SIEM collectors) expect, and every formatter above already strips
    newlines from the payload, so one event can never split into two.

    Set <vendor>_framing = 'octet' in config.global_params for collectors that
    want RFC 6587 octet counting instead.
    """
    sock = socket.create_connection((cfg["host"], cfg["port"]), timeout=_TIMEOUT)
    try:
        if tls:
            sock = _tls_context(cfg).wrap_socket(sock, server_hostname=cfg["host"])
        payload = line.encode("utf-8")
        if (cfg.get("framing") or "lf").lower() == "octet":
            payload = f"{len(payload)} ".encode("ascii") + payload
        else:
            payload += b"\n"
        sock.sendall(payload)
    finally:
        sock.close()


def send_http(cfg, event, fmt):
    """HTTPS ingest (Splunk HEC, Sumo collector, generic JSON endpoint)."""
    import requests

    url = cfg["host"]
    if not url.startswith(("http://", "https://")):
        url = f"https://{url}:{cfg['port']}" if cfg.get("port") else f"https://{url}"

    token = cfg.get("token")
    headers = {"Content-Type": "application/json"}
    vendor = cfg["vendor"]

    if vendor == "splunk":
        # Splunk HEC wraps the event and authenticates with a Splunk token.
        if token:
            headers["Authorization"] = f"Splunk {token}"
        payload = {"sourcetype": "dbdome:alert", "source": "dbdome", "event": json.loads(format_json(event))}
        if not url.rstrip("/").endswith("/services/collector/event"):
            url = url.rstrip("/") + "/services/collector/event"
    else:
        if token:
            headers["Authorization"] = f"Bearer {token}"
        payload = json.loads(format_json(event)) if fmt == "json" else {"raw": render(event, fmt)}

    verify = cfg.get("ca_cert") or False
    resp = requests.post(url, json=payload, headers=headers, timeout=10, verify=verify)
    if resp.status_code not in (200, 201, 202, 204):
        raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:200]}")


# ── public API ────────────────────────────────────────────────────────────────

def siem_generic_send(vendor, event_type, severity, server, root_cause_id,
                      description, additional_data=None):
    """
    Send one DBDOME event to `vendor` using the format/transport in config.siem.
    Returns True when the event was handed to the collector, False otherwise
    (never raises — a SIEM outage must not break collection).
    """
    if _breaker_is_open(vendor):
        return False          # known-down collector: skip without paying the timeout

    cfg = load_generic_config(vendor)
    if not cfg:
        return False          # vendor not configured: nothing to do, no noise
    if not cfg.get("host"):
        db_write_log(f"{vendor}: no service_ip configured", 0, "siem_generic_send", server)
        return False

    try:
        event = build_event(event_type, severity, server, root_cause_id,
                            description, additional_data)
        transport = cfg["transport"]
        fmt = cfg["format"]

        if transport == "http":
            send_http(cfg, event, fmt)
        else:
            line = render(event, fmt)
            if transport == "udp":
                send_udp(cfg, line)
            elif transport == "tls":
                send_tcp(cfg, line, tls=True)
            elif transport == "tcp":
                send_tcp(cfg, line, tls=False)
            else:
                raise ValueError(f"unknown SIEM transport: {transport}")

        _breaker_record(vendor, True)
        db_write_log(
            f"{vendor} event sent ({fmt}/{transport}): {root_cause_id} [{severity}]",
            0, "siem_generic_send", server)
        return True

    except Exception as e:
        _breaker_record(vendor, False)
        # Only log while the breaker is closed — once it opens we log once and go
        # quiet, so a dead collector can't flood log.operation_log.
        if not _breaker_is_open(vendor):
            db_write_log(f"siem_generic_send({vendor}) failed: {e}", 0, "siem_generic_send", server)
        return False


def siem_send_all(event_type, severity, server, root_cause_id, description,
                  additional_data=None):
    """Fan out to every generic vendor that has a row in config.siem.

    The three purpose-built senders (wazuh, crowdstrike, rapid_7) keep their own
    modules and are NOT dispatched here, so nothing is sent twice.
    """
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()
        cur.execute(
            "SELECT service_type FROM config.siem WHERE service_type = ANY(%s)",
            (list(_VENDOR_DEFAULTS.keys()),),
        )
        vendors = [r[0] for r in cur.fetchall()]
        conn.close()
    except Exception as e:
        db_write_log(f"siem_send_all vendor lookup failed: {e}", 0, "siem_send_all", server)
        return 0

    sent = 0
    for vendor in vendors:
        if siem_generic_send(vendor, event_type, severity, server, root_cause_id,
                             description, additional_data):
            sent += 1
    return sent
