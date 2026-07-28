-- =============================================================================
-- 6100_dp_log.sql
-- Audit log for the data-protection processes (processes/data_protection.py):
-- dynamic masking, static masking, tokenization, anonymization. One row per
-- action on a target column. Lives in dbanalytics (PostgreSQL). Idempotent.
-- =============================================================================
CREATE TABLE IF NOT EXISTS metrics.dp_log (
    row_id        bigserial PRIMARY KEY,
    server        text,
    database_name text,
    schema_name   text,
    table_name    text,
    column_name   text,
    technique     text,          -- dynamic_mask | static_mask | tokenize | anonymize
    status        text,          -- ok | error | skipped
    detail        text,
    entry_date    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_dp_log_entry  ON metrics.dp_log (entry_date DESC);
CREATE INDEX IF NOT EXISTS ix_dp_log_target ON metrics.dp_log (server, database_name, entry_date DESC);
