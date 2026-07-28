-- ============================================================
-- Copy the SQL Server detection CONTENT of PERF-SQL-TX-010-RC02
-- into PERF-SQL-QE-001-RC04.
--
-- In rootcause.v_rootcauses the `content` column comes from
-- rootcause.detection_steps.content (the {'sql': ...} the collector runs),
-- reached via detection_paths -> detection_path_steps -> detection_steps,
-- vendor = detection_steps.vendor_slug.
--
-- Source: PERF-SQL-TX-010-RC02 / sqlserver -> step id 15639
--         ("Retrieve active transactions with execution plan")
-- Target: PERF-SQL-QE-001-RC04 / sqlserver -> step ids 2230, 2231
--         (both belong ONLY to this root cause - safe to overwrite)
--
-- NOTE 1: QE-001-RC04 has TWO sqlserver steps; BOTH are set to the source
--         content, so all of QE-001-RC04's sqlserver content becomes the
--         TX-010-RC02 content.
-- NOTE 2: only `content` (the SQL) is copied. The steps' `expected` conditions
--         are LEFT AS-IS and were written for the old query's output columns,
--         so they may no longer match the active-transactions query's columns.
--         To also copy `expected` (recommended for a consistent detection),
--         uncomment the second SET line below.
-- ============================================================

-- ---- OPTIONAL PREVIEW (run alone; changes nothing) ----
-- SELECT dp.root_cause_id, s.id, s.name, left(s.content::text,60) AS content_now
-- FROM rootcause.detection_paths dp
-- JOIN rootcause.detection_path_steps ps ON ps.detection_path_id = dp.id
-- JOIN rootcause.detection_steps s ON s.id = ps.detection_step_id
-- WHERE dp.root_cause_id IN ('PERF-SQL-QE-001-RC04','PERF-SQL-TX-010-RC02')
--   AND s.vendor_slug = 'sqlserver'
-- ORDER BY dp.root_cause_id, s.id;
-- -------------------------------------------------------

BEGIN;

WITH src AS (
    SELECT s.content, s.expected
    FROM rootcause.detection_paths dp
    JOIN rootcause.detection_path_steps ps ON ps.detection_path_id = dp.id
    JOIN rootcause.detection_steps s ON s.id = ps.detection_step_id
    WHERE dp.root_cause_id = 'PERF-SQL-TX-010-RC02'
      AND s.vendor_slug = 'sqlserver'
    LIMIT 1
),
tgt AS (
    SELECT s.id
    FROM rootcause.detection_paths dp
    JOIN rootcause.detection_path_steps ps ON ps.detection_path_id = dp.id
    JOIN rootcause.detection_steps s ON s.id = ps.detection_step_id
    WHERE dp.root_cause_id = 'PERF-SQL-QE-001-RC04'
      AND s.vendor_slug = 'sqlserver'
)
UPDATE rootcause.detection_steps d
SET content  = src.content
    -- , expected = src.expected      -- uncomment to also copy the match condition
FROM src
WHERE d.id IN (SELECT id FROM tgt);

COMMIT;   -- or ROLLBACK;
