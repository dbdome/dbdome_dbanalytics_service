-- ============================================================
-- 6350  Add BVN (Bank Verification Number, an ID number) as a recognised sensitive
--       column across ALL sensitive-column / sensitive-data detection rules.
--
--   For every rootcause.detection_steps whose SQL scans column names for the 'ssn'
--   PII anchor, add a parallel 'bvn' match, handling the three styles used:
--     * LIKE lists / CASE WHEN :  <expr> LIKE '%ssn%'  -> ... OR <expr> LIKE '%bvn%'
--     * regex alternation       :  ~ '(ssn|...)'       -> ~ '(ssn|bvn|...)'
--     * VALUES pattern rows      :  ('ssn|...','SSN')   -> ('ssn|bvn|...','SSN')
--   Idempotent: rows already containing 'bvn' are skipped.
--
--   Companion code change (discovery patterns) is in
--   processes/sensitive_schema_discovery.py and processes/continuous_data_discovery.py
--   (BVN added to the national-ID / SSN group), so auto-discovery of sensitive columns
--   also recognises BVN.
-- ============================================================

UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb(
    regexp_replace(
      regexp_replace(
        content->>'sql',
        '(\S+)\s+LIKE\s+(''%ssn%'')',
        '\1 LIKE \2 OR \1 LIKE ''%bvn%''', 'gi'),
      '([''(|])ssn([|)''])',
      '\1ssn|bvn\2', 'gi')
))
WHERE content->>'sql' ~* '(^|[^[:alpha:]])ssn([^[:alpha:]]|$)'
  AND content->>'sql' !~* 'bvn';

-- verify: how many detection steps now recognise BVN
SELECT count(*) AS steps_with_bvn
FROM rootcause.detection_steps
WHERE content->>'sql' ~* '\mbvn\M';
