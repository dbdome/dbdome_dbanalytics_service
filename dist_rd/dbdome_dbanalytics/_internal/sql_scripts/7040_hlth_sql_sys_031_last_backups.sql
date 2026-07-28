-- ============================================================
-- 7040  HLTH-SQL-SYS-031-RC01  Latest backups per database & type captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base last-backup query:
--     * driven from sys.databases so never-backed-up databases APPEAR
--       (the base only listed databases present in backupset)
--     * current recovery model from sys.databases (the base showed the
--       model recorded at backup time - stale after ALTER DATABASE)
--     * backup_size/1000000 pseudo-MB fixed to /1048576; TimeTaken
--       varchar(4) overflow replaced with integer seconds; added
--       hours_since, compressed size and is_copy_only
--   2008+ (compressed_backup_size). Requires msdb read access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-031','HLTH','SQL','SYS','Backup Recency & Chain','last-backups-per-type',
        'Latest backup per database per type (Full/Differential/Log) with device, LSN chain, size and duration - and databases with NO backup at all.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-031-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-031-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-031-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-031-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-031-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-031-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-031-RC01', 'HLTH-SQL-SYS-031', 'Latest backups per database & type captured',
    'last-backups-per-type-rc01',
    'Driven from sys.databases (tempdb excluded) so a database with NO backup history still appears (with NULL backup columns - the loudest finding): per database and backup type, the most recent backup with start time, hours since, duration, raw and compressed size, copy-only flag, target device, first/last LSN (chain verification) and the current recovery model. Complements HLTH-SQL-SYS-019 (growth trend) with recovery-readiness.',
    ARRAY['health', 'backups', 'recovery', 'rpo', 'lsn'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-031-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH b AS (\n    SELECT s.database_name, s.type,\n           ROW_NUMBER() OVER (PARTITION BY s.database_name, s.type ORDER BY s.backup_start_date DESC) AS rn,\n           s.backup_start_date, s.backup_finish_date, s.backup_size, s.compressed_backup_size,\n           s.first_lsn, s.last_lsn, s.server_name, s.is_copy_only, s.media_set_id\n    FROM msdb.dbo.backupset s\n)\nSELECT TOP 500\n    d.name AS database_name,\n    d.recovery_model_desc AS current_recovery_model,\n    CASE lb.type WHEN ''D'' THEN ''Full'' WHEN ''I'' THEN ''Differential'' WHEN ''L'' THEN ''TransactionLog'' ELSE lb.type END AS backup_type,\n    CONVERT(varchar(19), lb.backup_start_date, 120) AS backup_start,\n    DATEDIFF(SECOND, lb.backup_start_date, lb.backup_finish_date) AS duration_sec,\n    DATEDIFF(HOUR, lb.backup_start_date, GETDATE()) AS hours_since,\n    CAST(lb.backup_size/1048576.0 AS decimal(18,1)) AS backup_mb,\n    CAST(lb.compressed_backup_size/1048576.0 AS decimal(18,1)) AS compressed_mb,\n    lb.is_copy_only,\n    m.physical_device_name,\n    CAST(lb.first_lsn AS varchar(50)) AS first_lsn,\n    CAST(lb.last_lsn AS varchar(50)) AS last_lsn,\n    lb.server_name\nFROM sys.databases d\nLEFT JOIN b lb ON lb.database_name = d.name AND lb.rn = 1\nLEFT JOIN msdb.dbo.backupmediafamily m ON m.media_set_id = lb.media_set_id\nWHERE d.database_id <> 2\nORDER BY d.name, backup_type"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Backup recency rows captured (NULL backup columns = database never backed up)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-031-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-031-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-031-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-031-RC01 (sqlserver)', 'Latest backups per database & type captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-031-RC01 (sqlserver)', '{"action": "A FULL-recovery database whose newest TransactionLog row is old (or absent) has an unbounded RPO and a growing log - schedule log backups or switch to SIMPLE deliberately; NULL backup_type rows are databases with no backup at all; hours_since on the Full row against your RPO policy is the core alert; physical_device_name on the same volume as the data files means backups die with the disk; is_copy_only = 1 does not advance the differential base or log chain."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-031-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-031-RC01 (sqlserver)', 'resolve-hlth_sql_sys_031_rc01-sqlserver', 'Latest backups per database & type captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_031_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_031_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')               AS database_name,
    (j.value ->> 'current_recovery_model')      AS current_recovery_model,
    (j.value ->> 'backup_type')                 AS backup_type,
    (j.value ->> 'backup_start')                AS backup_start,
    (j.value ->> 'duration_sec')::bigint        AS duration_sec,
    (j.value ->> 'hours_since')::bigint         AS hours_since,
    (j.value ->> 'backup_mb')::numeric          AS backup_mb,
    (j.value ->> 'compressed_mb')::numeric      AS compressed_mb,
    (j.value ->> 'is_copy_only')::int           AS is_copy_only,
    (j.value ->> 'physical_device_name')        AS physical_device_name,
    (j.value ->> 'first_lsn')                   AS first_lsn,
    (j.value ->> 'last_lsn')                    AS last_lsn,
    (j.value ->> 'server_name')                 AS server_name,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-031-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_031_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_031_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-031-RC01';

COMMIT;
