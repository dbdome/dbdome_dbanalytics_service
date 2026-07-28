import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime, MetaData
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
try:
    from analysis.self_activity_filter import filter_excluded_logins as _dbdome_filter_excluded_logins
except Exception:
    def _dbdome_filter_excluded_logins(df, *a, **k):
        return df
from utils.oracle_client import oracle_connect
from utils.secrets_crypto import decrypt_secret
import psycopg2
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from datetime import datetime, timedelta

def collect_metric_active_transactions_from_oracle():

    pg_con = get_connection_string()
    engine = create_engine(pg_con, pool_pre_ping=True, future=True)
    raw_conn = psycopg2.connect(pg_con)

    pg_sql = """
        SELECT server, username, password, port, service_name
        FROM metrics.servers
        WHERE lower(db_vendor) = 'oracle'
          AND is_active = true
    """

    # Active transactions only: v$transaction.addr = v$session.taddr is the
    # Oracle analog of SQL Server's dm_tran_active_transactions join — a session
    # appears only while it holds an open transaction.
    oracle_sql = """
        SELECT
            sys_context('USERENV','SERVER_HOST')                 AS server,
            sys_context('USERENV','DB_NAME')                     AS database_name,
            s.sid                                                AS session_id,
            s.blocking_session                                   AS blocking_session,
            ROUND((SYSDATE - TO_DATE(t.start_time,'MM/DD/RR HH24:MI:SS')) * 86400) AS duration_secs,
            TO_DATE(t.start_time,'MM/DD/RR HH24:MI:SS')          AS start_time,
            s.username                                           AS login_name,
            s.program                                            AS program,
            s.machine                                            AS host_name,
            s.command                                            AS command,
            s.last_call_et                                       AS last_call_et,
            ROUND(NVL(q.cpu_time, 0) / 1000)                     AS cpu_time,
            (t.xidusn || '.' || t.xidslot || '.' || t.xidsqn)    AS transaction_id,
            REPLACE(REPLACE(REPLACE(
                DBMS_LOB.SUBSTR(q.sql_fulltext, 4000, 1),
                CHR(0), ''), CHR(13), ' '), CHR(10), ' ')        AS query_text
        FROM v$transaction t
        JOIN v$session s   ON s.taddr = t.addr
        LEFT JOIN v$sql q  ON q.sql_id = s.sql_id
                          AND q.child_number = s.sql_child_number
        WHERE s.type = 'USER'
    """

    try:
        cur = raw_conn.cursor()
        cur.execute(pg_sql)

        for server, user, pwd, port, service in cur.fetchall():

            # password is stored encrypted; decrypt_secret is idempotent (legacy
            # plaintext passes through unchanged)
            with oracle_connect(user, decrypt_secret(pwd), server, port, service) as ora_conn:

                df = pd.read_sql_query(oracle_sql, ora_conn)
                df.columns = [c.lower() for c in df.columns]  # normalize Oracle's UPPER aliases
                df = _dbdome_filter_excluded_logins(df)

                for _, r in df.iterrows():
                    # Prefer the transaction start; fall back to now - last_call_et.
                    start_time = r.start_time
                    if pd.isna(start_time):
                        start_time = datetime.now() - timedelta(seconds=int(r.last_call_et or 0))

                    with engine.begin() as pg:
                        pg.execute(
                            text("""
                                INSERT INTO monitoring.active_transactions
                                (server, session_id, blocking_session_id, duration_secs,
                                 database_name, start_time, open_transaction_count,
                                 cpu_time, command, login_name, program_name, host_name, query)
                                VALUES
                                (:server, :sid, :block_sid, :duration,
                                 :database_name, :start_time, :open_txn,
                                 :cpu_time, :command, :login_name, :program, :host, :query)
                            """),
                            {
                                "server": r.server,
                                "sid": int(r.session_id),
                                "block_sid": int(r.blocking_session) if not pd.isna(r.blocking_session) else 0,
                                "duration": int(r.duration_secs) if not pd.isna(r.duration_secs) else 0,
                                "database_name": r.database_name,
                                "start_time": start_time,
                                "open_txn": 1,
                                "cpu_time": int(r.cpu_time) if not pd.isna(r.cpu_time) else 0,
                                "command": r.command,
                                "login_name": r.login_name,
                                "program": r.program,
                                "host": r.host_name,
                                "query": r.query_text,
                            }
                        )

    finally:
        raw_conn.close()
        db_write_log("completed", 0, "metrics_active_transactions_oracle", "")

    return 0
