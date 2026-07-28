-- ============================================================
-- Backfill missing hours in monitoring.gmmr_2026_06
--
-- Finds hour-buckets that have NO records (within the table's observed
-- first..last-hour range) and fills each from the NEAREST other day that has
-- records at the same hour-of-day (ties -> the earlier day). Every column is
-- copied from the donor rows EXCEPT the auto-generated `id`; `entry_date` is set
-- to the MISSING day + the donor row's time-of-day, e.g.
--     donor  2026-06-12 11:17:22   ->   new  2026-06-11 11:17:22
--
-- Idempotent: after a run the filled hours have records, so re-running finds no
-- missing hours and inserts nothing.
--
-- To target another monthly partition, replace monitoring.gmmr_2026_06
-- everywhere below (it appears in present_hours, bounds, the donor lateral,
-- and the INSERT/JOIN).
-- ============================================================

-- ---- OPTIONAL PREVIEW ---------------------------------------------------------
-- Run this SELECT on its own first to review what will be inserted (missing hour,
-- chosen donor day, and how many rows it will add). It changes nothing.
--
-- WITH present_hours AS (
--     SELECT DISTINCT date_trunc('hour', entry_date) AS h FROM monitoring.gmmr_2026_06
-- ), bounds AS (
--     SELECT date_trunc('hour', min(entry_date)) AS lo,
--            date_trunc('hour', max(entry_date)) AS hi FROM monitoring.gmmr_2026_06
-- ), grid AS (
--     SELECT generate_series(lo, hi, interval '1 hour') AS h FROM bounds
-- ), missing AS (
--     SELECT g.h AS missing_hour, g.h::date AS missing_day,
--            extract(hour FROM g.h)::int AS hod
--     FROM grid g LEFT JOIN present_hours p ON p.h = g.h WHERE p.h IS NULL
-- ), donor AS (
--     SELECT m.missing_hour, m.missing_day, m.hod, d.donor_day FROM missing m
--     CROSS JOIN LATERAL (
--         SELECT s.entry_date::date AS donor_day FROM monitoring.gmmr_2026_06 s
--         WHERE extract(hour FROM s.entry_date)::int = m.hod
--           AND s.entry_date::date <> m.missing_day
--         GROUP BY s.entry_date::date
--         ORDER BY abs(s.entry_date::date - m.missing_day), s.entry_date::date LIMIT 1
--     ) d
-- )
-- SELECT d.missing_hour, d.donor_day,
--        (SELECT count(*) FROM monitoring.gmmr_2026_06 s
--          WHERE s.entry_date::date = d.donor_day
--            AND extract(hour FROM s.entry_date)::int = d.hod) AS rows_to_add
-- FROM donor d ORDER BY d.missing_hour;
-- -----------------------------------------------------------------------------

BEGIN;

WITH present_hours AS (
    SELECT DISTINCT date_trunc('hour', entry_date) AS h
    FROM monitoring.gmmr_2026_06
),
bounds AS (
    SELECT date_trunc('hour', min(entry_date)) AS lo,
           date_trunc('hour', max(entry_date)) AS hi
    FROM monitoring.gmmr_2026_06
),
grid AS (
    SELECT generate_series(lo, hi, interval '1 hour') AS h FROM bounds
),
missing AS (   -- hour-buckets in range with zero rows
    SELECT g.h AS missing_hour, g.h::date AS missing_day,
           extract(hour FROM g.h)::int AS hod
    FROM grid g
    LEFT JOIN present_hours p ON p.h = g.h
    WHERE p.h IS NULL
),
donor AS (     -- nearest other day that has rows at the same hour-of-day
    SELECT m.missing_hour, m.missing_day, m.hod, d.donor_day
    FROM missing m
    CROSS JOIN LATERAL (
        SELECT s.entry_date::date AS donor_day
        FROM monitoring.gmmr_2026_06 s
        WHERE extract(hour FROM s.entry_date)::int = m.hod
          AND s.entry_date::date <> m.missing_day
        GROUP BY s.entry_date::date
        ORDER BY abs(s.entry_date::date - m.missing_day), s.entry_date::date
        LIMIT 1
    ) d
)
INSERT INTO monitoring.gmmr_2026_06
    (row_id, server, category_id, metric_name, metric_config, metric_metadata,
     entry_date, metric_metadata_vs_expected, server_id)
SELECT s.row_id, s.server, s.category_id, s.metric_name, s.metric_config,
       s.metric_metadata,
       d.missing_day + (s.entry_date - date_trunc('day', s.entry_date)) AS entry_date,
       s.metric_metadata_vs_expected, s.server_id
FROM donor d
JOIN monitoring.gmmr_2026_06 s
  ON s.entry_date::date = d.donor_day
 AND extract(hour FROM s.entry_date)::int = d.hod;

-- Review the INSERT row count above, then keep or discard:
COMMIT;   -- or ROLLBACK;
