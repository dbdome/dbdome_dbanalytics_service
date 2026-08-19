"""GRC Phase 10: Data Retention Enforcement Engine"""
import hashlib
import psycopg2
import psycopg2.errors  # explicit: psycopg2/__init__ never imports this statically (the binding happens inside the compiled _psycopg), so a frozen build drops it and psycopg2.errors.* raises AttributeError at runtime
from datetime import date, timedelta
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def _get_conn():
    return psycopg2.connect(get_connection_string())


def _execute_purge(conn, policy: dict):
    cutoff = date.today() - timedelta(days=policy['retention_days'])

    if policy['retention_days'] < policy.get('min_retain_days', 0):
        db_write_log(
            f"SKIPPED '{policy['policy_name']}': retention_days ({policy['retention_days']}) "
            f"< min_retain_days ({policy['min_retain_days']})",
            0, "retention_engine", "")
        return

    schema = policy['target_schema']
    table  = policy['target_table']
    ts_col = policy.get('timestamp_column') or 'event_time'
    sql    = f"DELETE FROM {schema}.{table} WHERE {ts_col} < %s"

    rows_deleted = 0
    success      = True
    error_msg    = None

    try:
        cur = conn.cursor()
        cur.execute(sql, (cutoff,))
        rows_deleted = cur.rowcount
        conn.commit()
        cur.close()
        print(f"[retention] {policy['policy_name']}: deleted {rows_deleted} rows (cutoff {cutoff})")
    except Exception as e:
        conn.rollback()
        success   = False
        error_msg = str(e)
        db_write_log(f"purge {schema}.{table}: {e}", 0, "retention_engine", "")

    sha256_manifest = hashlib.sha256(
        f"{table}:{cutoff}:{rows_deleted}".encode()
    ).hexdigest()

    try:
        ic = conn.cursor()
        ic.execute("""
            INSERT INTO log.retention_executions
                (retention_id, policy_name, target_table, cutoff_date,
                 rows_deleted, purge_mode, regulation, executed_by,
                 success, error_message, sha256_manifest)
            VALUES (%s,%s,%s,%s,%s,%s,%s,'retention_engine',%s,%s,%s)
        """, (policy['retention_id'], policy['policy_name'], table,
              cutoff, rows_deleted,
              policy.get('purge_mode','DELETE'),
              policy.get('regulation'),
              success, error_msg, sha256_manifest))
        ic.execute("""
            UPDATE config.retention_policies SET last_run_at=NOW()
             WHERE retention_id=%s
        """, (policy['retention_id'],))
        conn.commit()
        ic.close()
    except Exception as e:
        conn.rollback()
        db_write_log(f"retention_executions insert: {e}", 0, "retention_engine", "")

    if not success:
        try:
            from processes.grc_alert_dispatcher import dispatch_grc_alert
            dispatch_grc_alert(
                severity='HIGH',
                source_feature='retention_enforcement',
                server_name='',
                event_summary=f"Retention purge FAILED for {table}: {error_msg}",
                regulation=policy.get('regulation'),
            )
        except Exception:
            pass


def run_retention_enforcement():
    try:
        conn = _get_conn()
        try:
            cur = conn.cursor()
            cur.execute("SELECT * FROM config.retention_policies WHERE is_active=TRUE ORDER BY retention_id")
            cols     = [d[0] for d in cur.description]
            policies = [dict(zip(cols, row)) for row in cur.fetchall()]
            cur.close()

            for policy in policies:
                _execute_purge(conn, policy)
        finally:
            conn.close()
    except psycopg2.errors.UndefinedTable:
        pass
    except Exception as e:
        db_write_log(f"run_retention_enforcement: {e}", 0, "retention_engine", "")


def refresh_retention_overview():
    """Materialise metrics.retention_overview() into the cache table
    metrics.t_retention_overview so the retention dashboard reads instantly
    (the function samples ~2.5M rows and still takes several seconds).

    DROP + CREATE run inside ONE transaction: PostgreSQL DDL is transactional, so
    concurrent dashboard reads keep seeing the previous table until COMMIT - there
    is no window where t_retention_overview is missing. Scheduled every 60s."""
    try:
        conn = _get_conn()
        try:
            with conn:                       # commit on success, rollback on error
                cur = conn.cursor()
                cur.execute("DROP TABLE IF EXISTS metrics.t_retention_overview")
                cur.execute("CREATE TABLE IF NOT EXISTS metrics.t_retention_overview "
                            "AS SELECT * FROM metrics.retention_overview()")
                cur.close()
        finally:
            conn.close()
    except Exception as e:
        db_write_log(f"refresh_retention_overview: {e}", 0, "retention_engine", "")
