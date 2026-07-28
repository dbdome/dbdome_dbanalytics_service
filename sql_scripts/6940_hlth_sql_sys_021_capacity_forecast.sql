-- ============================================================
-- 6940  HLTH-SQL-SYS-021-RC01  Capacity forecast per file & volume captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base master_files/volume_stats query, fixing:
--     * DB_ID(f.name) passed a LOGICAL FILE name as a database name into
--       dm_os_volume_stats -> NULL; now dm_os_volume_stats(mf.database_id,
--       mf.file_id) per master_files row
--     * the volume CTE read sys.database_files of the CONNECTED db only;
--       master_files covers every database
--     * the TA join condition repeated the T condition, cross-joining
--       volumes; now a proper per-file CROSS APPLY
--     * days-to-exceed now uses growth PER DAY from 90d of backup history
--       (the base divided by avg-per-BACKUP + 1)
--     * added max_size cap, volume percent free, growth_setting decoded
--   2008 R2+ (dm_os_volume_stats). Requires VIEW SERVER STATE + msdb read.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-021','HLTH','SQL','SYS','Storage Capacity Forecast','capacity-forecast',
        'Per file: size, autogrowth setting, hosting volume free space, backup-derived growth rate and projected days until the volume fills.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-021-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-021-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-021-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-021-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-021-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-021-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-021-RC01', 'HLTH-SQL-SYS-021', 'Capacity forecast per file & volume captured',
    'capacity-forecast-rc01',
    'Every database file with its size, autogrowth setting (percent growth flagged - a smell on big files), max-size cap, the hosting VOLUME total/available/percent-free, the database growth rate derived from 90 days of full-backup history, and days_to_full = available space / growth per day. Files on the most-at-risk volumes sort first.',
    ARRAY['health', 'capacity', 'storage', 'growth', 'forecast'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-021-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH b AS (\n    SELECT database_name, backup_start_date,\n           CAST(backup_size/1048576.0 AS decimal(18,1)) AS mb,\n           ROW_NUMBER() OVER (PARTITION BY database_name ORDER BY backup_start_date) AS rn,\n           ROW_NUMBER() OVER (PARTITION BY database_name ORDER BY backup_start_date DESC) AS rn_desc\n    FROM msdb.dbo.backupset\n    WHERE type = ''D'' AND backup_start_date >= DATEADD(DAY, -90, GETDATE())\n), g AS (\n    SELECT l.database_name,\n           CAST(CASE WHEN DATEDIFF(DAY, f.backup_start_date, l.backup_start_date) > 0\n                     THEN (l.mb - f.mb) / DATEDIFF(DAY, f.backup_start_date, l.backup_start_date)\n                     END AS decimal(18,2)) AS growth_mb_per_day\n    FROM b l\n    JOIN b f ON f.database_name = l.database_name AND f.rn = 1\n    WHERE l.rn_desc = 1\n)\nSELECT TOP 500\n    DB_NAME(mf.database_id) AS database_name,\n    mf.name AS logical_file_name,\n    mf.physical_name,\n    mf.type_desc,\n    mf.state_desc,\n    mf.is_percent_growth,\n    CASE WHEN mf.is_percent_growth = 1 THEN CONVERT(varchar(10), mf.growth) + '' %''\n         ELSE CONVERT(varchar(20), mf.growth/128) + '' MB'' END AS growth_setting,\n    CONVERT(bigint, mf.size/128.0) AS file_size_mb,\n    CASE WHEN mf.max_size IN (-1, 268435456) THEN NULL\n         ELSE CONVERT(bigint, mf.max_size/128.0) END AS max_size_mb,\n    vs.volume_mount_point,\n    CONVERT(bigint, vs.total_bytes/1048576) AS volume_total_mb,\n    CONVERT(bigint, vs.available_bytes/1048576) AS volume_available_mb,\n    CAST(vs.available_bytes * 100.0 / NULLIF(vs.total_bytes, 0) AS decimal(5,2)) AS volume_free_pct,\n    g.growth_mb_per_day,\n    CASE WHEN g.growth_mb_per_day > 0\n         THEN CONVERT(bigint, vs.available_bytes/1048576.0 / g.growth_mb_per_day)\n         END AS days_to_full\nFROM sys.master_files mf\nCROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs\nLEFT JOIN g ON g.database_name = DB_NAME(mf.database_id)\nORDER BY days_to_full ASC, volume_free_pct ASC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "File and volume capacity data captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-021-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-021-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-021-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-021-RC01 (sqlserver)', 'Capacity forecast per file & volume captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-021-RC01 (sqlserver)', '{"action": "days_to_full below your provisioning lead time is the action trigger - archive, shrink after archiving, or extend the volume; is_percent_growth = 1 on large files causes progressively bigger growth events and stalls (switch to fixed MB); several databases sharing one volume compound the risk - sum their growth rates against that volume; growth_mb_per_day is NULL when fewer than two full backups exist in 90 days (fix backups first - correlate HLTH-SQL-SYS-019)."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-021-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-021-RC01 (sqlserver)', 'resolve-hlth_sql_sys_021_rc01-sqlserver', 'Capacity forecast per file & volume captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

CREATE OR REPLACE VIEW monitoring.v_hlth_sql_sys_021_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')                 AS database_name,
    (j.value ->> 'logical_file_name')             AS logical_file_name,
    (j.value ->> 'physical_name')                 AS physical_name,
    (j.value ->> 'type_desc')                     AS type_desc,
    (j.value ->> 'state_desc')                    AS state_desc,
    (j.value ->> 'is_percent_growth')::int        AS is_percent_growth,
    (j.value ->> 'growth_setting')                AS growth_setting,
    (j.value ->> 'file_size_mb')::bigint          AS file_size_mb,
    (j.value ->> 'max_size_mb')::bigint           AS max_size_mb,
    (j.value ->> 'volume_mount_point')            AS volume_mount_point,
    (j.value ->> 'volume_total_mb')::bigint       AS volume_total_mb,
    (j.value ->> 'volume_available_mb')::bigint   AS volume_available_mb,
    (j.value ->> 'volume_free_pct')::numeric      AS volume_free_pct,
    (j.value ->> 'growth_mb_per_day')::numeric    AS growth_mb_per_day,
    (j.value ->> 'days_to_full')::bigint          AS days_to_full,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-021-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_021_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_021_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-021-RC01';

COMMIT;
