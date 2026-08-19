"""GRC Phase 7: DDL / Schema-Change Audit Scanner"""
import psycopg2
import psycopg2.errors  # explicit: psycopg2/__init__ never imports this statically (the binding happens inside the compiled _psycopg), so a frozen build drops it and psycopg2.errors.* raises AttributeError at runtime
from datetime import datetime, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

_LOOKBACK_SECONDS = 130
_PCI_PATTERNS  = ('payment','card','ccnum','credit','cardholder','pan')
_HIPAA_PATTERNS= ('phi','patient','hipaa','medical','diagnosis','health')
_GDPR_PATTERNS = ('pii','personal','gdpr','subject','consent','private')


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _classify(ddl_command: str, object_name: str):
    cmd  = (ddl_command or '').upper()
    name = (object_name  or '').lower()
    if cmd in ('DROP', 'TRUNCATE'):
        risk = 'HIGH'
    elif cmd == 'ALTER' and any(p in name for p in _PCI_PATTERNS + _HIPAA_PATTERNS + _GDPR_PATTERNS):
        risk = 'HIGH'
    elif cmd == 'ALTER':
        risk = 'MEDIUM'
    else:
        risk = 'LOW'
    if   any(p in name for p in _PCI_PATTERNS):   reg = 'PCI-DSS'
    elif any(p in name for p in _HIPAA_PATTERNS):  reg = 'HIPAA'
    elif any(p in name for p in _GDPR_PATTERNS):   reg = 'GDPR'
    else:                                           reg = None
    return risk, reg


def _scan_ddl_events(conn, since: datetime):
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT r.server,
                   rc.vendor_name,
                   j.value ->> 'db_user'       AS db_user,
                   j.value ->> 'client_ip'     AS client_ip,
                   j.value ->> 'db_name'       AS db_name,
                   j.value ->> 'object_schema' AS object_schema,
                   j.value ->> 'object_name'   AS object_name,
                   j.value ->> 'object_type'   AS object_type,
                   j.value ->> 'ddl_command'   AS ddl_command,
                   j.value ->> 'ddl_statement' AS ddl_statement,
                   r.entry_date
            FROM   monitoring.general_metric_metadata_results r
            JOIN   rootcause.v_rootcauses rc ON rc.root_cause_id = r.metric_name
            CROSS  JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
            WHERE  (rc.area_code IN ('DDL','SCH','CFG')
                    OR r.metric_name ILIKE '%ddl%'
                    OR r.metric_name ILIKE '%schema%')
              AND  r.entry_date >= %s
        """, (since,))
        rows = cur.fetchall()
        cur.close()
        for row in rows:
            (server_name, vendor, db_user, client_ip, db_name,
             object_schema, object_name, object_type,
             ddl_command, ddl_statement, entry_date) = row
            if not ddl_command:
                continue
            risk_level, regulation = _classify(ddl_command, object_name)
            try:
                ic = conn.cursor()
                ic.execute("""
                    INSERT INTO log.ddl_audit_log
                        (event_time, server_name, vendor, db_user, client_ip,
                         db_name, object_schema, object_name, object_type,
                         ddl_command, ddl_statement, regulation, risk_level)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """, (entry_date, server_name or '', vendor or '',
                      db_user, client_ip, db_name, object_schema,
                      object_name, object_type, (ddl_command or '').upper(),
                      ddl_statement, regulation, risk_level))
                conn.commit()
                ic.close()
            except Exception as e:
                conn.rollback()
                db_write_log(f"ddl_audit_log insert: {e}", 0, "ddl_audit_scanner", server_name or "")
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"_scan_ddl_events: {e}", 0, "ddl_audit_scanner", "")


def run_ddl_audit_scan():
    since = datetime.utcnow() - timedelta(seconds=_LOOKBACK_SECONDS)
    try:
        conn = _get_conn()
        try:
            _scan_ddl_events(conn, since)
        finally:
            conn.close()
    except Exception as e:
        db_write_log(f"run_ddl_audit_scan: {e}", 0, "ddl_audit_scanner", "")
