-- ============================================================
-- Repoint EVERY remaining view off the stale pre-partition backup table
-- general_metric_metadata_results_old onto the live partitioned table
-- general_metric_metadata_results, then drop the backup.
--
-- Covers all view families (v_sec_*, v_perf_*, v_hlth_*, and standalone views).
-- Verified beforehand that no matviews, functions, or other non-view objects
-- reference _old, so once the views are repointed nothing depends on the backup
-- and it can be dropped.
--
-- CREATE OR REPLACE preserves each view's columns (only the FROM source
-- changes). Idempotent: a re-run repoints nothing and the table is already gone.
-- ============================================================

-- 1) Repoint all views (any schema) off _old.
DO $do$
DECLARE
    r      record;
    newdef text;
    n      int := 0;
BEGIN
    FOR r IN
        SELECT c.oid, ns.nspname, c.relname
        FROM pg_class c
        JOIN pg_namespace ns ON ns.oid = c.relnamespace
        WHERE c.relkind = 'v'
          AND pg_get_viewdef(c.oid) ILIKE '%general_metric_metadata_results_old%'
    LOOP
        newdef := replace(pg_get_viewdef(r.oid, true),
                          'general_metric_metadata_results_old',
                          'general_metric_metadata_results');
        EXECUTE format('CREATE OR REPLACE VIEW %I.%I AS %s', r.nspname, r.relname, newdef);
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'repointed % view(s) off general_metric_metadata_results_old', n;
END $do$;

-- 2) Drop the backup table once nothing references it.
DO $do$
DECLARE
    remaining int;
BEGIN
    SELECT count(*) INTO remaining
    FROM pg_class c
    WHERE c.relkind IN ('v', 'm')
      AND pg_get_viewdef(c.oid) ILIKE '%general_metric_metadata_results_old%';

    IF remaining = 0 THEN
        DROP TABLE IF EXISTS monitoring.general_metric_metadata_results_old;
        RAISE NOTICE 'dropped monitoring.general_metric_metadata_results_old';
    ELSE
        RAISE NOTICE 'NOT dropping _old: % view(s) still reference it', remaining;
    END IF;
END $do$;
