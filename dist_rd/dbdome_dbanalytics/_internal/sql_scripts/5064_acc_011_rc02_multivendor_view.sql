-- =============================================================================
-- 5064_acc_011_rc02_multivendor_view.sql
-- Make monitoring.v_sec_sql_acc_011_rc02 render rows from ALL vendors
-- (sqlserver/WhoIsActive keys + oracle/postgresql/mysql/mariadb canonical keys)
-- and expose transaction_begin_time as a timestamp WITHOUT time zone (no
-- Asia/Jerusalem conversion).
--
-- 1) Oracle query: v$transaction.start_time is a 'MM/DD/YY HH24:MI:SS' string;
--    convert to an ISO 'YYYY-MM-DD HH24:MI:SS' string so the view parses it.
-- 2) Rebuild the view to coalesce both key sets; transaction_begin_time tolerates
--    epoch-ms (pandas-serialised datetimes: sqlserver/pg/mysql) and ISO strings
--    (oracle), yielding 'timestamp without time zone'.
-- The view changes column type, so DROP CASCADE + recreate; the dependent
-- monitoring.v_all_active_transactions (2700) is recreated right after.
-- =============================================================================

-- 1) Oracle: ISO transaction_begin_time -------------------------------------
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb(
        replace(content->>'sql',
            $f$t.start_time AS transaction_begin_time$f$,
            $r$TO_CHAR(TO_DATE(t.start_time,'MM/DD/YY HH24:MI:SS'),'YYYY-MM-DD HH24:MI:SS') AS transaction_begin_time$r$)
    ))
WHERE vendor_slug = 'oracle' AND name LIKE '%ACC-011-RC02%';

-- 2) Multi-vendor, tz-free view ---------------------------------------------
DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_011_rc02 CASCADE;
CREATE VIEW monitoring.v_sec_sql_acc_011_rc02 AS
SELECT
    b.server,
    b.server_id,
    b.v ->> 'session_id'                          AS session_id,
    b.v ->> 'login_name'                          AS login_name,
    b.v ->> 'host_name'                           AS host_name,
    b.v ->> 'program_name'                        AS program_name,
    b.v ->> 'database_name'                        AS database_name,
    b.v ->> 'transaction_id'                       AS transaction_id,
    -- timestamp WITHOUT time zone: epoch-ms (sqlserver/pg/mysql) or ISO (oracle)
    CASE
        WHEN bt.val ~ '^[0-9]{9,}$'
            THEN (to_timestamp(bt.val::double precision /
                    CASE WHEN length(bt.val) >= 13 THEN 1000 ELSE 1 END) AT TIME ZONE 'UTC')
        WHEN bt.val ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
            THEN bt.val::timestamp
        ELSE NULL
    END                                            AS transaction_begin_time,
    COALESCE(b.v ->> 'duration_seconds',
             (NULLIF(b.v ->> 'elapsed_ms','')::numeric / 1000.0)::text) AS duration_seconds,
    COALESCE(b.v ->> 'transaction_state',
             b.v ->> 'activity',
             b.v ->> 'status')                     AS transaction_state,
    COALESCE(b.v ->> 'query_text',
             b.v ->> 'sql_text')                   AS query_text,
    b.entry_date,
    (
        EXTRACT(DOW  FROM b.entry_date) IN (5, 6)
        OR EXTRACT(HOUR FROM b.entry_date) < 8
        OR EXTRACT(HOUR FROM b.entry_date) >= 18
    )                                              AS after_hours,
    (
        COALESCE(NULLIF(b.v ->> 'open_tran_count','')::numeric, 0) > 0
        OR NULLIF(b.v ->> 'transaction_id','') IS NOT NULL
        OR bt.val IS NOT NULL
    )                                              AS in_transaction
FROM (
    SELECT r.server, r.server_id, r.entry_date, monitoring.jsonb_lower_keys(j_raw.value) AS v
    FROM monitoring.general_metric_metadata_results r
    CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value)
    WHERE r.metric_name = 'SEC-SQL-ACC-011-RC02'
) b
CROSS JOIN LATERAL (
    SELECT NULLIF(COALESCE(b.v ->> 'transaction_begin_time', b.v ->> 'tran_begin_time'), '') AS val
) bt;

-- VERIFY
SELECT 'view ok' WHERE EXISTS (SELECT 1 FROM information_schema.views
  WHERE table_schema='monitoring' AND table_name='v_sec_sql_acc_011_rc02');
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='monitoring' AND table_name='v_sec_sql_acc_011_rc02'
  AND column_name='transaction_begin_time';
