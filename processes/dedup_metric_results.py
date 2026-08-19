"""
Scheduled de-duplication of monitoring.general_metric_metadata_results.

A duplicate = two rows with identical content IGNORING row_id and entry_date,
i.e. same (server, category_id, metric_name, metric_config, metric_metadata).
The most recent row per group is kept (max entry_date, then max id); the rest
are deleted.

Requires the migrated (partitioned) schema that has the surrogate `id` column
+ PK (entry_date, id). If the table hasn't been migrated yet it is skipped
cleanly.
"""
import psycopg2
import psycopg2.errors  # explicit: psycopg2/__init__ never imports this statically (the binding happens inside the compiled _psycopg), so a frozen build drops it and psycopg2.errors.* raises AttributeError at runtime

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


# md5 over the content columns keeps the PARTITION BY key small/fast.
# json (metric_config) has no equality operator, so we compare on ::text.
_DEDUP_SQL = """
WITH ranked AS (
    SELECT entry_date, id,
           row_number() OVER (
               PARTITION BY server, category_id, metric_name, server_id,
                            md5(coalesce(metric_config::text, '') || '|' ||
                                coalesce(metric_metadata::text, '') || '|' ||
                                coalesce(metric_metadata_vs_expected::text, ''))
               ORDER BY entry_date DESC NULLS LAST, id DESC
           ) AS rn
    FROM monitoring.general_metric_metadata_results
)
DELETE FROM monitoring.general_metric_metadata_results t
USING ranked r
WHERE t.entry_date = r.entry_date
  AND t.id = r.id
  AND r.rn > 1;
"""

_HAS_ID_SQL = """
SELECT 1 FROM information_schema.columns
WHERE table_schema = 'monitoring'
  AND table_name   = 'general_metric_metadata_results'
  AND column_name  = 'id'
"""


def run_dedup_metric_results():
    try:
        conn = psycopg2.connect(get_connection_string())
    except Exception as e:
        db_write_log(f"dedup connect: {e}", 0, "dedup_metric_results", "")
        return
    try:
        cur = conn.cursor()
        cur.execute(_HAS_ID_SQL)
        if cur.fetchone() is None:
            cur.close()
            print("[dedup_metric_results] table not migrated (no id column) — skipping")
            return

        cur.execute(_DEDUP_SQL)
        deleted = cur.rowcount
        conn.commit()
        cur.close()
        print(f"[dedup_metric_results] deleted {deleted} duplicate row(s)")
        if deleted:
            db_write_log(f"deleted {deleted} duplicates", 0, "dedup_metric_results", "")
    except psycopg2.errors.UndefinedTable:
        conn.rollback()
        print("[dedup_metric_results] table missing — skipping")
    except Exception as e:
        conn.rollback()
        db_write_log(f"run_dedup_metric_results: {e}", 0, "dedup_metric_results", "")
    finally:
        conn.close()
