-- =============================================================================
-- 5061_complete_sec_sql_dsc_family.sql
-- Complete the SEC-SQL-DSC discovery family so both root causes collect AND
-- display:
--   * SEC-SQL-DSC-001-RC01  Data Structure Discovery  (db -> schema -> table -> column)
--   * SEC-SQL-DSC-002-RC01  RBAC Principal Inventory   (server/db roles, logins, users)
--
-- Collection path: a metric runs only when it is in BOTH rootcause.v_rootcauses
-- AND metrics.v_custom_metrics. v_custom_metrics derives directly from
-- v_rootcauses, and v_rootcauses INNER JOINs detection_paths AND resolution_paths.
-- DSC-001-RC01 got its resolution_path in 5060; DSC-002-RC01 still lacks one, so
-- this adds it (idempotent) -> DSC-002-RC01 enters v_rootcauses -> auto-collects.
--
-- Display path: each RC needs a monitoring view that projects its per-row JSON
-- (stored in monitoring.general_metric_metadata_results) into flat columns.
-- Neither DSC view existed; both are created here.
-- Idempotent throughout. =============================================================================

-- 1) SEC-SQL-DSC-002-RC01: add the missing resolution_path + step ------------
DO $fix$
DECLARE
    v_res_step bigint;
    v_res_path bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM rootcause.resolution_paths
        WHERE root_cause_id = 'SEC-SQL-DSC-002-RC01' AND vendor_slug = 'sqlserver'
    ) THEN
        INSERT INTO rootcause.resolution_steps
            (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES (
            'sqlserver', 'recommendation',
            'Resolve: SEC-SQL-DSC-002-RC01 (sqlserver)',
            '{"action": "Review the RBAC principal inventory (server roles, database roles, logins, users). Confirm each principal is expected and least-privileged, investigate unknown logins/users, and remove or disable stale or orphaned principals."}'::jsonb,
            'low', false, true)
        RETURNING id INTO v_res_step;

        INSERT INTO rootcause.resolution_paths
            (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES (
            'SEC-SQL-DSC-002-RC01', 'sqlserver',
            'Resolve: SEC-SQL-DSC-002-RC01 (sqlserver)',
            'resolve-sec_sql_dsc_002_rc01-sqlserver',
            'Review and curate the RBAC principal inventory; enforce least privilege and remove stale principals.',
            'supervised', 'low', true)
        RETURNING id INTO v_res_path;

        INSERT INTO rootcause.resolution_path_steps
            (resolution_path_id, resolution_step_id, step_order)
        VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$fix$;

-- 2) Monitoring view: DSC-001-RC01 (data structure hierarchy) ----------------
CREATE OR REPLACE VIEW monitoring.v_sec_sql_dsc_001_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name' AS database_name,
    j.value ->> 'schema_name'   AS schema_name,
    j.value ->> 'table_name'    AS table_name,
    j.value ->> 'column_name'   AS column_name,
    j.value ->> 'data_type'     AS data_type,
    j.value ->> 'ordinal'       AS ordinal,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-DSC-001-RC01';

-- 3) Monitoring view: DSC-002-RC01 (RBAC principal inventory) ----------------
CREATE OR REPLACE VIEW monitoring.v_sec_sql_dsc_002_rc01 AS
SELECT
    r.server,
    j.value ->> 'database_name'  AS database_name,
    j.value ->> 'principal_type' AS principal_type,
    j.value ->> 'principal_name' AS principal_name,
    j.value ->> 'detail'         AS detail,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-DSC-002-RC01';

-- VERIFY: both DSC RCs now in v_rootcauses; both views exist
SELECT root_cause_id, vendor_name, risk_level
FROM rootcause.v_rootcauses
WHERE root_cause_id IN ('SEC-SQL-DSC-001-RC01','SEC-SQL-DSC-002-RC01')
ORDER BY root_cause_id;

SELECT table_name FROM information_schema.views
WHERE table_schema='monitoring' AND table_name IN ('v_sec_sql_dsc_001_rc01','v_sec_sql_dsc_002_rc01')
ORDER BY table_name;
