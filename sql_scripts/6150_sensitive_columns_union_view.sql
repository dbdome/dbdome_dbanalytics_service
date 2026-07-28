-- =============================================================================
-- 6150_sensitive_columns_union_view.sql
-- metrics.v_sensitive_columns_all : the single source of truth for "which
-- columns are sensitive", as the UNION of:
--   * metrics.sensitive_columns   (operator-curated, has pii_category)
--   * monitoring.sensitive_schema (auto-discovered by
--     collect_metric_mssql_sensitive_data_activity; has data_type but no
--     pii_category, so we derive it from the column name here)
--
-- Consumed by the collector's sensitive-list injection (see RC15) so the
-- per-cycle detection no longer scans every database's catalog on the target.
-- Normalised columns: server, db_name, schema_name, table_name, column_name,
-- pii_category. UNION (not UNION ALL) de-duplicates identical rows.
-- =============================================================================
CREATE OR REPLACE VIEW metrics.v_sensitive_columns_all AS
SELECT server, db_name, schema_name, table_name, column_name, pii_category
FROM (
    SELECT server, db_name, schema_name, table_name, column_name, pii_category
    FROM metrics.sensitive_columns
    UNION
    SELECT server,
           database_name AS db_name,
           table_schema  AS schema_name,
           table_name,
           column_name,
           CASE
             WHEN lower(column_name) ~ '(password|pass)'   THEN 'Password'
             WHEN lower(column_name) ~ '(secret|token|key)' THEN 'Credential'
             WHEN lower(column_name) ~ '(credit|card)'     THEN 'Credit Card'
             WHEN lower(column_name) ~ 'ssn'               THEN 'SSN'
             WHEN lower(column_name) ~ 'email'             THEN 'Email'
             WHEN lower(column_name) ~ 'phone'             THEN 'Phone'
             WHEN lower(column_name) ~ 'address'           THEN 'Address'
             WHEN lower(column_name) ~ '(dob|birth)'       THEN 'Date of Birth'
             WHEN lower(column_name) ~ 'salary'            THEN 'Salary'
             WHEN lower(column_name) ~ 'passport'          THEN 'Passport'
             WHEN lower(column_name) ~ '(medical|diagnosis)' THEN 'Medical'
             WHEN lower(column_name) ~ 'teudat'            THEN 'Teudat Zehut'
             ELSE 'Other Sensitive'
           END AS pii_category
    FROM monitoring.sensitive_schema
) u
WHERE table_name IS NOT NULL AND column_name IS NOT NULL;
