import json

import psycopg2
import pandas as pd
from sqlalchemy import create_engine

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log

ROOT_CAUSE_ID = "SEC-SQL-PRI-001-RC15"

# Sensitive tables/columns come from monitoring.v_sec_sql_pri_001_rc12 (server +
# db_name + schema_name + table_name + column_name + pii_category, itself sourced
# from metrics.sensitive_columns). Captured query text comes from
# monitoring.v_sec_sql_acc_011_rc02 (multi-vendor). A match is query_text
# containing a sensitive column_name OR table_name, scoped to the same
# server + database so a same-named column in an unrelated database doesn't
# false-positive. Only queries captured in the last minute are scanned each
# run (both views are derived from the very large, JSON-backed
# general_metric_metadata_results, so an unbounded historical scan here is
# expensive) -- repeat-alert suppression is left to alerts.alert_log's own
# one-alert-per-server-per-root-cause-per-hour dedup, not a second historical
# lookback in this query.
FIND_SQL = """
WITH sensitive AS (
    SELECT DISTINCT server, db_name, schema_name, table_name, column_name, pii_category
    FROM monitoring.v_sec_sql_pri_001_rc12
)
SELECT
    acc.server,
    acc.database_name,
    acc.session_id,
    acc.transaction_id,
    acc.login_name,
    acc.transaction_begin_time,
    acc.query_text,
    s.schema_name,
    s.table_name,
    s.column_name,
    s.pii_category
FROM monitoring.v_sec_sql_acc_011_rc02 acc
JOIN sensitive s
  ON acc.server = s.server
 AND acc.database_name = s.db_name
 AND (acc.query_text ILIKE '%' || s.column_name || '%'
      OR acc.query_text ILIKE '%' || s.table_name || '%')
WHERE acc.query_text IS NOT NULL
  AND acc.entry_date > now() - interval '1 minute'
"""


def metrics_sensitive_column_access_analysis():
    """SEC-SQL-PRI-001-RC15: flag captured queries that reference a known
    sensitive table or column, storing a finding row (for the drill-down UI)
    and raising an alerts.alert_log entry, mirroring analysis/anomaly_agent.py.
    """
    engine = create_engine(get_connection_string())
    conn = engine.raw_connection()
    stored = 0
    try:
        df = pd.read_sql_query(FIND_SQL, con=conn)
        if df.empty:
            return 1

        cur = conn.cursor()
        cur.execute("""SELECT risk_level FROM rootcause.v_rootcauses
                       WHERE root_cause_id = %s LIMIT 1""", (ROOT_CAUSE_ID,))
        risk_row = cur.fetchone()
        risk_level = risk_row[0] if risk_row else "high"

        for _, row in df.iterrows():
            server = row['server']
            element = {
                "source": "captured_query",
                "session_id": row['session_id'],
                "transaction_id": row['transaction_id'],
                "login_name": row['login_name'],
                "db_name": row['database_name'],
                "schema_name": row['schema_name'],
                "table_name": row['table_name'],
                "column_name": row['column_name'],
                "pii_category": row['pii_category'],
                "transaction_begin_time": row['transaction_begin_time'],
                "query_text": row['query_text'],
            }
            metric_config = {
                "source": "analyse_metrics_sensitive_column_access",
                "query": "monitoring.v_sec_sql_pri_001_rc12 x monitoring.v_sec_sql_acc_011_rc02",
            }

            # borrow a category_id from a recent row of this server (nullable-safe)
            cur.execute("""SELECT category_id FROM monitoring.general_metric_metadata_results
                           WHERE server = %s AND category_id IS NOT NULL
                           ORDER BY entry_date DESC LIMIT 1""", (server,))
            cat_row = cur.fetchone()
            category_id = cat_row[0] if cat_row else None

            cur.execute("""
                INSERT INTO monitoring.general_metric_metadata_results
                    (server, category_id, metric_name, metric_config, metric_metadata)
                VALUES (%s, %s, %s, %s, %s)
            """, (server, category_id, ROOT_CAUSE_ID, json.dumps(metric_config),
                  json.dumps([element], default=str)))

            try:
                cur.execute("CALL rootcause.update_root_cause_result(%s, %s)", (ROOT_CAUSE_ID, server))
            except Exception:
                pass  # optional pipeline hook; never block the finding on it

            # one alert per server+root_cause per hour (mirror the collectors / anomaly_agent)
            cur.execute("""DELETE FROM alerts.alert_log
                           WHERE server = %s AND root_cause_id = %s
                             AND date_trunc('hour', entry_date) = date_trunc('hour', LOCALTIMESTAMP)""",
                        (server, ROOT_CAUSE_ID))
            cur.execute("""
                INSERT INTO alerts.alert_log (server, root_cause_id, risk_level, metadata, login_name)
                VALUES (%s, %s, %s, %s, %s)
            """, (server, ROOT_CAUSE_ID, risk_level, json.dumps(element, default=str), row['login_name']))
            stored += 1

        conn.commit()
    except Exception as e:
        conn.rollback()
        db_write_log(f"metrics_sensitive_column_access_analysis failed with error:{e}", 0,
                      "metrics_sensitive_column_access_analysis", "")
    finally:
        db_write_log(f"metrics_sensitive_column_access_analysis stored {stored} finding(s)", 0,
                      "metrics_sensitive_column_access_analysis", "")
        conn.close()
    return 1
