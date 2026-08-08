"""Unified entry point for DBDOME dbanalytics service.

Starts both the scheduler and the HTTP server in a single process.
Can run as a Windows service or as a console application.

Usage (console):
    python dbdome_main.py                    # both scheduler + HTTP server
    python dbdome_main.py --web-only         # HTTP server only
    python dbdome_main.py --scheduler-only   # scheduler only
    python dbdome_main.py --port 8080        # custom HTTP port

Usage (Windows service):
    python dbdome_service.py install          # install service
    python dbdome_service.py start            # start service
    python dbdome_service.py stop             # stop service
    python dbdome_service.py remove           # uninstall service
"""

import warnings
# pandas emits a UserWarning when read_sql() is handed a raw DBAPI2 connection
# (psycopg2/pyodbc) instead of a SQLAlchemy engine. The raw connections work
# fine here; silence the cosmetic warning so it doesn't flood the service log.
warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy connectable")

import argparse
import os
import sys
import threading
import time

# Collectors print status lines containing emoji (🔍/✅/❌). On a cp1252
# console or redirected stdout those prints raise UnicodeEncodeError INSIDE
# the collection loop and abort the whole collector run. Never let console
# encoding kill collection: replace unencodable characters instead.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(errors="replace")
    except (AttributeError, ValueError, OSError):
        pass  # frozen/pythonw builds may have no real console streams

# Force matplotlib's non-interactive backend before anything imports pyplot.
# On Windows (session-0 service) the default GUI backend (Tk) has no display and
# blocks forever when a report renders a chart — this made the IPS report hang.
os.environ.setdefault("MPLBACKEND", "Agg")


def rotate_service_log():
    """Truncate dbdome_service.log once per hour."""
    # Truncation must succeed even if db_write_log is unavailable.
    try:
        log_path = getattr(sys.stdout, 'name', None)
        if not log_path or not log_path.endswith('.log'):
            base = (os.path.dirname(sys.executable)
                    if getattr(sys, 'frozen', False)
                    else os.path.dirname(os.path.abspath(__file__)))
            log_path = os.path.join(base, "dbdome_service.log")

        old_out, old_err = sys.stdout, sys.stderr
        new_f = open(log_path, "w", buffering=1, encoding="utf-8", errors="replace")
        sys.stdout = new_f
        sys.stderr = new_f

        for f in {old_out, old_err}:
            if f not in (sys.__stdout__, sys.__stderr__) and hasattr(f, 'close'):
                try:
                    f.close()
                except Exception:
                    pass

        stamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{stamp}] Log file rotated (hourly truncate)", flush=True)
    except Exception as e:
        try:
            print(f"rotate_service_log truncate failed: {e}", flush=True)
        except Exception:
            pass

    try:
        from utils.log4dbexpert import db_write_log
        db_write_log("Log file rotated (hourly)", "INFO", "rotate_service_log", "")
    except Exception:
        pass


def start_scheduler():
    """Start the APScheduler-based job scheduler."""
    from apscheduler.schedulers.background import BackgroundScheduler
    from config.registered_processes.registered_processes import add_registered_processes
    from utils.log4dbexpert import db_write_log
    from job_operation_scheduler import get_function_by_name
    from processes.grc_firewall_scanner import run_grc_firewall_scan
    from processes.compliance_report_generator import (
        run_compliance_reports_daily,
        run_compliance_reports_weekly,
    )
    from analysis.analyse_user_risk import run_user_risk_scoring
    from processes.data_masking_engine import sync_masking_rules
    from processes.threat_response_engine import run_threat_response
    from processes.ddl_audit_scanner import run_ddl_audit_scan
    from processes.privilege_change_scanner import run_privilege_change_scan
    from processes.sod_scanner import run_sod_violation_scan
    from processes.policy_exception_notifier import run_exception_expiry_check
    from processes.access_review_scheduler import run_access_review_cycle_check
    from processes.continuous_data_discovery import run_continuous_data_discovery
    from processes.tls_enforcement_scanner import run_tls_enforcement_scan
    from processes.vulnerability_scanner import run_vulnerability_scan
    from processes.retention_engine import run_retention_enforcement, refresh_retention_overview
    from processes.sql_script_runner import run_sql_scripts
    from processes.dedup_metric_results import run_dedup_metric_results
    from datetime import datetime

    scheduler = BackgroundScheduler(daemon=True, timezone="Asia/Jerusalem")
    scheduler.start()

    # Apply sql_scripts migrations in a dedicated thread at startup: as a pool
    # job it competes with the flood of collection jobs, misfires past its
    # grace window and is silently skipped (observed: 6390-6480 never applied).
    import threading

    def _migrate_then_stamp_version():
        # Version registration has to follow the migrations in the SAME thread:
        # config.set_version ships in 7440, so on an upgrade it does not exist
        # until run_sql_scripts has applied it.
        run_sql_scripts()
        from utils import version as _version
        registered = _version.register()
        print(f"[version] running {_version.version_label()}"
              + ("" if registered else " (not registered in config.app_version)"))

    threading.Thread(target=_migrate_then_stamp_version,
                     name="sql_script_runner_startup", daemon=True).start()

    current_jobs = {}

    def load_processes():
        try:
            _process_list = add_registered_processes()
            if not _process_list:
                return {}
            return {proc: interval for proc, interval in _process_list}
        except Exception as e:
            db_write_log(e, "", "Scheduler", "")
            return {}

    def sync_jobs():
        nonlocal current_jobs
        new_config = load_processes()

        for job_id in list(current_jobs.keys()):
            if job_id not in new_config:
                try:
                    scheduler.remove_job(job_id)
                    del current_jobs[job_id]
                    print(f"[scheduler] Removed job: {job_id}")
                except Exception as e:
                    db_write_log(e, "", "Scheduler", "")

        for process_name, interval_secs in new_config.items():
            if process_name not in current_jobs:
                func = get_function_by_name(process_name)
                if func is None:
                    db_write_log(f"Unknown process: '{process_name}'", "", "Scheduler", "")
                    print(f"[scheduler] Skipping unknown process: {process_name}")
                    continue
                scheduler.add_job(
                    func, 'interval', seconds=interval_secs,
                    # max_instances=1: never overlap the same collection routine —
                    # overlapping runs piled up threads/connections and spammed
                    # "maximum number of running instances reached". coalesce drops
                    # the backlog so a slow run just delays, never stacks.
                    id=process_name, max_instances=1,
                    coalesce=True, misfire_grace_time=60,
                )
                current_jobs[process_name] = interval_secs
                print(f"[scheduler] Added job: {process_name} ({interval_secs}s)")
            elif current_jobs[process_name] != interval_secs:
                scheduler.reschedule_job(
                    process_name, trigger='interval', seconds=interval_secs,
                )
                current_jobs[process_name] = interval_secs
                print(f"[scheduler] Rescheduled job: {process_name} ({interval_secs}s)")

    scheduler.add_job(
        sync_jobs, 'interval', seconds=30,
        id="config_watcher", max_instances=1,
    )

    scheduler.add_job(
        rotate_service_log, 'interval', seconds=3600,
        id="log_rotation", max_instances=1,
        coalesce=True,
    )

    scheduler.add_job(
        run_grc_firewall_scan, 'interval', seconds=60,
        id="grc_firewall_scan", max_instances=1,
        coalesce=True, misfire_grace_time=30,
    )

    # retention: refresh the metrics.t_retention_overview cache table every minute
    # so the retention dashboard reads a precomputed table instead of recomputing
    # per-metric sizes (~several seconds) on every panel load.
    scheduler.add_job(
        refresh_retention_overview, 'interval', seconds=60,
        id="retention", max_instances=1,
        coalesce=True, misfire_grace_time=30,
    )

    scheduler.add_job(
        run_compliance_reports_daily, 'interval', seconds=86400,
        id="compliance_reports_daily", max_instances=1,
        coalesce=True, misfire_grace_time=3600,
    )

    scheduler.add_job(
        run_compliance_reports_weekly, 'interval', seconds=604800,
        id="compliance_reports_weekly", max_instances=1,
        coalesce=True, misfire_grace_time=3600,
    )

    scheduler.add_job(
        run_user_risk_scoring, 'interval', seconds=300,
        id="user_risk_scoring", max_instances=1,
        coalesce=True, misfire_grace_time=60,
    )

    scheduler.add_job(
        sync_masking_rules, 'interval', seconds=3600,
        id="sync_masking_rules", max_instances=1,
        coalesce=True, misfire_grace_time=300,
    )

    scheduler.add_job(
        run_threat_response, 'interval', seconds=60,
        id="threat_response", max_instances=1,
        coalesce=True, misfire_grace_time=30,
    )

    scheduler.add_job(
        run_ddl_audit_scan, 'interval', seconds=300,
        id="ddl_audit_scan", max_instances=1,
        coalesce=True, misfire_grace_time=60,
    )

    scheduler.add_job(
        run_privilege_change_scan, 'interval', seconds=300,
        id="privilege_change_scan", max_instances=1,
        coalesce=True, misfire_grace_time=60,
    )

    scheduler.add_job(
        run_sod_violation_scan, 'interval', seconds=300,
        id="sod_violation_scan", max_instances=1,
        coalesce=True, misfire_grace_time=60,
    )

    scheduler.add_job(
        run_exception_expiry_check, 'interval', seconds=3600,
        id="exception_expiry_check", max_instances=1,
        coalesce=True, misfire_grace_time=300,
    )

    scheduler.add_job(
        run_access_review_cycle_check, 'interval', seconds=3600,
        id="access_review_cycle_check", max_instances=1,
        coalesce=True, misfire_grace_time=300,
    )

    scheduler.add_job(
        run_continuous_data_discovery, 'interval', seconds=3600,
        id="continuous_data_discovery", max_instances=1,
        coalesce=True, misfire_grace_time=300,
    )

    scheduler.add_job(
        run_tls_enforcement_scan, 'interval', seconds=300,
        id="tls_enforcement_scan", max_instances=1,
        coalesce=True, misfire_grace_time=60,
    )

    scheduler.add_job(
        run_vulnerability_scan, 'interval', seconds=86400,
        id="vulnerability_scan", max_instances=1,
        coalesce=True, misfire_grace_time=3600,
    )

    scheduler.add_job(
        run_retention_enforcement, 'interval', seconds=3600,
        id="retention_enforcement", max_instances=1,
        coalesce=True, misfire_grace_time=300,
    )

    # Generic SQL-scripts runner: applies views/functions/migrations from the
    # sql_scripts folder. Startup pass runs in its own thread (above); this is
    # the daily re-run. misfire_grace_time=None: never skip for pool contention
    # (the advisory lock + checksum ledger make a late/duplicate run a no-op).
    scheduler.add_job(
        run_sql_scripts, 'interval', seconds=86400,
        id="sql_script_runner", max_instances=1,
        coalesce=True, misfire_grace_time=None,
    )

    # De-duplicate monitoring.general_metric_metadata_results, ignoring
    # row_id + entry_date (keeps the latest row per identical content).
    scheduler.add_job(
        run_dedup_metric_results, 'interval', seconds=86400,
        id="dedup_metric_results", max_instances=1,
        coalesce=True, misfire_grace_time=600,
    )

    print("[scheduler] Started")
    return scheduler


def start_web(port=8080):
    """Start the FastAPI HTTP server in a background thread."""
    import uvicorn
    from http_server import app

    # Resolve TLS: serve HTTPS with the active certificate (self-signed
    # "personal" cert by default, or a customer-uploaded cert once installed).
    # get_uvicorn_ssl_kwargs() returns {} when SSL is disabled or unavailable,
    # in which case we fall back to plain HTTP exactly as before.
    ssl_kwargs = {}
    try:
        from utils.ssl_cert import get_uvicorn_ssl_kwargs
        ssl_kwargs = get_uvicorn_ssl_kwargs()
    except Exception as e:
        print(f"[http] SSL setup failed, serving plain HTTP: {e}")
        ssl_kwargs = {}

    scheme = "https" if ssl_kwargs else "http"

    def _run():
        try:
            print(f"[http] Uvicorn starting on {scheme}://0.0.0.0:{port}...")
            uvicorn.run(app, host="0.0.0.0", port=port, log_level="info", **ssl_kwargs)
        except Exception as e:
            print(f"[http] ERROR: {e}")

    thread = threading.Thread(target=_run, daemon=True, name="http-server")
    thread.start()
    # Wait a moment for uvicorn to bind the port
    time.sleep(2)
    if thread.is_alive():
        print(f"[http] Started on port {port} ({scheme.upper()})")
    else:
        print(f"[http] FAILED to start on port {port}")
    return thread


def run(port=8080, web_only=False, scheduler_only=False):
    """Main run loop — used by both console and Windows service."""
    # Silence SQLAlchemy per-statement INFO logging (was flooding the service log
    # to tens of MB). Backstop in case any create_engine(echo=True) slips back in.
    import logging as _logging
    for _n in ("sqlalchemy.engine", "sqlalchemy.pool", "sqlalchemy.dialects", "sqlalchemy.orm"):
        _logging.getLogger(_n).setLevel(_logging.WARNING)

    run_scheduler = not web_only
    run_web = not scheduler_only

    scheduler = None

    if run_web:
        start_web(port=port)

    if run_scheduler:
        scheduler = start_scheduler()

    print()
    print("DBDOME dbanalytics service running")
    if run_scheduler:
        print("  Scheduler: active")
    if run_web:
        try:
            from utils.ssl_cert import web_scheme
            _scheme = web_scheme()
        except Exception:
            _scheme = "http"
        print(f"  HTTP:      {_scheme}://localhost:{port}")
    print()

    return scheduler


def main():
    """Console entry point."""
    parser = argparse.ArgumentParser(description="DBDOME dbanalytics service")
    parser.add_argument("--web-only", action="store_true", help="Run HTTP server only")
    parser.add_argument("--scheduler-only", action="store_true", help="Run scheduler only")
    parser.add_argument("--port", type=int, default=8080, help="HTTP port (default: 8080)")
    args = parser.parse_args()

    scheduler = run(port=args.port, web_only=args.web_only, scheduler_only=args.scheduler_only)

    print("Press Ctrl+C to stop.")

    try:
        while True:
            time.sleep(2)
    except (KeyboardInterrupt, SystemExit):
        print("\nShutting down...")
        if scheduler:
            scheduler.shutdown(wait=False)


if __name__ == "__main__":
    main()
