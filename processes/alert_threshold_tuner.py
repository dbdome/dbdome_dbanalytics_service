"""Raise per-server alert thresholds for root causes that keep recurring.

Scheduled process (metrics.registered_processes 'alert_threshold_tuner', hourly).
Delegates the whole decision to rootcause.tune_alert_thresholds(), which:

  * finds every (server, root_cause_id) that alerted >= tuning_min_recurrences
    times inside tuning_window_hours;
  * reads the value actually observed for that alert out of
    alerts.alert_log.metadata;
  * writes a per-server override into rootcause.parameter_tuning set just above
    the observed max (+ tuning_margin_pct), capped at base * tuning_max_raise_multiple.

rootcause.detection_steps.parameters is never modified - the override is scoped
to the one noisy server, so every other target keeps the shipped sensitivity.

Both switches default OFF: config.global_params.tuning_enabled and this
process's is_active row. Turn them on deliberately.

Policy lives in SQL for the same reason as alert_auto_resolve: one place, and
the UI/manual path shares the same tables and rules.
"""
import psycopg2

from utils.config_dotenv import get_connection_string
from utils.log4dbexpert import db_write_log


def run_alert_threshold_tuner():
    conn = None
    try:
        conn = psycopg2.connect(get_connection_string())
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("SELECT rootcause.tune_alert_thresholds()")
        n = cur.fetchone()[0]
        if n:
            db_write_log(f"raised {n} alert threshold(s) from recurring alerts", 0,
                         "alert_threshold_tuner", "")

        # Surface parameters we could not learn: the detection step's condition
        # is prose, so no metadata column could be derived. These are recorded
        # but never tuned - they need a human to set observed_key.
        cur.execute("""
            SELECT count(*) FROM rootcause.parameter_tuning
            WHERE needs_mapping AND updated_at > now() - interval '1 hour'
        """)
        unmapped = cur.fetchone()[0]
        if unmapped:
            db_write_log(
                f"{unmapped} recurring parameter(s) could not be tuned automatically "
                f"(condition is not a machine-readable expression) - see "
                f"rootcause.v_parameter_tuning WHERE needs_mapping", 0,
                "alert_threshold_tuner", "")
        return 1
    except Exception as e:
        db_write_log(f"alert_threshold_tuner failed: {e}", 0, "alert_threshold_tuner", "")
        return 0
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
