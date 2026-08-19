from apscheduler.schedulers.background import BackgroundScheduler
import os
import time
from config.registered_processes.registered_processes import add_registered_processes
from utils.log4dbexpert import db_write_log
import numpy
scheduler = BackgroundScheduler(daemon=True, timezone="Asia/Jerusalem")
scheduler.start()

# Track current jobs
current_jobs = {}

def load_processes():
    try:
        # fetch latest process configuration
        _process_list = add_registered_processes()
        if not _process_list:
            return {}
        return {proc: interval for proc, interval in _process_list}
    except Exception as e:
        db_write_log(e, "", "Scheduler", "")
        return {}

def sync_jobs():
    global current_jobs
    new_config = load_processes()
    
    # Remove jobs that no longer exist
    for job_id in list(current_jobs.keys()):
        if job_id not in new_config:
            try:
                scheduler.remove_job(job_id)
                del current_jobs[job_id]
                print(f"Removed job: {job_id}")
            except Exception as e:
                db_write_log(e, "", "Scheduler", "")
    
    # Add new jobs or update interval if changed
    for process_name, interval_secs in new_config.items():
        if process_name not in current_jobs:
            # Add job
            func = get_function_by_name(process_name)
            if func is None:
                db_write_log(f"Unknown process name: '{process_name}' — skipping", "", "Scheduler", "")
                print(f"Skipping unknown process: {process_name}")
                continue
            scheduler.add_job(func, 'interval', seconds=interval_secs, id=process_name,
                              max_instances=1, coalesce=True, misfire_grace_time=60)
            current_jobs[process_name] = interval_secs
            print(f"Added job: {process_name} ({interval_secs}s)")
        elif current_jobs[process_name] != interval_secs:
            # Update job interval
            scheduler.reschedule_job(process_name, trigger='interval', seconds=interval_secs)
            current_jobs[process_name] = interval_secs
            print(f"Rescheduled job: {process_name} ({interval_secs}s)")

def get_function_by_name(name):
    # Map process names to actual functions
    from collection.collect_metrics import (
        collect_metrics_operation,
        collect_metrics_operation_sec,
        collect_metrics_operation_perf,
        collect_metrics_operation_hlth,
        collect_metrics_operation_other,
        collect_metrics_operation_critical,
        collect_metrics_operation_active_tx,
    )
    from widgets.monitoring_dashboard_widget_export import widget_dashboard_json_export
    from email_utils.email_handler import email_sender_operation
    from synch.synch_aggregations import execute_synch_aggregations
    from advisories.monitoring_metrics_advisory import issue_root_causes
    from alerts.alert_helper import manage_alerts
    from collection.monitoring_metrics_category_definitions import metrics_category_definitions
    from jobs.job_handler import job_next_run
    from processes.process_handler import execute_process
    from processes.detection_tree_builder import build_all_vendor_trees
    from processes.detection_tree_executor import execute_vendor_detection_tree
    from processes.category_definitions_export import export_category_definitions
    from processes.dashboard_data_export import export_dashboard_data
    from processes.grc_firewall_scanner import run_grc_firewall_scan
    from processes.compliance_report_generator import (
        run_compliance_reports_daily,
        run_compliance_reports_weekly,
    )
    from analysis.analyse_user_risk import run_user_risk_scoring
    from analysis.analyse_metrics_sensitive_column_access import metrics_sensitive_column_access_analysis
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
    from processes.retention_engine import run_retention_enforcement
    from processes.evidence_package_generator import run_evidence_package_generation
    from processes.gmmr_maintenance import run_gmmr_maintain
    from processes.dump_metrics import run_dump_and_prune_metrics
    from processes.retention_space_alert import run_retention_space_alert
    from processes.blocker import run_blocker
    from processes.auto_mask import run_auto_mask
    from processes.alert_auto_resolve import run_alert_auto_resolve
    from processes.alert_threshold_tuner import run_alert_threshold_tuner
    from processes.internal_health_monitor import run_internal_health_monitor
    from processes.app_login_guard import run_app_login_guard
    from processes.ransomware_guard import run_ransomware_guard
    from functools import partial
    mapping = {
        "app_login_guard": run_app_login_guard,
        "ransomware_guard": run_ransomware_guard,
        "alert_auto_resolve": run_alert_auto_resolve,
        "alert_threshold_tuner": run_alert_threshold_tuner,
        "internal_health_monitor": run_internal_health_monitor,
        "gmmr_maintain": run_gmmr_maintain,
        "dump_and_prune_metrics": run_dump_and_prune_metrics,
        "retention_space_alert": run_retention_space_alert,
        "blocker": run_blocker,
        "auto_mask": run_auto_mask,
        "sensitive_column_access_scan": metrics_sensitive_column_access_analysis,
        "collect_metrics_operation": collect_metrics_operation,
        "collect_metrics_operation_sec": collect_metrics_operation_sec,
        "collect_metrics_operation_perf": collect_metrics_operation_perf,
        "collect_metrics_operation_hlth": collect_metrics_operation_hlth,
        "collect_metrics_operation_other": collect_metrics_operation_other,
        "collect_metrics_operation_critical": collect_metrics_operation_critical,
        # Dedicated 30s collector for SEC-SQL-ACC-011-RC02 - its query has a 60s
        # lookback and the generic sweep only reaches it every 5.5-14 min.
        "active_tx_fast_collect": collect_metrics_operation_active_tx,
        "widget_dashboard_json_export": widget_dashboard_json_export,
        "email_sender_operation": email_sender_operation,
        "synch_aggregations": execute_synch_aggregations,
        "metrics_category_definitions": metrics_category_definitions,
        "report_job": job_next_run,
        "alerts": manage_alerts , 
        "process_update": execute_process,
        "category_definitions_export": export_category_definitions,
        "dashboard_data_export": export_dashboard_data,
        "detection_tree_build": build_all_vendor_trees,
        "detection_tree_sqlserver": partial(execute_vendor_detection_tree, "sqlserver"),
        "detection_tree_oracle": partial(execute_vendor_detection_tree, "oracle"),
        "detection_tree_postgresql": partial(execute_vendor_detection_tree, "postgresql"),
        "detection_tree_mysql": partial(execute_vendor_detection_tree, "mysql"),
        "grc_firewall_scan":             run_grc_firewall_scan,
        "compliance_reports_daily":      run_compliance_reports_daily,
        "compliance_reports_weekly":     run_compliance_reports_weekly,
        "user_risk_scoring":             run_user_risk_scoring,
        "sync_masking_rules":            sync_masking_rules,
        "run_threat_response":           run_threat_response,
        "ddl_audit_scan":                run_ddl_audit_scan,
        "privilege_change_scan":         run_privilege_change_scan,
        "sod_violation_scan":            run_sod_violation_scan,
        "exception_expiry_check":        run_exception_expiry_check,
        "access_review_cycle_check":     run_access_review_cycle_check,
        "continuous_data_discovery":     run_continuous_data_discovery,
        "tls_enforcement_scan":          run_tls_enforcement_scan,
        "vulnerability_scan":            run_vulnerability_scan,
        "retention_enforcement":         run_retention_enforcement,
        "evidence_package_generation":   run_evidence_package_generation,
    }
    return mapping.get(name)

# Schedule the config watcher — interval and max_instances are read from .env
# (CONFIG_WATCHER_INTERVAL, CONFIG_WATCHER_MAX_INSTANCES); defaults preserve
# the prior hard-coded values.
scheduler.add_job(
    sync_jobs, 'interval',
    seconds=int(os.getenv("CONFIG_WATCHER_INTERVAL", "30")),
    id="config_watcher",
    max_instances=int(os.getenv("CONFIG_WATCHER_MAX_INSTANCES", "100")),
)

import signal

def _graceful_shutdown(signum=None, frame=None):
    # On SIGTERM/SIGINT (systemd/nssm service stop or restart) stop the scheduler
    # cleanly BEFORE the interpreter's concurrent.futures atexit tears down the
    # thread pool. Pause first so the timer stops submitting jobs to the executor,
    # then shut down without waiting -- otherwise the daemon scheduler thread keeps
    # firing jobs into a dead pool ("RuntimeError: cannot schedule new futures
    # after shutdown"). Mirrors dbdome_service.py SvcStop.
    try:
        if scheduler.running:
            scheduler.pause()
            scheduler.shutdown(wait=False)
    except Exception as e:
        db_write_log(e, "", "Scheduler", "")
    raise SystemExit(0)

# SIGTERM is what systemd/nssm send on stop; the default handler does NOT raise
# SystemExit, so without this the clean-shutdown path below never runs.
for _signame in ("SIGTERM", "SIGINT"):
    _sig = getattr(signal, _signame, None)
    if _sig is not None:
        try:
            signal.signal(_sig, _graceful_shutdown)
        except (ValueError, OSError):
            pass  # not in the main thread / unsupported on this platform

# Keep the main thread alive
try:
    while True:
        time.sleep(2)
except (KeyboardInterrupt, SystemExit):
    pass
finally:
    try:
        if scheduler.running:
            scheduler.pause()
            scheduler.shutdown(wait=False)
    except Exception:
        pass
    