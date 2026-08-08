-- =============================================================================
-- 7480_mongodb_vendor_support.sql
-- Register MongoDB as a monitored vendor, the same way 7260 registered ClickHouse:
--   * rootcause.vendors row (slug 'mongodb', database_type 'DOC')
--   * metrics.routines row so upsert_monitored_server links a server whose
--     db_vendor='mongodb' to the generic collector
--     collect_all_metrics_mongodb_queries
--       (upsert_monitored_server matches metrics.routines.db_version =
--        lower(server.db_vendor); collect_metrics.py dispatches on routine_name)
--
-- The DOC detection catalogue itself ships in 7450_mongodb_doc_detections.sql;
-- this script only makes the collector reachable. Until a mongodb server is
-- registered the collector never runs.
--
-- NOTE on connection fields: the target's service_name carries the MongoDB
-- **authSource**. Mongo users are scoped to the database they were created in -
-- normally `admin`, not the monitored database - and getting it wrong surfaces as
-- "Authentication failed" against a correct password.
--
-- Idempotent.
-- =============================================================================

INSERT INTO rootcause.vendors (slug, name, database_type_code)
VALUES ('mongodb', 'MongoDB', 'DOC')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name,
                                 database_type_code = EXCLUDED.database_type_code;

INSERT INTO metrics.routines (routine_name, is_active, db_version)
SELECT 'collect_all_metrics_mongodb_queries', true, 'mongodb'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.routines
    WHERE routine_name = 'collect_all_metrics_mongodb_queries'
      AND lower(db_version) = 'mongodb'
);

-- Keep it active if it already existed.
UPDATE metrics.routines SET is_active = true
WHERE routine_name = 'collect_all_metrics_mongodb_queries'
  AND lower(db_version) = 'mongodb';
