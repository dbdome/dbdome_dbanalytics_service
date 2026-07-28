-- =============================================================================
-- 5063_acc_011_rc02_multivendor_queries.sql
-- SEC-SQL-ACC-011-RC02 "Active transactions" had a query only for sqlserver.
-- Add per-vendor detection queries (active transactions / sessions active within
-- the last 120 seconds) plus the detection_path + resolution_path each needs to
-- appear in rootcause.v_rootcauses and be collected. Vendors (in priority order):
--   oracle, postgresql, mysql, mariadb.
--
-- Common output columns per vendor (active-transactions shape):
--   session_id, login_name, host_name, program_name, database_name,
--   transaction_id, transaction_begin_time, duration_seconds,
--   transaction_state, query_text
-- Single SELECT each, no '--' comments inside the stored SQL (the collector
-- flattens \n -> space), no trailing ';'. Idempotent (re-run safe).
-- =============================================================================

-- ===== ORACLE ===============================================================
DO $do$
DECLARE v_step bigint; v_path bigint; v_rstep bigint; v_rpath bigint;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle','query','Detect SEC-SQL-ACC-011-RC02 (oracle)',
        jsonb_build_object('sql', $qora$SELECT
  s.sid AS session_id,
  s.username AS login_name,
  s.machine AS host_name,
  s.program AS program_name,
  SYS_CONTEXT('USERENV','DB_NAME') AS database_name,
  t.xidusn || '.' || t.xidslot || '.' || t.xidsqn AS transaction_id,
  t.start_time AS transaction_begin_time,
  s.last_call_et AS duration_seconds,
  s.status AS transaction_state,
  SUBSTR(sq.sql_text, 1, 4000) AS query_text
FROM v$session s
LEFT JOIN v$transaction t ON t.ses_addr = s.saddr
LEFT JOIN v$sql sq ON sq.sql_id = s.sql_id
WHERE s.type = 'USER' AND s.username IS NOT NULL
  AND s.username NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN','XDB')
  AND (s.status = 'ACTIVE' OR t.ses_addr IS NOT NULL OR s.last_call_et <= 120)$qora$),
        '{"condition":"row_count > 0","description":"Active transactions/sessions within the last 120 seconds (oracle)"}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;
    SELECT id INTO v_step FROM rootcause.detection_steps WHERE vendor_slug='oracle' AND name='Detect SEC-SQL-ACC-011-RC02 (oracle)' ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='oracle') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','oracle','Detect SEC-SQL-ACC-011-RC02 (oracle)','Active transactions (oracle)','diagnostic',true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed','ruled_out');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='oracle') THEN
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('oracle','recommendation','Resolve: SEC-SQL-ACC-011-RC02 (oracle)','{"action":"Review long-running or abandoned transactions: identify the session/login, duration and SQL text; chase blockers and transactions open beyond expected thresholds."}'::jsonb,'low',false,true) RETURNING id INTO v_rstep;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','oracle','Resolve: SEC-SQL-ACC-011-RC02 (oracle)','resolve-sec_sql_acc_011_rc02-oracle','Review active transactions (oracle).','supervised','low',true) RETURNING id INTO v_rpath;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_rpath, v_rstep, 1);
    END IF;
END $do$;

-- ===== POSTGRESQL ===========================================================
DO $do$
DECLARE v_step bigint; v_path bigint; v_rstep bigint; v_rpath bigint;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql','query','Detect SEC-SQL-ACC-011-RC02 (postgresql)',
        jsonb_build_object('sql', $qpg$SELECT
  pid AS session_id,
  usename AS login_name,
  client_addr::text AS host_name,
  application_name AS program_name,
  datname AS database_name,
  backend_xid::text AS transaction_id,
  xact_start AS transaction_begin_time,
  EXTRACT(EPOCH FROM (now() - COALESCE(xact_start, query_start, state_change)))::int AS duration_seconds,
  state AS transaction_state,
  left(query, 4000) AS query_text
FROM pg_stat_activity
WHERE backend_type = 'client backend'
  AND pid <> pg_backend_pid()
  AND COALESCE(usename,'') NOT LIKE 'dbdome%'
  AND (state IN ('active','idle in transaction','idle in transaction (aborted)')
       OR state_change >= now() - interval '120 seconds')$qpg$),
        '{"condition":"row_count > 0","description":"Active transactions/sessions within the last 120 seconds (postgresql)"}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;
    SELECT id INTO v_step FROM rootcause.detection_steps WHERE vendor_slug='postgresql' AND name='Detect SEC-SQL-ACC-011-RC02 (postgresql)' ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='postgresql') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','postgresql','Detect SEC-SQL-ACC-011-RC02 (postgresql)','Active transactions (postgresql)','diagnostic',true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed','ruled_out');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='postgresql') THEN
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('postgresql','recommendation','Resolve: SEC-SQL-ACC-011-RC02 (postgresql)','{"action":"Review long-running or idle-in-transaction sessions; terminate or fix sessions holding transactions open beyond expected thresholds."}'::jsonb,'low',false,true) RETURNING id INTO v_rstep;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','postgresql','Resolve: SEC-SQL-ACC-011-RC02 (postgresql)','resolve-sec_sql_acc_011_rc02-postgresql','Review active transactions (postgresql).','supervised','low',true) RETURNING id INTO v_rpath;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_rpath, v_rstep, 1);
    END IF;
END $do$;

-- ===== MYSQL ================================================================
DO $do$
DECLARE v_step bigint; v_path bigint; v_rstep bigint; v_rpath bigint;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql','query','Detect SEC-SQL-ACC-011-RC02 (mysql)',
        jsonb_build_object('sql', $qmy$SELECT
  p.id AS session_id,
  p.user AS login_name,
  p.host AS host_name,
  p.command AS program_name,
  p.db AS database_name,
  t.trx_id AS transaction_id,
  t.trx_started AS transaction_begin_time,
  COALESCE(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()), p.time) AS duration_seconds,
  COALESCE(t.trx_state, p.state, p.command) AS transaction_state,
  LEFT(COALESCE(t.trx_query, p.info), 4000) AS query_text
FROM information_schema.processlist p
LEFT JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id
WHERE COALESCE(p.user,'') NOT IN ('dbdome','dbdome_mon_usr','event_scheduler','system user')
  AND (p.command <> 'Sleep' OR t.trx_id IS NOT NULL OR p.time <= 120)$qmy$),
        '{"condition":"row_count > 0","description":"Active transactions/sessions within the last 120 seconds (mysql)"}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;
    SELECT id INTO v_step FROM rootcause.detection_steps WHERE vendor_slug='mysql' AND name='Detect SEC-SQL-ACC-011-RC02 (mysql)' ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='mysql') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','mysql','Detect SEC-SQL-ACC-011-RC02 (mysql)','Active transactions (mysql)','diagnostic',true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed','ruled_out');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='mysql') THEN
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('mysql','recommendation','Resolve: SEC-SQL-ACC-011-RC02 (mysql)','{"action":"Review long-running or abandoned InnoDB transactions; kill or fix threads holding transactions open beyond expected thresholds."}'::jsonb,'low',false,true) RETURNING id INTO v_rstep;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','mysql','Resolve: SEC-SQL-ACC-011-RC02 (mysql)','resolve-sec_sql_acc_011_rc02-mysql','Review active transactions (mysql).','supervised','low',true) RETURNING id INTO v_rpath;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_rpath, v_rstep, 1);
    END IF;
END $do$;

-- ===== MARIADB ==============================================================
DO $do$
DECLARE v_step bigint; v_path bigint; v_rstep bigint; v_rpath bigint;
BEGIN
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mariadb','query','Detect SEC-SQL-ACC-011-RC02 (mariadb)',
        jsonb_build_object('sql', $qmar$SELECT
  p.id AS session_id,
  p.user AS login_name,
  p.host AS host_name,
  p.command AS program_name,
  p.db AS database_name,
  t.trx_id AS transaction_id,
  t.trx_started AS transaction_begin_time,
  COALESCE(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()), p.time) AS duration_seconds,
  COALESCE(t.trx_state, p.state, p.command) AS transaction_state,
  LEFT(COALESCE(t.trx_query, p.info), 4000) AS query_text
FROM information_schema.processlist p
LEFT JOIN information_schema.innodb_trx t ON t.trx_mysql_thread_id = p.id
WHERE COALESCE(p.user,'') NOT IN ('dbdome','dbdome_mon_usr','event_scheduler','system user')
  AND (p.command <> 'Sleep' OR t.trx_id IS NOT NULL OR p.time <= 120)$qmar$),
        '{"condition":"row_count > 0","description":"Active transactions/sessions within the last 120 seconds (mariadb)"}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;
    SELECT id INTO v_step FROM rootcause.detection_steps WHERE vendor_slug='mariadb' AND name='Detect SEC-SQL-ACC-011-RC02 (mariadb)' ORDER BY id DESC LIMIT 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='mariadb') THEN
        INSERT INTO rootcause.detection_paths (root_cause_id, vendor_slug, name, description, path_type, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','mariadb','Detect SEC-SQL-ACC-011-RC02 (mariadb)','Active transactions (mariadb)','diagnostic',true) RETURNING id INTO v_path;
        INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
        VALUES (v_path, v_step, 1, 'confirmed','ruled_out');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rootcause.resolution_paths WHERE root_cause_id='SEC-SQL-ACC-011-RC02' AND vendor_slug='mariadb') THEN
        INSERT INTO rootcause.resolution_steps (vendor_slug, step_type, name, content, risk_level, requires_confirmation, is_reversible)
        VALUES ('mariadb','recommendation','Resolve: SEC-SQL-ACC-011-RC02 (mariadb)','{"action":"Review long-running or abandoned InnoDB transactions; kill or fix threads holding transactions open beyond expected thresholds."}'::jsonb,'low',false,true) RETURNING id INTO v_rstep;
        INSERT INTO rootcause.resolution_paths (root_cause_id, vendor_slug, name, slug, description, execution_mode, risk_level, is_active)
        VALUES ('SEC-SQL-ACC-011-RC02','mariadb','Resolve: SEC-SQL-ACC-011-RC02 (mariadb)','resolve-sec_sql_acc_011_rc02-mariadb','Review active transactions (mariadb).','supervised','low',true) RETURNING id INTO v_rpath;
        INSERT INTO rootcause.resolution_path_steps (resolution_path_id, resolution_step_id, step_order) VALUES (v_rpath, v_rstep, 1);
    END IF;
END $do$;

-- VERIFY: vendors now present for the RC in v_rootcauses
SELECT DISTINCT vendor_name FROM rootcause.v_rootcauses
WHERE root_cause_id='SEC-SQL-ACC-011-RC02' ORDER BY vendor_name;
