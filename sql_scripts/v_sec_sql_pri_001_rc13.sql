-- ============================================================
-- View: monitoring.v_sec_sql_pri_001_rc13
-- Root cause: SEC-SQL-PRI-001-RC13
-- "Sensitive columns actively queried (PII in use)"
--
-- Projects the JSON array stored in
-- monitoring.general_metric_metadata_results.metric_metadata
-- into one row per PII column observed being read.
--
-- Columns mirror the keys the PII usage collector writes for
-- this metric.
-- ============================================================

-- DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc13;

CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc13 AS
SELECT r.server,
       (j.value ->> 'schema_name')    AS schema_name,
       (j.value ->> 'table_name')     AS table_name,
       (j.value ->> 'column_name')    AS column_name,
       (j.value ->> 'pii_category')   AS pii_category,
       (j.value ->> 'total_reads')    AS total_reads,
       (j.value ->> 'table_rows')     AS table_rows,
       (j.value ->> 'num_rows')       AS num_rows,
       (j.value ->> 'last_user_seek') AS last_user_seek,
       (j.value ->> 'last_user_scan') AS last_user_scan,
       (j.value ->> 'last_activity')  AS last_activity,
       (j.value ->> 'last_analyzed')  AS last_analyzed,
       r.entry_date
  FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)
 WHERE r.metric_name = 'SEC-SQL-PRI-001-RC13';

ALTER VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc13
    OWNER TO enterprisedb;

-- Read permission for the app roles
GRANT SELECT ON monitoring.v_sec_sql_pri_001_rc13 TO dbexpert_adm;
GRANT SELECT ON monitoring.v_sec_sql_pri_001_rc13 TO dbexpert_mon_usr;
