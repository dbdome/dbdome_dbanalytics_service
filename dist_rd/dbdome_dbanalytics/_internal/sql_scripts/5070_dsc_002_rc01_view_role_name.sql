-- =============================================================================
-- 5070_dsc_002_rc01_view_role_name.sql
-- Surface the role-membership relationship added in 5069 as a first-class column.
-- For the new membership rows (principal_type 'database_role_member' /
-- 'server_role_member') 'detail' holds the role the member belongs to; expose it
-- as role_name so consumers can filter/join on it (e.g. role_name='db_owner').
-- For non-membership rows role_name is NULL ('detail' still holds type_desc).
-- DROP + CREATE (no dependents) so both dbanalytics and dbanalytics_install end
-- up identical -- they had diverged (install lacked the 'id' column). Idempotent.
-- =============================================================================
DROP VIEW IF EXISTS monitoring.v_sec_sql_dsc_002_rc01;
CREATE VIEW monitoring.v_sec_sql_dsc_002_rc01 AS
SELECT
    r.server,
    r.id,
    j.value ->> 'database_name'   AS database_name,
    j.value ->> 'principal_type'  AS principal_type,
    j.value ->> 'principal_name'  AS principal_name,
    j.value ->> 'detail'          AS detail,
    r.entry_date,
    CASE WHEN j.value ->> 'principal_type' IN ('database_role_member','server_role_member')
         THEN j.value ->> 'detail' END AS role_name
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name::text = 'SEC-SQL-DSC-002-RC01';

-- VERIFY
SELECT column_name FROM information_schema.columns
WHERE table_schema='monitoring' AND table_name='v_sec_sql_dsc_002_rc01' AND column_name='role_name';
