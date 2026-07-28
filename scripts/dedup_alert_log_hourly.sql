-- =============================================================================
-- Collapse alerts.alert_log to ONE record per (server, root_cause_id, hour):
-- keep the most recent row in each hour bucket, delete the rest.
--
-- Same shape the collector now enforces at insert time (delete-then-insert);
-- this cleans the existing backlog. Idempotent: once deduped, re-running deletes
-- nothing. Deletes via the row_id PK, so it's exact.
-- =============================================================================

WITH ranked AS (
    SELECT row_id,
           row_number() OVER (
               PARTITION BY server, root_cause_id, date_trunc('hour', entry_date)
               ORDER BY entry_date DESC, row_id DESC      -- keep the latest in each hour
           ) AS rn
    FROM alerts.alert_log
)
DELETE FROM alerts.alert_log a
USING ranked r
WHERE a.row_id = r.row_id
  AND r.rn > 1;

-- Space is reclaimed by autovacuum; to reclaim immediately run separately
-- (VACUUM cannot run inside a transaction / psql -1):
--   VACUUM (ANALYZE) alerts.alert_log;
