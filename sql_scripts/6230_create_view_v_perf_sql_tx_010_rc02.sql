-- ============================================================
-- View: monitoring.v_perf_sql_tx_010_rc02
-- Root cause: PERF-SQL-TX-010-RC02 (sqlserver)
--   "Active transactions snapshot with execution plans" - sibling of
--   PERF-SQL-TX-010-RC01 (6200) that additionally returns EACH active request's
--   execution plan as XML text via sys.dm_exec_text_query_plan(). Excludes the
--   monitoring session ( s.session_id <> @@SPID ) and the dbdome account.
--
-- Projects the per-row JSON the collector stores in
-- monitoring.general_metric_metadata_results.metric_metadata (a jsonb array,
-- one element per active request) into flat columns. Column vocabulary is kept
-- consistent with monitoring.v_perf_sql_tx_010_rc01 (6220) so the two views can
-- be queried / compared with the same names; the RC02-specific addition is
-- execution_plan_xml.
--
-- Detection output keys (sqlserver): session_id, status, login_name, host_name,
--   program_name, database_name, command, wait_type, wait_time,
--   blocking_session_id, cpu_ms, elapsed_ms, reads, writes, logical_reads,
--   request_start_time, query_text, execution_plan_xml.
--
-- pandas to_json serialises datetimes as epoch MILLISECONDS, hence the
-- to_timestamp(... / 1000) conversion on request_start_time. Numeric columns
-- use NULLIF(...,'')::numeric because pandas serialises int columns that contain
-- NULLs as floats ("123.0"). jsonb_lower_keys() guards vendor case variance.
-- Idempotent: DROP + CREATE (no dependents).
-- ============================================================

DROP VIEW IF EXISTS monitoring.v_perf_sql_tx_010_rc02;

CREATE VIEW monitoring.v_perf_sql_tx_010_rc02 AS
SELECT
    r.server,
    j.value ->> 'command'                                  AS command,
    j.value ->> 'cpu_ms'                                   AS cpu_time,
    j.value ->> 'database_name'                            AS database_name,
    (NULLIF(j.value ->> 'elapsed_ms','')::numeric / 1000.0)::text  AS elapsed_sec,
    j.value ->> 'host_name'                                AS host_name,
    j.value ->> 'login_name'                               AS login_name,
    j.value ->> 'program_name'                             AS program_name,
    j.value ->> 'query_text'                               AS query_text,
    j.value ->> 'reads'                                    AS reads,
    j.value ->> 'session_id'                               AS session_id,
    j.value ->> 'status'                                  AS status,
    j.value ->> 'wait_time'                               AS wait_time,
    j.value ->> 'wait_type'                               AS wait_type,
    j.value ->> 'writes'                                  AS writes,
    (r.entry_date AT TIME ZONE 'Asia/Jerusalem')          AS entry_date,
    -- ---- typed / RC02-specific columns ----
    NULLIF(j.value ->> 'blocking_session_id','')::numeric AS blocking_session_id,
    NULLIF(j.value ->> 'cpu_ms','')::numeric              AS cpu_ms,
    NULLIF(j.value ->> 'elapsed_ms','')::numeric          AS elapsed_ms,
    NULLIF(j.value ->> 'logical_reads','')::numeric       AS logical_reads,
    (NULLIF(j.value ->> 'elapsed_ms','')::numeric / 1000.0)::text  AS duration_seconds,
    (to_timestamp(NULLIF(j.value ->> 'request_start_time','')::bigint / 1000.0)
        AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Jerusalem' AS request_start_time,
    j.value ->> 'execution_plan_xml'                      AS execution_plan_xml,
    -- after_hours: observed outside Sun-Thu 08:00-18:00 (Asia/Jerusalem).
    -- EXTRACT(DOW): Sun=0..Sat=6, so weekend = 5 (Fri), 6 (Sat).
    (
        EXTRACT(DOW  FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) IN (5, 6)
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) < 8
        OR EXTRACT(HOUR FROM (r.entry_date::timestamptz AT TIME ZONE 'Asia/Jerusalem')) >= 18
    )                                                         AS after_hours
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j_raw(value),
LATERAL (SELECT monitoring.jsonb_lower_keys(j_raw.value) AS value) j
WHERE r.metric_name = 'PERF-SQL-TX-010-RC02';
