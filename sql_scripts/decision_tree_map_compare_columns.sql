--
-- PostgreSQL database dump
--

-- NOTE: pg_dump 18 wraps its output in \restrict / \unrestrict psql
-- directives. Those are CLIENT commands; this file is applied by
-- processes/sql_script_runner.py through psycopg2, which cannot parse a backslash
-- command and failed the whole file on line 5. They only guard against a hostile
-- dump being sourced interactively, which is irrelevant here - the runner already
-- executes each file inside its own transaction.

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
-- Data for Name: decision_tree_map_compare_columns; Type: TABLE DATA; Schema: rootcause; Owner: postgres
--

INSERT INTO rootcause.decision_tree_map_compare_columns (row_id, decision_tree_item_id, source_root_cause_id, source_param, target_root_cause_id, target_param, entry_date) VALUES (1, 1, 'PERF-SQL-TX-010-RC02', 'object_table', 'HLTH-SQL-SYS-034-RC01', 'table_ref', '2026-07-28 18:57:35.278544');
INSERT INTO rootcause.decision_tree_map_compare_columns (row_id, decision_tree_item_id, source_root_cause_id, source_param, target_root_cause_id, target_param, entry_date) VALUES (2, 2, 'HLTH-SQL-SYS-034-RC01', 'table_ref', 'HLTH-SQL-SYS-027-RC01', 'table_name', '2026-07-28 19:00:54.37676');
INSERT INTO rootcause.decision_tree_map_compare_columns (row_id, decision_tree_item_id, source_root_cause_id, source_param, target_root_cause_id, target_param, entry_date) VALUES (3, 3, 'HLTH-SQL-SYS-034-RC01', 'table_name', 'HLTH-SQL-SYS-002-RC01', 'sql_text', '2026-07-28 19:05:30.258496');
INSERT INTO rootcause.decision_tree_map_compare_columns (row_id, decision_tree_item_id, source_root_cause_id, source_param, target_root_cause_id, target_param, entry_date) VALUES (4, 4, 'HLTH-SQL-SYS-002-RC-01', 'sql_text', 'HLTH-SQL-SYS-003-RC01', 'sql_text', '2026-07-28 19:45:45.073968');


--
-- Name: decision_tree_map_compare_columns_row_id_seq; Type: SEQUENCE SET; Schema: rootcause; Owner: postgres
--

SELECT pg_catalog.setval('rootcause.decision_tree_map_compare_columns_row_id_seq', 4, true);


--
-- PostgreSQL database dump complete
--


