-- =============================================================================
-- Fix all sequences after data-only dump restore
-- =============================================================================
-- Sets each sequence to MAX(id) + 1 of its owning column,
-- so new inserts get IDs higher than any existing row.
--
-- Run on: dbanalytics (port 5444) after restoring a data-only dump
-- =============================================================================

DO $$
DECLARE
    r RECORD;
    max_val BIGINT;
    seq_val BIGINT;
    fixed INT := 0;
    skipped INT := 0;
BEGIN
    RAISE NOTICE 'Fixing sequences after data restore...';
    RAISE NOTICE '';

    FOR r IN
        SELECT
            n.nspname AS schema_name,
            c.relname AS seq_name,
            t.relname AS table_name,
            tn.nspname AS table_schema,
            a.attname AS column_name,
            n.nspname || '.' || c.relname AS seq_full,
            tn.nspname || '.' || t.relname AS table_full
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_depend d ON d.objid = c.oid AND d.deptype = 'a'
        JOIN pg_class t ON t.oid = d.refobjid
        JOIN pg_namespace tn ON tn.oid = t.relnamespace
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
        WHERE c.relkind = 'S'
          AND n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
        ORDER BY n.nspname, c.relname
    LOOP
        BEGIN
            -- Get max value from the table column
            EXECUTE format('SELECT COALESCE(MAX(%I), 0) FROM %s', r.column_name, r.table_full) INTO max_val;

            -- Get current sequence value
            EXECUTE format('SELECT last_value FROM %s', r.seq_full) INTO seq_val;

            IF max_val > 0 AND (seq_val IS NULL OR max_val >= seq_val) THEN
                EXECUTE format('SELECT setval(%L, %s)', r.seq_full, max_val);
                RAISE NOTICE '  FIXED: % -> % (was %, table max = %)', r.seq_full, max_val, COALESCE(seq_val::text, 'NULL'), max_val;
                fixed := fixed + 1;
            ELSE
                skipped := skipped + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '  SKIP: % — %', r.seq_full, SQLERRM;
            skipped := skipped + 1;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE 'Done: % sequences fixed, % skipped (already correct or empty)', fixed, skipped;
END;
$$;

-- Verify: show all sequences and their current values vs table max
SELECT
    n.nspname || '.' || c.relname AS sequence_name,
    pg_sequences.last_value AS seq_current,
    tn.nspname || '.' || t.relname AS table_name,
    a.attname AS column_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_sequences ON pg_sequences.schemaname = n.nspname AND pg_sequences.sequencename = c.relname
JOIN pg_depend d ON d.objid = c.oid AND d.deptype = 'a'
JOIN pg_class t ON t.oid = d.refobjid
JOIN pg_namespace tn ON tn.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
WHERE c.relkind = 'S'
  AND n.nspname NOT IN ('information_schema', 'pg_catalog', 'sys')
ORDER BY n.nspname, c.relname;
