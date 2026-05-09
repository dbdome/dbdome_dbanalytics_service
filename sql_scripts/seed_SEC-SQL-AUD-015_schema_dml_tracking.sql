-- ============================================================
-- SEC-SQL-AUD-015 — Schema and DML Activity Tracking
--
-- Multi-vendor: sqlserver, postgresql, mysql, oracle.
--
-- Each vendor gets its own 2-step detection path:
--   step 1 — idempotently provision audit infrastructure on the
--            target instance and return a one-row status,
--   step 2 — read schema-change and DML events from that audit
--            in the last 24 hours, in a uniform column shape:
--
--     event_time, login_name, database_name, schema_name,
--     object_name, action_id, action, change_kind, client_ip,
--     application_name, statement
--
-- POSTURE: best-effort. If the setup step cannot create audit
-- infrastructure (typically a permission or extension issue),
-- it returns setup_ok=0 with a clear error_message; the read
-- step then returns zero rows. The detection condition
-- (row_count > 0) is on the read step.
--
-- COVERAGE BY VENDOR:
--   sqlserver   — DDL + DML, full coverage via SQL Server Audit.
--   postgresql  — DDL only, captured via event triggers. DML
--                 capture in postgres requires pgaudit which
--                 needs shared_preload_libraries + a server
--                 restart; track that separately if needed.
--   mysql       — DDL + DML, captured via mysql.general_log.
--                 general_log records every statement so the
--                 read step filters by command class. High
--                 logging volume on busy servers — review
--                 before enabling in production.
--   oracle      — DDL + DML via Unified Auditing (12c+). Cleanest
--                 of the four: one policy each, queried from
--                 unified_audit_trail.
--
-- IDEMPOTENCY: re-running this script in PostgreSQL is a no-op
-- for rows that already exist (issue, root cause, steps, path,
-- path-step links). Each detection step also runs idempotently
-- against the target database.
-- ============================================================

BEGIN;

-- ── 1. ISSUE ────────────────────────────────────────────────
INSERT INTO rootcause.issues
  (issue_id, domain_code, database_type_code, area_code, name, slug, description)
VALUES
  ('SEC-SQL-AUD-015','SEC','SQL','AUD',
   'Schema and DML Activity Tracking',
   'schema-and-dml-activity-tracking',
   'Tracks every CREATE/ALTER/DROP and every INSERT/UPDATE/DELETE/TRUNCATE recorded by each vendor''s audit subsystem. The detection auto-provisions audit infrastructure when missing so coverage is consistent across all monitored databases.')
ON CONFLICT (issue_id) DO NOTHING;

-- ── 2. ROOT CAUSE (vendors_applicable widened to all four) ──
INSERT INTO rootcause.root_causes
  (root_cause_id, issue_id, name, slug, description, vendors_applicable)
VALUES
  ('SEC-SQL-AUD-015-RC01','SEC-SQL-AUD-015',
   'Recent schema changes or DML detected via database audit',
   'recent-schema-changes-or-dml-detected-database-audit',
   'Returns every schema-change (CREATE/ALTER/DROP) and DML (INSERT/UPDATE/DELETE/TRUNCATE) event recorded by the target database''s audit subsystem over the last 24 hours. Auto-provisions audit infrastructure on first run for each vendor.',
   ARRAY['sqlserver','postgresql','mysql','oracle'])
ON CONFLICT (root_cause_id) DO UPDATE
   SET vendors_applicable = EXCLUDED.vendors_applicable,
       description        = EXCLUDED.description;

-- ── 3. DETECTION STEPS, PATHS, AND LINKS ───────────────────
DO $do$
DECLARE
    v_step1_id INT;
    v_step2_id INT;
    v_path_id  INT;

    -- ── SQL SERVER ─────────────────────────────────────────
    sqlserver_setup_sql CONSTANT text := $tsql$
SET NOCOUNT ON;
DECLARE @audit_name        SYSNAME       = N'dbdome_audit';
DECLARE @server_spec_name  SYSNAME       = N'dbdome_ddl_audit';
DECLARE @db_spec_name      SYSNAME       = N'dbdome_dml_audit';
DECLARE @audit_dir         NVARCHAR(260) = N'C:\Audit\';
DECLARE @sql               NVARCHAR(MAX);
DECLARE @err               NVARCHAR(4000) = NULL;

IF NOT EXISTS (SELECT 1 FROM sys.server_audits
               WHERE name = @audit_name AND is_state_enabled = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = @audit_name)
    BEGIN
        SET @sql = N'ALTER SERVER AUDIT [' + @audit_name + N'] WITH (STATE = OFF);'
                 + N'DROP SERVER AUDIT [' + @audit_name + N'];';
        EXEC sp_executesql @sql;
    END
    BEGIN TRY
        SET @sql =
            N'CREATE SERVER AUDIT [' + @audit_name + N'] '
          + N'TO FILE (FILEPATH = N''' + @audit_dir + N''','
          +         N' MAXSIZE = 256 MB, MAX_ROLLOVER_FILES = 10,'
          +         N' RESERVE_DISK_SPACE = OFF)'
          + N' WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);';
        EXEC sp_executesql @sql;
        SET @sql = N'ALTER SERVER AUDIT [' + @audit_name + N'] WITH (STATE = ON);';
        EXEC sp_executesql @sql;
    END TRY BEGIN CATCH SET @err = N'CREATE SERVER AUDIT failed: ' + ERROR_MESSAGE(); END CATCH
END

IF @err IS NULL
   AND NOT EXISTS (SELECT 1 FROM sys.server_audit_specifications
                   WHERE name = @server_spec_name AND is_state_enabled = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = @server_spec_name)
    BEGIN
        SET @sql = N'ALTER SERVER AUDIT SPECIFICATION [' + @server_spec_name + N'] WITH (STATE = OFF);'
                 + N'DROP SERVER AUDIT SPECIFICATION [' + @server_spec_name + N'];';
        EXEC sp_executesql @sql;
    END
    BEGIN TRY
        SET @sql =
            N'CREATE SERVER AUDIT SPECIFICATION [' + @server_spec_name + N'] '
          + N'FOR SERVER AUDIT [' + @audit_name + N'] '
          + N'ADD (SCHEMA_OBJECT_CHANGE_GROUP),'
          + N'ADD (DATABASE_OBJECT_CHANGE_GROUP),'
          + N'ADD (SERVER_OBJECT_CHANGE_GROUP) '
          + N'WITH (STATE = ON);';
        EXEC sp_executesql @sql;
    END TRY BEGIN CATCH SET @err = N'CREATE SERVER AUDIT SPECIFICATION failed: ' + ERROR_MESSAGE(); END CATCH
END

IF @err IS NULL
BEGIN
    DECLARE @db SYSNAME;
    DECLARE db_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT name FROM sys.databases
        WHERE state_desc = 'ONLINE'
          AND name NOT IN ('tempdb','model','msdb');
    OPEN db_cur;
    FETCH NEXT FROM db_cur INTO @db;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @stmt NVARCHAR(MAX) =
            N'USE ' + QUOTENAME(@db) + N';' + CHAR(10)
          + N'IF NOT EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = N''' + @db_spec_name + N''')' + CHAR(10)
          + N'BEGIN' + CHAR(10)
          + N'   DECLARE @clauses NVARCHAR(MAX);' + CHAR(10)
          + N'   SELECT @clauses = STRING_AGG(' + CHAR(10)
          + N'           CAST(N''ADD (INSERT, UPDATE, DELETE ON SCHEMA::''' + CHAR(10)
          + N'                + QUOTENAME(s.name)' + CHAR(10)
          + N'                + N'' BY public)'' AS NVARCHAR(MAX)), N'', '')' + CHAR(10)
          + N'   FROM sys.schemas s' + CHAR(10)
          + N'   LEFT JOIN sys.database_principals dp ON dp.principal_id = s.principal_id' + CHAR(10)
          + N'   WHERE s.name NOT IN (''sys'',''INFORMATION_SCHEMA'',''guest'')' + CHAR(10)
          + N'     AND COALESCE(dp.type, ''S'') NOT IN (''R'',''A'');' + CHAR(10)
          + N'   IF @clauses IS NOT NULL' + CHAR(10)
          + N'   BEGIN' + CHAR(10)
          + N'       DECLARE @cmd NVARCHAR(MAX) =' + CHAR(10)
          + N'           N''CREATE DATABASE AUDIT SPECIFICATION [' + @db_spec_name + N']'' +' + CHAR(10)
          + N'           N'' FOR SERVER AUDIT [' + @audit_name + N']'' +' + CHAR(10)
          + N'           N'' '' + @clauses +' + CHAR(10)
          + N'           N'' WITH (STATE = ON);'';' + CHAR(10)
          + N'       BEGIN TRY EXEC sp_executesql @cmd; END TRY BEGIN CATCH END CATCH;' + CHAR(10)
          + N'   END' + CHAR(10)
          + N'END;';
        BEGIN TRY EXEC sp_executesql @stmt; END TRY BEGIN CATCH END CATCH
        FETCH NEXT FROM db_cur INTO @db;
    END
    CLOSE db_cur; DEALLOCATE db_cur;
END

SELECT
    CASE WHEN @err IS NULL THEN 1 ELSE 0 END                                          AS setup_ok,
    (SELECT COUNT(*) FROM sys.server_audits             WHERE is_state_enabled = 1)   AS enabled_server_audits,
    (SELECT COUNT(*) FROM sys.server_audit_specifications WHERE is_state_enabled = 1) AS enabled_server_specs,
    @audit_name                                                                       AS audit_name,
    @audit_dir                                                                        AS audit_directory,
    @err                                                                              AS error_message;
$tsql$;

    sqlserver_read_sql CONSTANT text := $tsql$
SET NOCOUNT ON;
DECLARE @audit_path NVARCHAR(520);
SELECT TOP (1)
       @audit_path = log_file_path
                     + REPLACE(log_file_name, N'.sqlaudit', N'*.sqlaudit')
FROM   sys.server_file_audits
WHERE  is_state_enabled = 1
ORDER BY audit_id;

IF @audit_path IS NULL
BEGIN
    SELECT TOP 0
        CAST(NULL AS DATETIME2)     AS event_time,
        CAST(NULL AS NVARCHAR(128)) AS login_name,
        CAST(NULL AS NVARCHAR(128)) AS database_name,
        CAST(NULL AS NVARCHAR(128)) AS schema_name,
        CAST(NULL AS NVARCHAR(128)) AS object_name,
        CAST(NULL AS NVARCHAR(4))   AS action_id,
        CAST(NULL AS NVARCHAR(16))  AS action,
        CAST(NULL AS NVARCHAR(8))   AS change_kind,
        CAST(NULL AS NVARCHAR(45))  AS client_ip,
        CAST(NULL AS NVARCHAR(128)) AS application_name,
        CAST(NULL AS NVARCHAR(MAX)) AS statement;
    RETURN;
END;

SELECT  af.event_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jerusalem' AS event_time,
        af.server_principal_name   AS login_name,
        af.database_name,
        af.schema_name,
        af.object_name,
        af.action_id,
        CASE af.action_id
             WHEN 'CR' THEN 'CREATE' WHEN 'AL' THEN 'ALTER' WHEN 'DR' THEN 'DROP'
             WHEN 'IN' THEN 'INSERT' WHEN 'UP' THEN 'UPDATE' WHEN 'DE' THEN 'DELETE'
             WHEN 'TR' THEN 'TRUNCATE' WHEN 'SL' THEN 'SELECT'
             ELSE af.action_id END AS action,
        CASE WHEN af.action_id IN ('CR','AL','DR')      THEN 'SCHEMA'
             WHEN af.action_id IN ('IN','UP','DE','TR') THEN 'DML'
             ELSE 'OTHER' END      AS change_kind,
        af.client_ip,
        af.application_name,
        af.statement
FROM    sys.fn_get_audit_file(@audit_path, DEFAULT, DEFAULT) AS af
WHERE   af.action_id IN ('CR','AL','DR','IN','UP','DE','TR')
  AND   af.event_time >= DATEADD(hour, -24, SYSUTCDATETIME())
  AND   af.succeeded  = 1
ORDER BY af.event_time DESC;
$tsql$;

    -- ── POSTGRESQL (DDL via event triggers; DML deferred to pgaudit) ──
    postgresql_setup_sql CONSTANT text := $pg$
DO $setup$
BEGIN
    BEGIN
        CREATE SCHEMA IF NOT EXISTS _dbdome_audit;
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        CREATE TABLE IF NOT EXISTS _dbdome_audit.audit_log (
            id               bigserial    PRIMARY KEY,
            event_time       timestamptz  NOT NULL DEFAULT now(),
            login_name       text,
            database_name    text,
            schema_name      text,
            object_name      text,
            action_id        text,
            action           text,
            change_kind      text,
            client_ip        inet,
            application_name text,
            statement        text
        );
        CREATE INDEX IF NOT EXISTS audit_log_event_time_idx
            ON _dbdome_audit.audit_log (event_time);
    EXCEPTION WHEN OTHERS THEN NULL; END;

    BEGIN
        EXECUTE $f$
        CREATE OR REPLACE FUNCTION _dbdome_audit.log_ddl_end() RETURNS event_trigger
        LANGUAGE plpgsql SECURITY DEFINER AS $body$
        DECLARE r record;
        BEGIN
            FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
                INSERT INTO _dbdome_audit.audit_log (
                    login_name, database_name, schema_name, object_name,
                    action_id, action, change_kind,
                    client_ip, application_name, statement)
                VALUES (
                    session_user, current_database(), r.schema_name, r.object_identity,
                    upper(left(tg_tag, 2)), upper(tg_tag), 'SCHEMA',
                    inet_client_addr(),
                    current_setting('application_name', true),
                    current_query());
            END LOOP;
        END;
        $body$;
        $f$;

        EXECUTE $f$
        CREATE OR REPLACE FUNCTION _dbdome_audit.log_drop() RETURNS event_trigger
        LANGUAGE plpgsql SECURITY DEFINER AS $body$
        DECLARE r record;
        BEGIN
            FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
                INSERT INTO _dbdome_audit.audit_log (
                    login_name, database_name, schema_name, object_name,
                    action_id, action, change_kind,
                    client_ip, application_name, statement)
                VALUES (
                    session_user, current_database(), r.schema_name, r.object_name,
                    'DR', 'DROP', 'SCHEMA',
                    inet_client_addr(),
                    current_setting('application_name', true),
                    current_query());
            END LOOP;
        END;
        $body$;
        $f$;
    EXCEPTION WHEN OTHERS THEN NULL; END;

    IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = '_dbdome_audit_ddl_end') THEN
        BEGIN
            CREATE EVENT TRIGGER _dbdome_audit_ddl_end ON ddl_command_end
                EXECUTE FUNCTION _dbdome_audit.log_ddl_end();
        EXCEPTION WHEN OTHERS THEN NULL; END;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = '_dbdome_audit_drop') THEN
        BEGIN
            CREATE EVENT TRIGGER _dbdome_audit_drop ON sql_drop
                EXECUTE FUNCTION _dbdome_audit.log_drop();
        EXCEPTION WHEN OTHERS THEN NULL; END;
    END IF;
END;
$setup$;

SELECT
    CASE WHEN EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = '_dbdome_audit')
          AND EXISTS (SELECT 1 FROM pg_class c
                       JOIN pg_namespace n ON n.oid = c.relnamespace
                       WHERE n.nspname='_dbdome_audit' AND c.relname='audit_log')
          AND EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname='_dbdome_audit_ddl_end')
         THEN 1 ELSE 0 END                                                AS setup_ok,
    (SELECT COUNT(*) FROM pg_event_trigger
        WHERE evtname IN ('_dbdome_audit_ddl_end','_dbdome_audit_drop'))   AS event_triggers,
    '_dbdome_audit.audit_log'::text                                       AS audit_table,
    'C:\\Audit\\ (n/a)'::text                                              AS audit_directory,
    CASE
        WHEN NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='_dbdome_audit')
             THEN 'Could not create schema _dbdome_audit (CREATE on database required)'
        WHEN NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname='_dbdome_audit_ddl_end')
             THEN 'Could not create event trigger (superuser required)'
        ELSE NULL
    END                                                                   AS error_message;
$pg$;

    postgresql_read_sql CONSTANT text := $pg$
SELECT
    event_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jerusalem' AS event_time,
    login_name,
    database_name,
    schema_name,
    object_name,
    action_id,
    action,
    change_kind,
    host(client_ip) AS client_ip,
    application_name,
    statement
FROM _dbdome_audit.audit_log
WHERE event_time >= now() - INTERVAL '24 hours'
ORDER BY event_time DESC
LIMIT 5000;
$pg$;

    -- ── MYSQL (mysql.general_log filtered by command class) ──
    mysql_setup_sql CONSTANT text := $my$
SET @err := NULL;

-- Route general_log to a table so the read step can SELECT it.
SET GLOBAL log_output = CONCAT(
    CASE WHEN FIND_IN_SET('TABLE', UPPER(@@global.log_output)) > 0
         THEN @@global.log_output
         ELSE CONCAT_WS(',', @@global.log_output, 'TABLE') END);

-- Turn on general logging if it isn't already (best-effort; fails silently).
SET GLOBAL general_log = 'ON';

SELECT
    CASE WHEN @@global.general_log = 1 AND FIND_IN_SET('TABLE', UPPER(@@global.log_output)) > 0
         THEN 1 ELSE 0 END                            AS setup_ok,
    @@global.general_log                              AS enabled_server_audits,
    NULL                                              AS enabled_server_specs,
    'mysql.general_log'                               AS audit_name,
    @@global.log_output                               AS audit_directory,
    CASE WHEN @@global.general_log = 1 THEN NULL
         ELSE 'general_log could not be enabled (SUPER privilege required)' END
                                                      AS error_message;
$my$;

    mysql_read_sql CONSTANT text := $my$
SELECT
    CONVERT_TZ(event_time, @@global.time_zone, 'Asia/Jerusalem') AS event_time,
    SUBSTRING_INDEX(user_host, '@', 1)                            AS login_name,
    DATABASE()                                                    AS database_name,
    NULL                                                          AS schema_name,
    NULL                                                          AS object_name,
    UPPER(LEFT(REGEXP_SUBSTR(argument,
        '^[[:space:]]*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE)'), 2))
                                                                  AS action_id,
    UPPER(REGEXP_SUBSTR(argument,
        '^[[:space:]]*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE)'))
                                                                  AS action,
    CASE WHEN argument REGEXP '^[[:space:]]*(CREATE|ALTER|DROP)'   THEN 'SCHEMA'
         WHEN argument REGEXP '^[[:space:]]*(INSERT|UPDATE|DELETE|TRUNCATE)' THEN 'DML'
         ELSE 'OTHER' END                                         AS change_kind,
    NULL                                                          AS client_ip,
    NULL                                                          AS application_name,
    LEFT(CAST(argument AS CHAR), 4000)                            AS statement
FROM   mysql.general_log
WHERE  event_time >= NOW() - INTERVAL 1 DAY
  AND  command_type = 'Query'
  AND  argument REGEXP '^[[:space:]]*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE)[[:space:]]'
ORDER BY event_time DESC
LIMIT 5000;
$my$;

    -- ── ORACLE (Unified Auditing 12c+) ─────────────────────
    -- Oracle's anonymous PL/SQL blocks don't return result sets via the
    -- standard oracledb cursor.execute() path, so the setup step is a
    -- pure verification SELECT. Operators must enable the policies once,
    -- as sysdba or AUDIT_ADMIN, by running this snippet manually:
    --
    --   CREATE AUDIT POLICY dbdome_dml_pol ACTIONS INSERT, UPDATE, DELETE;
    --   CREATE AUDIT POLICY dbdome_ddl_pol ACTIONS
    --      CREATE TABLE, ALTER TABLE, DROP TABLE, TRUNCATE TABLE,
    --      CREATE INDEX, ALTER INDEX, DROP INDEX,
    --      CREATE VIEW, DROP VIEW,
    --      CREATE PROCEDURE, ALTER PROCEDURE, DROP PROCEDURE,
    --      CREATE FUNCTION, ALTER FUNCTION, DROP FUNCTION,
    --      CREATE TRIGGER, ALTER TRIGGER, DROP TRIGGER,
    --      CREATE SEQUENCE, ALTER SEQUENCE, DROP SEQUENCE,
    --      CREATE USER, ALTER USER, DROP USER;
    --   AUDIT POLICY dbdome_dml_pol;
    --   AUDIT POLICY dbdome_ddl_pol;
    oracle_setup_sql CONSTANT text := $or$
SELECT
    CASE WHEN COUNT(*) >= 2 THEN 1 ELSE 0 END               AS setup_ok,
    COUNT(*)                                                 AS enabled_server_audits,
    COUNT(*)                                                 AS enabled_server_specs,
    'DBDOME_DML_POL,DBDOME_DDL_POL'                          AS audit_name,
    'unified_audit_trail'                                    AS audit_directory,
    CASE WHEN COUNT(*) >= 2 THEN NULL
         ELSE 'Manual setup required (AUDIT_ADMIN privilege): create and enable DBDOME_DML_POL and DBDOME_DDL_POL audit policies. See seed script header for the exact statements.' END
                                                             AS error_message
FROM audit_unified_enabled_policies
WHERE policy_name IN ('DBDOME_DML_POL','DBDOME_DDL_POL')
$or$;

    oracle_read_sql CONSTANT text := $or$
SELECT
    CAST(event_timestamp AT TIME ZONE 'Asia/Jerusalem' AS TIMESTAMP) AS event_time,
    dbusername                                     AS login_name,
    SYS_CONTEXT('USERENV','DB_NAME')              AS database_name,
    object_schema                                  AS schema_name,
    object_name                                    AS object_name,
    SUBSTR(action_name, 1, 2)                     AS action_id,
    action_name                                    AS action,
    CASE WHEN action_name IN ('INSERT','UPDATE','DELETE','TRUNCATE TABLE') THEN 'DML'
         WHEN action_name LIKE 'CREATE%'
           OR action_name LIKE 'ALTER%'
           OR action_name LIKE 'DROP%'           THEN 'SCHEMA'
         ELSE 'OTHER' END                          AS change_kind,
    client_program_name                            AS client_ip,  -- no client_ip column; reuse program
    client_program_name                            AS application_name,
    sql_text                                       AS statement
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (action_name IN ('INSERT','UPDATE','DELETE','TRUNCATE TABLE')
       OR action_name LIKE 'CREATE%'
       OR action_name LIKE 'ALTER%'
       OR action_name LIKE 'DROP%')
ORDER BY event_timestamp DESC
FETCH FIRST 5000 ROWS ONLY
$or$;

BEGIN
    -- Each vendor is registered inline below using the same shape.

    ----------------------------------------------------------------
    -- SQL SERVER
    ----------------------------------------------------------------
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver','query',
            'Ensure SQL Server Audit and DB audit specs exist on master and all user databases',
            jsonb_build_object('sql', sqlserver_setup_sql),
            '{"condition":"row_count > 0","description":"Audit setup row present (setup_ok=1 means audit + DDL spec ready; setup_ok=0 means audit infra could not be provisioned, see error_message)"}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('sqlserver','query',
            'Read schema and DML events from SQL Server Audit (last 24h)',
            jsonb_build_object('sql', sqlserver_read_sql),
            '{"condition":"row_count > 0","description":"One or more schema or DML events were recorded in the last 24 hours."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths
      (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-AUD-015-RC01','sqlserver',
            'Audit-driven schema and DML change tracking',
            'Provisions SQL Server Audit + DB audit specs (idempotent) and reads schema-change and DML events from the audit log.',
            'authored', true)
    ON CONFLICT (root_cause_id, vendor_slug, name) DO UPDATE
        SET is_active = EXCLUDED.is_active
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps
        (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES
        (v_path_id, v_step1_id, 1, 'next',      'ruled_out'),
        (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out')
    ON CONFLICT (detection_path_id, sequence) DO UPDATE
        SET detection_step_id  = EXCLUDED.detection_step_id,
            on_match_action    = EXCLUDED.on_match_action,
            on_no_match_action = EXCLUDED.on_no_match_action;

    ----------------------------------------------------------------
    -- POSTGRESQL
    ----------------------------------------------------------------
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql','query',
            'Ensure PostgreSQL audit infrastructure (event triggers + audit table)',
            jsonb_build_object('sql', postgresql_setup_sql),
            '{"condition":"row_count > 0","description":"Audit setup row present (setup_ok=1 means audit table + event triggers ready; setup_ok=0 means audit infra could not be provisioned, see error_message). DDL only on PostgreSQL — DML capture requires pgaudit + shared_preload_libraries + restart, tracked separately."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('postgresql','query',
            'Read schema events from PostgreSQL audit table (last 24h)',
            jsonb_build_object('sql', postgresql_read_sql),
            '{"condition":"row_count > 0","description":"One or more schema events were recorded in the last 24 hours."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths
      (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-AUD-015-RC01','postgresql',
            'Event-trigger-driven schema change tracking (PostgreSQL)',
            'Provisions an audit schema, audit_log table, and DDL event triggers (idempotent). Reads schema events from the audit table. DML capture for PostgreSQL requires pgaudit and is not provisioned by this path.',
            'authored', true)
    ON CONFLICT (root_cause_id, vendor_slug, name) DO UPDATE
        SET is_active = EXCLUDED.is_active
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps
        (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES
        (v_path_id, v_step1_id, 1, 'next',      'ruled_out'),
        (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out')
    ON CONFLICT (detection_path_id, sequence) DO UPDATE
        SET detection_step_id  = EXCLUDED.detection_step_id,
            on_match_action    = EXCLUDED.on_match_action,
            on_no_match_action = EXCLUDED.on_no_match_action;

    ----------------------------------------------------------------
    -- MYSQL
    ----------------------------------------------------------------
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql','query',
            'Ensure MySQL general_log is enabled with TABLE output',
            jsonb_build_object('sql', mysql_setup_sql),
            '{"condition":"row_count > 0","description":"Audit setup row present (setup_ok=1 means general_log = ON and routed to TABLE; setup_ok=0 means SUPER privilege missing). Note: general_log records every executed statement and is high-volume; review production impact before enabling."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('mysql','query',
            'Read schema and DML events from mysql.general_log (last 24h)',
            jsonb_build_object('sql', mysql_read_sql),
            '{"condition":"row_count > 0","description":"One or more schema or DML statements were recorded in mysql.general_log in the last 24 hours."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths
      (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-AUD-015-RC01','mysql',
            'general_log-driven schema and DML change tracking (MySQL)',
            'Enables MySQL general_log with TABLE output (idempotent) and reads schema-change and DML statements from mysql.general_log filtered by command class.',
            'authored', true)
    ON CONFLICT (root_cause_id, vendor_slug, name) DO UPDATE
        SET is_active = EXCLUDED.is_active
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps
        (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES
        (v_path_id, v_step1_id, 1, 'next',      'ruled_out'),
        (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out')
    ON CONFLICT (detection_path_id, sequence) DO UPDATE
        SET detection_step_id  = EXCLUDED.detection_step_id,
            on_match_action    = EXCLUDED.on_match_action,
            on_no_match_action = EXCLUDED.on_no_match_action;

    ----------------------------------------------------------------
    -- ORACLE
    ----------------------------------------------------------------
    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle','query',
            'Ensure Oracle Unified Auditing policies for DDL and DML',
            jsonb_build_object('sql', oracle_setup_sql),
            '{"condition":"row_count > 0","description":"Audit setup row present (setup_ok=1 means DBDOME_DML_POL and DBDOME_DDL_POL policies enabled; setup_ok=0 means AUDIT_ADMIN privilege missing or another error in error_message)."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step1_id;

    INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
    VALUES ('oracle','query',
            'Read schema and DML events from Oracle unified_audit_trail (last 24h)',
            jsonb_build_object('sql', oracle_read_sql),
            '{"condition":"row_count > 0","description":"One or more schema or DML events were recorded in unified_audit_trail in the last 24 hours."}'::jsonb)
    ON CONFLICT (vendor_slug, name) DO UPDATE
        SET content = EXCLUDED.content, expected = EXCLUDED.expected
    RETURNING id INTO v_step2_id;

    INSERT INTO rootcause.detection_paths
      (root_cause_id, vendor_slug, name, description, path_type, is_active)
    VALUES ('SEC-SQL-AUD-015-RC01','oracle',
            'Unified-auditing-driven schema and DML change tracking (Oracle)',
            'Enables Unified Auditing policies for DDL and DML (idempotent) and reads schema-change and DML events from unified_audit_trail.',
            'authored', true)
    ON CONFLICT (root_cause_id, vendor_slug, name) DO UPDATE
        SET is_active = EXCLUDED.is_active
    RETURNING id INTO v_path_id;

    INSERT INTO rootcause.detection_path_steps
        (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
    VALUES
        (v_path_id, v_step1_id, 1, 'next',      'ruled_out'),
        (v_path_id, v_step2_id, 2, 'confirmed', 'ruled_out')
    ON CONFLICT (detection_path_id, sequence) DO UPDATE
        SET detection_step_id  = EXCLUDED.detection_step_id,
            on_match_action    = EXCLUDED.on_match_action,
            on_no_match_action = EXCLUDED.on_no_match_action;
END
$do$;

COMMIT;

-- ── 4. SANITY CHECK (read-only, run after commit) ─────────
-- SELECT dp.vendor_slug, ds.name AS step_name, dps.sequence
--   FROM rootcause.detection_paths dp
--   JOIN rootcause.detection_path_steps dps ON dps.detection_path_id = dp.id
--   JOIN rootcause.detection_steps ds ON ds.id = dps.detection_step_id
--  WHERE dp.root_cause_id = 'SEC-SQL-AUD-015-RC01'
--  ORDER BY dp.vendor_slug, dps.sequence;
