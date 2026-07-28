"""GRC Phase 8: Real-time Alert Dispatcher
Library module — called synchronously from all GRC scanners.
Supports EMAIL, SYSLOG_CEF, and WEBHOOK channels.
"""
import os
import json
import socket
import smtplib
import time
import urllib.request
from email.mime.text import MIMEText
from typing import Optional
import psycopg2
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_channels_cache: list = []
_channels_loaded_at: float = 0.0
_CACHE_TTL = 60.0

_SEV_RANK = {'LOW': 1, 'MEDIUM': 2, 'HIGH': 3, 'CRITICAL': 4}
_CEF_SEV  = {'LOW': 3, 'MEDIUM': 5, 'HIGH': 7, 'CRITICAL': 10}


def reload_channel_cache():
    global _channels_loaded_at
    _channels_loaded_at = 0.0


def _load_channels(conn):
    global _channels_cache, _channels_loaded_at
    if time.time() - _channels_loaded_at < _CACHE_TTL:
        return _channels_cache
    cur = conn.cursor()
    cur.execute("SELECT * FROM config.grc_alert_channels WHERE is_active=TRUE")
    cols = [d[0] for d in cur.description]
    _channels_cache = [dict(zip(cols, row)) for row in cur.fetchall()]
    _channels_loaded_at = time.time()
    cur.close()
    return _channels_cache


def _should_send(channel: dict, severity: str, source_feature: str, regulation: Optional[str]) -> bool:
    if _SEV_RANK.get(severity, 0) < _SEV_RANK.get(channel.get('min_severity', 'LOW'), 0):
        return False
    feat_filter = channel.get('feature_sources') or []
    if feat_filter and source_feature not in feat_filter:
        return False
    reg_filter = channel.get('regulations') or []
    if reg_filter and regulation and regulation not in reg_filter:
        return False
    return True


def _dedup_check(conn, channel_id: int, source_feature: str,
                 server_name: str, event_summary: str) -> bool:
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT 1 FROM log.grc_alert_delivery_log
            WHERE channel_id=%s AND source_feature=%s AND server_name=%s
              AND event_summary=%s AND delivered_at >= NOW()-INTERVAL '5 minutes'
            LIMIT 1
        """, (channel_id, source_feature, server_name, event_summary[:500]))
        found = cur.fetchone() is not None
        cur.close()
        return found
    except Exception:
        return False


def _log_delivery(conn, channel: dict, source_feature: str, severity: str,
                  regulation: Optional[str], server_name: str,
                  event_summary: str, success: bool, error: str = None):
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO log.grc_alert_delivery_log
                (channel_id, channel_name, channel_type, source_feature,
                 severity, regulation, server_name, event_summary, success, error_message)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (channel.get('channel_id'), channel.get('channel_name'),
              channel.get('channel_type'), source_feature, severity, regulation,
              server_name, (event_summary or '')[:500], success,
              (str(error) or '')[:500] if error else None))
        conn.commit()
        cur.close()
    except Exception as e:
        db_write_log(f"_log_delivery: {e}", 0, "grc_alert_dispatcher", "")


def _send_email(channel: dict, severity: str, source_feature: str,
                server_name: str, event_summary: str, regulation: Optional[str]):
    host = os.getenv('SMTP_HOST', 'localhost')
    port = int(os.getenv('SMTP_PORT', '25'))
    user = os.getenv('SMTP_USER', '')
    pwd  = os.getenv('SMTP_PASS', '')
    prefix = channel.get('subject_prefix') or '[GRC-ALERT]'
    recipients = [r.strip() for r in (channel.get('recipients') or '').split(',') if r.strip()]
    if not recipients:
        return
    body = (f"GRC Alert\n\nSeverity:  {severity}\nFeature:   {source_feature}\n"
            f"Server:    {server_name}\nRegulation:{regulation or 'N/A'}\n\n{event_summary}")
    msg = MIMEText(body)
    msg['Subject'] = f"{prefix} [{severity}] {source_feature} on {server_name}"
    msg['From'] = user or 'grc@dbdome.local'
    msg['To']   = ', '.join(recipients)
    with smtplib.SMTP(host, port, timeout=10) as s:
        if user and pwd:
            s.login(user, pwd)
        s.sendmail(msg['From'], recipients, msg.as_string())


def _send_syslog_cef(channel: dict, severity: str, source_feature: str,
                     server_name: str, event_summary: str):
    host     = channel.get('syslog_host') or 'localhost'
    port     = int(channel.get('syslog_port') or 514)
    proto    = (channel.get('syslog_protocol') or 'UDP').upper()
    vendor   = channel.get('cef_vendor') or 'DBDOME'
    product  = channel.get('cef_product') or 'GRC'
    version  = channel.get('cef_version') or '0'
    sev_int  = _CEF_SEV.get(severity, 5)
    cef_msg  = (f"CEF:0|{vendor}|{product}|{version}|{source_feature}|"
                f"{event_summary[:150]}|{sev_int}|src={server_name}")
    syslog_msg = f"<134>{cef_msg}\n"
    data = syslog_msg.encode('utf-8', errors='replace')
    if proto == 'TCP':
        with socket.create_connection((host, port), timeout=5) as s:
            s.sendall(data)
    else:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.sendto(data, (host, port))


def _send_webhook(channel: dict, severity: str, source_feature: str,
                  server_name: str, event_summary: str,
                  regulation: Optional[str], detail: Optional[dict]):
    url = channel.get('webhook_url') or ''
    if not url:
        return
    payload = json.dumps({
        'severity': severity, 'source_feature': source_feature,
        'server_name': server_name, 'event_summary': event_summary,
        'regulation': regulation, 'detail': detail or {},
    }).encode('utf-8')
    req = urllib.request.Request(url, data=payload,
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=10):
        pass


def dispatch_grc_alert(severity: str, source_feature: str, server_name: str,
                       event_summary: str, regulation: str = None,
                       detail: dict = None) -> None:
    try:
        conn = psycopg2.connect(get_connection_string())
        try:
            channels = _load_channels(conn)
            for channel in channels:
                if not _should_send(channel, severity, source_feature, regulation):
                    continue
                if _dedup_check(conn, channel['channel_id'], source_feature, server_name, event_summary):
                    continue
                success, error = True, None
                try:
                    ctype = (channel.get('channel_type') or '').upper()
                    if ctype == 'EMAIL':
                        _send_email(channel, severity, source_feature, server_name, event_summary, regulation)
                    elif ctype == 'SYSLOG_CEF':
                        _send_syslog_cef(channel, severity, source_feature, server_name, event_summary)
                    elif ctype == 'WEBHOOK':
                        _send_webhook(channel, severity, source_feature, server_name, event_summary, regulation, detail)
                except Exception as e:
                    success, error = False, str(e)
                    db_write_log(f"dispatch channel {channel.get('channel_name')}: {e}", 0, "grc_alert_dispatcher", server_name)
                _log_delivery(conn, channel, source_feature, severity, regulation,
                              server_name, event_summary, success, error)
        finally:
            conn.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"dispatch_grc_alert: {e}", 0, "grc_alert_dispatcher", server_name or "")
