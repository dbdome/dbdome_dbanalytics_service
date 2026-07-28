-- =============================================================================
-- One-off cleanup: collapse duplicate rows in
-- monitoring.general_metric_metadata_results that carry identical metric_metadata
-- for the same (server, metric_name). Keeps the NEWEST row (max id) per identical
-- snapshot and deletes the older copies.
--
-- Cause: the historical O(K^2) per-metric re-insert bug (now fixed) plus repeated
-- collection of config metrics whose metadata never changes.
--
-- Idempotent: after running, no duplicate (server, metric_name, metadata) group
-- remains, so a second run deletes nothing.
--
-- One-off — keep this in scripts/ (run by hand), NOT in sql_scripts/, so the
-- runner doesn't re-scan the whole table every cycle.
-- =============================================================================

WITH ranked AS (
    SELECT entry_date, id,
           row_number() OVER (
               PARTITION BY server, metric_name, md5(coalesce(metric_metadata::text, ''))
               ORDER BY id DESC                       -- keep the latest copy
           ) AS rn
    FROM monitoring.general_metric_metadata_results
)
DELETE FROM monitoring.general_metric_metadata_results g
USING ranked r
WHERE g.entry_date = r.entry_date
  AND g.id = r.id
  AND r.rn > 1;

-- Space is reclaimed by autovacuum; to reclaim immediately run separately
-- (VACUUM cannot run inside a transaction / psql -1):
--   VACUUM (ANALYZE) monitoring.general_metric_metadata_results;
