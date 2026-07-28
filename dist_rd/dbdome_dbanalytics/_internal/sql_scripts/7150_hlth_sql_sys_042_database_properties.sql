-- ============================================================
-- 7150  HLTH-SQL-SYS-042-RC01  Database properties & log state captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base recovery-model query:
--     * LEFT JOIN (not INNER) to the log perf counters so a database with
--       no counter row still appears; ls.cntr_value > 0 filter dropped
--       (it hid databases and the base then divided anyway)
--     * log KB -> MB, exact log_used_pct via NULLIF
--     * added state, is_encrypted (TDE); NOLOCK/RECOMPILE dropped
--   2008+ (is_encrypted 2008; is_auto_update_stats_async 2005). No special
--   permission beyond catalog visibility + VIEW SERVER STATE for counters.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-042','HLTH','SQL','SYS','Database Properties & Log State','database-properties',
        'Per-database recovery model, log reuse wait, transaction log size/usage, and the safety/perf option flags in one row.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-042-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-042-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-042-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-042-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-042-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-042-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-042-RC01', 'HLTH-SQL-SYS-042', 'Database properties & log state captured',
    'database-properties-rc01',
    'Every database with: state, recovery model, log_reuse_wait (why the log cannot truncate), log size/used MB and percent, compatibility level, page verify option (CHECKSUM expected), the auto-stats/auto-close/auto-shrink flags, forced parameterization, snapshot isolation / RCSI state, CDC and TDE flags. The configuration-and-log-health baseline per database; feeds drift detection and log-growth root causes.',
    ARRAY['health', 'databases', 'configuration', 'log', 'recovery-model'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-042-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT TOP 500\n    db.name AS database_name,\n    db.state_desc AS state,\n    db.recovery_model_desc AS recovery_model,\n    db.log_reuse_wait_desc AS log_reuse_wait,\n    CONVERT(bigint, ls.cntr_value/1024) AS log_size_mb,\n    CONVERT(bigint, lu.cntr_value/1024) AS log_used_mb,\n    CAST(lu.cntr_value * 100.0 / NULLIF(ls.cntr_value, 0) AS decimal(5,2)) AS log_used_pct,\n    db.compatibility_level,\n    db.page_verify_option_desc AS page_verify,\n    db.is_auto_create_stats_on,\n    db.is_auto_update_stats_on,\n    db.is_auto_update_stats_async_on,\n    db.is_parameterization_forced,\n    db.snapshot_isolation_state_desc AS snapshot_isolation,\n    db.is_read_committed_snapshot_on AS is_rcsi_on,\n    db.is_auto_close_on,\n    db.is_auto_shrink_on,\n    db.is_cdc_enabled,\n    db.is_encrypted AS is_tde_on\nFROM sys.databases db\nLEFT JOIN sys.dm_os_performance_counters lu\n    ON lu.instance_name = db.name AND lu.counter_name LIKE N''Log File(s) Used Size (KB)%''\nLEFT JOIN sys.dm_os_performance_counters ls\n    ON ls.instance_name = db.name AND ls.counter_name LIKE N''Log File(s) Size (KB)%''\nORDER BY log_used_pct DESC, db.name"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Database properties captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-042-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-042-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-042-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-042-RC01 (sqlserver)', 'Database properties & log state captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-042-RC01 (sqlserver)', '{"action": "log_used_pct near 100 plus a log_reuse_wait other than NOTHING is the log-full diagnosis IN ONE ROW: LOG_BACKUP = take a log backup (FULL recovery without log backups - SYS-031), ACTIVE_TRANSACTION = a long open transaction (SYS-003), REPLICATION/AVAILABILITY_REPLICA = a lagging consumer; is_auto_shrink_on = 1 or is_auto_close_on = 1 are anti-patterns (turn off); page_verify not CHECKSUM leaves torn-page corruption undetected; compatibility_level far below the engine version blocks optimizer features; RCSI/snapshot state matters for the blocking guidance in SYS-013."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-042-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-042-RC01 (sqlserver)', 'resolve-hlth_sql_sys_042_rc01-sqlserver', 'Database properties & log state captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_042_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_042_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')                 AS database_name,
    (j.value ->> 'state')                         AS state,
    (j.value ->> 'recovery_model')                AS recovery_model,
    (j.value ->> 'log_reuse_wait')                AS log_reuse_wait,
    (j.value ->> 'log_size_mb')::bigint           AS log_size_mb,
    (j.value ->> 'log_used_mb')::bigint           AS log_used_mb,
    (j.value ->> 'log_used_pct')::numeric         AS log_used_pct,
    (j.value ->> 'compatibility_level')::int      AS compatibility_level,
    (j.value ->> 'page_verify')                   AS page_verify,
    (j.value ->> 'is_auto_create_stats_on')::int  AS is_auto_create_stats_on,
    (j.value ->> 'is_auto_update_stats_on')::int  AS is_auto_update_stats_on,
    (j.value ->> 'is_auto_update_stats_async_on')::int AS is_auto_update_stats_async_on,
    (j.value ->> 'is_parameterization_forced')::int AS is_parameterization_forced,
    (j.value ->> 'snapshot_isolation')            AS snapshot_isolation,
    (j.value ->> 'is_rcsi_on')::int               AS is_rcsi_on,
    (j.value ->> 'is_auto_close_on')::int         AS is_auto_close_on,
    (j.value ->> 'is_auto_shrink_on')::int        AS is_auto_shrink_on,
    (j.value ->> 'is_cdc_enabled')::int           AS is_cdc_enabled,
    (j.value ->> 'is_tde_on')::int                AS is_tde_on,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-042-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_042_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_042_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-042-RC01';

COMMIT;
