"""GRC Phase 9: TLS / Encrypted Connection Enforcement Scanner"""
import psycopg2
from datetime import datetime, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_LOOKBACK_SECONDS = 310
_policy_cache: dict = {}
_policy_loaded_at: float = 0.0
_POLICY_TTL = 120.0


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _load_tls_policies(conn) -> dict:
    import time
    global _policy_cache, _policy_loaded_at
    if time.time() - _policy_loaded_at < _POLICY_TTL:
        return _policy_cache
    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM config.tls_enforcement_policies WHERE is_active=TRUE")
        cols = [d[0] for d in cur.description]
        _policy_cache = {row[cols.index('server_name')]: dict(zip(cols, row))
                         for row in cur.fetchall()}
        _policy_loaded_at = time.time()
        cur.close()
    except psycopg2.errors.UndefinedTable:
        pass
    return _policy_cache


def _get_ssl_for_sessions(conn, server_name: str, since: datetime) -> dict:
    """Return {session_id: ssl_mode} for a server."""
    result = {}
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT j.value ->> 'session_id' AS session_id,
                   COALESCE(j.value ->> 'ssl_mode',
                            j.value ->> 'ssl',
                            j.value ->> 'encryption') AS ssl_mode
            FROM   monitoring.general_metric_metadata_results r
            CROSS  JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
            WHERE  r.server = %s
              AND  r.entry_date >= %s
              AND  (j.value ->> 'session_id') IS NOT NULL
        """, (server_name, since))
        for sid, ssl_mode in cur.fetchall():
            if sid:
                result[sid] = ssl_mode
        cur.close()
    except Exception:
        pass
    return result


def _scan_unencrypted_sessions(conn, since: datetime):
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT server_name, vendor, db_user, client_ip, db_name, session_id
            FROM   monitoring.v_recent_active_sessions
            WHERE  collected_at >= %s
        """, (since,))
        rows = cur.fetchall()
        cur.close()

        policies = _load_tls_policies(conn)
        # Group by server to batch SSL lookups
        by_server: dict = {}
        for row in rows:
            server_name = row[0]
            by_server.setdefault(server_name, []).append(row)

        for server_name, server_rows in by_server.items():
            policy = policies.get(server_name, {'require_ssl': True, 'action': 'ALERT',
                                                 'regulation': 'PCI-DSS', 'tls_policy_id': None})
            if not policy.get('require_ssl', True):
                continue
            ssl_map = _get_ssl_for_sessions(conn, server_name, since)

            for row in server_rows:
                server_name, vendor, db_user, client_ip, db_name, session_id = row
                ssl_mode = ssl_map.get(str(session_id) if session_id else '')
                if ssl_mode in (None, '', 'disable', 'off', 'false', '0'):
                    try:
                        ic = conn.cursor()
                        ic.execute("""
                            INSERT INTO log.tls_violations
                                (server_name, vendor, db_user, client_ip, db_name,
                                 session_id, ssl_mode, regulation, risk_level,
                                 action_taken, policy_ref)
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'HIGH',%s,%s)
                        """, (server_name, vendor, db_user, client_ip, db_name,
                              str(session_id) if session_id else None,
                              ssl_mode or 'none',
                              policy.get('regulation', 'PCI-DSS'),
                              policy.get('action', 'ALERT'),
                              policy.get('tls_policy_id')))
                        conn.commit()
                        ic.close()
                        try:
                            from processes.grc_alert_dispatcher import dispatch_grc_alert
                            dispatch_grc_alert(
                                severity='HIGH',
                                source_feature='tls_enforcement',
                                server_name=server_name,
                                event_summary=f"Unencrypted connection: user={db_user} ip={client_ip}",
                                regulation=policy.get('regulation', 'PCI-DSS'),
                            )
                        except Exception:
                            pass
                    except Exception as e:
                        conn.rollback()
                        db_write_log(f"tls_violations insert: {e}", 0, "tls_enforcement_scanner", server_name)
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"_scan_unencrypted_sessions: {e}", 0, "tls_enforcement_scanner", "")


def run_tls_enforcement_scan():
    since = datetime.utcnow() - timedelta(seconds=_LOOKBACK_SECONDS)
    try:
        conn = _get_conn()
        try:
            _scan_unencrypted_sessions(conn, since)
        finally:
            conn.close()
    except Exception as e:
        db_write_log(f"run_tls_enforcement_scan: {e}", 0, "tls_enforcement_scanner", "")
