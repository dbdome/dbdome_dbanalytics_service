-- ============================================================
-- Fix two SQL Server detections that errored against the target server.
--
--   SEC-SQL-AUTHZ-001-RC01: "Cannot resolve collation conflict for string_agg"
--     -> coerce the FIRST operand of each STRING_AGG to COLLATE DATABASE_DEFAULT.
--        An explicit collation on the first operand makes the whole '+' chain
--        (and the separator) explicit, so no operand conflict remains.
--
--   SEC-SQL-AUD-010-RC04: "Invalid column name 'is_sysadmin'"
--     -> sys.dm_exec_sessions has no is_sysadmin column; test server-role
--        membership with IS_SRVROLEMEMBER('sysadmin', login_name) instead.
--
-- Idempotent: each anchored substring stops matching once replaced, so a
-- second run changes nothing.
-- ============================================================

-- 1) SEC-SQL-AUTHZ-001-RC01 — STRING_AGG collation conflict
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb(
        replace(
            replace(content->>'sql',
                'STRING_AGG(rolep.name,',       'STRING_AGG(rolep.name COLLATE DATABASE_DEFAULT,'),
            'STRING_AGG(perm.state_desc +',     'STRING_AGG(perm.state_desc COLLATE DATABASE_DEFAULT +')
    ))
WHERE vendor_slug = 'sqlserver'
  AND content->>'sql' LIKE '%STRING_AGG(rolep.name,%';

-- 2) SEC-SQL-AUD-010-RC04 — sys.dm_exec_sessions has no is_sysadmin
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb(
        replace(
            replace(content->>'sql',
                's.is_sysadmin, t.text', 'IS_SRVROLEMEMBER(''sysadmin'', s.login_name) AS is_sysadmin, t.text'),
            's.is_sysadmin = 0',        'IS_SRVROLEMEMBER(''sysadmin'', s.login_name) = 0')
    ))
WHERE vendor_slug = 'sqlserver'
  AND content->>'sql' LIKE '%s.is_sysadmin = 0%';
