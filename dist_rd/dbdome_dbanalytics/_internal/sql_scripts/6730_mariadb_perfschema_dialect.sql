-- =============================================================================
-- 6730_mariadb_perfschema_dialect.sql
--
-- The mariadb-vendor detection steps were cloned from the mysql ones, but
-- MariaDB never moved server status/variables into performance_schema (that
-- was MySQL 5.7+): performance_schema.global_variables / global_status /
-- session_status DO NOT EXIST in MariaDB (error 1146), so ~570 mariadb
-- detections failed on any real MariaDB target.
--
-- MariaDB serves the same data, same VARIABLE_NAME/VARIABLE_VALUE columns,
-- from information_schema  ->  clean textual swap for vendor_slug='mariadb'
-- (applies to rootcause.detection_steps content and any mariadb rows in
-- metrics.custom_metrics).
--
-- NOT fixed here (MySQL-only features with no MariaDB equivalent table;
-- these steps fail gracefully per-metric and need real rewrites):
--   performance_schema.replication_* (122 steps; MariaDB uses SHOW SLAVE
--   STATUS), variables_by_thread (4), status_by_thread (5),
--   persisted_variables (8, MySQL SET PERSIST).
-- Idempotent.
-- =============================================================================

DO $$
DECLARE n int;
BEGIN
    UPDATE rootcause.detection_steps
    SET content = regexp_replace(
                    regexp_replace(
                      regexp_replace(content::text,
                        'performance_schema\.global_variables',  'information_schema.global_variables', 'gi'),
                      'performance_schema\.global_status',       'information_schema.global_status',    'gi'),
                    'performance_schema\.session_status',        'information_schema.session_status',   'gi')::json
    WHERE vendor_slug = 'mariadb'
      AND (content::text ILIKE '%performance_schema.global_variables%'
        OR content::text ILIKE '%performance_schema.global_status%'
        OR content::text ILIKE '%performance_schema.session_status%');
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE NOTICE '6730: rewrote perf-schema refs in % mariadb detection_steps', n;

    UPDATE metrics.custom_metrics
    SET query = regexp_replace(
                  regexp_replace(
                    regexp_replace(query,
                      'performance_schema\.global_variables',  'information_schema.global_variables', 'gi'),
                    'performance_schema\.global_status',       'information_schema.global_status',    'gi'),
                  'performance_schema\.session_status',        'information_schema.session_status',   'gi')
    WHERE lower(db_vendor) = 'mariadb'
      AND (query ILIKE '%performance_schema.global_variables%'
        OR query ILIKE '%performance_schema.global_status%'
        OR query ILIKE '%performance_schema.session_status%');
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE NOTICE '6730: rewrote perf-schema refs in % mariadb custom_metrics', n;
END $$;
