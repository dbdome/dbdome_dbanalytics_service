-- ============================================================
-- 6920  HLTH-SQL-SYS-019-RC01  Database growth from backup history captured (sqlserver)
--   HEALTH system series root cause.
--   Rebuilt from the base backupset LAG query:
--     * windowed to the last 90 days (the base scanned ALL history)
--     * LAG replaced with a ROW_NUMBER self-join - works on 2008/2008R2
--       (LAG needs 2012+)
--     * added latest and compressed backup size, first/last backup dates,
--       days_since_last_full (recovery-risk) and growth_mb_per_day
--       (first-to-last delta over the window - the capacity number)
--     * exact MB (decimal) instead of CAST-to-INT truncation
--   2008+ (compressed_backup_size). Requires msdb read access.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-019','HLTH','SQL','SYS','Database Growth Trend','database-growth-from-backups',
        'Database growth measured from full-backup sizes over the last 90 days: per-backup deltas, growth rate per day and backup recency.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-019-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-019-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-019-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-019-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-019-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-019-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-019-RC01', 'HLTH-SQL-SYS-019', 'Database growth from backup history captured',
    'database-growth-from-backups-rc01',
    'Per database over the last 90 days of FULL backups: sample count, first/last backup times, days since the last full (recovery-risk signal), latest backup size and compressed size, avg/max/min and LATEST size delta between consecutive backups, and derived growth MB/day. Zero rows means NO full backups in 90 days - a finding on its own.',
    ARRAY['health', 'growth', 'backups', 'capacity', 'trend'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-019-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nWITH b AS (\n    SELECT database_name,\n           backup_start_date,\n           CAST(backup_size/1048576.0 AS decimal(18,1)) AS backup_mb,\n           CAST(compressed_backup_size/1048576.0 AS decimal(18,1)) AS compressed_mb,\n           ROW_NUMBER() OVER (PARTITION BY database_name ORDER BY backup_start_date) AS rn,\n           ROW_NUMBER() OVER (PARTITION BY database_name ORDER BY backup_start_date DESC) AS rn_desc\n    FROM msdb.dbo.backupset\n    WHERE type = ''D'' AND backup_start_date >= DATEADD(DAY, -90, GETDATE())\n), agg AS (\n    SELECT database_name, COUNT(*) AS sample_count,\n           MIN(backup_start_date) AS first_backup, MAX(backup_start_date) AS last_backup\n    FROM b GROUP BY database_name\n), diffs AS (\n    SELECT cur.database_name,\n           CAST(AVG(cur.backup_mb - prev.backup_mb) AS decimal(18,1)) AS avg_diff_mb,\n           CAST(MAX(cur.backup_mb - prev.backup_mb) AS decimal(18,1)) AS max_diff_mb,\n           CAST(MIN(cur.backup_mb - prev.backup_mb) AS decimal(18,1)) AS min_diff_mb\n    FROM b cur\n    JOIN b prev ON prev.database_name = cur.database_name AND prev.rn = cur.rn - 1\n    GROUP BY cur.database_name\n), lastd AS (\n    SELECT cur.database_name,\n           CAST(cur.backup_mb - prev.backup_mb AS decimal(18,1)) AS last_diff_mb\n    FROM b cur\n    JOIN b prev ON prev.database_name = cur.database_name AND prev.rn_desc = 2\n    WHERE cur.rn_desc = 1\n)\nSELECT a.database_name,\n       a.sample_count,\n       CONVERT(varchar(19), a.first_backup, 120) AS first_backup,\n       CONVERT(varchar(19), a.last_backup, 120) AS last_backup,\n       DATEDIFF(DAY, a.last_backup, GETDATE()) AS days_since_last_full,\n       l.backup_mb AS latest_backup_mb,\n       l.compressed_mb AS latest_compressed_mb,\n       d.avg_diff_mb,\n       d.max_diff_mb,\n       d.min_diff_mb,\n       ld.last_diff_mb,\n       CAST(CASE WHEN DATEDIFF(DAY, a.first_backup, a.last_backup) > 0\n                 THEN (l.backup_mb - f.backup_mb) / DATEDIFF(DAY, a.first_backup, a.last_backup)\n                 END AS decimal(18,2)) AS growth_mb_per_day\nFROM agg a\nJOIN b l ON l.database_name = a.database_name AND l.rn_desc = 1\nJOIN b f ON f.database_name = a.database_name AND f.rn = 1\nLEFT JOIN diffs d ON d.database_name = a.database_name\nLEFT JOIN lastd ld ON ld.database_name = a.database_name\nORDER BY ISNULL(d.avg_diff_mb, 0) DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Full-backup history present (zero rows = no full backups in 90 days)"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-019-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-019-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-019-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-019-RC01 (sqlserver)', 'Database growth from backup history captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-019-RC01 (sqlserver)', '{"action": "growth_mb_per_day is the capacity-planning number - project it against volume free space; a sudden max_diff_mb spike names the day data ballooned (correlate application events); negative avg_diff_mb after shrink/archive is expected - otherwise investigate; days_since_last_full above your RPO policy is a recovery risk regardless of growth (correlate HLTH-SQL-BR-001); compare latest_backup_mb to latest_compressed_mb to see whether backup compression is on and effective."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-019-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-019-RC01 (sqlserver)', 'resolve-hlth_sql_sys_019_rc01-sqlserver', 'Database growth from backup history captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_019_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_019_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')                 AS database_name,
    (j.value ->> 'sample_count')::int             AS sample_count,
    (j.value ->> 'first_backup')                  AS first_backup,
    (j.value ->> 'last_backup')                   AS last_backup,
    (j.value ->> 'days_since_last_full')::int     AS days_since_last_full,
    (j.value ->> 'latest_backup_mb')::numeric     AS latest_backup_mb,
    (j.value ->> 'latest_compressed_mb')::numeric AS latest_compressed_mb,
    (j.value ->> 'avg_diff_mb')::numeric          AS avg_diff_mb,
    (j.value ->> 'max_diff_mb')::numeric          AS max_diff_mb,
    (j.value ->> 'min_diff_mb')::numeric          AS min_diff_mb,
    (j.value ->> 'last_diff_mb')::numeric         AS last_diff_mb,
    (j.value ->> 'growth_mb_per_day')::numeric    AS growth_mb_per_day,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-019-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_019_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_019_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-019-RC01';

COMMIT;
