-- =============================================================================
-- 7260_clickhouse_vendor_support.sql
-- Register ClickHouse as a monitored vendor:
--   * rootcause.vendors row (slug 'clickhouse', database_type 'SQL')
--   * metrics.routines row so upsert_monitored_server links a server whose
--     db_vendor='clickhouse' to the generic collector
--     collect_all_metrics_clickhouse_queries
--       (upsert_monitored_server matches metrics.routines.db_version =
--        lower(server.db_vendor); collect_metrics.py dispatches on routine_name)
-- Idempotent. Detection-step catalog for clickhouse is populated separately;
-- until then the collector runs and simply finds no metrics.
-- =============================================================================

INSERT INTO rootcause.vendors (slug, name, database_type_code)
VALUES ('clickhouse', 'ClickHouse', 'SQL')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, database_type_code = EXCLUDED.database_type_code;

INSERT INTO metrics.routines (routine_name, is_active, db_version)
SELECT 'collect_all_metrics_clickhouse_queries', true, 'clickhouse'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.routines
    WHERE routine_name = 'collect_all_metrics_clickhouse_queries'
      AND lower(db_version) = 'clickhouse'
);

-- Keep it active if it already existed.
UPDATE metrics.routines SET is_active = true
WHERE routine_name = 'collect_all_metrics_clickhouse_queries' AND lower(db_version) = 'clickhouse';
