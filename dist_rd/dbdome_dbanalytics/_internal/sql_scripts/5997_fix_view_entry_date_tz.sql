-- ============================================================
-- Fix the 3-hour Grafana offset on view entry_date columns.
--
-- entry_date is stored as a NAIVE `timestamp` holding Asia/Jerusalem wall-clock.
-- Grafana ($__timeFrom is UTC) then reads it 3h ahead. This converts each view's
-- entry_date to a real timestamptz with `AT TIME ZONE 'Asia/Jerusalem'`, which
-- reinterprets the naive local value as the correct UTC instant.
--
-- Method: wrap the original view as a subquery and re-project its columns in
-- order, replacing only entry_date. This is robust (no parsing of the inner SQL)
-- and preserves column order/names.
--
-- Scope: only views whose entry_date is naive `timestamp without time zone` AND
-- that have NO view/matview dependents. Converting changes the column type
-- (timestamp -> timestamptz), which needs DROP+CREATE; dependents would block the
-- DROP, and the dependent set here is a UNION/matview cluster
-- (v_all_active_transactions, v_combined_transactions,
-- v_high_number_blocking_transactions, v_schema's matviews) where mixing
-- timestamptz/timestamp branches would break UNION type-consistency. Those are
-- handled separately.
--
-- Idempotent: once converted, entry_date is timestamptz, so the type filter
-- excludes the view on a re-run.
-- ============================================================
DO $do$
DECLARE
    r       record;
    cols    text;
    origdef text;
    n       int := 0;
BEGIN
    FOR r IN
        SELECT c.oid, c.relname
        FROM pg_class c
        JOIN pg_namespace nsp ON nsp.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'entry_date'
                           AND NOT a.attisdropped
        WHERE c.relkind = 'v'
          AND nsp.nspname = 'monitoring'
          AND format_type(a.atttypid, a.atttypmod) = 'timestamp without time zone'
          AND NOT EXISTS (
              SELECT 1 FROM pg_depend d
              JOIN pg_rewrite rw ON rw.oid = d.objid
              JOIN pg_class dc ON dc.oid = rw.ev_class
              WHERE d.refobjid = c.oid AND dc.oid <> c.oid AND dc.relkind IN ('v','m'))
    LOOP
        SELECT string_agg(
                 CASE WHEN att.attname = 'entry_date'
                      THEN '(_o.entry_date AT TIME ZONE ''Asia/Jerusalem'') AS entry_date'
                      ELSE format('_o.%I', att.attname) END,
                 ', ' ORDER BY att.attnum)
          INTO cols
          FROM pg_attribute att
          WHERE att.attrelid = r.oid AND att.attnum > 0 AND NOT att.attisdropped;

        origdef := regexp_replace(pg_get_viewdef(r.oid, true), ';\s*$', '');
        EXECUTE format('DROP VIEW monitoring.%I', r.relname);
        EXECUTE format('CREATE VIEW monitoring.%I AS SELECT %s FROM (%s) _o',
                       r.relname, cols, origdef);
        n := n + 1;
    END LOOP;
    RAISE NOTICE 'converted entry_date -> timestamptz on % view(s)', n;
END $do$;
