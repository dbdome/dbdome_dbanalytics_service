-- =============================================================================
-- 6520_operation_log_retention.sql
-- Retention for log.operation_log (found at 233 GB: ~68M previously deleted
-- rows of dead bloat that plain DELETE can never give back to the OS, plus
-- ~1M new rows/day).
--
-- 1) Creates the GRC retention engine's tables (config.retention_policies +
--    log.retention_executions) — processes/retention_engine.py shipped without
--    them, so run_retention_enforcement() has been a silent no-op.
-- 2) Seeds a 10-day retention policy for log.operation_log; the engine runs
--    hourly and keeps it trimmed from now on.
-- 3) One-time copy-and-swap rebuild of log.operation_log keeping the last
--    10 days: reclaims all dead space immediately (a DELETE would not), and
--    adds ix_operation_log_entry_date so the hourly purge stays cheap.
--    Indexes are built BEFORE the bulk copy so the exclusive-lock window at
--    the end (delta rows + rename) lasts seconds, not minutes.
-- =============================================================================

-- 1) Retention engine tables (columns exactly as retention_engine.py uses them)
CREATE TABLE IF NOT EXISTS config.retention_policies (
    retention_id     serial PRIMARY KEY,
    policy_name      text        NOT NULL UNIQUE,
    target_schema    text        NOT NULL,
    target_table     text        NOT NULL,
    timestamp_column text        NOT NULL DEFAULT 'event_time',
    retention_days   integer     NOT NULL,
    min_retain_days  integer     NOT NULL DEFAULT 0,
    purge_mode       text        NOT NULL DEFAULT 'DELETE',
    regulation       text,
    is_active        boolean     NOT NULL DEFAULT true,
    last_run_at      timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS log.retention_executions (
    execution_id    bigserial PRIMARY KEY,
    retention_id    integer,
    policy_name     text,
    target_table    text,
    cutoff_date     date,
    rows_deleted    bigint,
    purge_mode      text,
    regulation      text,
    executed_by     text,
    success         boolean,
    error_message   text,
    sha256_manifest text,
    executed_at     timestamptz NOT NULL DEFAULT now()
);

-- 2) 10-day policy for operation_log
INSERT INTO config.retention_policies
    (policy_name, target_schema, target_table, timestamp_column,
     retention_days, min_retain_days, purge_mode)
SELECT 'operation_log_10_days', 'log', 'operation_log', 'entry_date', 10, 0, 'DELETE'
WHERE NOT EXISTS (
    SELECT 1 FROM config.retention_policies WHERE policy_name = 'operation_log_10_days'
);

-- 3) One-time rebuild keeping 10 days (skipped when the table doesn't exist)
DO $$
DECLARE
    seq   text;
    g     record;
BEGIN
    IF to_regclass('log.operation_log') IS NULL THEN
        RETURN;
    END IF;

    -- leftover from a previously failed run
    EXECUTE 'DROP TABLE IF EXISTS log.operation_log_new';

    EXECUTE 'CREATE TABLE log.operation_log_new (LIKE log.operation_log INCLUDING DEFAULTS)';
    -- Indexes up front: the big copy below runs WITHOUT any lock on the live
    -- table, so writers only wait during the short delta+rename phase.
    EXECUTE 'ALTER TABLE log.operation_log_new ADD CONSTRAINT operation_log_new_pkey PRIMARY KEY (row_id)';
    EXECUTE 'CREATE INDEX ix_routine_name_new ON log.operation_log_new (routine_name)';
    EXECUTE 'CREATE INDEX ix_operation_log_entry_date ON log.operation_log_new (entry_date)';

    EXECUTE $q$INSERT INTO log.operation_log_new
               SELECT * FROM log.operation_log
               WHERE entry_date >= now() - interval '10 days'$q$;

    seq := pg_get_serial_sequence('log.operation_log', 'row_id');

    EXECUTE 'LOCK TABLE log.operation_log IN ACCESS EXCLUSIVE MODE';

    -- rows written while the copy ran
    EXECUTE $q$INSERT INTO log.operation_log_new
               SELECT * FROM log.operation_log
               WHERE row_id > (SELECT COALESCE(MAX(row_id), 0) FROM log.operation_log_new)$q$;

    -- keep the shared sequence alive when the old table is dropped
    IF seq IS NOT NULL THEN
        EXECUTE format('ALTER SEQUENCE %s OWNED BY log.operation_log_new.row_id', seq);
    END IF;

    -- replay grants (LIKE does not copy ACLs; Grafana reads this table)
    FOR g IN
        SELECT grantee, privilege_type
        FROM information_schema.table_privileges
        WHERE table_schema = 'log' AND table_name = 'operation_log'
          AND grantee NOT IN ('PUBLIC', current_user::text)
    LOOP
        EXECUTE format('GRANT %s ON log.operation_log_new TO %I', g.privilege_type, g.grantee);
    END LOOP;

    EXECUTE 'ALTER TABLE log.operation_log RENAME TO operation_log_purged';
    EXECUTE 'ALTER TABLE log.operation_log_new RENAME TO operation_log';
    EXECUTE 'DROP TABLE log.operation_log_purged';

    -- restore canonical index/constraint names
    EXECUTE 'ALTER TABLE log.operation_log RENAME CONSTRAINT operation_log_new_pkey TO operation_log_pkey';
    EXECUTE 'ALTER INDEX log.ix_routine_name_new RENAME TO ix_routine_name';
END $$;
