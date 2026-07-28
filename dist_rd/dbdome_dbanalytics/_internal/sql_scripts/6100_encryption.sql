-- ============================================================
-- Column tokenization ("encryption") from the Sensitive Columns Explorer.
-- Flow (on the target SQL Server):
--   ENCRYPT: back the table up to schema [unencrypted] (once, pristine), then
--            UPDATE the column in place with a SHA2_256 token (fit to the column
--            length) instead of the original value.
--   REVERT : DROP the tokenized table and ALTER SCHEMA TRANSFER the [unencrypted]
--            backup back to the original schema/name.
--
--   * metrics.encryption_log     : audit of every encrypt/revert attempt.
--   * metrics.encryption_preview : original vs token sample (from the backup).
--   * config.global_params 'encryption_dry_run' : safety switch (default 'true').
-- ============================================================
CREATE TABLE IF NOT EXISTS metrics.encryption_log (
    log_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entry_date  timestamptz NOT NULL DEFAULT now(),
    server      text, db_name text, schema_name text, table_name text, column_name text,
    action      text,        -- backed-up | tokenized | reverted | dry-run | skipped | error
    detail      text
);

CREATE TABLE IF NOT EXISTS metrics.encryption_preview (
    preview_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entry_date     timestamptz NOT NULL DEFAULT now(),
    server         text, db_name text, schema_name text, table_name text, column_name text,
    row_no         integer,
    original_value text,
    token_value    text
);
CREATE INDEX IF NOT EXISTS ix_encryption_preview_col
    ON metrics.encryption_preview (server, db_name, schema_name, table_name, column_name);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'encryption_dry_run') THEN
        INSERT INTO config.global_params (key, value) VALUES ('encryption_dry_run', 'true');
    END IF;
END $do$;
