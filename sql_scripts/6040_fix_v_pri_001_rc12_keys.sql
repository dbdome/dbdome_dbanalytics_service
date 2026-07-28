-- ============================================================
-- Realign monitoring.v_sec_sql_pri_001_rc12 to the ACTUAL metric_metadata keys.
-- The detection now emits db_name / schema_name / table_name / column_name /
-- data_type / pii_category / max_length, but the view still read stale keys
-- (table_schema, owner/name, data_length) -> NULLs, and never surfaced db_name.
-- This exposes the real server -> db_name -> schema -> table -> column hierarchy.
-- DROP+CREATE because the column set changes (OR REPLACE can't). entry_date kept
-- as timestamptz (Asia/Jerusalem) like the other fixed views.
-- ============================================================
DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc12;
CREATE VIEW monitoring.v_sec_sql_pri_001_rc12 AS
SELECT r.server,
       j.value ->> 'db_name'      AS db_name,
       j.value ->> 'schema_name'  AS schema_name,
       j.value ->> 'table_name'   AS table_name,
       j.value ->> 'column_name'  AS column_name,
       j.value ->> 'data_type'    AS data_type,
       j.value ->> 'pii_category' AS pii_category,
       j.value ->> 'max_length'   AS max_length,
       (r.entry_date AT TIME ZONE 'Asia/Jerusalem') AS entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j
WHERE r.metric_name::text = 'SEC-SQL-PRI-001-RC12'::text;
