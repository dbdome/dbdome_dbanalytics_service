
  -- ============================================================
  -- SEC-SQL-ENC-005-RC10: Registry-based cipher check fails
  -- Fix: Use sys.dm_exec_connections to check actual TLS in use
  -- ============================================================
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT encrypt_option, COUNT(*) AS connection_count FROM sys.dm_exec_connections WHERE session_id IN (SELECT
  session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1) GROUP BY encrypt_option'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE dp.root_cause_id = 'SEC-SQL-ENC-005-RC10'
        AND ds.vendor_slug = 'sqlserver'
        AND ds.content::text LIKE '%xp_instance_regread%'
  );

  -- ============================================================
  -- SEC-SQL-ENC-005-RC11: Same registry-batch issue
  -- Fix: Check for weak protocol versions via dm_exec_connections
  -- ============================================================
  UPDATE rootcause.detection_steps
  SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
      'SELECT encrypt_option, protocol_type, auth_scheme, COUNT(*) AS connection_count FROM sys.dm_exec_connections
  WHERE session_id IN (SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process = 1) GROUP BY encrypt_option,
  protocol_type, auth_scheme'::text
  ))
  WHERE id IN (
      SELECT ds.id FROM rootcause.detection_steps ds
      JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
      JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
      WHERE dp.root_cause_id = 'SEC-SQL-ENC-005-RC11'
        AND ds.vendor_slug = 'sqlserver'
        AND ds.content::text LIKE '%xp_instance_regread%'
  );


-- ============================================================
-- Fix MSSQL detection step SQL errors
-- Run against dbanalytics (EDB AS 17, port 5444)
-- content column is JSON: {"sql": "..."} — use jsonb_set
-- ============================================================

-- ============================================================
-- SEC-SQL-AUD-008-RC04: Invalid column 'create_date' in sys.certificates
-- Fix: sys.certificates uses 'start_date' not 'create_date'
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT name, symmetric_key_id, key_algorithm, key_length, create_date FROM sys.symmetric_keys UNION ALL SELECT name, certificate_id, CAST(subject AS NVARCHAR(128)), key_length, start_date FROM sys.certificates'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-008-RC04'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%create_date%FROM sys.certificates%'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC01 (step 1): Wrong JOIN condition
-- session_id joined to last_execution_time (datetime), r.start_time undefined
-- Fix: Use dm_exec_requests properly
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT s.login_name, count(*) AS catalog_queries, max(r.start_time) AS last_seen FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE (t.text LIKE ''%INFORMATION_SCHEMA%'' OR t.text LIKE ''%sys.objects%'' OR t.text LIKE ''%sys.columns%'' OR t.text LIKE ''%sys.tables%'') AND r.start_time > DATEADD(minute,-5,GETDATE()) GROUP BY s.login_name HAVING count(*) > 20'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-010-RC01'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%dm_exec_query_stats qs ON s.session_id = qs.last_execution_time%'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC01 (step 2): Wrong JOIN - session_id = last_execution_time
-- Fix: Remove bad join to dm_exec_sessions, group by compile time
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT TOP 10 q.initial_compile_start_time, count(DISTINCT qt.query_sql_text) AS catalog_query_variants FROM sys.query_store_query_text qt JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id JOIN sys.query_store_runtime_stats rs ON rs.plan_id IN (SELECT plan_id FROM sys.query_store_plan WHERE query_id = q.query_id) WHERE qt.query_sql_text LIKE ''%INFORMATION_SCHEMA%'' OR qt.query_sql_text LIKE ''%sys.columns%'' GROUP BY q.initial_compile_start_time ORDER BY catalog_query_variants DESC'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-010-RC01'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%dm_exec_sessions s ON s.session_id = rs.last_execution_time%'
);

-- ============================================================
-- SEC-SQL-AUD-010-RC02: Invalid column 'is_sysadmin' in dm_exec_sessions
-- Fix: Use IS_SRVROLEMEMBER instead
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT s.login_name, CAST(t.text AS NVARCHAR(4000)) AS query_text, r.start_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 0 AND (t.text LIKE ''%sys.server_principals%'' OR t.text LIKE ''%sys.database_principals%'' OR t.text LIKE ''%sys.sql_logins%'')'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-010-RC02'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%s.is_sysadmin%'
);

-- ============================================================
-- SEC-SQL-AUD-012-RC04: Invalid column 'session_id' in dm_tran_database_transactions
-- Fix: Join through dm_tran_session_transactions
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT st.session_id, dt.database_id, dt.database_transaction_begin_time, dt.database_transaction_log_bytes_used, dt.database_transaction_log_bytes_reserved, dt.database_transaction_type FROM sys.dm_tran_database_transactions dt JOIN sys.dm_tran_session_transactions st ON st.transaction_id = dt.transaction_id WHERE dt.database_transaction_log_bytes_used > 10485760 ORDER BY dt.database_transaction_log_bytes_used DESC'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-012-RC04'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%SELECT session_id%FROM sys.dm_tran_database_transactions%'
);

-- ============================================================
-- SEC-SQL-AUD-013-RC01: Invalid column 'is_sysadmin' in dm_exec_sessions
-- Fix: Use IS_SRVROLEMEMBER
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT s.login_name, CAST(t.text AS NVARCHAR(4000)) AS query_text, r.start_time FROM sys.dm_exec_sessions s JOIN sys.dm_exec_requests r ON s.session_id = r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t WHERE IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 0 AND t.text LIKE ''%sp_configure%'''::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-013-RC01'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%s.is_sysadmin%'
);

-- ============================================================
-- SEC-SQL-AUD-013-RC04: Invalid column 'type_desc' in audit specifications
-- Fix: Use audit_guid instead
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT name, is_state_enabled, audit_guid, modify_date FROM sys.server_audit_specifications UNION ALL SELECT name, is_state_enabled, audit_guid, modify_date FROM sys.database_audit_specifications'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-013-RC04'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%type_desc%audit_specifications%'
);

-- ============================================================
-- SEC-SQL-AUD-014-RC03: Invalid column 'password_last_set_time' in sys.sql_logins
-- Fix: Replace with default_database_name
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT name, type_desc, is_disabled, modify_date, default_database_name FROM sys.sql_logins WHERE modify_date > DATEADD(hour,-1,GETDATE()) ORDER BY modify_date DESC'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-014-RC03'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%password_last_set_time%'
);

-- ============================================================
-- SEC-SQL-AUD-007-RC03: fn_get_audit_file hardcoded path doesn't exist
-- Fix: Use sys.dm_exec_connections for unexpected network addresses
-- ============================================================
UPDATE rootcause.detection_steps
SET content = jsonb_set(content::jsonb, '{sql}', to_jsonb(
    'SELECT s.login_name, c.client_net_address, s.program_name, s.login_time, s.host_name FROM sys.dm_exec_sessions s JOIN sys.dm_exec_connections c ON s.session_id = c.session_id WHERE s.is_user_process = 1 AND c.client_net_address NOT LIKE ''10.%'' AND c.client_net_address NOT LIKE ''192.168.%'' AND c.client_net_address NOT LIKE ''127.%'' AND c.client_net_address NOT LIKE ''<local machine>'' ORDER BY s.login_time DESC'::text
))
WHERE id IN (
    SELECT ds.id FROM rootcause.detection_steps ds
    JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
    JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
    WHERE dp.root_cause_id = 'SEC-SQL-AUD-007-RC03'
      AND ds.vendor_slug = 'sqlserver'
      AND ds.content::text LIKE '%fn_get_audit_file%'
);

-- ============================================================
-- DIAGNOSTIC: Find remaining broken steps
-- (001-RC04, 001-RC05, 001-RC12, 004-RC03, 004-RC06, 004-RC07)
-- ============================================================
-- SELECT dp.root_cause_id, ds.vendor_slug, ds.name, ds.content
-- FROM rootcause.detection_steps ds
-- JOIN rootcause.detection_path_steps dps ON dps.detection_step_id = ds.id
-- JOIN rootcause.detection_paths dp ON dp.id = dps.detection_path_id
-- WHERE dp.root_cause_id IN (
--     'SEC-SQL-AUD-001-RC04', 'SEC-SQL-AUD-001-RC05', 'SEC-SQL-AUD-001-RC12',
--     'SEC-SQL-AUD-004-RC03', 'SEC-SQL-AUD-004-RC06', 'SEC-SQL-AUD-004-RC07'
-- )
-- AND ds.vendor_slug = 'sqlserver'
-- ORDER BY dp.root_cause_id, dps.sequence;
