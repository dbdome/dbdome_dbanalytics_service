-- ============================================================
-- metrics.sensitive_columns : operator-curated list of sensitive columns.
-- The Sensitive Columns Explorer dashboard "track" action calls the
-- /sensitive_column_add API -> metrics.add_sensitive_column to add a row here
-- (same pattern as set_webook_alert). Idempotent.
-- ============================================================
CREATE TABLE IF NOT EXISTS metrics.sensitive_columns (
    row_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    server       text,
    db_name      text,
    schema_name  text,
    table_name   text,
    column_name  text,
    pii_category text,
    entry_date   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_metrics_sensitive_columns
    ON metrics.sensitive_columns (server, db_name, schema_name, table_name, column_name);

CREATE OR REPLACE PROCEDURE metrics.add_sensitive_column(
    p_server text, p_db text, p_schema text, p_table text, p_column text, p_pii text)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_table IS NULL OR p_column IS NULL OR p_table = '' OR p_column = '' THEN
        RAISE EXCEPTION 'add_sensitive_column: table_name and column_name are required';
    END IF;
    INSERT INTO metrics.sensitive_columns (server, db_name, schema_name, table_name, column_name, pii_category)
    VALUES (p_server, p_db, p_schema, p_table, p_column, p_pii)
    ON CONFLICT (server, db_name, schema_name, table_name, column_name)
    DO UPDATE SET pii_category = EXCLUDED.pii_category, entry_date = now();
END $$;
