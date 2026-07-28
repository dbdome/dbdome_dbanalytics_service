-- =============================================================================
-- 6110_data_hierarchy_rootcause.sql
-- Root cause SEC-SQL-DSC-001-RC01 "Server data hierarchy" — returns the full
-- SERVER -> database -> schema -> table -> column tree for a SQL Server, so the UI
-- can drive a server/data hierarchy picker (select server -> database -> tables).
-- Registered like every other RC (issue + root_cause + detection_step +
-- detection_path). Idempotent (ON CONFLICT / guarded inserts).
-- =============================================================================

-- 0a) AREA (FK target for the issue) ----------------------------------------
INSERT INTO rootcause.areas (code, database_type_code, name, description, is_enabled, category_id)
SELECT 'DSC','SQL','Data Structure Discovery','Server data hierarchy / data discovery scoping', true, 'c001'
WHERE NOT EXISTS (SELECT 1 FROM rootcause.areas WHERE code='DSC' AND database_type_code='SQL');

-- 0) ISSUE -------------------------------------------------------------------
INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, category_id)
VALUES ('SEC-SQL-DSC-001','SEC','SQL','DSC','Data Structure Discovery',
        'data-structure-discovery',
        'Inventory of the server data hierarchy (databases, schemas, tables and columns) used to drive data-protection scoping and classification.',
        'c001')
ON CONFLICT (issue_id) DO NOTHING;

-- 1) ROOT CAUSE --------------------------------------------------------------
INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'SEC-SQL-DSC-001-RC01','SEC-SQL-DSC-001','Server data hierarchy (databases -> schemas -> tables -> columns)',
    'server-data-hierarchy',
    'Enumerates the full data hierarchy of the server: every user database, its schemas, tables and columns (with data type). Powers the server/data tree used to select where RBAC and data-protection controls apply.',
    ARRAY['data discovery','hierarchy','schema','inventory','classification'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

-- 2) DETECTION STEP (sqlserver) ---------------------------------------------
-- One UNION ALL result set across all accessible user databases (3-part names, no
-- USE), one row per column: server, database, schema, table, column, data_type.
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver','query','Detect SEC-SQL-DSC-001-RC01 (sqlserver)',
    jsonb_build_object('sql', $q$
SET NOCOUNT ON;
DECLARE @sql nvarchar(max) = N'';
SELECT @sql = @sql + N'SELECT @@SERVERNAME AS server, ''' + name + N''' AS database_name, '
    + N's.name AS schema_name, t.name AS table_name, c.name AS column_name, ty.name AS data_type, c.column_id AS ordinal '
    + N'FROM ' + QUOTENAME(name) + N'.sys.tables t '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.schemas s ON s.schema_id = t.schema_id '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.columns c ON c.object_id = t.object_id '
    + N'JOIN ' + QUOTENAME(name) + N'.sys.types ty ON ty.user_type_id = c.user_type_id '
    + N'WHERE t.is_ms_shipped = 0 UNION ALL '
FROM sys.databases
WHERE state = 0 AND database_id > 4 AND HAS_DBACCESS(name) = 1
  AND name NOT IN ('distribution','ReportServer','ReportServerTempDB','SSISDB');
IF LEN(@sql) > 10 SET @sql = LEFT(@sql, LEN(@sql) - 10);
IF @sql <> N'' EXEC sys.sp_executesql @sql;
$q$),
    jsonb_build_object('condition','row_count > 0','description','Server data hierarchy enumerated (db/schema/table/column)'))
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

-- 3) DETECTION PATH + STEP ---------------------------------------------------
DO $gen$
DECLARE v_step_id bigint; v_path_id bigint;
BEGIN
    SELECT id INTO v_step_id FROM rootcause.detection_steps
     WHERE vendor_slug='sqlserver' AND name='Detect SEC-SQL-DSC-001-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id='SEC-SQL-DSC-001-RC01' AND vendor_slug='sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-DSC-001-RC01','sqlserver','Detect SEC-SQL-DSC-001-RC01 (sqlserver)',
                'Server data hierarchy', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
    END IF;
END
$gen$;
