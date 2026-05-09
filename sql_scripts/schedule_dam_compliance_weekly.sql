-- ============================================================
-- Schedule "DAM Compliance Report" (report_id 18) once per week.
-- Sends via the existing scheduler to every active mail_group
-- attached to the primary SMTP config (mail_config_id = 1).
--
-- Default send slot: every Monday 06:00 (server local time).
-- Adjust the two literals below to move it to a different time.
-- ============================================================

-- Parameters -------------------------------------------------
DO $$
DECLARE
    v_report_id   int  := 18;                       -- DAM Compliance Report
    v_occurance   text := 'weekly';
    v_occurs_at   time := '06:00:00';
    v_day_of_week int  := 1;                        -- 1 = Monday (ISO)
    v_job_id      int;
    v_next_run    timestamp;
BEGIN
    -- 1. Find (or create) the weekly-06:00 job template
    SELECT row_id INTO v_job_id
      FROM jobs.jobs
     WHERE occurance = v_occurance
       AND occurs_at = v_occurs_at
     LIMIT 1;

    IF v_job_id IS NULL THEN
        INSERT INTO jobs.jobs (schedule_type, occurance, occurs_at)
        VALUES (1, v_occurance, v_occurs_at)
        RETURNING row_id INTO v_job_id;
        RAISE NOTICE 'Created jobs.jobs row_id=%', v_job_id;
    ELSE
        RAISE NOTICE 'Reusing jobs.jobs row_id=%', v_job_id;
    END IF;

    -- 2. Link the report to the job (upsert into config.reports_jobs)
    IF EXISTS (SELECT 1 FROM config.reports_jobs WHERE report_id = v_report_id) THEN
        UPDATE config.reports_jobs
           SET job_id = v_job_id
         WHERE report_id = v_report_id;
        RAISE NOTICE 'Updated config.reports_jobs for report %', v_report_id;
    ELSE
        INSERT INTO config.reports_jobs (report_id, job_id)
        VALUES (v_report_id, v_job_id);
        RAISE NOTICE 'Inserted config.reports_jobs for report %', v_report_id;
    END IF;

    -- 3. Make sure the report is active
    UPDATE config.reports
       SET is_active = true
     WHERE row_id = v_report_id;

    -- 4. Seed jobs.job_schedules with the first run = next occurrence of
    --    day_of_week at occurs_at. If already present, just refresh next_run.
    v_next_run :=
        date_trunc('day', CURRENT_TIMESTAMP)
        + make_interval(days => ((v_day_of_week - EXTRACT(isodow FROM CURRENT_TIMESTAMP)::int + 7) % 7))
        + v_occurs_at;

    -- If that's already in the past today, bump by a week.
    IF v_next_run <= CURRENT_TIMESTAMP THEN
        v_next_run := v_next_run + INTERVAL '7 days';
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

-- Verify -----------------------------------------------------
SELECT r.row_id, r.report_name, r.is_active,
       j.occurance, j.occurs_at,
       js.next_run,
       string_agg(mg.group_name, ', ' ORDER BY mg.row_id) AS mail_groups,
       string_agg(mg.recipients, '; ' ORDER BY mg.row_id) AS all_recipients
  FROM config.reports r
  JOIN config.reports_jobs rj ON rj.report_id = r.row_id
  JOIN jobs.jobs          j  ON j.row_id      = rj.job_id
  JOIN jobs.job_schedules js ON js.report_id  = r.row_id
  LEFT JOIN config.mail_groups mg
         ON mg.mail_config_id = 1 AND mg.is_active = true
 WHERE r.row_id = 18
 GROUP BY r.row_id, r.report_name, r.is_active, j.occurance, j.occurs_at, js.next_run;
