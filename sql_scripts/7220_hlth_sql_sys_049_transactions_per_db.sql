-- ============================================================
-- 7220  HLTH-SQL-SYS-049-RC01  Per-database transaction throughput captured (sqlserver)
--   HEALTH system series root cause.
--   Enriched from the base Transactions/sec counter query:
--     * joined the companion Databases-object counters per database (write
--       transactions, active transactions, log flushes, log bytes flushed)
--       so throughput and WRITE intensity read together
--     * RTRIM on instance/counter names (perf counter names are space-padded
--       to fixed width - equality joins fail without it, a classic trap)
--     * excludes the _Total rollup; documents the cumulative-counter caveat
--   2005+. Requires VIEW SERVER STATE.
--   Idempotent (rebuilds the RC cleanly).
-- ============================================================
BEGIN;

INSERT INTO rootcause.areas (code, database_type_code, name)
VALUES ('SYS', 'SQL', 'System')
ON CONFLICT (code, database_type_code) DO NOTHING;

INSERT INTO rootcause.issues (issue_id, domain_code, database_type_code, area_code, name, slug, description, created_at, updated_at)
VALUES ('HLTH-SQL-SYS-049','HLTH','SQL','SYS','Transaction Throughput by Database','transactions-per-database',
        'Cumulative transaction, write-transaction and log-flush counters per database - the workload-distribution and write-intensity view.',now(),now())
ON CONFLICT (issue_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, updated_at=now();

DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-049-RC01');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SYS-049-RC01';
DELETE FROM rootcause.detection_steps WHERE name LIKE 'Detect HLTH-SQL-SYS-049-RC01 %';
DELETE FROM rootcause.resolution_path_steps WHERE resolution_path_id IN (SELECT id FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-049-RC01');
DELETE FROM rootcause.resolution_paths WHERE root_cause_id='HLTH-SQL-SYS-049-RC01';
DELETE FROM rootcause.resolution_steps WHERE name LIKE 'Resolve: Detect HLTH-SQL-SYS-049-RC01 %';

INSERT INTO rootcause.root_causes (root_cause_id, issue_id, name, slug, description, topics, vendors_applicable)
VALUES (
    'HLTH-SQL-SYS-049-RC01', 'HLTH-SQL-SYS-049', 'Per-database transaction throughput captured',
    'transactions-per-database-rc01',
    'Per-database Databases-object counters: cumulative Transactions/sec, Write Transactions/sec, current Active Transactions, Log Flushes/sec and Log Bytes Flushed - despite the /sec names these are CUMULATIVE tick counters, so real rates come from deltas between collector snapshots. Shows which database carries the workload and how write-intensive it is. Complements the CPU-by-database (SYS-018) and IO-by-database (SYS-008) views with the transaction/log dimension.',
    ARRAY['health', 'transactions', 'throughput', 'workload', 'log'], ARRAY['sqlserver']
) ON CONFLICT (root_cause_id) DO UPDATE SET
    name = EXCLUDED.name, description = EXCLUDED.description,
    topics = EXCLUDED.topics, vendors_applicable = EXCLUDED.vendors_applicable;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect HLTH-SQL-SYS-049-RC01 (sqlserver)',
        '{"sql": "SET NOCOUNT ON;\nSELECT\n    RTRIM(t.instance_name) AS database_name,\n    t.cntr_value AS transactions_total,\n    w.cntr_value AS write_transactions_total,\n    ao.cntr_value AS active_transactions,\n    lf.cntr_value AS log_flushes_total,\n    CONVERT(bigint, lb.cntr_value/1024) AS log_bytes_flushed_kb\nFROM sys.dm_os_performance_counters t\nLEFT JOIN sys.dm_os_performance_counters w\n    ON RTRIM(w.instance_name) = RTRIM(t.instance_name) AND RTRIM(w.counter_name) = ''Write Transactions/sec''\nLEFT JOIN sys.dm_os_performance_counters ao\n    ON RTRIM(ao.instance_name) = RTRIM(t.instance_name) AND RTRIM(ao.counter_name) = ''Active Transactions''\nLEFT JOIN sys.dm_os_performance_counters lf\n    ON RTRIM(lf.instance_name) = RTRIM(t.instance_name) AND RTRIM(lf.counter_name) = ''Log Flushes/sec''\nLEFT JOIN sys.dm_os_performance_counters lb\n    ON RTRIM(lb.instance_name) = RTRIM(t.instance_name) AND RTRIM(lb.counter_name) = ''Log Bytes Flushed/sec''\nWHERE RTRIM(t.counter_name) = ''Transactions/sec''\n  AND RTRIM(t.instance_name) <> ''_Total''\nORDER BY t.cntr_value DESC"}'::jsonb,
        '{"condition": "row_count > 0", "description": "Per-database transaction counters captured"}'::jsonb)
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
     WHERE vendor_slug = 'sqlserver' AND name = 'Detect HLTH-SQL-SYS-049-RC01 (sqlserver)' ORDER BY id DESC LIMIT 1;
    IF v_step_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rootcause.detection_paths
       WHERE root_cause_id = 'HLTH-SQL-SYS-049-RC01' AND vendor_slug = 'sqlserver') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SYS-049-RC01', 'sqlserver', 'Detect HLTH-SQL-SYS-049-RC01 (sqlserver)', 'Per-database transaction throughput captured', 'diagnostic', true) RETURNING id INTO v_path_id;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path_id, v_step_id, 1, 'confirmed', 'ruled_out');
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('sqlserver', 'recommendation', 'Resolve: Detect HLTH-SQL-SYS-049-RC01 (sqlserver)', '{"action": "Trend the DELTAS, not the absolutes: the database with the largest transactions delta is your busiest - size its resources and backups accordingly; a high write-transactions ratio drives log flushes and log-write latency (correlate SYS-011 log file / SYS-044 WRITELOG waits) - that database benefits most from fast log storage; a persistent non-zero Active Transactions with low throughput hints at long-running/idle-open transactions (SYS-003); log_bytes_flushed growth is the real backup and log-shipping volume driver."}'::jsonb, 'low', false, true) RETURNING id INTO v_res_step;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('HLTH-SQL-SYS-049-RC01', 'sqlserver', 'Resolve: Detect HLTH-SQL-SYS-049-RC01 (sqlserver)', 'resolve-hlth_sql_sys_049_rc01-sqlserver', 'Per-database transaction throughput captured: triage guidance.', 'supervised', 'low', true) RETURNING id INTO v_res_path;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_res_path, v_res_step, 1);
    END IF;
END
$gen$;

DROP VIEW IF EXISTS monitoring.v_hlth_sql_sys_049_rc01;
CREATE VIEW monitoring.v_hlth_sql_sys_049_rc01 AS
SELECT r.server,
    r.server_id,
    (j.value ->> 'database_name')                AS database_name,
    (j.value ->> 'transactions_total')::bigint   AS transactions_total,
    (j.value ->> 'write_transactions_total')::bigint AS write_transactions_total,
    (j.value ->> 'active_transactions')::bigint  AS active_transactions,
    (j.value ->> 'log_flushes_total')::bigint    AS log_flushes_total,
    (j.value ->> 'log_bytes_flushed_kb')::bigint AS log_bytes_flushed_kb,
    r.entry_date
FROM monitoring.general_metric_metadata_results r
  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
 WHERE r.metric_name = 'HLTH-SQL-SYS-049-RC01';

DO $own$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbexpert_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_049_rc01 OWNER TO dbexpert_engine;
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_engine') THEN
        ALTER VIEW monitoring.v_hlth_sql_sys_049_rc01 OWNER TO dbdome_engine;
    END IF;
END
$own$;

SELECT root_cause_id, name, vendors_applicable FROM rootcause.root_causes
 WHERE root_cause_id = 'HLTH-SQL-SYS-049-RC01';

COMMIT;
