"""GRC Phase 7: Separation of Duties (SoD) Detection Scanner"""
import re
import psycopg2
from datetime import datetime, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _load_sod_rules(conn):
    cur = conn.cursor()
    cur.execute("SELECT rule_id, rule_name, privilege_a, privilege_b, object_scope, severity, regulation FROM config.sod_rules WHERE is_active=TRUE")
    cols = [d[0] for d in cur.description]
    rules = [dict(zip(cols, row)) for row in cur.fetchall()]
    cur.close()
    return rules


def _get_user_privileges(conn):
    """Return {server: {user: [privilege_strings]}} from recent monitoring data."""
    user_privs = {}
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT r.server,
                   j.value ->> 'db_user'       AS db_user,
                   j.value ->> 'privilege'      AS privilege,
                   j.value ->> 'role'           AS role,
                   j.value ->> 'object'         AS object_name
            FROM   monitoring.general_metric_metadata_results r
            CROSS  JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
            WHERE  (r.metric_name ILIKE '%privilege%' OR r.metric_name ILIKE '%grant%'
                    OR r.metric_name ILIKE '%role%' OR r.metric_name ILIKE '%permission%')
              AND  r.entry_date >= NOW() - INTERVAL '2 hours'
        """)
        for row in cur.fetchall():
            server, db_user, privilege, role, object_name = row
            if not db_user:
                continue
            privs = user_privs.setdefault(server, {}).setdefault(db_user, [])
            if privilege:
                privs.append(privilege.lower())
                if object_name:
                    privs.append(f"{privilege.lower()} on {object_name.lower()}")
            if role:
                privs.append(role.lower())
        cur.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"_get_user_privileges: {e}", 0, "sod_scanner", "")
    return user_privs


def _priv_matches(priv_pattern: str, user_privs: list) -> str:
    """Return the first matching privilege string, or empty string."""
    pattern_lower = priv_pattern.lower()
    for p in user_privs:
        if pattern_lower in p or re.search(re.escape(pattern_lower), p):
            return p
    return ''


def _already_recorded(conn, rule_id, server_name, db_user) -> bool:
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT 1 FROM log.sod_violations
            WHERE rule_id=%s AND server_name=%s AND db_user=%s
              AND is_acknowledged=FALSE
              AND detected_at >= NOW() - INTERVAL '24 hours'
            LIMIT 1
        """, (rule_id, server_name, db_user))
        found = cur.fetchone() is not None
        cur.close()
        return found
    except Exception:
        return False


def run_sod_violation_scan():
    try:
        conn = _get_conn()
        try:
            rules = _load_sod_rules(conn)
            if not rules:
                return
            user_privs_map = _get_user_privileges(conn)
            for server_name, users in user_privs_map.items():
                for db_user, privs in users.items():
                    for rule in rules:
                        match_a = _priv_matches(rule['privilege_a'], privs)
                        match_b = _priv_matches(rule['privilege_b'], privs)
                        if match_a and match_b:
                            if _already_recorded(conn, rule['rule_id'], server_name, db_user):
                                continue
                            try:
                                ic = conn.cursor()
                                ic.execute("""
                                    INSERT INTO log.sod_violations
                                        (rule_id, rule_name, server_name, db_user,
                                         privilege_a_detail, privilege_b_detail,
                                         severity, regulation)
                                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                                """, (rule['rule_id'], rule['rule_name'],
                                      server_name, db_user,
                                      match_a, match_b,
                                      rule['severity'], rule['regulation']))
                                conn.commit()
                                ic.close()
                                db_write_log(
                                    f"SoD violation: {rule['rule_name']} user={db_user} server={server_name}",
                                    rule['severity'], "sod_scanner", server_name)
                            except Exception as e:
                                conn.rollback()
                                db_write_log(f"sod_violations insert: {e}", 0, "sod_scanner", server_name)
        finally:
            conn.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"run_sod_violation_scan: {e}", 0, "sod_scanner", "")
