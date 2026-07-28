import os
import socket
import psycopg2
import json
from datetime import datetime, timezone
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def load_siem_config(service_name: str, service_type: str):
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()

        cur.execute(
            """
            select service_ip, service_port
            from config.siem
            where service_type = %s
            and service_name = %s
            """,
            (service_type, service_name),
        )

        row = cur.fetchone()
        conn.close()
        return row

    except Exception as e:
        db_write_log(f"load_siem_config failed: {e}", 0, "load_siem_config", "")


def get_utc_timestamp():
    return datetime.now(timezone.utc).isoformat()


def message_format(event_type, status, server, description, timestamp):
    message = {
        "event_type": event_type,
        "status": status,
        "message": description,
        "server": server,
        "timestamp": timestamp,
    }

    return json.dumps(message)


def siem_rapid_send(event_type, status, server, description):

    _TIMEOUT = float(os.getenv("SIEM_TIMEOUT", "2"))
    sock = None

    config = load_siem_config("ip", "rapid_7")
    HOST = config[0]
    PORT = config[1]

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(_TIMEOUT)

        sock.connect((HOST, PORT))

        db_write_log("TCP connection successful", 0, "siem_rapid_send", "")

        timestamp = get_utc_timestamp()

        payload = message_format(event_type, status, server, description, timestamp)

        sock.sendall((payload + "\n").encode("utf-8"))

        db_write_log(f"Sent: {payload}", 0, "siem_rapid_send", "")

    except Exception as e:
        db_write_log(f"siem_rapid_send error: {e}", 0, "siem_rapid_send", "")

    finally:
        if sock:
            sock.close()