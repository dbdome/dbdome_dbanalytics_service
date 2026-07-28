-- ============================================================
-- Retention low-free-space alert support.
--   * metrics.disk_total_bytes()  : total bytes of the data-directory disk
--   * metrics.disk_free_pct()     : free space as a percentage (free/total*100)
--   * config.global_params 'retention_free_space_alert_pct' : threshold (default 10)
--   * registers the 'retention_space_alert' scheduler process (daily)
--
-- The scheduler process (processes/retention_space_alert.py) emails recipients
-- AT MOST ONCE A DAY when disk_free_pct() < threshold (daily interval + a 24h
-- guard against duplicate mails). Disk size comes via file_fdw + PowerShell
-- (same mechanism as metrics.disk_free_bytes); guarded so it degrades to NULL
-- where file_fdw/PowerShell aren't available. Idempotent.
-- ============================================================

-- ---- total-disk source (file_fdw -> PowerShell Get-PSDrive) ----
DO $do$
BEGIN
    BEGIN
        CREATE EXTENSION IF NOT EXISTS file_fdw;
        IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'dbdome_os') THEN
            CREATE SERVER dbdome_os FOREIGN DATA WRAPPER file_fdw;
        END IF;
        DROP FOREIGN TABLE IF EXISTS metrics._disk_total;
        CREATE FOREIGN TABLE metrics._disk_total (total_bytes text) SERVER dbdome_os
            OPTIONS (program 'powershell -NoProfile -Command "[int64]((Get-PSDrive C).Used + (Get-PSDrive C).Free)"', format 'csv');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'retention: disk-total source unavailable (%) -- disk_free_pct will be NULL', SQLERRM;
    END;
END $do$;

CREATE OR REPLACE FUNCTION metrics.disk_total_bytes()
RETURNS bigint LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE v bigint;
BEGIN
    IF to_regclass('metrics._disk_total') IS NULL THEN
        RETURN NULL;
    END IF;
    BEGIN
        SELECT total_bytes::bigint INTO v FROM metrics._disk_total LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        v := NULL;
    END;
    RETURN v;
END $$;

-- free space as a percentage of total (NULL when disk size is unavailable)
CREATE OR REPLACE FUNCTION metrics.disk_free_pct()
RETURNS numeric LANGUAGE sql STABLE AS $$
    SELECT CASE
        WHEN COALESCE(metrics.disk_total_bytes(), 0) > 0
        THEN round(metrics.disk_free_bytes()::numeric * 100.0 / metrics.disk_total_bytes(), 2)
        ELSE NULL
    END;
$$;

-- ---- threshold (percent) ----
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'retention_free_space_alert_pct') THEN
        INSERT INTO config.global_params (key, value) VALUES ('retention_free_space_alert_pct', '10');
    END IF;
END $do$;

-- ---- register the scheduler process (daily; mail at most once a day) ----
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'retention_space_alert', true, 86400,
       'Daily email alert when free disk space < retention_free_space_alert_pct (default 10%)'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.registered_processes WHERE process_name = 'retention_space_alert');
