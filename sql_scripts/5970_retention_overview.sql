-- 5970: retention overview reporting function.
-- metrics.retention_overview() returns one row per item:
--   * the pg_default tablespace total (data size in the tablespace's disk)
--   * alerts.alert_log         (data size + row count)
--   * alerts.mail_alert_log    (data size + row count)
--   * one row per metric_name in monitoring.general_metric_metadata_results
--     (total data size + row count for that metric)
-- plus a space_free column = free space on the data-directory disk.
--
-- Disk free is read via file_fdw + PowerShell (best-effort). The whole disk-free
-- setup is guarded so this migration still succeeds where file_fdw / PowerShell
-- aren't available (space_free is reported as 'n/a' in that case).

-- ---- disk free source (file_fdw -> PowerShell Get-PSDrive) ----
DO $do$
BEGIN
    BEGIN
        CREATE EXTENSION IF NOT EXISTS file_fdw;
        IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'dbdome_os') THEN
            CREATE SERVER dbdome_os FOREIGN DATA WRAPPER file_fdw;
        END IF;
        DROP FOREIGN TABLE IF EXISTS metrics._disk_free;
        CREATE FOREIGN TABLE metrics._disk_free (free_bytes text) SERVER dbdome_os
            OPTIONS (program 'powershell -NoProfile -Command "[int64]((Get-PSDrive C).Free)"', format 'csv');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'retention: disk-free source unavailable (%) -- space_free will be n/a', SQLERRM;
    END;
END $do$;

CREATE OR REPLACE FUNCTION metrics.disk_free_bytes()
RETURNS bigint LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE v bigint;
BEGIN
    IF to_regclass('metrics._disk_free') IS NULL THEN
        RETURN NULL;
    END IF;
    BEGIN
        SELECT free_bytes::bigint INTO v FROM metrics._disk_free LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        v := NULL;
    END;
    RETURN v;
END $$;

-- ---- the retention overview report ----
CREATE OR REPLACE FUNCTION metrics.retention_overview()
RETURNS TABLE(category text, item text, data_size text, data_bytes bigint, row_count bigint, space_free text)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_free_txt text := COALESCE(pg_size_pretty(metrics.disk_free_bytes()), 'n/a');
BEGIN
    RETURN QUERY SELECT 'TABLESPACE'::text,
        ('pg_default (' || current_setting('data_directory') || ')')::text,
        pg_size_pretty(pg_tablespace_size('pg_default')),
        pg_tablespace_size('pg_default')::bigint,
        NULL::bigint,
        v_free_txt;

    RETURN QUERY SELECT 'TABLE'::text, 'alerts.alert_log'::text,
        pg_size_pretty(pg_total_relation_size('alerts.alert_log')),
        pg_total_relation_size('alerts.alert_log')::bigint,
        (SELECT count(*) FROM alerts.alert_log),
        v_free_txt;

    RETURN QUERY SELECT 'TABLE'::text, 'alerts.mail_alert_log'::text,
        pg_size_pretty(pg_total_relation_size('alerts.mail_alert_log')),
        pg_total_relation_size('alerts.mail_alert_log')::bigint,
        (SELECT count(*) FROM alerts.mail_alert_log),
        v_free_txt;

    -- Per-metric size is ESTIMATED: exact row count x average row bytes.
    -- The old exact form summed pg_column_size(t.*) over ALL ~2.5M rows, deforming
    -- every (jsonb-bearing) tuple - 60s+ and unusable for a dashboard. There are
    -- ~600+ distinct metrics, so a per-metric sample would do one 26-partition
    -- merge PER metric. Instead we take ONE bounded sample (newest 50k rows) and
    -- average pg_column_size per metric from it; metrics absent from the sample
    -- (rare/dormant - negligible footprint) fall back to the global average.
    -- count(*) per metric is cheap via ix_gmmr_metric_date. Runs in ~3s.
    RETURN QUERY
        WITH sample AS (
            SELECT s.metric_name, avg(pg_column_size(s.*))::numeric AS avg_bytes
            FROM (SELECT * FROM monitoring.general_metric_metadata_results
                  ORDER BY entry_date DESC
                  LIMIT 50000) s
            GROUP BY s.metric_name
        ),
        cnt AS (
            SELECT t.metric_name, count(*) AS row_cnt
            FROM monitoring.general_metric_metadata_results t
            GROUP BY t.metric_name
        ),
        g AS (SELECT avg(avg_bytes) AS global_avg FROM sample)
        SELECT 'METRIC'::text, c.metric_name::text,
               pg_size_pretty((COALESCE(sm.avg_bytes, g.global_avg, 0) * c.row_cnt)::bigint),
               (COALESCE(sm.avg_bytes, g.global_avg, 0) * c.row_cnt)::bigint,
               c.row_cnt,
               v_free_txt
        FROM cnt c
        LEFT JOIN sample sm ON sm.metric_name = c.metric_name
        CROSS JOIN g
        ORDER BY (COALESCE(sm.avg_bytes, g.global_avg, 0) * c.row_cnt) DESC;
END $$;
