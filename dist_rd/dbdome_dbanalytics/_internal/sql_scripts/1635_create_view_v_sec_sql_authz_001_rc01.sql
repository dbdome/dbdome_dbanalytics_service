-- ============================================================
-- View: monitoring.v_sec_sql_authz_001_rc01
-- Root cause: SEC-SQL-AUTHZ-001-RC01
--   Database access & privilege inventory:
--   Server -> Database -> Login -> roles & grants (SQL Server).
-- Projects the detection's per-row JSON output (one element per
-- database principal) into flat columns.
-- Idempotent (CREATE OR REPLACE); re-applied by sql_script_runner
-- when this file's checksum changes.
-- ============================================================

DROP VIEW IF EXISTS monitoring.v_sec_sql_authz_001_rc01;

CREATE OR REPLACE VIEW monitoring.v_sec_sql_authz_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name'    AS database_name,
    j.value ->> 'login_name'       AS login_name,
    j.value ->> 'database_user'    AS database_user,
    j.value ->> 'principal_type'   AS principal_type,
    j.value ->> 'roles'            AS roles,
    j.value ->> 'permissions'      AS permissions,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-AUTHZ-001-RC01';
