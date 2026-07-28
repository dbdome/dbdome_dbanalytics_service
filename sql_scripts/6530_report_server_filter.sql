-- =============================================================================
-- 6530_report_server_filter.sql
-- Per-server report filtering for scheduled reports (/report_schedule).
--
-- 1) config.reports.server_name — optional server the report is filtered to
--    (NULL/'' = all servers). Set from the Server dropdown on /report_schedule.
-- 2) monitoring.v_job_scheduler — expose server_name (appended as the LAST
--    column so CREATE OR REPLACE VIEW is accepted) for jobs/job_handler.py,
--    which substitutes the {server} placeholder into report queries and tags
--    the emailed report with the server name.
-- =============================================================================

ALTER TABLE config.reports ADD COLUMN IF NOT EXISTS server_name text;

CREATE OR REPLACE VIEW monitoring.v_job_scheduler AS
 SELECT report_id,
    job_id,
    next_run,
    last_run,
    report_name,
    report_query,
    occurance,
    occurs_at,
    schedule_type,
    recipients,
    smtp_password,
    smtp_port,
    smtp_server,
    smtp_user,
    tls,
    mail_sender,
    alert_id,
    alert_name,
    alert_query,
    value_start,
    value_end,
    replace(report_url, '${global_ip}'::text, COALESCE(( SELECT global_params.value
           FROM config.global_params
          WHERE global_params.key = 'local_ip'::text), ''::text)) AS report_url,
    server_name
   FROM ( SELECT r.report_id,
            r.alert_id,
            r.alert_name,
            r.alert_query,
            j.row_id AS job_id,
            r.report_name,
            r.report_query,
            j.occurance,
            j.occurs_at,
            j.schedule_type,
            ( SELECT string_agg(DISTINCT TRIM(BOTH FROM rcpt.rcpt), ','::text ORDER BY (TRIM(BOTH FROM rcpt.rcpt))) AS string_agg
                   FROM config.mail_groups mg
                     CROSS JOIN LATERAL regexp_split_to_table(mg.recipients, '[,;\s]+'::text) rcpt(rcpt)
                  WHERE mg.mail_config_id = mc.row_id AND mg.is_active = true AND length(TRIM(BOTH FROM rcpt.rcpt)) > 0) AS recipients,
            mc.smtp_password,
            mc.smtp_port,
            mc.smtp_server,
            mc.smtp_user,
            mc.tls,
            mc.mail_sender,
            js.next_run,
            js.last_run,
            r.value_start,
            r.value_end,
            r.report_url,
            r.server_name
           FROM ( SELECT r_1.row_id AS report_id,
                    r_1.report_name,
                    r_1.report_query,
                    a_1.row_id AS alert_id,
                    a_1.alert_name,
                    a_1.alert_query,
                    a_1.value_start,
                    a_1.value_end,
                    r_1.report_url,
                    r_1.server_name
                   FROM config.reports r_1
                     LEFT JOIN config.alerts_reports ar ON ar.report_id = r_1.row_id
                     LEFT JOIN ( SELECT a_2.row_id,
                            a_2.alert_name,
                            a_2.alert_query,
                            a_2.entry_date,
                            t.value_start,
                            t.value_end
                           FROM config.alerts a_2
                             JOIN config.alerts_thresholds ta ON ta.alert_id = a_2.row_id
                             JOIN config.thresholds t ON t.row_id = ta.threshold_id) a_1 ON a_1.row_id = ar.alert_id) r
             JOIN config.reports_jobs rj ON rj.report_id = r.report_id
             JOIN jobs.jobs j ON j.row_id = rj.job_id
             JOIN config.mail_jobs mj ON mj.job_id = rj.job_id
             JOIN config.mail_config mc ON mc.row_id = mj.mail_id
             LEFT JOIN jobs.job_schedules js ON js.report_id = r.report_id AND js.schedule_id = j.row_id) a
  WHERE COALESCE(next_run, now()::timestamp without time zone) <= now() AND last_run IS NULL;

ALTER VIEW monitoring.v_job_scheduler OWNER TO dbdome_adm;
