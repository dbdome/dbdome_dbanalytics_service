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

import argparse
import os
import sys
import threading
import time


def rotate_service_log():
    """Recreate dbdome_service.log every hour (wipes old content)."""
    import time
    from utils.log4dbexpert import db_write_log
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
        print(f"[{stamp}] Log file rotated (hourly)", flush=True)
        db_write_log("Log file rotated (hourly)", "INFO", "rotate_service_log", "")
    except Exception as e:
        try:
            from utils.log4dbexpert import db_write_log
            db_write_log(f"rotate_service_log failed: {e}", "ERROR", "rotate_service_log", "")
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

    scheduler = BackgroundScheduler(daemon=True, timezone="Asia/Jerusalem")
    scheduler.start()

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
                    id=process_name, max_instances=10,
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

    print("[scheduler] Started")
    return scheduler


def start_web(port=8080):
    """Start the FastAPI HTTP server in a background thread."""
    import uvicorn
    from http_server import app

    def _run():
        try:
            print(f"[http] Uvicorn starting on 0.0.0.0:{port}...")
            uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
        except Exception as e:
            print(f"[http] ERROR: {e}")

    thread = threading.Thread(target=_run, daemon=True, name="http-server")
    thread.start()
    # Wait a moment for uvicorn to bind the port
    time.sleep(2)
    if thread.is_alive():
        print(f"[http] Started on port {port}")
    else:
        print(f"[http] FAILED to start on port {port}")
    return thread


def run(port=8080, web_only=False, scheduler_only=False):
    """Main run loop — used by both console and Windows service."""
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
        print(f"  HTTP:      http://localhost:{port}")
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
