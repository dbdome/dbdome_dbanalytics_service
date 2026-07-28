-- =============================================================================
-- 6720_fix_rc12_mysql_mariadb_parens.sql
--
-- SEC-SQL-PRI-001-RC12 (sensitive-columns inventory) for vendors mysql and
-- mariadb has unbalanced parentheses in its detection SQL:
--     ... AND (column_name LIKE '%ssn%' OR (column_name LIKE '%bvn%' OR ...
--     ... LIKE '%biometric%') ORDER BY ...
-- two opens, one close -> MySQL/MariaDB error 1064 near 'ORDER BY', so the
-- metric fails on every mysql/mariadb target. Remove the stray second '('
-- (the close paren before ORDER BY then balances the first).
--
-- The query lives in rootcause.detection_steps.content->'sql' (json) and
-- reaches the collector via rootcause.v_rootcauses -> metrics.v_custom_metrics.
-- Idempotent: the replace is a no-op once the stray '(' is gone.
-- =============================================================================

DO $$
DECLARE n int;
BEGIN
    UPDATE rootcause.detection_steps
    SET content = replace(
            content::text,
            '''%ssn%'' OR (column_name LIKE ''%bvn%''',
            '''%ssn%'' OR column_name LIKE ''%bvn%''')::json
    WHERE strpos(content::text, '''%ssn%'' OR (column_name LIKE ''%bvn%''') > 0;
    GET DIAGNOSTICS n = ROW_COUNT;
    RAISE NOTICE '6720: fixed unbalanced parens in % detection_steps row(s)', n;
END $$;
