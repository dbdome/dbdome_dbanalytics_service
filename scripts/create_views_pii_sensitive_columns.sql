-- =============================================================================
-- Views for PII Sensitive Column Detection Results
-- =============================================================================
-- SEC-SQL-PRI-001-RC12 — Sensitive columns discovered in schema
-- SEC-SQL-PRI-001-RC13 — Sensitive columns actively queried (in use)
-- =============================================================================

-- ─────────────────────────────────────────────
-- RC12: Sensitive columns discovered in schema
-- ─────────────────────────────────────────────

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc12
AS
SELECT r.server,
    (j.value ->> 'schema_name') AS schema_name,
    (j.value ->> 'table_name') AS table_name,
    (j.value ->> 'column_name') AS column_name,
    (j.value ->> 'data_type') AS data_type,
    (j.value ->> 'pii_category') AS pii_category,
    (j.value ->> 'max_length') AS max_length,
    (j.value ->> 'character_maximum_length') AS character_maximum_length,
    (j.value ->> 'data_length') AS data_length,
    r.entry_date
FROM (monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
WHERE (r.metric_name)::text = 'SEC-SQL-PRI-001-RC12';

ALTER TABLE IF EXISTS monitoring.v_sec_sql_pri_001_rc12
    OWNER TO enterprisedb;

-- ─────────────────────────────────────────────
-- RC13: Sensitive columns actively queried
-- ─────────────────────────────────────────────

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc13
AS
SELECT r.server,
    (j.value ->> 'schema_name') AS schema_name,
    (j.value ->> 'table_name') AS table_name,
    (j.value ->> 'column_name') AS column_name,
    (j.value ->> 'pii_category') AS pii_category,
    (j.value ->> 'total_reads') AS total_reads,
    (j.value ->> 'table_rows') AS table_rows,
    (j.value ->> 'num_rows') AS num_rows,
    (j.value ->> 'last_user_seek') AS last_user_seek,
    (j.value ->> 'last_user_scan') AS last_user_scan,
    (j.value ->> 'last_activity') AS last_activity,
    (j.value ->> 'last_analyzed') AS last_analyzed,
    r.entry_date
FROM (monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value))
WHERE (r.metric_name)::text = 'SEC-SQL-PRI-001-RC13';

ALTER TABLE IF EXISTS monitoring.v_sec_sql_pri_001_rc13
    OWNER TO enterprisedb;
