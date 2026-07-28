-- =============================================================================
-- 5060_fix_sec_sql_dsc_001_rc01_resolution.sql
-- SEC-SQL-DSC-001-RC01 was missing from monitoring/rootcause view
-- rootcause.v_rootcauses even though it exists in rootcause.root_causes.
--
-- Cause: v_rootcauses INNER JOINs the full chain
--   issues -> domains -> areas -> root_causes -> detection_paths ->
--   detection_path_steps -> detection_steps -> vendors ->
--   resolution_paths -> resolution_path_steps -> resolution_steps -> risk_level
-- SEC-SQL-DSC-001-RC01 had a detection_path (sqlserver) but NO resolution_path,
-- so the INNER JOIN to resolution_paths dropped it from the view.
--
-- Fix: add the missing resolution_path + resolution_step (+ link row) for the
-- sqlserver vendor, matching the seed pattern used by the other root causes.
-- Idempotent: only inserts when no resolution_path exists for this RC/vendor.
-- =============================================================================
DO $fix$
DECLARE
    v_res_step bigint;
    v_res_path bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM rootcause.resolution_paths
        WHERE root_cause_id = 'SEC-SQL-DSC-001-RC01' AND vendor_slug = 'sqlserver'
    ) THEN
        INSERT INTO rootcause.resolution_steps
            (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES (
            'sqlserver', 'recommendation',
            'Resolve: SEC-SQL-DSC-001-RC01 (sqlserver)',
            '{"action": "Review the discovered server data hierarchy (databases -> schemas -> tables -> columns). Confirm the inventory matches the expected footprint, investigate any unexpected databases/schemas/tables, and ensure sensitive tables/columns are classified and access-controlled."}'::jsonb,
            'low', false, true)
        RETURNING id INTO v_res_step;

        INSERT INTO rootcause.resolution_paths
            (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES (
            'SEC-SQL-DSC-001-RC01', 'sqlserver',
            'Resolve: SEC-SQL-DSC-001-RC01 (sqlserver)',
            'resolve-sec_sql_dsc_001_rc01-sqlserver',
            'Review and curate the discovered server data hierarchy; classify and protect sensitive objects.',
            'supervised', 'low', true)
        RETURNING id INTO v_res_path;

        INSERT INTO rootcause.resolution_path_steps
            (resolution_path_id, resolution_step_id, step_order)
        VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$fix$;

-- VERIFY: should now return 1 row
SELECT root_cause_id, vendor_name, risk_level
FROM rootcause.v_rootcauses
WHERE root_cause_id = 'SEC-SQL-DSC-001-RC01';
