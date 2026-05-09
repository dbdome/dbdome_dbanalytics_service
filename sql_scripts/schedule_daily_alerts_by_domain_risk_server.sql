-- =============================================================================
-- Register + schedule the "Daily Alert Summary" report.
--
-- Wires four tables together so monitoring.v_job_scheduler picks the report
-- up automatically (job_next_run() polls that view):
--
--   1. config.reports          -- defines the report (name, JSON template path)
--   2. jobs.jobs               -- defines a daily-07:00 schedule slot
--   3. config.reports_jobs     -- links the report to that schedule
--   4. jobs.job_schedules      -- holds the next_run timestamp
--
-- Default send slot: every day at 07:00 server local time. Adjust the two
-- literals below to move it. Recipients come from config.mail_groups attached
-- to the primary SMTP config (mail_config_id = 1) -- the same convention used
-- by schedule_dam_compliance_weekly.sql.
--
-- Idempotent: re-running this script finds existing rows and refreshes
-- next_run / job_id / is_active rather than creating duplicates.
--
-- HOW TO RUN:
--     psql -h localhost -p 5444 -U dbdome_adm -d dbanalytics \
--          -f schedule_daily_alerts_by_domain_risk_server.sql
-- =============================================================================

DO $$
DECLARE
    v_report_name text := 'Daily Alert Summary - by Domain, Risk, Server, Root Cause';
    v_report_url  text := 'templates/report_daily_alerts_by_domain_risk_server.json';
    v_report_query text := 'JSON-based report - see report_url for template';
    v_occurance   text := 'daily';
    v_occurs_at   time := '07:00:00';
    v_schedule_type int := 1;          -- 1 = recurring (daily/hourly/weekly/monthly)
    v_report_id   int;
    v_job_id      int;
    v_next_run    timestamp;
BEGIN
    -- 1. Find or create the config.reports row for this template.
    SELECT row_id
      INTO v_report_id
      FROM config.reports
     WHERE report_name = v_report_name
     LIMIT 1;

    IF v_report_id IS NULL THEN
        INSERT INTO config.reports (report_name, report_query, is_active, report_url)
        VALUES (v_report_name, v_report_query, true, v_report_url)
        RETURNING row_id INTO v_report_id;
        RAISE NOTICE 'Created config.reports row_id=%', v_report_id;
    ELSE
        UPDATE config.reports
           SET report_url = v_report_url,
               is_active  = true
         WHERE row_id = v_report_id;
        RAISE NOTICE 'Reusing config.reports row_id=%', v_report_id;
    END IF;

    -- 2. Find or create the daily-07:00 job slot in jobs.jobs.
    SELECT row_id
      INTO v_job_id
      FROM jobs.jobs
     WHERE occurance = v_occurance
       AND occurs_at = v_occurs_at
     LIMIT 1;

    IF v_job_id IS NULL THEN
        INSERT INTO jobs.jobs (schedule_type, occurance, occurs_at)
        VALUES (v_schedule_type, v_occurance, v_occurs_at)
        RETURNING row_id INTO v_job_id;
        RAISE NOTICE 'Created jobs.jobs row_id=%', v_job_id;
    ELSE
        RAISE NOTICE 'Reusing jobs.jobs row_id=%', v_job_id;
    END IF;

    -- 3. Link report <-> job (upsert).
    IF EXISTS (SELECT 1 FROM config.reports_jobs WHERE report_id = v_report_id) THEN
        UPDATE config.reports_jobs
           SET job_id = v_job_id
         WHERE report_id = v_report_id;
    ELSE
        INSERT INTO config.reports_jobs (report_id, job_id)
        VALUES (v_report_id, v_job_id);
    END IF;

    -- 4. Compute the first run: today at 07:00, or tomorrow if 07:00 is past.
    v_next_run := date_trunc('day', CURRENT_TIMESTAMP) + v_occurs_at;
    IF v_next_run <= CURRENT_TIMESTAMP THEN
        v_next_run := v_next_run + INTERVAL '1 day';
    END IF;

    IF EXISTS (SELECT 1 FROM jobs.job_schedules WHERE report_id = v_report_id) THEN
        UPDATE jobs.job_schedules
           SET schedule_id = v_job_id,
               next_run    = v_next_run
         WHERE report_id = v_report_id;
        RAISE NOTICE 'Updated jobs.job_schedules next_run=%', v_next_run;
    ELSE
        INSERT INTO jobs.job_schedules (report_id, schedule_id, next_run)
        VALUES (v_report_id, v_job_id, v_next_run);
        RAISE NOTICE 'Inserted jobs.job_schedules next_run=%', v_next_run;
    END IF;
END $$;

-- =============================================================================
-- VERIFY
-- =============================================================================
SELECT r.row_id        AS report_id,
       r.report_name,
       r.is_active,
       r.report_url,
       j.occurance,
       j.occurs_at,
       js.next_run,
       string_agg(mg.group_name, ', ' ORDER BY mg.row_id)  AS mail_groups,
       string_agg(mg.recipients, '; ' ORDER BY mg.row_id)  AS all_recipients
  FROM config.reports         r
  JOIN config.reports_jobs    rj ON rj.report_id = r.row_id
  JOIN jobs.jobs              j  ON j.row_id     = rj.job_id
  JOIN jobs.job_schedules     js ON js.report_id = r.row_id
  LEFT JOIN config.mail_groups mg
         ON mg.mail_config_id = 1 AND mg.is_active = true
 WHERE r.report_name = 'Daily Alert Summary - by Domain, Risk, Server, Root Cause'
 GROUP BY r.row_id, r.report_name, r.is_active, r.report_url,
          j.occurance, j.occurs_at, js.next_run;
