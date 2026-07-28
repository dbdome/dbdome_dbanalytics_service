-- =============================================================================
-- Migrate monitoring.general_metric_metadata_results to a partitioned design
-- -----------------------------------------------------------------------------
-- IDEMPOTENT — safe to run on every dbdome_update. It detects whether the table
-- is already partitioned and skips the one-time migration if so; the supporting
-- objects (indexes, latest-result table, trigger, maintenance fn) are created
-- with IF NOT EXISTS / CREATE OR REPLACE so re-runs are no-ops.
--
--  * RANGE partition by entry_date, one partition per month
--  * Retention: keep 12 months (monitoring.gmmr_maintain drops older)
--  * Read pattern: per-server -> (server, metric_name, entry_date DESC) index
--  * metric_latest_result -> tiny current-state table for dashboards
--
-- Strategy: create-new-and-swap; the old table is kept as
--   monitoring.general_metric_metadata_results_old  (drop once verified).
--
-- Place this in the update package's  postgres\install\  folder. Prefix the
-- filename so it runs before the view scripts, e.g. 00_migrate_gmmr_partition.sql
-- Tested target: PostgreSQL 18.
-- =============================================================================

-- Run the ENTIRE script only when the table is not already partitioned. When it
-- is already partitioned, skip everything (psql \if guard). gmmr_already_partitioned
-- is false when the table is plain ('r') or absent (fresh DB), so the migration
-- still runs in those cases.
SELECT COALESCE((SELECT c.relkind = 'p'
                 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE n.nspname = 'monitoring'
                   AND c.relname = 'general_metric_metadata_results'), false)
       AS gmmr_already_partitioned \gset
\if :gmmr_already_partitioned
\echo '>>> monitoring.general_metric_metadata_results is already partitioned - skipping 0010_migrate_gmmr_partition.sql'
\else

SET search_path = monitoring, public;

-- ----------------------------------------------------------------------------
-- 1) One-time migration (guarded): only runs if the table is NOT yet partitioned
-- ----------------------------------------------------------------------------
DO $mig$
DECLARE
    v_relkind   "char";
    v_old_exists boolean;
    m     date;
    first date := (date_trunc('month', now()) - interval '12 months')::date;
    last  date := (date_trunc('month', now()) + interval '12 months')::date;
    pname text;
BEGIN
    SELECT c.relkind INTO v_relkind
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'monitoring' AND c.relname = 'general_metric_metadata_results';

    IF v_relkind = 'p' THEN
        RAISE NOTICE 'gmmr: already partitioned — skipping migration body';
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring'
          AND c.relname = 'general_metric_metadata_results_old'
    ) INTO v_old_exists;

    IF v_relkind = 'r' AND v_old_exists THEN
        RAISE NOTICE 'gmmr: plain table AND _old both exist — partial migration; '
                     'manual review needed, skipping';
        RETURN;
    END IF;

    -- Move the existing plain table aside (becomes the copy source/backup).
    IF v_relkind = 'r' THEN
        EXECUTE 'ALTER TABLE monitoring.general_metric_metadata_results '
                'RENAME TO general_metric_metadata_results_old';
        v_old_exists := true;
    END IF;

    -- New partitioned parent. entry_date must be in the PK (partition key) and
    -- therefore NOT NULL; collectors INSERT without it, so default to now() —
    -- the default is applied before partition routing, so rows land in the
    -- correct monthly partition rather than the DEFAULT one.
    EXECUTE '
        CREATE TABLE monitoring.general_metric_metadata_results (
            id              bigint GENERATED ALWAYS AS IDENTITY,
            row_id          integer,
            server          varchar(50),
            category_id     integer,
            metric_name     varchar(255),
            metric_config   json,
            metric_metadata jsonb,
            metric_metadata_vs_expected jsonb,
            server_id       uuid,
            entry_date      timestamp NOT NULL DEFAULT now(),
            PRIMARY KEY (entry_date, id)
        ) PARTITION BY RANGE (entry_date)';

    EXECUTE 'CREATE TABLE monitoring.gmmr_default '
            'PARTITION OF monitoring.general_metric_metadata_results DEFAULT';

    -- Monthly partitions: last 12 months .. 12 months ahead.
    m := first;
    WHILE m <= last LOOP
        pname := format('gmmr_%s', to_char(m, 'YYYY_MM'));
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS monitoring.%I '
            'PARTITION OF monitoring.general_metric_metadata_results '
            'FOR VALUES FROM (%L) TO (%L)',
            pname, m, (m + interval '1 month')::date);
        m := (m + interval '1 month')::date;
    END LOOP;

    -- Copy data (entry_date is NOT NULL now; coalesce any NULLs).
    IF v_old_exists THEN
        EXECUTE '
            INSERT INTO monitoring.general_metric_metadata_results
                (row_id, server, category_id, metric_name, metric_config, metric_metadata,
                 metric_metadata_vs_expected, server_id, entry_date)
            SELECT row_id, server, category_id, metric_name, metric_config, metric_metadata,
                   metric_metadata_vs_expected, server_id, COALESCE(entry_date, now())
            FROM monitoring.general_metric_metadata_results_old';
    END IF;

    RAISE NOTICE 'gmmr: migration completed';
END
$mig$;

-- Idempotent fixes for DBs already partitioned before this revision:
-- collectors INSERT without entry_date, so it must default; and ensure the
-- extra result columns exist. (No-ops if already correct.)
ALTER TABLE monitoring.general_metric_metadata_results
    ALTER COLUMN entry_date SET DEFAULT now();
ALTER TABLE monitoring.general_metric_metadata_results
    ADD COLUMN IF NOT EXISTS metric_metadata_vs_expected jsonb;
ALTER TABLE monitoring.general_metric_metadata_results
    ADD COLUMN IF NOT EXISTS server_id uuid;

-- ----------------------------------------------------------------------------
-- 2) Indexes on the parent (auto-propagate to all partitions). Idempotent.
--    Per-server is the primary read path; metric_name-only is used by
--    get_root_cause_resultset() and the v_sec_* views.
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_gmmr_server_metric_date
    ON monitoring.general_metric_metadata_results (server, metric_name, entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_gmmr_metric_date
    ON monitoring.general_metric_metadata_results (metric_name, entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_gmmr_entry_brin
    ON monitoring.general_metric_metadata_results USING brin (entry_date);

-- Optional GIN — NOT required by current views. Every v_sec_* view and
-- get_root_cause_resultset() filter by metric_name (btree above) and then
-- expand metric_metadata with jsonb_array_elements(); none use @>, ?, or
-- jsonb_path operators, so a GIN would add write cost with no read benefit.
-- Enable ONLY if you later add containment/path predicates on the JSON:
-- CREATE INDEX IF NOT EXISTS ix_gmmr_metadata_gin
--     ON monitoring.general_metric_metadata_results USING gin (metric_metadata jsonb_path_ops);

-- ----------------------------------------------------------------------------
-- 3) Current-state table for fast dashboard reads (one row per server+metric)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monitoring.metric_latest_result (
    server          varchar(50)  NOT NULL,
    metric_name     varchar(255) NOT NULL,
    category_id     integer,
    metric_config   json,
    metric_metadata jsonb,
    entry_date      timestamp,
    PRIMARY KEY (server, metric_name)
);

-- Seed only if empty (so re-runs don't re-scan the whole history).
DO $seed$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM monitoring.metric_latest_result) THEN
        INSERT INTO monitoring.metric_latest_result
            (server, metric_name, category_id, metric_config, metric_metadata, entry_date)
        SELECT DISTINCT ON (server, metric_name)
               server, metric_name, category_id, metric_config, metric_metadata, entry_date
        FROM monitoring.general_metric_metadata_results
        WHERE server IS NOT NULL AND metric_name IS NOT NULL
        ORDER BY server, metric_name, entry_date DESC
        ON CONFLICT (server, metric_name) DO NOTHING;
    END IF;
END
$seed$;

CREATE OR REPLACE FUNCTION monitoring.gmmr_upsert_latest()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO monitoring.metric_latest_result
        (server, metric_name, category_id, metric_config, metric_metadata, entry_date)
    VALUES (NEW.server, NEW.metric_name, NEW.category_id,
            NEW.metric_config, NEW.metric_metadata, NEW.entry_date)
    ON CONFLICT (server, metric_name) DO UPDATE SET
        category_id     = EXCLUDED.category_id,
        metric_config   = EXCLUDED.metric_config,
        metric_metadata = EXCLUDED.metric_metadata,
        entry_date      = EXCLUDED.entry_date
    WHERE EXCLUDED.entry_date >= monitoring.metric_latest_result.entry_date
       OR monitoring.metric_latest_result.entry_date IS NULL;
    RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_gmmr_latest ON monitoring.general_metric_metadata_results;
CREATE TRIGGER trg_gmmr_latest
    AFTER INSERT ON monitoring.general_metric_metadata_results
    FOR EACH ROW
    WHEN (NEW.server IS NOT NULL AND NEW.metric_name IS NOT NULL)
    EXECUTE FUNCTION monitoring.gmmr_upsert_latest();

-- ----------------------------------------------------------------------------
-- 4) Monthly maintenance: create next month + drop partitions older than N months
-- ----------------------------------------------------------------------------
-- Drop the stale single-arg revision so only the canonical (keep, ahead) form
-- exists — otherwise gmmr_maintain() / gmmr_maintain(12) are ambiguous overloads.
DROP FUNCTION IF EXISTS monitoring.gmmr_maintain(integer);
CREATE OR REPLACE FUNCTION monitoring.gmmr_maintain(
    p_keep_months  int DEFAULT 12,
    p_ahead_months int DEFAULT 12)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    ahead_to date := (date_trunc('month', now()) + make_interval(months => p_ahead_months))::date;
    cutoff   date := (date_trunc('month', now()) - make_interval(months => p_keep_months))::date;
    m      date;
    pname  text;
    r      record;
    lo     date;
    v_dedup bigint;
    v_logdel bigint;
    v_fw_days int;
    v_aldel bigint;
BEGIN
    -- Ensure partitions exist from the current month through p_ahead_months ahead.
    m := date_trunc('month', now())::date;
    WHILE m <= ahead_to LOOP
        pname := format('gmmr_%s', to_char(m, 'YYYY_MM'));
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS monitoring.%I '
            'PARTITION OF monitoring.general_metric_metadata_results '
            'FOR VALUES FROM (%L) TO (%L)',
            pname, m, (m + interval '1 month')::date);
        m := (m + interval '1 month')::date;
    END LOOP;

    FOR r IN
        SELECT c.relname
        FROM pg_inherits i
        JOIN pg_class c     ON c.oid = i.inhrelid
        JOIN pg_class p     ON p.oid = i.inhparent
        JOIN pg_namespace n ON n.oid = p.relnamespace
        WHERE n.nspname = 'monitoring'
          AND p.relname = 'general_metric_metadata_results'
          AND c.relname ~ '^gmmr_[0-9]{4}_[0-9]{2}$'
    LOOP
        lo := to_date(substring(r.relname FROM 'gmmr_([0-9]{4}_[0-9]{2})'), 'YYYY_MM');
        IF lo < cutoff THEN
            EXECUTE format('DROP TABLE IF EXISTS monitoring.%I', r.relname);
            RAISE NOTICE 'gmmr: dropped old partition %', r.relname;
        END IF;
    END LOOP;

    -- Collapse duplicate snapshots: keep the newest row per
    -- (server, metric_name, identical metric_metadata); drop the older copies.
    -- (Folds in the former scripts/dedup_gmmr_metric_metadata.sql so the cleanup
    --  runs on the same maintenance schedule instead of by hand.)
    WITH ranked AS (
        SELECT entry_date, id,
               row_number() OVER (
                   PARTITION BY server, metric_name, md5(coalesce(metric_metadata::text, ''))
                   ORDER BY id DESC
               ) AS rn
        FROM monitoring.general_metric_metadata_results
    )
    DELETE FROM monitoring.general_metric_metadata_results g
    USING ranked r2
    WHERE g.entry_date = r2.entry_date AND g.id = r2.id AND r2.rn > 1;
    GET DIAGNOSTICS v_dedup = ROW_COUNT;
    RAISE NOTICE 'gmmr: deduped % duplicate metric_metadata rows', v_dedup;

    -- Retention: prune metrics.server_log beyond the keep window (same p_keep_months).
    -- Guarded so gmmr_maintain still works if server_log hasn't been created yet.
    IF to_regclass('metrics.server_log') IS NOT NULL THEN
        DELETE FROM metrics.server_log
        WHERE changed_at < (now() - make_interval(months => p_keep_months));
        GET DIAGNOSTICS v_logdel = ROW_COUNT;
        RAISE NOTICE 'gmmr: pruned % server_log rows older than % months', v_logdel, p_keep_months;
    END IF;

    -- Prune log.firewall_audit_log (high-volume audit) beyond its OWN retention in
    -- DAYS (config.global_params 'firewall_audit_retention_days', default 90).
    -- A months-based window would never prune this table given its daily volume.
    -- event_time is indexed (idx_fw_audit_event_time), so this stays cheap.
    IF to_regclass('log.firewall_audit_log') IS NOT NULL THEN
        v_fw_days := 90;
        IF to_regclass('config.global_params') IS NOT NULL THEN
            SELECT NULLIF(value, '')::int INTO v_fw_days
            FROM config.global_params WHERE key = 'firewall_audit_retention_days';
        END IF;
        v_fw_days := COALESCE(v_fw_days, 90);
        DELETE FROM log.firewall_audit_log
        WHERE event_time < (now() - make_interval(days => v_fw_days));
        GET DIAGNOSTICS v_logdel = ROW_COUNT;
        RAISE NOTICE 'gmmr: pruned % firewall_audit_log rows older than % days', v_logdel, v_fw_days;
    END IF;

    -- Collapse alerts.alert_log to ONE row per (server, root_cause_id, hour):
    -- keep the newest in each hour bucket, drop older copies. Self-heals hourly
    -- dups in case any undeployed collector still inserts without delete-then-insert.
    -- (Folds in scripts/dedup_alert_log_hourly.sql.) Guarded for safety.
    IF to_regclass('alerts.alert_log') IS NOT NULL THEN
        WITH ranked AS (
            SELECT row_id,
                   row_number() OVER (
                       PARTITION BY server, root_cause_id, date_trunc('hour', entry_date)
                       ORDER BY entry_date DESC, row_id DESC
                   ) AS rn
            FROM alerts.alert_log
        )
        DELETE FROM alerts.alert_log a
        USING ranked r3
        WHERE a.row_id = r3.row_id AND r3.rn > 1;
        GET DIAGNOSTICS v_aldel = ROW_COUNT;
        RAISE NOTICE 'gmmr: deduped % alert_log rows (1/hour per server+root_cause)', v_aldel;
    END IF;
END $$;

-- Schedule monthly — pg_cron (if installed) or call from the app scheduler:
--   SELECT cron.schedule('gmmr_maintain','0 1 1 * *',$$SELECT monitoring.gmmr_maintain(12)$$);
--   -- or: SELECT monitoring.gmmr_maintain(12);

ANALYZE monitoring.general_metric_metadata_results;
ANALYZE monitoring.metric_latest_result;

-- Verify, then drop the backup once happy:
--   SELECT count(*) FROM monitoring.general_metric_metadata_results;
--   SELECT count(*) FROM monitoring.general_metric_metadata_results_old;
--   -- DROP TABLE monitoring.general_metric_metadata_results_old;

\endif
-- end guard: skipped entirely when already partitioned
