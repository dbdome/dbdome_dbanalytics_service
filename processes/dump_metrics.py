"""
Scheduled metric dump + prune.

Reads config.global_params 'dump_location', ensures the folder exists, then calls
config.dump_and_prune_metrics() which, for every row in config.dump_metrics:
  * COPYs the rows older than current_date - retention_months to a CSV in the
    dump location, then
  * DELETEs exactly those rows from monitoring.general_metric_metadata_results.

Registered as the 'dump_and_prune_metrics' process (metrics.registered_processes)
so the scheduler runs it on an interval.
"""
import os

import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def run_dump_and_prune_metrics():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        with conn.cursor() as cur:
            # ensure the dump folder exists (COPY ... TO won't create it)
            cur.execute("SELECT config.get_dump_location()")
            loc = (cur.fetchone() or [None])[0]
            if loc:
                try:
                    os.makedirs(loc, exist_ok=True)
                except Exception as e:
                    db_write_log(f"could not create dump_location '{loc}': {e}",
                                 0, "run_dump_and_prune_metrics", "")

            cur.execute(
                "SELECT metric_name, dumped_rows, deleted_rows, status "
                "FROM config.dump_and_prune_metrics()")
            rows = cur.fetchall()

        total = sum((r[2] or 0) for r in rows)
        errs = [r[0] for r in rows if r[3] and r[3].startswith("ERROR")]
        db_write_log(
            f"dump_and_prune_metrics: {len(rows)} metric(s), {total} row(s) pruned"
            + (f"; errors on {errs}" if errs else ""),
            0, "run_dump_and_prune_metrics", "")
    except Exception as e:
        db_write_log(f"dump_and_prune_metrics failed: {e}",
                     0, "run_dump_and_prune_metrics", "")
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
