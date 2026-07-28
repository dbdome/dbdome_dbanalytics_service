-- =============================================================================
-- 7320_fix_gmmr_partition_attach.sql
--
-- Heal installs where the gmmr partitions exist as STANDALONE tables.
--
-- Root cause: gen_install_tables.py ignored pg_dump's "TABLE ATTACH" blocks,
-- so base_install created monitoring.gmmr_YYYY_MM / monitoring.gmmr_default as
-- plain tables never attached to monitoring.general_metric_metadata_results.
-- On such installs every collector INSERT fails with
--   "no partition of relation general_metric_metadata_results found for row"
-- and monitoring.gmmr_maintain() cannot self-heal: its
-- CREATE TABLE IF NOT EXISTS ... PARTITION OF silently no-ops because a table
-- with that name already exists (detached).
--
-- This script, idempotently:
--   1) ATTACHes every detached gmmr_YYYY_MM as its month's range partition
--      (rescuing any rows a detached table may somehow hold — none expected);
--   2) ATTACHes a detached gmmr_default as the DEFAULT partition;
--   3) creates any missing partitions from the current month 12 months ahead.
--
-- Safe on healthy catalogs (everything already attached -> no-op).
-- =============================================================================
DO $$
DECLARE
    r      record;
    lo     date;
    m      date;
    pname  text;
BEGIN
    IF to_regclass('monitoring.general_metric_metadata_results') IS NULL THEN
        RAISE NOTICE '7320: parent table missing - skipping';
        RETURN;
    END IF;

    -- 1) attach detached monthly partitions
    FOR r IN
        SELECT c.relname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring'
          AND c.relname ~ '^gmmr_[0-9]{4}_[0-9]{2}$'
          AND c.relkind = 'r'
          AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
        ORDER BY c.relname
    LOOP
        lo := to_date(substring(r.relname FROM 'gmmr_([0-9]{4}_[0-9]{2})'), 'YYYY_MM');
        EXECUTE format(
            'ALTER TABLE monitoring.general_metric_metadata_results '
            'ATTACH PARTITION monitoring.%I FOR VALUES FROM (%L) TO (%L)',
            r.relname, lo, (lo + interval '1 month')::date);
        RAISE NOTICE '7320: attached % as partition [% .. %)', r.relname, lo,
                     (lo + interval '1 month')::date;
    END LOOP;

    -- 2) attach a detached default partition
    IF to_regclass('monitoring.gmmr_default') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_inherits
                       WHERE inhrelid = 'monitoring.gmmr_default'::regclass) THEN
        EXECUTE 'ALTER TABLE monitoring.general_metric_metadata_results '
                'ATTACH PARTITION monitoring.gmmr_default DEFAULT';
        RAISE NOTICE '7320: attached gmmr_default as DEFAULT partition';
    END IF;

    -- 3) ensure current month .. +12 months exist (mirrors gmmr_maintain,
    --    without the dedup/retention work - not migration business)
    m := date_trunc('month', now())::date;
    WHILE m <= (date_trunc('month', now()) + interval '12 months')::date LOOP
        pname := format('gmmr_%s', to_char(m, 'YYYY_MM'));
        IF to_regclass('monitoring.' || pname) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE monitoring.%I '
                'PARTITION OF monitoring.general_metric_metadata_results '
                'FOR VALUES FROM (%L) TO (%L)',
                pname, m, (m + interval '1 month')::date);
            RAISE NOTICE '7320: created missing partition %', pname;
        END IF;
        m := (m + interval '1 month')::date;
    END LOOP;
END $$;
