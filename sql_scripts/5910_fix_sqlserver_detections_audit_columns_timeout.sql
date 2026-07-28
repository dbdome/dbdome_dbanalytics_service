-- ============================================================
-- Fix two more SQL Server detections that errored against the target server.
--
--   SEC-SQL-PRI-005-RC03: "Invalid column name 'max_rollover_files'/'max_file_size'"
--     -> those columns are on sys.server_file_audits, not sys.server_audits.
--        Correct the FROM clause.
--
--   SEC-SQL-AU-001-RC06: query timeout ("driver did not supply an error")
--     -> the NOT EXISTS wrapped sys.database_principals in a sys.databases
--        CROSS APPLY, but sys.database_principals always reflects the CURRENT
--        database regardless of the join, so iterating databases was a pure
--        Cartesian. Collapse to a single NOT EXISTS (identical result, fast).
--
-- Idempotent: anchored substrings / patterns stop matching once replaced.
-- ============================================================

-- 1) SEC-SQL-PRI-005-RC03 — wrong catalog view
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb(
        replace(content->>'sql',
            'max_file_size FROM sys.server_audits',
            'max_file_size FROM sys.server_file_audits')))
WHERE vendor_slug = 'sqlserver'
  AND content->>'sql' LIKE '%max_file_size FROM sys.server_audits%';

-- 2) SEC-SQL-AU-001-RC06 — collapse the redundant sys.databases CROSS APPLY
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb(
        regexp_replace(content->>'sql',
            'FROM\s+sys\.databases\s+d\s+CROSS APPLY\s*\(\s*SELECT\s+dp\.sid\s+FROM\s+sys\.database_principals\s+dp\s+WHERE\s+dp\.sid\s*=\s*sp\.sid\s+AND\s+dp\.type\s*=\s*''S''\s*\)\s*u',
            'FROM sys.database_principals dp WHERE dp.sid = sp.sid AND dp.type = ''S''', 'g')))
WHERE vendor_slug = 'sqlserver'
  AND content->>'sql' ~ 'FROM\s+sys\.databases\s+d\s+CROSS APPLY\s*\(\s*SELECT\s+dp\.sid\s+FROM\s+sys\.database_principals\s+dp\s+WHERE\s+dp\.sid\s*=\s*sp\.sid';
