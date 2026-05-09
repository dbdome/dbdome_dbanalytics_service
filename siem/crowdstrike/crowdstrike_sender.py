"""
CrowdStrike Falcon SIEM Integration for DBDOME
================================================
Sends database security events and alerts to CrowdStrike Falcon
via the Falcon Event Streams / Falcon LogScale (Humio) ingestion API.

Supports two modes:
  1. Falcon LogScale (Humio) Ingest API — structured JSON events
  2. Falcon SIEM Connector — Syslog/CEF format over TCP/UDP

Configuration stored in config.siem table:
  service_type = 'crowdstrike'
  service_name = 'logscale' | 'syslog'
"""

import socket
import json
import requests
import psycopg2
from datetime import datetime, timezone
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


# ═══════════════════════════════════════════════════════════════
# Configuration loader
# ═══════════════════════════════════════════════════════════════

def load_crowdstrike_config():
    """
    Load CrowdStrike SIEM configuration from config.siem.
    Returns dict with keys: service_name, service_ip, service_port,
    plus extended config from config.siem_crowdstrike if available.
    """
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()

        cur.execute("""
            SELECT service_name, service_ip, service_port
            FROM config.siem
            WHERE service_type = 'crowdstrike'
            LIMIT 1
        """)
        row = cur.fetchone()

        if not row:
            conn.close()
            return None

        config = {
            "service_name": row[0],
            "service_ip": row[1],
            "service_port": row[2],
        }

        # Try to load extended config (API token, etc.)
        cur.execute("""
            SELECT key, value FROM config.global_params
            WHERE key LIKE 'crowdstrike_%%'
        """)
        for key, value in cur.fetchall():
            config[key.replace("crowdstrike_", "")] = value

        conn.close()
        return config

    except Exception as e:
        db_write_log(f"load_crowdstrike_config failed: {e}", 0, "load_crowdstrike_config", "")
        return None


# ═══════════════════════════════════════════════════════════════
# Event formatting
# ═══════════════════════════════════════════════════════════════

def _utc_now():
    return datetime.now(timezone.utc).isoformat()


def format_dbdome_event(event_type, severity, server, root_cause_id,
                        description, additional_data=None):
    """
    Format a DBDOME detection event for CrowdStrike ingestion.

    Returns a dict suitable for JSON serialization.
    """
    event = {
        "timestamp": _utc_now(),
        "source": "DBDOME",
        "source_type": "database_monitoring",
        "event_type": event_type,
        "severity": severity,
        "server": server,
        "root_cause_id": root_cause_id,
        "description": description,
        "vendor": "DBDOME",
        "product": "DB Expert AI",
        "version": "2.0",
    }

    if additional_data and isinstance(additional_data, dict):
        event["details"] = additional_data

    return event


def format_cef(event_type, severity, server, root_cause_id, description):
    """
    Format event as CEF (Common Event Format) for syslog ingestion.
    CEF:Version|Device Vendor|Device Product|Device Version|Signature ID|Name|Severity|Extension
    """
    # Map severity to CEF numeric (0-10)
    sev_map = {
        "critical": 10, "high": 8, "medium": 5,
        "low": 3, "info": 1, "informational": 1,
    }
    cef_severity = sev_map.get(severity.lower(), 5)

    cef = (
        f"CEF:0|DBDOME|DBExpertAI|2.0|{root_cause_id}|{event_type}|{cef_severity}|"
        f"src={server} "
        f"msg={description} "
        f"cs1={root_cause_id} cs1Label=RootCauseID "
        f"cs2={severity} cs2Label=DBDOMESeverity "
        f"rt={_utc_now()}"
    )
    return cef


# ═══════════════════════════════════════════════════════════════
# Sender: Falcon LogScale (Humio) Ingest API
# ═══════════════════════════════════════════════════════════════

def send_to_logscale(event_type, severity, server, root_cause_id,
                     description, additional_data=None):
    """
    Send event to CrowdStrike Falcon LogScale (Humio) via HTTP Ingest API.

    Requires config.global_params:
      crowdstrike_ingest_token = '<your-ingest-token>'
      crowdstrike_logscale_url = 'https://cloud.community.humio.com'  (or your LogScale URL)
    """
    config = load_crowdstrike_config()
    if not config:
        db_write_log("CrowdStrike not configured in config.siem", 0,
                     "send_to_logscale", server)
        return False

    ingest_token = config.get("ingest_token")
    logscale_url = config.get("logscale_url", config.get("service_ip", ""))

    if not ingest_token:
        db_write_log("Missing crowdstrike_ingest_token in config.global_params", 0,
                     "send_to_logscale", server)
        return False

    # Build LogScale structured event
    event = format_dbdome_event(
        event_type, severity, server, root_cause_id,
        description, additional_data
    )

    # LogScale Ingest API payload
    payload = [{
        "tags": {
            "source": "dbdome",
            "sourcetype": "database_security",
        },
        "events": [{
            "timestamp": event["timestamp"],
            "attributes": event,
        }],
    }]

    url = f"{logscale_url.rstrip('/')}/api/v1/ingest/humio-structured"
    headers = {
        "Authorization": f"Bearer {ingest_token}",
        "Content-Type": "application/json",
    }

    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=10)

        if resp.status_code in (200, 201):
            db_write_log(
                f"CrowdStrike LogScale event sent: {root_cause_id} [{severity}]",
                0, "send_to_logscale", server)
            return True
        else:
            db_write_log(
                f"CrowdStrike LogScale error {resp.status_code}: {resp.text[:200]}",
                0, "send_to_logscale", server)
            return False

    except Exception as e:
        db_write_log(f"CrowdStrike LogScale send failed: {e}", 0,
                     "send_to_logscale", server)
        return False


# ═══════════════════════════════════════════════════════════════
# Sender: Falcon SIEM Connector (Syslog/CEF over TCP)
# ═══════════════════════════════════════════════════════════════

def send_to_syslog(event_type, severity, server, root_cause_id, description):
    """
    Send event to CrowdStrike via Syslog (CEF format) over TCP.

    Uses config.siem:
      service_type = 'crowdstrike'
      service_name = 'syslog'
      service_ip   = '<collector-ip>'
      service_port = <port>
    """
    config = load_crowdstrike_config()
    if not config:
        db_write_log("CrowdStrike syslog not configured", 0,
                     "send_to_syslog", server)
        return False

    host = config["service_ip"]
    port = int(config["service_port"])

    cef_message = format_cef(event_type, severity, server, root_cause_id, description)

    sock = None
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((host, port))
        sock.sendall((cef_message + "\n").encode("utf-8"))

        db_write_log(
            f"CrowdStrike syslog sent: {root_cause_id} [{severity}] to {host}:{port}",
            0, "send_to_syslog", server)
        return True

    except Exception as e:
        db_write_log(f"CrowdStrike syslog send failed: {e}", 0,
                     "send_to_syslog", server)
        return False

    finally:
        if sock:
            sock.close()


# ═══════════════════════════════════════════════════════════════
# Unified sender — auto-detects mode from config
# ═══════════════════════════════════════════════════════════════

def siem_crowdstrike_send(event_type, severity, server, root_cause_id,
                          description, additional_data=None):
    """
    Send a DBDOME event to CrowdStrike Falcon.
    Auto-detects mode (logscale vs syslog) from config.siem.service_name.

    Args:
        event_type:  'finding', 'alert', 'anomaly', 'compliance', etc.
        severity:    'critical', 'high', 'medium', 'low', 'info'
        server:      Monitored database server name
        root_cause_id: e.g. 'SEC-SQL-AU-001-RC01'
        description: Human-readable event description
        additional_data: Optional dict with extra context (query results, etc.)

    Returns:
        True if sent successfully
    """
    config = load_crowdstrike_config()
    if not config:
        db_write_log("CrowdStrike not configured — skipping", 0,
                     "siem_crowdstrike_send", server)
        return False

    mode = config.get("service_name", "logscale").lower()

    if mode in ("logscale", "humio", "api"):
        return send_to_logscale(
            event_type, severity, server, root_cause_id,
            description, additional_data)
    elif mode in ("syslog", "cef", "tcp"):
        return send_to_syslog(
            event_type, severity, server, root_cause_id, description)
    else:
        db_write_log(f"Unknown CrowdStrike mode: {mode}", 0,
                     "siem_crowdstrike_send", server)
        return False
