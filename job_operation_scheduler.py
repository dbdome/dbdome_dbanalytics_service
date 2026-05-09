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
    )
    from analysis.analyse_metrics import analyse_metrics_operation
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
    from purgers.purge_metric_metadata import purge_general_metric_metadata
    from processes.grc_firewall_scanner import run_grc_firewall_scan
    from processes.compliance_report_generator import (
        run_compliance_reports_daily,
        run_compliance_reports_weekly,
    )
    from analysis.analyse_user_risk import run_user_risk_scoring
    from functools import partial
    mapping = {
        "collect_metrics_operation": collect_metrics_operation,
        "collect_metrics_operation_sec": collect_metrics_operation_sec,
        "collect_metrics_operation_perf": collect_metrics_operation_perf,
        "collect_metrics_operation_hlth": collect_metrics_operation_hlth,
        "collect_metrics_operation_other": collect_metrics_operation_other,
        "collect_metrics_operation_critical": collect_metrics_operation_critical,
        "analyse_metrics_operation": analyse_metrics_operation,
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
        "purge_general_metric_metadata": purge_general_metric_metadata,
        "grc_firewall_scan":             run_grc_firewall_scan,
        "compliance_reports_daily":      run_compliance_reports_daily,
        "compliance_reports_weekly":     run_compliance_reports_weekly,
        "user_risk_scoring":             run_user_risk_scoring,
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

# Keep the main thread alive
try:
    while True:
        time.sleep(2)
except (KeyboardInterrupt, SystemExit):
    scheduler.shutdown()
    