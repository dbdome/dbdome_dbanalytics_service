-- 5950: expose server_id (unique per monitored instance) in
-- monitoring.v_sec_sql_authz_001_rc01, so the Configuration dashboard can filter
-- server details per-instance (instances sharing an IP have distinct server_id).
-- CREATE OR REPLACE appends server_id at the end (no DROP, no dependency risk).

CREATE OR REPLACE VIEW monitoring.v_sec_sql_authz_001_rc01 AS
 SELECT r.server,
    j.value ->> 'database_name'  AS database_name,
    j.value ->> 'login_name'     AS login_name,
    j.value ->> 'database_user'  AS database_user,
    j.value ->> 'principal_type' AS principal_type,
    j.value ->> 'roles'          AS roles,
    j.value ->> 'permissions'    AS permissions,
    r.entry_date,
    j.value ->> 'login_status'   AS login_status,
    r.server_id
   FROM monitoring.general_metric_metadata_results r
     CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
    LATERAL ( SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
  WHERE r.metric_name::text = 'SEC-SQL-AUTHZ-001-RC01'::text;
