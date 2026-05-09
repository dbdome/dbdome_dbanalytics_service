"""Purger for monitoring.general_metric_metadata_results.

Keeps only the most recent row per (metric_name, server) for metric_names
that exist in rootcause.v_rootcauses. Activated as a scheduled job
registered in metrics.registered_processes.
"""

import psycopg2
from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


PURGE_SQL = """
delete from monitoring.general_metric_metadata_results
where row_id in (
    select row_id from (
        select row_id, entry_date, metric_name, server_id
        from (
            select row_id,
                   row_number() over (
                       partition by metric_name, server_id,metric_config::text
                       order by entry_date desc
                   ) seq,
                   date_trunc('hour', entry_date) entry_date,
                   metric_name,
                   server_id
            from monitoring.general_metric_metadata_results gmmr
            join rootcause.v_rootcauses rc
              on rc.root_cause_id = gmmr.metric_name
        ) ranked
        where seq > 1
    ) victims
)
"""


def purge_general_metric_metadata():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        cur = conn.cursor()
        cur.execute(PURGE_SQL)
        deleted = cur.rowcount
        conn.commit()
        db_write_log(
            f"purge_general_metric_metadata deleted {deleted} rows",
            0, "purge_general_metric_metadata", "",
        )
    except Exception as e:
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                pass
        db_write_log(
            f"purge_general_metric_metadata failed: {e}",
            0, "purge_general_metric_metadata", "",
        )
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass







PURGE_SQL_PER_ROOT_CAUSE = """
  delete from monitoring.general_metric_metadata_results
  where row_id in (
      select row_id
      from (
          select row_id,
                 row_number() over (
                     partition by metric_name, server_id , metric_config::text
                     order by entry_date desc
                 ) as seq
          from monitoring.general_metric_metadata_results
          where metric_name = %s
      ) ranked
      where seq > 1
  )
"""



def purge_general_metric_metadata_per_root_cause(rootcause_id):
      conn = None
      try:
          conn = psycopg2.connect(get_connection_string())
          cur = conn.cursor()
          cur.execute(PURGE_SQL_PER_ROOT_CAUSE, (rootcause_id,))
          deleted = cur.rowcount
          conn.commit()
          db_write_log(
              f"purge_general_metric_metadata_per_root_cause({rootcause_id}) deleted {deleted} rows",
              0, "purge_general_metric_metadata_per_root_cause", "",
          )
      except Exception as e:
          if conn is not None:
              try:
                  conn.rollback()
              except Exception:
                  pass
          db_write_log(
              f"purge_general_metric_metadata_per_root_cause({rootcause_id}) failed: {e}",
              0, "purge_general_metric_metadata_per_root_cause", "",
          )
      finally:
          if conn is not None:
              try:
                  conn.close()
              except Exception:
                  pass