-- ============================================================
-- SEC-SQL-ACC-010-RC10  "Same login active from multiple hosts"
--
-- Add the queries each session is running to the detection (an aggregated
-- `queries` column, one row per login). Only the sqlserver step was correct;
-- the other four vendors held mismatched placeholder SQL (plugins / deadlocks /
-- FK-index), so those are replaced with a proper multi-host-login detection that
-- also surfaces the per-user queries.
--
-- Output per row: login_name, host_count, hosts, session_count, queries
-- Finding condition stays: row_count > 0 (HAVING already requires >1 host).
--
-- Idempotent: full-value SET, so re-running stores the same content.
--
-- Privilege notes:
--   * postgresql: query text of other users needs superuser / pg_read_all_stats.
--   * mysql/mariadb: GROUP_CONCAT is bounded by group_concat_max_len (1024 default).
--   * sqlserver/oracle: needs VIEW SERVER STATE / SELECT on gv$ views.
-- ============================================================

-- 1) SQL Server — extend the existing detection with a queries column
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT login_name,
       COUNT(DISTINCT host_name) AS host_count,
       STUFF((SELECT DISTINCT ', ' + host_name FROM sys.dm_exec_sessions s2 WHERE s2.login_name = s.login_name AND s2.host_name IS NOT NULL FOR XML PATH('')), 1, 2, '') AS hosts,
       COUNT(*) AS session_count,
       STUFF((SELECT DISTINCT ' | ' + LEFT(qt.text, 500)
              FROM sys.dm_exec_sessions s3
              JOIN sys.dm_exec_connections c3 ON c3.session_id = s3.session_id
              CROSS APPLY sys.dm_exec_sql_text(c3.most_recent_sql_handle) qt
              WHERE s3.login_name = s.login_name AND s3.is_user_process = 1 AND qt.text IS NOT NULL
              FOR XML PATH(''), TYPE).value('text()[1]', 'nvarchar(max)'), 1, 3, '') AS queries
FROM sys.dm_exec_sessions s
WHERE is_user_process = 1 AND login_name IS NOT NULL AND host_name IS NOT NULL
GROUP BY login_name
HAVING COUNT(DISTINCT host_name) > 1
ORDER BY host_count DESC$q$::text)),
    expected = jsonb_build_object('condition', 'row_count > 0',
        'description', 'Same login active from multiple hosts may indicate credential sharing or compromise; the queries column lists the recent SQL each session is running')
WHERE vendor_slug = 'sqlserver'
  AND name = 'Detect same login active from multiple hosts';

-- 2) PostgreSQL
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT usename AS login_name,
       COUNT(DISTINCT client_addr) AS host_count,
       string_agg(DISTINCT host(client_addr), ', ') AS hosts,
       COUNT(*) AS session_count,
       string_agg(DISTINCT left(query, 500), ' | ') AS queries
FROM pg_stat_activity
WHERE usename IS NOT NULL AND client_addr IS NOT NULL AND pid <> pg_backend_pid()
GROUP BY usename
HAVING COUNT(DISTINCT client_addr) > 1
ORDER BY host_count DESC$q$::text)),
    expected = jsonb_build_object('condition', 'row_count > 0',
        'description', 'Same login active from multiple hosts may indicate credential sharing or compromise; the queries column lists the recent SQL each session is running')
WHERE vendor_slug = 'postgresql'
  AND name = 'Detect same login active from multiple hosts';

-- 3) Oracle
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT username AS login_name,
       COUNT(DISTINCT machine) AS host_count,
       LISTAGG(DISTINCT machine, ', ') WITHIN GROUP (ORDER BY machine) AS hosts,
       COUNT(*) AS session_count,
       LISTAGG(DISTINCT SUBSTR(sql_text, 1, 500), ' | ') WITHIN GROUP (ORDER BY SUBSTR(sql_text, 1, 500)) AS queries
FROM (
    SELECT s.username, s.machine, s.sid, q.sql_text
    FROM gv$session s
    LEFT JOIN gv$sql q ON q.sql_id = s.sql_id AND q.inst_id = s.inst_id
    WHERE s.username IS NOT NULL AND s.type = 'USER' AND s.machine IS NOT NULL
)
GROUP BY username
HAVING COUNT(DISTINCT machine) > 1
ORDER BY host_count DESC$q$::text)),
    expected = jsonb_build_object('condition', 'row_count > 0',
        'description', 'Same login active from multiple hosts may indicate credential sharing or compromise; the queries column lists the recent SQL each session is running')
WHERE vendor_slug = 'oracle'
  AND name = 'Detect same login active from multiple hosts';

-- 4) MySQL
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT USER AS login_name,
       COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS host_count,
       GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1) SEPARATOR ', ') AS hosts,
       COUNT(*) AS session_count,
       GROUP_CONCAT(DISTINCT LEFT(INFO, 500) SEPARATOR ' | ') AS queries
FROM information_schema.PROCESSLIST
WHERE USER IS NOT NULL AND USER NOT IN ('system user', 'event_scheduler') AND HOST IS NOT NULL AND HOST <> ''
GROUP BY USER
HAVING COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) > 1
ORDER BY host_count DESC$q$::text)),
    expected = jsonb_build_object('condition', 'row_count > 0',
        'description', 'Same login active from multiple hosts may indicate credential sharing or compromise; the queries column lists the recent SQL each session is running')
WHERE vendor_slug = 'mysql'
  AND name = 'Detect same login active from multiple hosts';

-- 5) MariaDB (same processlist shape as MySQL)
UPDATE rootcause.detection_steps
SET content = jsonb_set(content, '{sql}', to_jsonb($q$SELECT USER AS login_name,
       COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS host_count,
       GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1) SEPARATOR ', ') AS hosts,
       COUNT(*) AS session_count,
       GROUP_CONCAT(DISTINCT LEFT(INFO, 500) SEPARATOR ' | ') AS queries
FROM information_schema.PROCESSLIST
WHERE USER IS NOT NULL AND USER NOT IN ('system user', 'event_scheduler') AND HOST IS NOT NULL AND HOST <> ''
GROUP BY USER
HAVING COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) > 1
ORDER BY host_count DESC$q$::text)),
    expected = jsonb_build_object('condition', 'row_count > 0',
        'description', 'Same login active from multiple hosts may indicate credential sharing or compromise; the queries column lists the recent SQL each session is running')
WHERE vendor_slug = 'mariadb'
  AND name = 'Detect same login active from multiple hosts';

-- ------------------------------------------------------------
-- Rebuild the reporting view:
--   * add the new `queries` column;
--   * read the live partitioned table (was general_metric_metadata_results_old,
--     the pre-partition backup that never receives new collections);
--   * expose entry_date as timestamptz. entry_date is stored as a NAIVE
--     timestamp holding Asia/Jerusalem wall-clock; Grafana ($__timeFrom is UTC)
--     then reads it 3h ahead. `AT TIME ZONE 'Asia/Jerusalem'` reinterprets the
--     naive local value as the correct UTC instant so time filtering/display
--     line up.
-- DROP+CREATE (not OR REPLACE) because entry_date changes type (timestamp ->
-- timestamptz), which OR REPLACE cannot do. No objects depend on this view.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS monitoring.v_sec_sql_acc_010_rc10;
CREATE VIEW monitoring.v_sec_sql_acc_010_rc10 AS
SELECT r.server,
       j.value ->> 'host_count'    AS host_count,
       j.value ->> 'hosts'         AS hosts,
       j.value ->> 'login_name'    AS login_name,
       j.value ->> 'session_count' AS session_count,
       (r.entry_date AT TIME ZONE 'Asia/Jerusalem') AS entry_date,
       j.value ->> 'queries'       AS queries
FROM monitoring.general_metric_metadata_results r
CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
WHERE r.metric_name::text = 'SEC-SQL-ACC-010-RC10'::text;
