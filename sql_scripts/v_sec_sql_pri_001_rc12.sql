-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc12
-- Root cause: SEC-SQL-PRI-001-RC12
-- "Sensitive columns discovered in schema (PII)"
--
-- Projects the JSON array stored in
-- monitoring.general_metric_metadata_results.metric_metadata
-- into one row per detected sensitive column.
--
-- Columns mirror the keys the PII discovery collector writes for
-- this metric.
-- ============================================================

-- DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc12;

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc12 AS
SELECT r.server,
       (j.value ->> 'schema_name')              AS schema_name,
       (j.value ->> 'table_name')               AS table_name,
       (j.value ->> 'column_name')              AS column_name,
       (j.value ->> 'data_type')                AS data_type,
       (j.value ->> 'pii_category')             AS pii_category,
       (j.value ->> 'max_length')               AS max_length,
       (j.value ->> 'character_maximum_length') AS character_maximum_length,
       (j.value ->> 'data_length')              AS data_length,
       r.entry_date
  FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
 WHERE r.metric_name = 'SEC-SQL-PRI-001-RC12';

ALTER VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc12
    OWNER TO enterprisedb;

-- Read permission for the app roles
GRANT SELECT ON monitoring.v_sec_sql_pri_001_rc12 TO dbexpert_adm;
GRANT SELECT ON monitoring.v_sec_sql_pri_001_rc12 TO dbexpert_mon_usr;
