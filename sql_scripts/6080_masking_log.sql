-- ============================================================
-- Dynamic Data Masking from the Sensitive Columns Explorer.
--   * metrics.masking_log     : audit of every mask attempt (dry-run or applied).
--   * config.global_params 'masking_dry_run' : safety switch (default 'true').
--     While true, /mask_column only LOGS the DDL it would run; set to 'false'
--     to actually apply ALTER ... ADD MASKED on the target SQL Server.
-- ============================================================
CREATE TABLE IF NOT EXISTS metrics.masking_log (
    log_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entry_date    timestamptz NOT NULL DEFAULT now(),
    server        text,
    db_name       text,
    schema_name   text,
    table_name    text,
    column_name   text,
    mask_function text,
    action        text,        -- dry-run | masked | already-masked | skipped | error
    detail        text
);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'masking_dry_run') THEN
        INSERT INTO config.global_params (key, value) VALUES ('masking_dry_run', 'true');
    END IF;
END $do$;
