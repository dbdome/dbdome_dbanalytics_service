--
-- PostgreSQL database dump
--

\restrict BAeGIMmlw5GUUDc67QZwQMBrDovM8NzLK0Wg43wvBqjFN9Y6fsLeIz0HXElN2Lr

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: decision_tree; Type: TABLE DATA; Schema: rootcause; Owner: postgres
--

INSERT INTO rootcause.decision_tree (row_id, decision_tree_name, decision_tree_desc, source_root_cause_id, source_query, target_root_cause_id, target_query, vendor_name, entry_date) VALUES (2, 'Active transactions snapshot with execution plans', 'Point-in-time snapshot of active user requests that also returns each request''s execution plan as XML text (sys.dm_exec_text_query_plan), for plan-level diagnosis of expensive or blocking statements. Excludes the monitoring session (@@SPID) and the dbdome service account.', 'HLTH-SQL-SYS-034-RC01', 'select  database_name, index_advantage, last_user_seek, table_ref, equality_columns, inequality_columns, included_columns, unique_compiles, user_seeks, user_scans, avg_total_user_cost, avg_user_impact, create_index_statement, entry_date
from monitoring.v_hlth_sql_sys_034_rc01 where server = p_server ', 'HLTH-SQL-SYS-027-RC01', 'select  database_name, schema_name, table_name, index_name, index_id, index_type, page_count, index_mb, fragmentation_pct, fragment_count, recommended_action, entry_date
from monitoring.v_hlth_sql_sys_027_rc01
where server_id = ''$__server''
and entry_date > ''$__timeFrom''', 'sqlserver', '2026-07-28 17:54:29.391603');
INSERT INTO rootcause.decision_tree (row_id, decision_tree_name, decision_tree_desc, source_root_cause_id, source_query, target_root_cause_id, target_query, vendor_name, entry_date) VALUES (1, 'Active transactions snapshot with execution plans', 'Point-in-time snapshot of active user requests that also returns each request''s execution plan as XML text (sys.dm_exec_text_query_plan), for plan-level diagnosis of expensive or blocking statements. Excludes the monitoring session (@@SPID) and the dbdome service account.', 'PERF-SQL-TX-010-RC02', '
select 
row_id , 
server,
login_name, 
database_name,       
elapsed_ms, 
cpu_ms,
query_text , 
q.physical_op , 
missing_index_impact, 
missing_index_table,
estimate_rows,
estimate_cpu,
estimate_io,
subtree_cost, object_schema, object_table, object_index, index_kind,
predicate, has_warning, warning_detail,
missing_index_count , 
statement_type , entry_date
from 
(
SELECT
g.id row_id , 
g.entry_date,
       g.server,
       q->>''login_name'' AS login_name, q->>''database_name'' AS database_name,       
       (q->>''elapsed_ms'')::bigint AS elapsed_ms, (q->>''cpu_ms'')::bigint AS cpu_ms,
       (q->>''logical_reads'')::bigint AS logical_reads,
       left(q->>''query_text'', 300) AS query_text
FROM monitoring.general_metric_metadata_results g
CROSS JOIN LATERAL jsonb_array_elements(g.metric_metadata) q
WHERE g.metric_name = ''PERF-SQL-TX-010-RC02''
  AND jsonb_typeof(g.metric_metadata) = ''array''
  AND q->>''execution_plan_xml'' IS NOT NULL
  and entry_date > now() - interval ''5 minutes'' 
LIMIT 200
) A 
CROSS JOIN LATERAL monitoring.parse_execution_plan(row_id) q
 where subtree_cost >0
and  server = p_server
and entry_date > p_timefrom
order by row_id , subtree_cost desc
', 'HLTH-SQL-SYS-034-RC01', 'select  database_name, index_advantage, last_user_seek, table_ref, equality_columns, inequality_columns, included_columns, unique_compiles, user_seeks, user_scans, avg_total_user_cost, avg_user_impact, create_index_statement, entry_date
from monitoring.v_hlth_sql_sys_034_rc01 where server = ''$__server''', 'sqlserver', '2026-07-28 17:39:04.453176');
INSERT INTO rootcause.decision_tree (row_id, decision_tree_name, decision_tree_desc, source_root_cause_id, source_query, target_root_cause_id, target_query, vendor_name, entry_date) VALUES (3, 'Active transactions snapshot with execution plans', 'Point-in-time snapshot of active user requests that also returns each request''s execution plan as XML text (sys.dm_exec_text_query_plan), for plan-level diagnosis of expensive or blocking statements. Excludes the monitoring session (@@SPID) and the dbdome service account.', 'HLTH-SQL-SYS-027-RC01', 'select  database_name, schema_name, table_name, index_name, index_id, index_type, page_count, index_mb, fragmentation_pct, fragment_count, recommended_action, entry_date
from monitoring.v_hlth_sql_sys_027_rc01
where server_id = p_server
and entry_date > p_timeFrom', 'HLTH-SQL-SYS-002-RC01', 'select login_name , sql_text ,   session_id, blocking_session_id, status, command, database_name, host_name, program_name, wait_time_ms, wait_type, last_wait_type, wait_resource, isolation_level, lock_timeout_ms, cpu_time_ms, elapsed_time_ms, logical_reads, reads, writes, row_count, start_time,  entry_date 
from monitoring.v_hlth_sql_sys_002_rc01 where sql_text != ''sp_server_diagnostics''
where server_id = ''$__server''
and entry_date > ''$__timeFrom''', 'sqlserver', '2026-07-28 18:10:37.908832');
INSERT INTO rootcause.decision_tree (row_id, decision_tree_name, decision_tree_desc, source_root_cause_id, source_query, target_root_cause_id, target_query, vendor_name, entry_date) VALUES (4, 'Active transactions snapshot with execution plans', 'Point-in-time snapshot of active user requests that also returns each request''s execution plan as XML text (sys.dm_exec_text_query_plan), for plan-level diagnosis of expensive or blocking statements. Excludes the monitoring session (@@SPID) and the dbdome service account.', 'HLTH-SQL-SYS-002-RC01', 'select login_name , sql_text ,   session_id, blocking_session_id, status, command, database_name, host_name, program_name, wait_time_ms, wait_type, last_wait_type, wait_resource, isolation_level, lock_timeout_ms, cpu_time_ms, elapsed_time_ms, logical_reads, reads, writes, row_count, start_time,  entry_date 
from monitoring.v_hlth_sql_sys_002_rc01 where sql_text != ''sp_server_diagnostics''
where server_id = p_server
and entry_date > p_timeFrom', 'HLTH-SQL-SYS-003-RC01', 'select 
 session_id, blocking_session_id,  program_name, host_name, sql_text,duration_sec, database_name, transaction_name, transaction_begin_time, transaction_state, is_idle_with_open_tran, open_transaction_count, log_bytes_used, request_start_time, last_request_end_time, session_cpu_time_ms, command, logical_reads, reads, writes, percent_complete, wait_type, last_wait_type, login_name, improvement_measure, equality_columns, missing_index_table, create_index_statement, entry_date
from monitoring.v_hlth_sql_sys_003_rc01 where transaction_begin_time > $__timeFrom()  and server_id = ''${server}''
', 'sqlserver', '2026-07-28 18:13:52.527538');


--
-- Name: decision_tree_row_id_seq; Type: SEQUENCE SET; Schema: rootcause; Owner: postgres
--

SELECT pg_catalog.setval('rootcause.decision_tree_row_id_seq', 4, true);


--
-- PostgreSQL database dump complete
--

\unrestrict BAeGIMmlw5GUUDc67QZwQMBrDovM8NzLK0Wg43wvBqjFN9Y6fsLeIz0HXElN2Lr

