-- =============================================================================
-- 6080_t_retention_overview_cache.sql
-- Cache table for the retention-overview dashboard.
--
-- metrics.retention_overview() samples ~2.5M rows and takes several seconds, too
-- slow for a live panel. The 'retention' scheduler job (dbdome_main, every 60s)
-- refreshes metrics.t_retention_overview from the function; the panel reads this
-- precomputed table instantly. Created empty here so the panel never errors
-- before the first refresh on a fresh install (the job recreates it with data).
-- Idempotent.
-- =============================================================================
CREATE TABLE IF NOT EXISTS metrics.t_retention_overview (
    category   text,
    item       text,
    data_size  text,
    data_bytes bigint,
    row_count  bigint,
    space_free text
);
