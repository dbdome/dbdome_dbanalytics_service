-- =============================================================================
-- 7620_gmmr_server_entry_index.sql
--
-- Index monitoring.general_metric_metadata_results on (server, entry_date DESC).
--
-- THE MEASUREMENT
--   The security agent's precedent lookup is
--       WHERE server = :s AND metric_metadata IS NOT NULL
--       ORDER BY entry_date DESC LIMIT 400
--   EXPLAIN ANALYZE on 2026-08-21 (server 192.168.1.229):
--       Execution Time: 2,823 ms WARM
--       -> gmmr_2026_06: Rows Removed by Filter: 678,529
--          Buffers: shared hit=413,382 read=174,975   (2,820 ms of the 2,823)
--   COLD, those 175k reads took ~50 minutes in an end-to-end test.
--
--   The plan is a Merge Append over all 26 partitions, each doing an Index Scan
--   Backward on entry_date and filtering by server. In any partition dominated
--   by other servers it must walk the whole partition backwards to discover
--   there are no rows for this one.
--
-- WHY THE EXISTING INDEXES DO NOT HELP
--   ix_gmmr_server_metric_date is (server, metric_name, entry_date DESC). With
--   no metric_name predicate the leading column matches but the sort cannot be
--   satisfied, so the planner falls back to the entry_date index and filters.
--   That widened lookup -- server only, no metric -- is precisely the path the
--   retriever takes when a metric-scoped search returns too few candidates.
--   ix_server is (server) alone and offers no ordering.
--
--   (server, entry_date DESC) lets each partition seek straight to that
--   server's newest rows and stop after LIMIT.
--
-- LOCKING
--   CREATE INDEX on a partitioned parent cannot be CONCURRENT in PostgreSQL, so
--   this takes a SHARE lock on each partition and blocks writes to gmmr while it
--   builds. Run it during a collection pause. On this database (1.47M rows,
--   26 partitions) expect single-digit minutes.
--
-- Idempotent.
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_gmmr_server_entry
    ON monitoring.general_metric_metadata_results (server, entry_date DESC);

COMMENT ON INDEX monitoring.ix_gmmr_server_entry IS
    'Serves "newest N rows for one server" -- the security agent precedent '
    'lookup. Without it a Merge Append filters entry_date scans by server and '
    'walks whole partitions (678k rows in gmmr_2026_06, ~50 min cold).';

-- Refresh statistics so the planner actually chooses it.
ANALYZE monitoring.general_metric_metadata_results;

DO $mig$
DECLARE
    v_idx int;
BEGIN
    SELECT count(*) INTO v_idx
      FROM pg_indexes
     WHERE schemaname = 'monitoring'
       AND indexname = 'ix_gmmr_server_entry';

    IF v_idx = 0 THEN
        RAISE EXCEPTION '7620: ix_gmmr_server_entry was not created';
    END IF;

    RAISE NOTICE '7620: ix_gmmr_server_entry present. Re-measure the agent''s '
                 'precedent query - it was 2,823ms warm / ~50min cold before this.';
END $mig$;
