-- ============================================================
-- 6270  Second detection step for SEC-SQL-AUD-020 (sqlserver + oracle):
--   live-OR-audit two-step path. sqlserver step2 = fn_get_audit_file (guarded);
--   oracle step2 = v$session/v$sql live query (per SEC-SQL-ACC-011-RC02).
--   Auto-generated; edit build_step2.py and regenerate. Idempotent.
-- ============================================================
BEGIN;

-- 1) new detection steps (step 2 per rc x vendor) -------------------------
INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect SEC-SQL-AUD-020-RC01 (sqlserver) - audit trail (fn_get_audit_file)',
        '{"sql": "SET NOCOUNT ON;\nBEGIN TRY\n  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement\n  FROM sys.fn_get_audit_file(N''C:\\Audit\\dbdome_audit*.sqlaudit'', DEFAULT, DEFAULT)\n  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())\n    AND (statement LIKE ''%DROP%DATABASE%'' OR statement LIKE ''%DROP%SCHEMA%'')\n  ORDER BY event_time DESC;\nEND TRY\nBEGIN CATCH\n  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,\n         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,\n         CAST(NULL AS NVARCHAR(MAX)) AS statement\n  WHERE 1=0;\nEND CATCH"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC01 detected via audit trail"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Detect SEC-SQL-AUD-020-RC01 (oracle) - live activity (v$session)',
        '{"sql": "SELECT\n  TO_CHAR(SYSTIMESTAMP,''YYYY-MM-DD HH24:MI:SS'') AS event_time,\n  s.username AS login_name,\n  SYS_CONTEXT(''USERENV'',''DB_NAME'') AS database_name,\n  CAST(NULL AS VARCHAR2(128)) AS object_name,\n  SUBSTR(sq.sql_text,1,4000) AS statement\nFROM v$session s\nJOIN v$sql sq ON sq.sql_id = s.sql_id\nWHERE s.type = ''USER'' AND s.username IS NOT NULL\n  AND s.username NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''SYSMAN'',''XDB'')\n  AND (UPPER(sq.sql_text) LIKE ''%DROP DATABASE%'' OR UPPER(sq.sql_text) LIKE ''%DROP PLUGGABLE DATABASE%'' OR UPPER(sq.sql_text) LIKE ''%DROP TABLESPACE%'' OR UPPER(sq.sql_text) LIKE ''%DROP SCHEMA%'')"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC01 detected via live activity"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect SEC-SQL-AUD-020-RC02 (sqlserver) - audit trail (fn_get_audit_file)',
        '{"sql": "SET NOCOUNT ON;\nBEGIN TRY\n  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement\n  FROM sys.fn_get_audit_file(N''C:\\Audit\\dbdome_audit*.sqlaudit'', DEFAULT, DEFAULT)\n  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())\n    AND (statement LIKE ''%DROP%TABLE%'')\n  ORDER BY event_time DESC;\nEND TRY\nBEGIN CATCH\n  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,\n         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,\n         CAST(NULL AS NVARCHAR(MAX)) AS statement\n  WHERE 1=0;\nEND CATCH"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC02 detected via audit trail"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Detect SEC-SQL-AUD-020-RC02 (oracle) - live activity (v$session)',
        '{"sql": "SELECT\n  TO_CHAR(SYSTIMESTAMP,''YYYY-MM-DD HH24:MI:SS'') AS event_time,\n  s.username AS login_name,\n  SYS_CONTEXT(''USERENV'',''DB_NAME'') AS database_name,\n  CAST(NULL AS VARCHAR2(128)) AS object_name,\n  SUBSTR(sq.sql_text,1,4000) AS statement\nFROM v$session s\nJOIN v$sql sq ON sq.sql_id = s.sql_id\nWHERE s.type = ''USER'' AND s.username IS NOT NULL\n  AND s.username NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''SYSMAN'',''XDB'')\n  AND (UPPER(sq.sql_text) LIKE ''%DROP TABLE%'')"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC02 detected via live activity"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect SEC-SQL-AUD-020-RC03 (sqlserver) - audit trail (fn_get_audit_file)',
        '{"sql": "SET NOCOUNT ON;\nBEGIN TRY\n  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement\n  FROM sys.fn_get_audit_file(N''C:\\Audit\\dbdome_audit*.sqlaudit'', DEFAULT, DEFAULT)\n  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())\n    AND (statement LIKE ''%DROP%LOGIN%'' OR statement LIKE ''%DROP%USER%'' OR statement LIKE ''%DROP%ROLE%'')\n  ORDER BY event_time DESC;\nEND TRY\nBEGIN CATCH\n  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,\n         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,\n         CAST(NULL AS NVARCHAR(MAX)) AS statement\n  WHERE 1=0;\nEND CATCH"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC03 detected via audit trail"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Detect SEC-SQL-AUD-020-RC03 (oracle) - live activity (v$session)',
        '{"sql": "SELECT\n  TO_CHAR(SYSTIMESTAMP,''YYYY-MM-DD HH24:MI:SS'') AS event_time,\n  s.username AS login_name,\n  SYS_CONTEXT(''USERENV'',''DB_NAME'') AS database_name,\n  CAST(NULL AS VARCHAR2(128)) AS object_name,\n  SUBSTR(sq.sql_text,1,4000) AS statement\nFROM v$session s\nJOIN v$sql sq ON sq.sql_id = s.sql_id\nWHERE s.type = ''USER'' AND s.username IS NOT NULL\n  AND s.username NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''SYSMAN'',''XDB'')\n  AND (UPPER(sq.sql_text) LIKE ''%DROP USER%'' OR UPPER(sq.sql_text) LIKE ''%DROP ROLE%'')"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC03 detected via live activity"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('sqlserver', 'query', 'Detect SEC-SQL-AUD-020-RC04 (sqlserver) - audit trail (fn_get_audit_file)',
        '{"sql": "SET NOCOUNT ON;\nBEGIN TRY\n  SELECT TOP 500 event_time, server_principal_name AS login_name, database_name, object_name, statement\n  FROM sys.fn_get_audit_file(N''C:\\Audit\\dbdome_audit*.sqlaudit'', DEFAULT, DEFAULT)\n  WHERE event_time > DATEADD(DAY,-1, SYSUTCDATETIME())\n    AND (statement LIKE ''%DELETE%FROM%'' OR statement LIKE ''%TRUNCATE%TABLE%'')\n  ORDER BY event_time DESC;\nEND TRY\nBEGIN CATCH\n  SELECT CAST(NULL AS DATETIME2) AS event_time, CAST(NULL AS SYSNAME) AS login_name,\n         CAST(NULL AS SYSNAME) AS database_name, CAST(NULL AS SYSNAME) AS object_name,\n         CAST(NULL AS NVARCHAR(MAX)) AS statement\n  WHERE 1=0;\nEND CATCH"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC04 detected via audit trail"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

INSERT INTO rootcause.detection_steps (vendor_slug, step_type, name, content, expected)
VALUES ('oracle', 'query', 'Detect SEC-SQL-AUD-020-RC04 (oracle) - live activity (v$session)',
        '{"sql": "SELECT\n  TO_CHAR(SYSTIMESTAMP,''YYYY-MM-DD HH24:MI:SS'') AS event_time,\n  s.username AS login_name,\n  SYS_CONTEXT(''USERENV'',''DB_NAME'') AS database_name,\n  CAST(NULL AS VARCHAR2(128)) AS object_name,\n  SUBSTR(sq.sql_text,1,4000) AS statement\nFROM v$session s\nJOIN v$sql sq ON sq.sql_id = s.sql_id\nWHERE s.type = ''USER'' AND s.username IS NOT NULL\n  AND s.username NOT IN (''SYS'',''SYSTEM'',''DBSNMP'',''SYSMAN'',''XDB'')\n  AND (UPPER(sq.sql_text) LIKE ''%DELETE %'' OR UPPER(sq.sql_text) LIKE ''%TRUNCATE TABLE%'')"}'::jsonb,
        '{"condition": "row_count > 0", "description": "SEC-SQL-AUD-020-RC04 detected via live activity"}'::jsonb)
ON CONFLICT (vendor_slug, name) DO UPDATE SET content = EXCLUDED.content, expected = EXCLUDED.expected;

-- 2) wire step2 into each existing path; flip step1 on_no_match -> 'next' --
DO $g$
DECLARE v_path bigint; v_step2 bigint;
BEGIN
  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC01' AND vendor_slug = 'sqlserver' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC01 (sqlserver) - audit trail (fn_get_audit_file)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC01' AND vendor_slug = 'oracle' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC01 (oracle) - live activity (v$session)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC02' AND vendor_slug = 'sqlserver' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC02 (sqlserver) - audit trail (fn_get_audit_file)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC02' AND vendor_slug = 'oracle' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC02 (oracle) - live activity (v$session)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC03' AND vendor_slug = 'sqlserver' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC03 (sqlserver) - audit trail (fn_get_audit_file)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC03' AND vendor_slug = 'oracle' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC03 (oracle) - live activity (v$session)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC04' AND vendor_slug = 'sqlserver' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'sqlserver' AND name = 'Detect SEC-SQL-AUD-020-RC04 (sqlserver) - audit trail (fn_get_audit_file)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

  SELECT id INTO v_path FROM rootcause.detection_paths WHERE root_cause_id = 'SEC-SQL-AUD-020-RC04' AND vendor_slug = 'oracle' ORDER BY id LIMIT 1;
  SELECT id INTO v_step2 FROM rootcause.detection_steps WHERE vendor_slug = 'oracle' AND name = 'Detect SEC-SQL-AUD-020-RC04 (oracle) - live activity (v$session)' ORDER BY id DESC LIMIT 1;
  IF v_path IS NOT NULL AND v_step2 IS NOT NULL THEN
    UPDATE rootcause.detection_path_steps SET on_no_match_action = 'next', on_no_match_goto = NULL WHERE detection_path_id = v_path AND sequence = 1;
    IF NOT EXISTS (SELECT 1 FROM rootcause.detection_path_steps WHERE detection_path_id = v_path AND detection_step_id = v_step2) THEN
      INSERT INTO rootcause.detection_path_steps (detection_path_id, detection_step_id, sequence, on_match_action, on_no_match_action)
      VALUES (v_path, v_step2, 2, 'confirmed', 'ruled_out');
    END IF;
  END IF;

END
$g$;

-- 3) verify: 2 steps per rc x vendor ------------------------------------
SELECT root_cause_id, vendor_name, count(*) AS steps
FROM rootcause.v_rootcauses WHERE root_cause_id LIKE 'SEC-SQL-AUD-020-%'
GROUP BY 1,2 ORDER BY 1,2;

COMMIT;
