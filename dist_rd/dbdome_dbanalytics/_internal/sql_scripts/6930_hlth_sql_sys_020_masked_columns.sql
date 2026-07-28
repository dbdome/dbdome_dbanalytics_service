-- ============================================================
-- 6930  HLTH-SQL-SYS-020-RC01  Masked columns inventory captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base OPENQUERY/cursor version:
--     * the collector talks to the target directly, so the OPENQUERY(@SERVER)
--       wrapper and #DBS cursor are unnecessary - replaced with one dynamic
--       UNION ALL over sys.databases (database_id >= 5, ONLINE only)
--     * guarded for pre-2016 servers (sys.masked_columns absent -> empty
--       result instead of a compile error)
--     * added schema_name; COLLATE DATABASE_DEFAULT on every string column
--       so cross-database collation differences cannot break the UNION
--     * dropped is_masked (constant 1 by definition of sys.masked_columns)
--   2016+ feature; earlier versions return the empty shape. Needs db access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-020','HLTH','SQL','SYS','Dynamic Data Masking Inventory','masked-columns-inventory',
        'Inventory of every column protected by Dynamic Data Masking across all user databases: where masking is applied and with which function.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-020-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-020-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-020-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-020-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-020-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-020-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-020-RC01', 'HLTH-SQL-SYS-020', 'Masked columns inventory captured',
    'masked-columns-inventory-rc01',
    'All DDM-masked columns across every ONLINE user database: database, schema, table, column and masking function. Zero rows means no Dynamic Data Masking is in use (or the server predates 2016). Correlates with the sensitive-columns tracking and auto-mask features: sensitive columns WITHOUT a mask are the actionable gap.',
    ARRAY['health', 'masking', 'ddm', 'data-protection', 'inventory'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-020-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nDECLARE @sql nvarchar(max) = N'''';\nIF OBJECT_ID(N''sys.masked_columns'') IS NULL\nBEGIN\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS schema_name,\n           CAST(NULL AS sysname) AS table_name, CAST(NULL AS sysname) AS column_name,\n           CAST(NULL AS nvarchar(4000)) AS masking_function\n    WHERE 1 = 0;\n    RETURN;\nEND;\nSELECT @sql = @sql + N'' UNION ALL SELECT N'''''' + REPLACE(name, '''''''', '''''''''''') + N'''''' COLLATE DATABASE_DEFAULT AS database_name,''\n    + N'' sch.name COLLATE DATABASE_DEFAULT AS schema_name, t.name COLLATE DATABASE_DEFAULT AS table_name,''\n    + N'' c.name COLLATE DATABASE_DEFAULT AS column_name, m.masking_function COLLATE DATABASE_DEFAULT AS masking_function''\n    + N'' FROM '' + QUOTENAME(name) + N''.sys.masked_columns m''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.columns c ON c.object_id = m.object_id AND c.column_id = m.column_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.tables t ON t.object_id = m.object_id''\n    + N'' JOIN '' + QUOTENAME(name) + N''.sys.schemas sch ON sch.schema_id = t.schema_id''\nFROM sys.databases\nWHERE database_id >= 5 AND state = 0;\nIF @sql = N''''\n    SELECT CAST(NULL AS sysname) AS database_name, CAST(NULL AS sysname) AS schema_name,\n           CAST(NULL AS sysname) AS table_name, CAST(NULL AS sysname) AS column_name,\n           CAST(NULL AS nvarchar(4000)) AS masking_function\n    WHERE 1 = 0;\nELSE\nBEGIN\n    SET @sql = STUFF(@sql, 1, 11, N'''');\n    EXEC(@sql);\nEND"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Masked columns found (zero rows = no DDM in use on this instance)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET
    content = EXCLUDED.content, expected = EXCLUDED.expected;

DO $gen$
DECLARE
    v_step_id   bigint;
    v_path_id   bigint;
    v_res_step  bigint;
    v_res_path  bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-020-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-020-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-020-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-020-RC01 (sqlserver)', 'Masked columns inventory captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-020-RC01 (sqlserver)', '{"action": "Cross-check against the sensitive-columns catalog (metrics.sensitive_columns): a column classified sensitive but absent here is unprotected - candidate for auto_mask; default() on numerics returns 0 which can silently break aggregates - verify the function fits the consumer; remember DDM is presentation-layer only (UNMASK permission and inference attacks bypass it) - it complements, not replaces, encryption and access control."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-020-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-020-RC01 (sqlserver)', 'resolve-hlth_sql_sys_020_rc01-sqlserver', 'Masked columns inventory captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_020_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'schema_name')                 AS schema_name,
    (j.value ->> 'table_name')                  AS table_name,
    (j.value ->> 'column_name')                 AS column_name,
    (j.value ->> 'masking_function')            AS masking_function,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-020-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_020_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_020_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-020-RC01';

COMMIT;
