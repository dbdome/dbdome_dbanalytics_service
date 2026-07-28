-- ============================================================
-- Generate synthetic "Active transactions" captures for every hour of every day
-- in May 2026, into monitoring.gmmr_2026_05.
--
-- Source pool: all UNIQUE transactions (by query_text) taken from June's
-- ("Active transactions" / "active transactions") rows in monitoring.gmmr_2026_06
-- -- each metric_metadata element is one transaction object carrying query_text.
--
-- For each of the 31*24 = 744 hourly slots it inserts ONE row:
--   * metric_name    = 'Active transactions'
--   * metric_metadata= a RANDOM subset (random 3..20) of the unique-tx pool
--   * entry_date     = that day+hour + a random second within the hour
--   * server / server_id / category_id / metric_config copied from a
--     representative June row; id auto-generates; row_id / vs_expected = NULL
-- ============================================================

BEGIN;

WITH pool AS MATERIALIZED (           -- one representative tx per unique query_text
    SELECT DISTINCT ON (e->>'query_text') e AS tx
    FROM monitoring.gmmr_2026_06 r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) e
    WHERE r.metric_name IN ('Active transactions', 'active transactions')
      AND e ? 'query_text'
    ORDER BY e->>'query_text'
),
template AS (                         -- row-level fields for the synthetic captures
    SELECT server, server_id, category_id, metric_config
    FROM monitoring.gmmr_2026_06
    WHERE metric_name IN ('Active transactions', 'active transactions')
      AND metric_config IS NOT NULL
    ORDER BY entry_date DESC
    LIMIT 1
),
hours AS MATERIALIZED (               -- 744 hourly slots, each with its own random size
    SELECT gs AS h, (3 + floor(random() * 18))::int AS k
    FROM generate_series(timestamp '2026-05-01 00:00:00',
                         timestamp '2026-05-31 23:00:00',
                         interval '1 hour') gs
),
picks AS MATERIALIZED (               -- rank the pool randomly within each hour
    SELECT h.h, h.k, p.tx,
           row_number() OVER (PARTITION BY h.h ORDER BY random()) AS rn
    FROM hours h CROSS JOIN pool p
),
captures AS (                         -- keep the first k -> a random subset per hour
    SELECT h, jsonb_agg(tx) AS md
    FROM picks
    WHERE rn <= k
    GROUP BY h
)
INSERT INTO monitoring.gmmr_2026_05
    (row_id, server, category_id, metric_name, metric_config,
     metric_metadata, entry_date, metric_metadata_vs_expected, server_id)
SELECT NULL, t.server, t.category_id, 'Active transactions', t.metric_config,
       c.md,
       c.h + (floor(random() * 3600) * interval '1 second') AS entry_date,
       NULL, t.server_id
FROM captures c CROSS JOIN template t;

COMMIT;   -- or ROLLBACK;
