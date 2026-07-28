-- =============================================================================
-- 7270_clickhouse_detections.sql
-- Curated ClickHouse (system.* tables) detection variants attached to the
-- best-fit EXISTING root causes. Each root cause already has a resolution path
-- (shared across vendors), so adding a clickhouse detection_step + detection_
-- path makes it surface in rootcause.v_rootcauses with vendor_name='clickhouse'
-- and become collectable by collect_all_metrics_clickhouse_queries.
--
-- Curated (not cloned): ClickHouse is a columnar OLAP engine; only root causes
-- with a genuine ClickHouse system-table mapping are covered. Idempotent.
-- =============================================================================
BEGIN;

-- ---- SEC-SQL-AUTHZ-001-RC01 : ClickHouse access & privilege inventory (system.grants + roles) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUTHZ-001-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-AUTHZ-001-RC01 (clickhouse)', '{"sql": "SELECT user_name, role_name, access_type, database, table, column, is_partial_revoke, grant_option FROM system.grants ORDER BY user_name, role_name LIMIT 1000"}'::jsonb, '{"condition": "row_count > 0", "description": "Access/privilege grants inventory captured"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUTHZ-001-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-AUTHZ-001-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-AUTHZ-001-RC01', 'clickhouse', 'Detect SEC-SQL-AUTHZ-001-RC01 (clickhouse)', 'ClickHouse access & privilege inventory (system.grants + roles)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-PRI-007-RC01 : ClickHouse users with weak/no password policy (system.users) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-PRI-007-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-PRI-007-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-PRI-007-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-PRI-007-RC01 (clickhouse)', '{"sql": "SELECT name, auth_type, host_ip, host_names FROM system.users WHERE auth_type IN (''no_password'',''plaintext_password'') ORDER BY name"}'::jsonb, '{"condition": "row_count > 0", "description": "Users with no or plaintext password found"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-PRI-007-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-PRI-007-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-PRI-007-RC01', 'clickhouse', 'Detect SEC-SQL-PRI-007-RC01 (clickhouse)', 'ClickHouse users with weak/no password policy (system.users)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-AU-002-RC05 : ClickHouse users with no password set (system.users) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AU-002-RC05' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AU-002-RC05' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AU-002-RC05 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-AU-002-RC05 (clickhouse)', '{"sql": "SELECT name, host_ip, host_names FROM system.users WHERE auth_type = ''no_password'' ORDER BY name"}'::jsonb, '{"condition": "row_count > 0", "description": "Users authenticating with no password"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AU-002-RC05 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-AU-002-RC05') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-AU-002-RC05', 'clickhouse', 'Detect SEC-SQL-AU-002-RC05 (clickhouse)', 'ClickHouse users with no password set (system.users)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-ACC-010-RC10 : ClickHouse same user connected from multiple hosts (system.processes) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-010-RC10' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-010-RC10' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-ACC-010-RC10 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-ACC-010-RC10 (clickhouse)', '{"sql": "SELECT user, uniqExact(address) AS host_count, arrayStringConcat(groupUniqArray(toString(address)), '', '') AS hosts FROM system.processes WHERE user != ''default'' GROUP BY user HAVING host_count > 1"}'::jsonb, '{"condition": "row_count > 0", "description": "A user is active from more than one host"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-ACC-010-RC10 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-ACC-010-RC10') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-010-RC10', 'clickhouse', 'Detect SEC-SQL-ACC-010-RC10 (clickhouse)', 'ClickHouse same user connected from multiple hosts (system.processes)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-ACC-011-RC02 : ClickHouse active queries excluding the monitoring user (system.processes) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-ACC-011-RC02 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-ACC-011-RC02 (clickhouse)', '{"sql": "SELECT query_id, user, toString(address) AS host_name, round(elapsed,1) AS elapsed_sec, read_rows, formatReadableSize(memory_usage) AS memory, substring(query,1,4000) AS query_text FROM system.processes WHERE user NOT ILIKE ''%dbdome%'' AND query NOT ILIKE ''%system.processes%'' ORDER BY elapsed DESC"}'::jsonb, '{"condition": "row_count > 0", "description": "Active user queries present"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-ACC-011-RC02 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-ACC-011-RC02') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02', 'clickhouse', 'Detect SEC-SQL-ACC-011-RC02 (clickhouse)', 'ClickHouse active queries excluding the monitoring user (system.processes)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-AUD-014-RC01 : ClickHouse user/role created in the last 24h (system.query_log) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-014-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-014-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUD-014-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-AUD-014-RC01 (clickhouse)', '{"sql": "SELECT toString(event_time) AS event_time, user, toString(address) AS host_name, substring(query,1,4000) AS query_text FROM system.query_log WHERE type = ''QueryFinish'' AND event_time > now() - INTERVAL 24 HOUR AND (query ILIKE ''%CREATE USER%'' OR query ILIKE ''%CREATE ROLE%'') ORDER BY event_time DESC LIMIT 500"}'::jsonb, '{"condition": "row_count > 0", "description": "User/role creation detected in the audit window"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUD-014-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-AUD-014-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-AUD-014-RC01', 'clickhouse', 'Detect SEC-SQL-AUD-014-RC01 (clickhouse)', 'ClickHouse user/role created in the last 24h (system.query_log)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-AUD-014-RC02 : ClickHouse privilege GRANT / user-alter in the last 24h (system.query_log) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-014-RC02' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-014-RC02' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUD-014-RC02 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-AUD-014-RC02 (clickhouse)', '{"sql": "SELECT toString(event_time) AS event_time, user, toString(address) AS host_name, substring(query,1,4000) AS query_text FROM system.query_log WHERE type = ''QueryFinish'' AND event_time > now() - INTERVAL 24 HOUR AND (query ILIKE ''%GRANT %'' OR query ILIKE ''%ALTER USER%'' OR query ILIKE ''%ALTER ROLE%'') ORDER BY event_time DESC LIMIT 500"}'::jsonb, '{"condition": "row_count > 0", "description": "Privilege/grant change detected in the audit window"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUD-014-RC02 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-AUD-014-RC02') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-AUD-014-RC02', 'clickhouse', 'Detect SEC-SQL-AUD-014-RC02 (clickhouse)', 'ClickHouse privilege GRANT / user-alter in the last 24h (system.query_log)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- SEC-SQL-AUD-001-RC02 : ClickHouse query logging disabled (system.settings log_queries) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-001-RC02' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-AUD-001-RC02' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUD-001-RC02 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect SEC-SQL-AUD-001-RC02 (clickhouse)', '{"sql": "SELECT name, value FROM system.settings WHERE name = ''log_queries'' AND value = ''0''"}'::jsonb, '{"condition": "row_count > 0", "description": "Query logging (audit trail) is disabled"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect SEC-SQL-AUD-001-RC02 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='SEC-SQL-AUD-001-RC02') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-AUD-001-RC02', 'clickhouse', 'Detect SEC-SQL-AUD-001-RC02 (clickhouse)', 'ClickHouse query logging disabled (system.settings log_queries)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-AD-001-RC02 : ClickHouse slow finished queries in the last hour (system.query_log) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-001-RC02' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-001-RC02' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-001-RC02 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-AD-001-RC02 (clickhouse)', '{"sql": "SELECT toString(event_time) AS event_time, user, query_duration_ms, read_rows, formatReadableSize(memory_usage) AS memory, substring(query,1,4000) AS query_text FROM system.query_log WHERE type = ''QueryFinish'' AND event_time > now() - INTERVAL 1 HOUR AND query_duration_ms > 10000 ORDER BY query_duration_ms DESC LIMIT 100"}'::jsonb, '{"condition": "row_count > 0", "description": "Queries slower than 10s in the last hour"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-001-RC02 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-AD-001-RC02') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-AD-001-RC02', 'clickhouse', 'Detect HLTH-SQL-AD-001-RC02 (clickhouse)', 'ClickHouse slow finished queries in the last hour (system.query_log)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- PERF-SQL-TX-010-RC01 : ClickHouse running-query snapshot (system.processes) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='PERF-SQL-TX-010-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='PERF-SQL-TX-010-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect PERF-SQL-TX-010-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect PERF-SQL-TX-010-RC01 (clickhouse)', '{"sql": "SELECT query_id, user, round(elapsed,1) AS elapsed_sec, read_rows, formatReadableSize(memory_usage) AS memory, substring(query,1,4000) AS query_text FROM system.processes ORDER BY elapsed DESC"}'::jsonb, '{"condition": "row_count > 0", "description": "Running query snapshot captured"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect PERF-SQL-TX-010-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='PERF-SQL-TX-010-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('PERF-SQL-TX-010-RC01', 'clickhouse', 'Detect PERF-SQL-TX-010-RC01 (clickhouse)', 'ClickHouse running-query snapshot (system.processes)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-AD-003-RC01 : ClickHouse memory-limit-exceeded errors (system.errors) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-003-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-003-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-003-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-AD-003-RC01 (clickhouse)', '{"sql": "SELECT name, code, value AS occurrences, toString(last_error_time) AS last_error_time, substring(last_error_message,1,1000) AS last_error_message FROM system.errors WHERE name ILIKE ''%MEMORY_LIMIT%'' AND value > 0"}'::jsonb, '{"condition": "row_count > 0", "description": "Memory-limit errors have occurred"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-003-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-AD-003-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-AD-003-RC01', 'clickhouse', 'Detect HLTH-SQL-AD-003-RC01 (clickhouse)', 'ClickHouse memory-limit-exceeded errors (system.errors)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-AD-003-RC05 : ClickHouse disk free space below 10% (system.disks) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-003-RC05' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-003-RC05' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-003-RC05 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-AD-003-RC05 (clickhouse)', '{"sql": "SELECT name, path, formatReadableSize(free_space) AS free, formatReadableSize(total_space) AS total, round(100.0 * free_space / total_space, 2) AS free_pct FROM system.disks WHERE total_space > 0 AND (100.0 * free_space / total_space) < 10 ORDER BY free_pct"}'::jsonb, '{"condition": "row_count > 0", "description": "A disk is below 10% free"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-003-RC05 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-AD-003-RC05') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-AD-003-RC05', 'clickhouse', 'Detect HLTH-SQL-AD-003-RC05 (clickhouse)', 'ClickHouse disk free space below 10% (system.disks)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-AD-001-RC01 : ClickHouse open connection counts (system.metrics) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-001-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-001-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-001-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-AD-001-RC01 (clickhouse)', '{"sql": "SELECT metric, value FROM system.metrics WHERE metric IN (''TCPConnection'',''HTTPConnection'',''MySQLConnection'',''PostgreSQLConnection'',''InterserverConnection'') AND value > 0 ORDER BY value DESC"}'::jsonb, '{"condition": "row_count > 0", "description": "Open connection counts captured"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-001-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-AD-001-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-AD-001-RC01', 'clickhouse', 'Detect HLTH-SQL-AD-001-RC01 (clickhouse)', 'ClickHouse open connection counts (system.metrics)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-CD-001-RC07 : ClickHouse read-only / session-expired replicas (system.replicas) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-CD-001-RC07' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-CD-001-RC07' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-CD-001-RC07 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-CD-001-RC07 (clickhouse)', '{"sql": "SELECT database, table, is_readonly, is_session_expired, absolute_delay, queue_size, inserts_in_queue, merges_in_queue FROM system.replicas WHERE is_readonly = 1 OR is_session_expired = 1"}'::jsonb, '{"condition": "row_count > 0", "description": "A replicated table is read-only or its session expired"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-CD-001-RC07 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-CD-001-RC07') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-CD-001-RC07', 'clickhouse', 'Detect HLTH-SQL-CD-001-RC07 (clickhouse)', 'ClickHouse read-only / session-expired replicas (system.replicas)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-BR-003-RC03 : ClickHouse replication lag > 60s (system.replicas) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-BR-003-RC03' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-BR-003-RC03' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-BR-003-RC03 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-BR-003-RC03 (clickhouse)', '{"sql": "SELECT database, table, absolute_delay, queue_size, inserts_in_queue, merges_in_queue, log_pointer, log_max_index FROM system.replicas WHERE absolute_delay > 60 ORDER BY absolute_delay DESC"}'::jsonb, '{"condition": "row_count > 0", "description": "Replication delay exceeds 60 seconds"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-BR-003-RC03 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-BR-003-RC03') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-BR-003-RC03', 'clickhouse', 'Detect HLTH-SQL-BR-003-RC03 (clickhouse)', 'ClickHouse replication lag > 60s (system.replicas)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-DM-004-RC07 : ClickHouse long-running merges > 5min (system.merges) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-DM-004-RC07' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-DM-004-RC07' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-DM-004-RC07 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-DM-004-RC07 (clickhouse)', '{"sql": "SELECT database, table, round(elapsed,1) AS elapsed_sec, round(progress,3) AS progress, num_parts, formatReadableSize(total_size_bytes_compressed) AS size, is_mutation FROM system.merges WHERE elapsed > 300 ORDER BY elapsed DESC"}'::jsonb, '{"condition": "row_count > 0", "description": "A merge has been running over 5 minutes"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-DM-004-RC07 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-DM-004-RC07') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-DM-004-RC07', 'clickhouse', 'Detect HLTH-SQL-DM-004-RC07 (clickhouse)', 'ClickHouse long-running merges > 5min (system.merges)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-DM-001-RC01 : ClickHouse unfinished / failed mutations (system.mutations) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-DM-001-RC01' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-DM-001-RC01' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-DM-001-RC01 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-DM-001-RC01 (clickhouse)', '{"sql": "SELECT database, table, mutation_id, parts_to_do, toString(latest_fail_time) AS latest_fail_time, substring(latest_fail_reason,1,1000) AS latest_fail_reason FROM system.mutations WHERE is_done = 0 ORDER BY create_time LIMIT 200"}'::jsonb, '{"condition": "row_count > 0", "description": "Unfinished mutations (possibly stuck/failed)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-DM-001-RC01 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-DM-001-RC01') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-DM-001-RC01', 'clickhouse', 'Detect HLTH-SQL-DM-001-RC01 (clickhouse)', 'ClickHouse unfinished / failed mutations (system.mutations)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-SM-001-RC08 : ClickHouse tables with too many active parts > 300 (system.parts) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SM-001-RC08' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SM-001-RC08' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-SM-001-RC08 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-SM-001-RC08 (clickhouse)', '{"sql": "SELECT database, table, count() AS active_parts, formatReadableSize(sum(bytes_on_disk)) AS size, sum(rows) AS rows FROM system.parts WHERE active GROUP BY database, table HAVING active_parts > 300 ORDER BY active_parts DESC"}'::jsonb, '{"condition": "row_count > 0", "description": "Tables with excessive active parts (compaction lag)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-SM-001-RC08 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-SM-001-RC08') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SM-001-RC08', 'clickhouse', 'Detect HLTH-SQL-SM-001-RC08 (clickhouse)', 'ClickHouse tables with too many active parts > 300 (system.parts)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-AD-003-RC11 : ClickHouse detached parts present (system.detached_parts) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-003-RC11' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-AD-003-RC11' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-003-RC11 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-AD-003-RC11 (clickhouse)', '{"sql": "SELECT database, table, partition_id, name, reason FROM system.detached_parts ORDER BY database, table LIMIT 500"}'::jsonb, '{"condition": "row_count > 0", "description": "Detached parts present (data anomaly/corruption)"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-AD-003-RC11 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-AD-003-RC11') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-AD-003-RC11', 'clickhouse', 'Detect HLTH-SQL-AD-003-RC11 (clickhouse)', 'ClickHouse detached parts present (system.detached_parts)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-SM-002-RC05 : ClickHouse largest tables by disk size (system.parts) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SM-002-RC05' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-SM-002-RC05' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-SM-002-RC05 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-SM-002-RC05 (clickhouse)', '{"sql": "SELECT database, table, formatReadableSize(sum(bytes_on_disk)) AS size, sum(rows) AS rows, count() AS parts FROM system.parts WHERE active GROUP BY database, table ORDER BY sum(bytes_on_disk) DESC LIMIT 50"}'::jsonb, '{"condition": "row_count > 0", "description": "Largest tables inventory captured"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-SM-002-RC05 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-SM-002-RC05') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-SM-002-RC05', 'clickhouse', 'Detect HLTH-SQL-SM-002-RC05 (clickhouse)', 'ClickHouse largest tables by disk size (system.parts)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

-- ---- HLTH-SQL-DM-006-RC12 : ClickHouse recent server errors in the last hour (system.errors) ----
DELETE FROM rootcause.detection_path_steps WHERE detection_path_id IN
    (SELECT id FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-DM-006-RC12' AND vendor_slug='clickhouse');
DELETE FROM rootcause.detection_paths WHERE root_cause_id='HLTH-SQL-DM-006-RC12' AND vendor_slug='clickhouse';
DELETE FROM rootcause.detection_steps WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-DM-006-RC12 (clickhouse)';

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('clickhouse', 'query', 'Detect HLTH-SQL-DM-006-RC12 (clickhouse)', '{"sql": "SELECT name, code, value AS occurrences, toString(last_error_time) AS last_error_time, substring(last_error_message,1,1000) AS last_error_message FROM system.errors WHERE last_error_time > now() - INTERVAL 1 HOUR AND value > 0 ORDER BY last_error_time DESC LIMIT 100"}'::jsonb, '{"condition": "row_count > 0", "description": "Server errors recorded in the last hour"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content=EXCLUDED.content, expected=EXCLUDED.expected;

DO $ch$
DECLARE v_step bigint; v_path bigint;
BEGIN
    SELECT id INTO v_step FROM rootcause.detection_steps
     WHERE vendor_slug='clickhouse' AND name='Detect HLTH-SQL-DM-006-RC12 (clickhouse)' ORDER BY id DESC LIMIT 1;
    IF v_step IS NOT NULL AND EXISTS (SELECT 1 FROM rootcause.root_causes WHERE root_cause_id='HLTH-SQL-DM-006-RC12') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('HLTH-SQL-DM-006-RC12', 'clickhouse', 'Detect HLTH-SQL-DM-006-RC12 (clickhouse)', 'ClickHouse recent server errors in the last hour (system.errors)', 'diagnostic', true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed', 'ruled_out');
    END IF;
END $ch$;

COMMIT;
