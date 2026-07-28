"""
Wazuh SIEM Integration for DBDOME
==================================
Sends database security events and alerts to a Wazuh manager via its
remote syslog listener (ossec.conf <remote><connection>syslog</connection>).

Each event is one RFC-3164 syslog line whose message body is a JSON object,
tagged with program name "dbdome" so the manager's dbdome decoder
(JSON_Decoder child) turns every JSON key into a Wazuh field:

    <134>Jul 13 08:00:00 DBDOME dbdome: {"event_type": ..., "severity": ...}

Configuration stored in config.siem:
  service_type = 'wazuh'
  service_name = 'syslog'      (TCP, default)  |  'udp'
  service_ip   = <wazuh manager ip>
  service_port = <syslog port, typically 514>
"""

import os
import socket
import json
from datetime import datetime, timezone

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

# Short by design — an unreachable manager must not add seconds to every alert.
_TIMEOUT = float(os.getenv("SIEM_TIMEOUT", "2"))
# facility local0 (16), severity informational (6) -> PRI 134
_SYSLOG_PRI = 134
_PROGRAM = "dbdome"


def load_wazuh_config():
    """Load Wazuh SIEM configuration from config.siem (None when absent)."""
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()
        cur.execute(
            """
            SELECT service_name, service_ip, service_port
            FROM config.siem
            WHERE service_type = 'wazuh'
            LIMIT 1
            """
        )
        row = cur.fetchone()
        conn.close()
        if not row:
            return None
        return {
            "service_name": (row[0] or "syslog").lower(),
            "service_ip": row[1],
            "service_port": int(row[2]),
        }
    except Exception as e:
        db_write_log(f"load_wazuh_config failed: {e}", 0, "load_wazuh_config", "")
        return None


def format_wazuh_event(event_type, severity, server, root_cause_id,
                       description, additional_data=None):
    """Build the JSON event body (flat keys become Wazuh fields)."""
    event = {
        "integration": "dbdome",
        "event_type": event_type,
        "severity": severity,
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


def _syslog_line(event):
    """Wrap the JSON event in an RFC-3164 syslog header tagged 'dbdome'."""
    ts = datetime.now().strftime("%b %d %H:%M:%S")
    hostname = socket.gethostname().split(".")[0] or "DBDOME"
    body = json.dumps(event, default=str, ensure_ascii=False)
    return f"<{_SYSLOG_PRI}>{ts} {hostname} {_PROGRAM}: {body}"


def siem_wazuh_send(event_type, severity, server, root_cause_id,
                    description, additional_data=None):
    """
    Send a DBDOME event to the Wazuh manager.

    Args:
        event_type:      'finding', 'alert', or a root-cause id
        severity:        'critical', 'high', 'medium', 'low', 'info'
        server:          Monitored database server name
        root_cause_id:   e.g. 'SEC-SQL-AU-001-RC01'
        description:     Human-readable event description
        additional_data: Optional dict with extra context

    Returns True when the event was handed to the manager.
    """
    config = load_wazuh_config()
    if not config:
        db_write_log("Wazuh not configured in config.siem — skipping", 0,
                     "siem_wazuh_send", server)
        return False

    host = config["service_ip"]
    port = config["service_port"]
    use_udp = config["service_name"] in ("udp", "syslog_udp")

    event = format_wazuh_event(event_type, severity, server, root_cause_id,
                               description, additional_data)
    line = _syslog_line(event)

    sock = None
    try:
        if use_udp:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(_TIMEOUT)
            sock.sendto(line.encode("utf-8"), (host, port))
        else:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(_TIMEOUT)
            sock.connect((host, port))
            sock.sendall((line + "\n").encode("utf-8"))

        db_write_log(
            f"Wazuh event sent: {root_cause_id} [{severity}] to {host}:{port}",
            0, "siem_wazuh_send", server)
        return True

    except Exception as e:
        db_write_log(f"siem_wazuh_send failed: {e}", 0, "siem_wazuh_send", server)
        return False

    finally:
        if sock:
            sock.close()
