"""GRC Phase 7: Privilege Change Tracking Scanner"""
import psycopg2
from datetime import datetime, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_LOOKBACK_SECONDS = 310
_PCI_PATTERNS  = ('payment','card','ccnum','credit','cardholder','pan','financial')
_GDPR_PATTERNS = ('pii','personal','gdpr','subject','private','sensitive')


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _classify_privilege(privilege_type: str, object_name: str, with_grant: bool):
    name = (object_name or '').lower()
    priv = (privilege_type or '').upper()
    if with_grant and priv == 'ALL':
        regulation = 'SOC2'
    elif any(p in name for p in _PCI_PATTERNS):
        regulation = 'PCI-DSS'
    elif any(p in name for p in _GDPR_PATTERNS):
        regulation = 'GDPR'
    else:
        regulation = None
    return regulation


def _scan_privilege_events(conn, since: datetime):
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT r.server,
                   rc.vendor_name,
                   j.value ->> 'grantor'       AS grantor_user,
                   j.value ->> 'grantee'       AS grantee_user,
                   COALESCE(j.value ->> 'operation','GRANT') AS operation,
                   j.value ->> 'privilege'     AS privilege_type,
                   j.value ->> 'object_schema' AS object_schema,
                   j.value ->> 'object'        AS object_name,
                   j.value ->> 'object_type'   AS object_type,
                   j.value ->> 'db_name'       AS db_name,
                   COALESCE((j.value ->> 'with_grant')::boolean, FALSE) AS with_grant,
                   r.entry_date
            FROM   monitoring.general_metric_metadata_results r
            JOIN   rootcause.v_rootcauses rc ON rc.root_cause_id = r.metric_name
            CROSS  JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
            WHERE  (rc.area_code IN ('PRI','AZ','AUTHZ','AUTH')
                    OR r.metric_name ILIKE '%grant%'
                    OR r.metric_name ILIKE '%privilege%')
              AND  r.entry_date >= %s
        """, (since,))
        rows = cur.fetchall()
        cur.close()
        for row in rows:
            (server_name, vendor, grantor_user, grantee_user, operation,
             privilege_type, object_schema, object_name, object_type,
             db_name, with_grant, entry_date) = row
            if not grantee_user:
                continue
            regulation = _classify_privilege(privilege_type, object_name, with_grant)
            try:
                ic = conn.cursor()
                ic.execute("""
                    INSERT INTO log.privilege_change_log
                        (event_time, server_name, vendor, grantor_user, grantee_user,
                         operation, privilege_type, object_schema, object_name,
                         object_type, db_name, with_grant, regulation)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """, (entry_date, server_name or '', vendor or '',
                      grantor_user, grantee_user, (operation or 'GRANT').upper(),
                      privilege_type, object_schema, object_name,
                      object_type, db_name, bool(with_grant), regulation))
                conn.commit()
                ic.close()
            except Exception as e:
                conn.rollback()
                db_write_log(f"privilege_change_log insert: {e}", 0, "privilege_change_scanner", server_name or "")
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"_scan_privilege_events: {e}", 0, "privilege_change_scanner", "")


def run_privilege_change_scan():
    since = datetime.utcnow() - timedelta(seconds=_LOOKBACK_SECONDS)
    try:
        conn = _get_conn()
        try:
            _scan_privilege_events(conn, since)
        finally:
            conn.close()
    except Exception as e:
        db_write_log(f"run_privilege_change_scan: {e}", 0, "privilege_change_scanner", "")
