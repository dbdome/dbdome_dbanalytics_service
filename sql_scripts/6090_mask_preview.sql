-- ============================================================
-- Masked-data preview captured by /mask_column after applying masking:
-- a sample of the column read as the privileged login (real) vs read while
-- impersonating the unprivileged test user dbdome_mask_test (masked). Shown in
-- the "Masked data preview" panel of the Sensitive Columns Explorer.
-- ============================================================
CREATE TABLE IF NOT EXISTS metrics.mask_preview (
    preview_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server       text,
    db_name      text,
    schema_name  text,
    table_name   text,
    column_name  text,
    row_no       integer,
    real_value   text,
    masked_value text,
    entry_date   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_mask_preview_col
    ON metrics.mask_preview (server, db_name, schema_name, table_name, column_name);
