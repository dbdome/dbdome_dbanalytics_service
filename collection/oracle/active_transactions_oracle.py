import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime, MetaData
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log
import oracledb
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

    oracle_sql = """
        SELECT
            sys_context('USERENV','SERVER_HOST') AS server,
            s.sid AS session_id,
            s.blocking_session,
            (SYSDATE - s.logon_time) * 86400 AS duration_secs,
            s.program,
            s.machine AS host_name,
            q.sql_text AS query_text,
            s.last_call_et,
            s.command
        FROM v$session s
        LEFT JOIN v$sql q ON s.sql_id = q.sql_id
        WHERE s.username IS NOT NULL
          AND s.type = 'USER'
    """

    try:
        cur = raw_conn.cursor()
        cur.execute(pg_sql)

        for server, user, pwd, port, service in cur.fetchall():

            with oracledb.connect(
                user=user,
                password=pwd,
                host=server,
                port=port,
                service_name=service
            ) as ora_conn:

                df = pd.read_sql_query(oracle_sql, ora_conn)

                for _, r in df.iterrows():
                    start_time = datetime.now() - timedelta(seconds=int(r.last_call_et))

                    with engine.begin() as pg:
                        pg.execute(
                            text("""
                                INSERT INTO monitoring.active_transactions
                                (server, session_id, blocking_session_id,
                                 duration_secs, start_time,
                                 program_name, host_name, query, command)
                                VALUES
                                (:server, :sid, :block_sid,
                                 :duration, :start_time,
                                 :program, :host, :query, :command)
                            """),
                            {
                                "server": r.server,
                                "sid": r.session_id,
                                "block_sid": r.blocking_session or 0,
                                "duration": r.duration_secs,
                                "start_time": start_time,
                                "program": r.program,
                                "host": r.host_name,
                                "query": r.query_text,
                                "command": r.command
                            }
                        )

    finally:
        raw_conn.close()
        db_write_log("completed", 0, "metrics_active_transactions_oracle", "")

    return 0
