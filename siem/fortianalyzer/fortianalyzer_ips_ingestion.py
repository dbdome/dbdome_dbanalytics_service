"""
FortiAnalyzer IPS Ingestion
============================
Populates siem.fortianalyzer_ips_events from three sources:

  1. ingest_from_api()   — polls the FortiAnalyzer JSON-RPC API
  2. ingest_from_csv()   — parses a CSV exported from FortiAnalyzer
  3. ingest_from_syslog_line() — called per-line from a syslog receiver

Configuration in config.siem:
  service_type = 'fortianalyzer'
  service_name = 'ips'
  service_ip   = <FortiAnalyzer host>
  service_port = 443
  + config.global_params rows:
      fortianalyzer_user     = <admin user>
      fortianalyzer_password = <password>
      fortianalyzer_adom     = root   (default)
      fortianalyzer_verify_ssl = false
"""

import csv
import io
import json
import re
import requests
import urllib3
import psycopg2
import psycopg2.extras
from datetime import datetime, timezone
from typing import Optional

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ---------------------------------------------------------------------------
# Severity / intrusion-type normalisation
# ---------------------------------------------------------------------------

_SEVERITY_MAP = {
    "critical": "critical",
    "high":     "high",
    "medium":   "medium",
    "low":      "low",
    "info":     "info",
    "information": "info",
}

_TYPE_MAP = {
    "buffer_overflow":   "Buffer Errors",
    "buffer-overflow":   "Buffer Errors",
    "buffer_error":      "Buffer Errors",
    "anomaly":           "Anomaly",
    "access_control":    "Permission/Privilege/Access Control",
    "privilege":         "Permission/Privilege/Access Control",
    "code_injection":    "Code Injection",
    "injection":         "Code Injection",
    "malware":           "Malware",
    "virus":             "Malware",
    "botnet":            "Malware",
    "other":             "Other",
}


def _norm_severity(raw: str) -> str:
    return _SEVERITY_MAP.get((raw or "").strip().lower(), "info")


def _norm_type(raw: str) -> Optional[str]:
    key = (raw or "").strip().lower().replace(" ", "_").replace("/", "_")
    return _TYPE_MAP.get(key, raw.strip() if raw else None)


def _norm_action(raw: str) -> str:
    raw = (raw or "").strip().lower()
    if raw in ("drop", "dropped", "block", "blocked", "reset", "deny"):
        return "blocked"
    return "monitored"


def _parse_dt(raw: str) -> Optional[datetime]:
    if not raw:
        return None
    for fmt in (
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y/%m/%d %H:%M:%S",
    ):
        try:
            dt = datetime.strptime(raw.strip(), fmt)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            continue
    return None


# ---------------------------------------------------------------------------
# Config loader (mirrors the pattern used by rapid_sender / crowdstrike_sender)
# ---------------------------------------------------------------------------

def _load_config() -> dict:
    conn = psycopg2.connect(get_connection_string())
    cur = conn.cursor()

    cur.execute("""
        SELECT service_ip, service_port
        FROM config.siem
        WHERE service_type = 'fortianalyzer' AND service_name = 'ips'
        LIMIT 1
    """)
    row = cur.fetchone()
    if not row:
        conn.close()
        raise RuntimeError("No fortianalyzer/ips row in config.siem")

    cfg = {"host": row[0], "port": row[1]}

    cur.execute("""
        SELECT key, value FROM config.global_params
        WHERE key LIKE 'fortianalyzer_%%'
    """)
    for k, v in cur.fetchall():
        cfg[k.replace("fortianalyzer_", "")] = v

    conn.close()
    return cfg


# ---------------------------------------------------------------------------
# Bulk insert helper
# ---------------------------------------------------------------------------

_INSERT_SQL = """
    INSERT INTO siem.fortianalyzer_ips_events
        (device_name, event_time, attack_name, cve_id, intrusion_type,
         severity, action, protocol, src_ip, dst_ip, src_port, dst_port, count)
    VALUES %s
    ON CONFLICT DO NOTHING
"""


def _bulk_insert(rows: list[tuple]) -> int:
    if not rows:
        return 0
    conn = psycopg2.connect(get_connection_string())
    try:
        with conn:
            with conn.cursor() as cur:
                psycopg2.extras.execute_values(cur, _INSERT_SQL, rows)
        inserted = len(rows)
        db_write_log(f"FortiAnalyzer IPS: inserted {inserted} rows", 0,
                     "fortianalyzer_ips_ingestion", "siem")
        return inserted
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# 1. FortiAnalyzer JSON-RPC API
# ---------------------------------------------------------------------------

class _FAZSession:
    def __init__(self, host: str, port: int, user: str, password: str,
                 adom: str = "root", verify_ssl: bool = False):
        self.base = f"https://{host}:{port}/jsonrpc"
        self.user = user
        self.password = password
        self.adom = adom
        self.verify = verify_ssl
        self.session_id = None
        self._id = 0

    def _call(self, method: str, url: str, data: dict = None) -> dict:
        self._id += 1
        body = {
            "id": self._id,
            "method": method,
            "params": [{"url": url, "data": data or {}}],
        }
        if self.session_id:
            body["session"] = self.session_id

        resp = requests.post(self.base, json=body, verify=self.verify, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def login(self):
        result = self._call("exec", "/sys/login/user",
                            {"user": self.user, "passwd": self.password})
        self.session_id = result.get("session")

    def logout(self):
        if self.session_id:
            self._call("exec", "/sys/logout")
            self.session_id = None

    def get_ips_logs(self, start_time: str, end_time: str,
                     limit: int = 10000) -> list:
        """
        Pull IPS logs from FortiAnalyzer.
        start_time / end_time: "YYYY-MM-DD HH:MM:SS"
        Returns list of log-entry dicts.
        """
        result = self._call("get", f"/logview/adom/{self.adom}/logfiles/search", {
            "logtype":    "ips",
            "time-range": {"start": start_time, "end": end_time},
            "limit":      limit,
            "offset":     0,
        })
        data = result.get("result", [{}])[0].get("data", [])
        return data if isinstance(data, list) else []


def ingest_from_api(start_time: str, end_time: str) -> int:
    """
    Pull IPS events from the FortiAnalyzer API and insert into
    siem.fortianalyzer_ips_events.

    Args:
        start_time: "YYYY-MM-DD HH:MM:SS"  (UTC)
        end_time:   "YYYY-MM-DD HH:MM:SS"  (UTC)

    Returns:
        Number of rows inserted.

    Usage:
        from siem.fortianalyzer.fortianalyzer_ips_ingestion import ingest_from_api
        ingest_from_api("2026-04-30 00:00:00", "2026-05-06 23:59:59")
    """
    cfg = _load_config()
    faz = _FAZSession(
        host=cfg["host"],
        port=int(cfg.get("port", 443)),
        user=cfg.get("user", "admin"),
        password=cfg.get("password", ""),
        adom=cfg.get("adom", "root"),
        verify_ssl=cfg.get("verify_ssl", "false").lower() == "true",
    )

    try:
        faz.login()
        logs = faz.get_ips_logs(start_time, end_time)
    finally:
        faz.logout()

    rows = []
    for entry in logs:
        # FortiAnalyzer IPS log field names (standard logview format)
        rows.append((
            entry.get("devname", "unknown"),              # device_name
            _parse_dt(entry.get("date", "") + " " + entry.get("time", "")),
            entry.get("attack", entry.get("attackname", "")),
            entry.get("cve-id") or entry.get("cve_id"),
            _norm_type(entry.get("attack_type", entry.get("attacktype", ""))),
            _norm_severity(entry.get("severity", "info")),
            _norm_action(entry.get("action", "monitored")),
            entry.get("proto", entry.get("protocol")),
            entry.get("srcip") or None,
            entry.get("dstip") or None,
            entry.get("srcport") or None,
            entry.get("dstport") or None,
            int(entry.get("count", 1)),
        ))

    return _bulk_insert(rows)


# ---------------------------------------------------------------------------
# 2. CSV file (exported from FortiAnalyzer UI or API)
# ---------------------------------------------------------------------------

# Maps CSV column headers → internal field names.
# FortiAnalyzer CSV exports vary slightly by firmware version.
_CSV_FIELD_MAP = {
    # event time
    "date":         "date",
    "time":         "time",
    "event_time":   "event_time",
    "timestamp":    "event_time",
    # device
    "devname":      "device_name",
    "device":       "device_name",
    "device name":  "device_name",
    # attack
    "attack":       "attack_name",
    "attackname":   "attack_name",
    "attack name":  "attack_name",
    "signature":    "attack_name",
    # cve
    "cve-id":       "cve_id",
    "cve_id":       "cve_id",
    "cve":          "cve_id",
    # type
    "attack_type":  "intrusion_type",
    "attacktype":   "intrusion_type",
    "type":         "intrusion_type",
    # severity
    "severity":     "severity",
    # action
    "action":       "action",
    # protocol
    "proto":        "protocol",
    "protocol":     "protocol",
    # ips
    "srcip":        "src_ip",
    "src_ip":       "src_ip",
    "source":       "src_ip",
    "dstip":        "dst_ip",
    "dst_ip":       "dst_ip",
    "destination":  "dst_ip",
    "srcport":      "src_port",
    "src_port":     "src_port",
    "dstport":      "dst_port",
    "dst_port":     "dst_port",
    # count
    "count":        "count",
    "counts":       "count",
}


def ingest_from_csv(path: str, device_name: str = "FortiAnalyzer-import") -> int:
    """
    Parse a CSV file exported from FortiAnalyzer and insert IPS events.

    The CSV must have a header row; column names are case-insensitive and
    matched via _CSV_FIELD_MAP above.

    Args:
        path:        Path to the .csv file.
        device_name: Fallback device name when the CSV has no devname column.

    Returns:
        Number of rows inserted.

    Usage:
        from siem.fortianalyzer.fortianalyzer_ips_ingestion import ingest_from_csv
        ingest_from_csv(r"E:\\install\\IPS_export_2026-05-07.csv")
    """
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        # normalise header names
        norm_headers = {
            _CSV_FIELD_MAP.get(h.strip().lower(), h.strip().lower()): h
            for h in (reader.fieldnames or [])
        }

        for raw in reader:
            # re-key using normalised names
            r = {norm_key: raw[orig_key]
                 for norm_key, orig_key in norm_headers.items()}

            # resolve event_time
            if "event_time" in r:
                dt = _parse_dt(r["event_time"])
            elif "date" in r and "time" in r:
                dt = _parse_dt(f"{r['date']} {r['time']}")
            else:
                dt = datetime.now(timezone.utc)

            rows.append((
                r.get("device_name") or device_name,
                dt,
                r.get("attack_name", ""),
                r.get("cve_id") or None,
                _norm_type(r.get("intrusion_type", "")),
                _norm_severity(r.get("severity", "info")),
                _norm_action(r.get("action", "monitored")),
                r.get("protocol") or None,
                r.get("src_ip") or None,
                r.get("dst_ip") or None,
                int(r["src_port"]) if r.get("src_port", "").isdigit() else None,
                int(r["dst_port"]) if r.get("dst_port", "").isdigit() else None,
                int(r["count"]) if r.get("count", "").isdigit() else 1,
            ))

    return _bulk_insert(rows)


# ---------------------------------------------------------------------------
# 3. Single syslog line (call this from a syslog receiver loop)
# ---------------------------------------------------------------------------

# Matches key=value or key="value" pairs in a FortiGate/FortiAnalyzer syslog line.
_KV_RE = re.compile(r'(\w[\w\-]*)=("(?:[^"\\]|\\.)*"|\S+)')


def _parse_syslog_kv(line: str) -> dict:
    return {k: v.strip('"') for k, v in _KV_RE.findall(line)}


def ingest_from_syslog_line(line: str) -> bool:
    """
    Parse one FortiAnalyzer/FortiGate IPS syslog line (key=value format)
    and insert a single row.

    Typical line format:
      date=2026-05-06 time=20:15:33 devname="FGT-TelAviv" type=ips
      subtype=signature severity=critical action=dropped
      attack="Apache.Log4j.Error.Log.Remote.Code.Execution"
      attack_type=permission srcip=49.149.136.86 dstip=84.110.218.202
      srcport=54321 dstport=443 proto=6 cve-id="CVE-2021-44228" ...

    Returns True if the line was an IPS event and was inserted.

    Usage (in a syslog receiver loop):
        for line in syslog_lines:
            ingest_from_syslog_line(line)
    """
    kv = _parse_syslog_kv(line)

    # only process IPS log entries
    if kv.get("type", "").lower() not in ("ips",) and \
       kv.get("logid", "").startswith("0") is False:
        return False

    dt_raw = kv.get("date", "") + " " + kv.get("time", "")
    dt = _parse_dt(dt_raw.strip()) or datetime.now(timezone.utc)

    row = (
        kv.get("devname", kv.get("hostname", "unknown")),
        dt,
        kv.get("attack", kv.get("attackname", "")),
        kv.get("cve-id") or kv.get("cve_id") or None,
        _norm_type(kv.get("attack_type", kv.get("attacktype", ""))),
        _norm_severity(kv.get("severity", "info")),
        _norm_action(kv.get("action", "monitored")),
        kv.get("proto") or kv.get("protocol") or None,
        kv.get("srcip") or None,
        kv.get("dstip") or None,
        int(kv["srcport"]) if kv.get("srcport", "").isdigit() else None,
        int(kv["dstport"]) if kv.get("dstport", "").isdigit() else None,
        int(kv["count"]) if kv.get("count", "").isdigit() else 1,
    )

    _bulk_insert([row])
    return True
