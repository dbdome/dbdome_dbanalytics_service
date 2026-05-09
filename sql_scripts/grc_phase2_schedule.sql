-- GRC Phase 2: Register compliance report jobs in metrics.registered_processes
-- Run after grc_phase2_report_views.sql

INSERT INTO metrics.registered_processes (process_name, interval, is_active, description)
VALUES
    ('compliance_reports_daily',  86400,  TRUE, 'GRC Phase 2: Daily PCI-DSS and HIPAA PDF reports'),
    ('compliance_reports_weekly', 604800, TRUE, 'GRC Phase 2: Weekly GDPR and SOC2 PDF reports')
ON CONFLICT (process_name) DO UPDATE
    SET interval    = EXCLUDED.interval,
        is_active   = EXCLUDED.is_active,
        description = EXCLUDED.description;
