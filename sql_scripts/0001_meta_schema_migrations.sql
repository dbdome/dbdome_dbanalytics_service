-- =============================================================================
-- 0001_meta_schema_migrations.sql
-- Ledger for the SQL script runner (processes/sql_script_runner.py).
--
-- The runner records every *.sql it applies here so each script runs only once
-- per content (filename + checksum), in filename order. This file mirrors the
-- runner's internal bootstrap DDL exactly, so the table exists even if you
-- initialise the database by hand or from postgres\install. Fully idempotent —
-- safe to run repeatedly and safe to run alongside the runner.
--
-- Sorts first (0001_) so the ledger is in place before any other migration.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS meta;

CREATE TABLE IF NOT EXISTS meta.schema_migrations (
    id           bigserial   PRIMARY KEY,
    filename     text        NOT NULL,                 -- script basename, e.g. 1010_create_view_*.sql
    checksum     text        NOT NULL,                 -- sha256 of script text (line-ending-insensitive)
    applied_at   timestamptz NOT NULL DEFAULT now(),   -- when this attempt ran
    execution_ms integer,                              -- wall-clock duration of the apply
    success      boolean     NOT NULL DEFAULT true,    -- false rows = failed attempt (see error)
    error        text                                  -- error text when success = false
);

-- One lookup per file, newest first: the runner reads the latest successful
-- checksum per filename to decide skip vs (re)apply.
CREATE INDEX IF NOT EXISTS ix_schema_migrations_file
    ON meta.schema_migrations (filename, applied_at DESC);

-- Column documentation.
COMMENT ON TABLE  meta.schema_migrations              IS 'Ledger of SQL scripts applied by sql_script_runner; one row per apply attempt.';
COMMENT ON COLUMN meta.schema_migrations.filename     IS 'Script basename (sequence-numbered, e.g. 0010_migrate_gmmr_partition.sql).';
COMMENT ON COLUMN meta.schema_migrations.checksum     IS 'sha256 of normalised script text; a change triggers re-apply.';
COMMENT ON COLUMN meta.schema_migrations.execution_ms IS 'Apply duration in milliseconds.';
COMMENT ON COLUMN meta.schema_migrations.success      IS 'TRUE = applied cleanly; FALSE = failed (error populated).';

-- Convenience: latest attempt per script, with a status label. Handy for
-- "what ran / what failed" without writing window functions each time.
CREATE OR REPLACE VIEW meta.v_schema_migrations_latest AS
SELECT DISTINCT ON (filename)
       filename,
       checksum,
       applied_at,
       execution_ms,
       success,
       error,
       CASE WHEN success THEN 'ok' ELSE 'failed' END AS status
FROM   meta.schema_migrations
ORDER  BY filename, applied_at DESC;

COMMENT ON VIEW meta.v_schema_migrations_latest IS 'Most recent apply attempt per script (latest row per filename).';
