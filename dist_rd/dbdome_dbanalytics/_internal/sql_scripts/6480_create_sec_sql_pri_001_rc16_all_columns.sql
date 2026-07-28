-- ============================================================
-- New root cause: SEC-SQL-PRI-001-RC16  "All columns discovered in schema"
--
-- Same schema-mapping detection as SEC-SQL-PRI-001-RC12 (sensitive columns),
-- but WITHOUT the sensitive/PII filter -- it inventories EVERY column of every
-- user table. RC12 is fed a pre-computed sensitive-column list via a placeholder;
-- RC16 instead runs a straight schema-inventory query per vendor that returns the
-- same output shape (db_name, schema_name, table_name, column_name, data_type,
-- max_length, pii_category[=NULL]).
--
-- Clones RC12's detection paths (5 vendors x high/medium) and resolution paths
-- into RC16, swapping the detection content for the all-columns query, and
-- creates the presentation view monitoring.v_sec_sql_pri_001_rc16 (mirrors
-- v_sec_sql_pri_001_rc12). Idempotent: re-running is a no-op once RC16 exists.
-- ============================================================

BEGIN;

DO $do$
DECLARE
    v_step int;
    v_path int;
    r      record;
BEGIN
    IF EXISTS (SELECT 1 FROM rootcause.detection_paths
               WHERE root_cause_id = 'SEC-SQL-PRI-001-RC16') THEN
        RAISE NOTICE 'SEC-SQL-PRI-001-RC16 already present - skipping';
        RETURN;
    END IF;

    -- 1) root cause (copy RC12 metadata, new id/name/slug/description) --------
    INSERT INTO rootcause.root_causes
        (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
    SELECT 'SEC-SQL-PRI-001-RC16', issue_id,
           'All columns discovered in schema',
           'all-columns-discovered',
           'Full inventory of every column in the database schema (all columns, not '
           'just sensitive/PII columns) - the same schema-mapping detection as '
           'SEC-SQL-PRI-001-RC12 but without the sensitive-column filter. Provides '
           'complete column coverage for data classification and schema auditing.',
           topics, vendors_applicable
    FROM rootcause.root_causes
    WHERE root_cause_id = 'SEC-SQL-PRI-001-RC12'
    ON CONFLICT (root_cause_id) DO NOTHING;

    -- 2) one detection step per vendor: an ALL-COLUMNS schema-inventory query --
    CREATE TEMP TABLE _rc16_step (vendor text PRIMARY KEY, step_id int) ON COMMIT DROP;

    FOR r IN
        SELECT * FROM (VALUES
        ('sqlserver', $ss$SET NOCOUNT ON;
SELECT
    DB_NAME()                  AS db_name,
    s.name                     AS schema_name,
    t.name                     AS table_name,
    c.name                     AS column_name,
    ty.name                    AS data_type,
    c.max_length               AS max_length,
    CAST(NULL AS nvarchar(50)) AS pii_category
FROM sys.columns c
JOIN sys.tables  t  ON t.object_id     = c.object_id
JOIN sys.schemas s  ON s.schema_id     = t.schema_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id
ORDER BY s.name, t.name, c.column_id;$ss$),
        ('oracle', $or$SELECT
    SYS_CONTEXT('USERENV','DB_NAME') AS db_name,
    owner                            AS schema_name,
    table_name                       AS table_name,
    column_name                      AS column_name,
    data_type                        AS data_type,
    data_length                      AS max_length,
    CAST(NULL AS VARCHAR2(50))       AS pii_category
FROM all_tab_columns
WHERE owner NOT IN ('SYS','SYSTEM','XDB','MDSYS','CTXSYS','DBSNMP','OUTLN',
    'APPQOSSYS','ORDSYS','WMSYS','GSMADMIN_INTERNAL','AUDSYS','DVSYS','LBACSYS',
    'OJVMSYS','ORDDATA','OLAPSYS')
ORDER BY owner, table_name, column_id$or$),
        ('postgresql', $pg$SELECT
    current_database()         AS db_name,
    c.table_schema             AS schema_name,
    c.table_name               AS table_name,
    c.column_name              AS column_name,
    c.data_type                AS data_type,
    c.character_maximum_length AS max_length,
    NULL::text                 AS pii_category
FROM information_schema.columns c
JOIN information_schema.tables t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
 AND t.table_type = 'BASE TABLE'
WHERE c.table_schema NOT IN ('pg_catalog','information_schema')
ORDER BY c.table_schema, c.table_name, c.ordinal_position;$pg$),
        ('mysql', $my$SELECT
    TABLE_SCHEMA             AS db_name,
    TABLE_SCHEMA             AS schema_name,
    TABLE_NAME               AS table_name,
    COLUMN_NAME              AS column_name,
    DATA_TYPE                AS data_type,
    CHARACTER_MAXIMUM_LENGTH AS max_length,
    NULL                     AS pii_category
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;$my$),
        ('mariadb', $md$SELECT
    TABLE_SCHEMA             AS db_name,
    TABLE_SCHEMA             AS schema_name,
    TABLE_NAME               AS table_name,
    COLUMN_NAME              AS column_name,
    DATA_TYPE                AS data_type,
    CHARACTER_MAXIMUM_LENGTH AS max_length,
    NULL                     AS pii_category
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;$md$)
        ) v(vendor, sqltext)
    LOOP
        INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
        VALUES (
            r.vendor,
            COALESCE((SELECT s.step_type FROM rootcause.detection_paths dp
                      JOIN rootcause.detection_path_steps ps ON ps.detection_path_id = dp.id
                      JOIN rootcause.detection_steps s ON s.id = ps.detection_step_id
                      WHERE dp.root_cause_id='SEC-SQL-PRI-001-RC12' AND s.vendor_slug=r.vendor
                      LIMIT 1), 'query'),
            'Discover all columns in schema (' || r.vendor || ')',
            jsonb_build_object('sql', r.sqltext),
            jsonb_build_object('condition','row_count > 0',
                               'description','All columns in database schema')
        )
        RETURNING id INTO v_step;
        INSERT INTO _rc16_step VALUES (r.vendor, v_step);
    END LOOP;

    -- 3) clone RC12's detection paths -> RC16, each linked to the same-vendor step
    FOR r IN
        SELECT dp.vendor_slug, dp.name, dp.path_type, dp.is_active,
               dps.sequence, dps.on_match_action, dps.on_match_goto,
               dps.on_no_match_action, dps.on_no_match_goto, dps.notes
        FROM rootcause.detection_paths dp
        JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
        WHERE dp.root_cause_id = 'SEC-SQL-PRI-001-RC12'
    LOOP
        INSERT INTO rootcause.detection_paths
            (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-PRI-001-RC16', r.vendor_slug,
                replace(r.name, 'sensitive columns', 'all columns'),
                'Inventory all columns via schema analysis',
                r.path_type, r.is_active)
        RETURNING id INTO v_path;

        INSERT INTO rootcause.detection_path_steps
            (detection_path_id, detection_step_id, sequence,
             on_match_action, on_match_goto, on_no_match_action, on_no_match_goto, notes)
        VALUES (v_path,
                (SELECT step_id FROM _rc16_step WHERE vendor = r.vendor_slug),
                COALESCE(r.sequence, 1), r.on_match_action, r.on_match_goto,
                r.on_no_match_action, r.on_no_match_goto, r.notes);
    END LOOP;

    -- 4) clone RC12's resolution paths -> RC16 (reuse RC12's resolution steps) --
    CREATE TEMP TABLE _rc16_respath (old_id int, new_id int) ON COMMIT DROP;
    FOR r IN SELECT * FROM rootcause.resolution_paths
             WHERE root_cause_id = 'SEC-SQL-PRI-001-RC12'
    LOOP
        INSERT INTO rootcause.resolution_paths
            (root_cause_id, vendor_slug, name, slug, description, execution_mode,
             risk_level, risk_description, status, prerequisites, is_active,
             min_version, max_version)
        VALUES ('SEC-SQL-PRI-001-RC16', r.vendor_slug,
                replace(r.name, 'sensitive columns', 'all columns'),
                r.slug || '-rc16', r.description, r.execution_mode, r.risk_level,
                r.risk_description, r.status, r.prerequisites, r.is_active,
                r.min_version, r.max_version)
        RETURNING id INTO v_path;
        INSERT INTO _rc16_respath VALUES (r.id, v_path);
    END LOOP;

    INSERT INTO rootcause.resolution_path_steps
        (resolution_path_id, resolution_step_id, step_order, condition,
         on_success, on_success_goto, on_failure, on_failure_goto, notes)
    SELECT m.new_id, rps.resolution_step_id, rps.step_order, rps.condition,
           rps.on_success, rps.on_success_goto, rps.on_failure, rps.on_failure_goto, rps.notes
    FROM _rc16_respath m
    JOIN rootcause.resolution_path_steps rps ON rps.resolution_path_id = m.old_id;

    RAISE NOTICE 'SEC-SQL-PRI-001-RC16 created';
END $do$;

-- 5) presentation view (mirrors monitoring.v_sec_sql_pri_001_rc12) ------------
DROP VIEW IF EXISTS monitoring.v_sec_sql_pri_001_rc16;
CREATE OR REPLACE VIEW monitoring.v_sec_sql_pri_001_rc16 AS
SELECT
    r.server,
    COALESCE(j.value ->> 'owner', j.value ->> 'name') AS username,
    j.value ->> 'max_length' AS max_length,
    j.value ->> 'table_name' AS table_name,
    j.value ->> 'column_name' AS column_name,
    j.value ->> 'data_type' AS data_type,
    j.value ->> 'data_length' AS data_length,
    j.value ->> 'pii_category' AS pii_category,
    j.value ->> 'table_schema' AS table_schema,
    j.value ->> 'character_maximum_length' AS character_maximum_length,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'SEC-SQL-PRI-001-RC16';

COMMIT;   -- or ROLLBACK;
