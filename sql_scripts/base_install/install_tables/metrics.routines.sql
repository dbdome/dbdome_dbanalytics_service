-- Idempotent install for metrics.routines
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS metrics;

CREATE SEQUENCE IF NOT EXISTS metrics.routines_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS metrics.routines (
    row_id integer NOT NULL,
    routine_name text NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    entry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    db_version character varying(50)
);

ALTER TABLE metrics.routines ALTER COLUMN row_id SET DEFAULT nextval('metrics.routines_row_id_seq'::regclass);
ALTER SEQUENCE metrics.routines_row_id_seq OWNED BY metrics.routines.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE metrics.routines);
COPY _stg_load (row_id, routine_name, is_active, entry_date, db_version) FROM stdin;
2	tcp_connections_mssql	f	2025-04-19 18:37:13.019498	MSSQL
3	transaction_requests	f	2025-04-20 19:24:07.381093	MSSQL
4	collect_metric_mssql_network_connection_io	f	2025-04-26 13:31:28.534137	MSSQL
5	collect_metric_mssql_database_performance	f	2025-04-26 16:35:51.061176	MSSQL
6	collect_metric_mssql_database_unmasked_users	f	2025-04-26 19:13:15.843069	MSSQL
7	collect_metric_mssql_sql_injection	f	2025-04-26 20:37:40.16177	MSSQL
8	collect_metric_mssql_server_hardening_unused_inactive_sql_server_logins	f	2025-04-26 21:31:29.921031	MSSQL
9	collect_metric_mssql_network_alerts	f	2025-04-28 21:54:47.120351	MSSQL
10	collect_metric_mssql_latency	f	2025-05-01 20:34:21.085143	MSSQL
11	collect_metric_mssql_active_sessions	f	2025-05-02 22:05:50.599533	MSSQL
12	collect_metric_mssql_ad_hoc_consuming_queries	f	2025-05-16 11:33:05.210654	MSSQL
13	collect_metric_postgres_missing_indexes	f	2025-06-26 05:06:50.034372	MSSQL
14	collect_metric_postgres_stat_activity	f	2025-06-26 05:07:12.441348	MSSQL
15	collect_metric_active_transactions_from_oracle	f	2025-06-26 05:16:48.442823	MSSQL
16	collect_metric_postgres_sensitive_data_activity	f	2025-06-26 05:28:25.926463	MSSQL
17	collect_metric_mssql_sensitive_data_activity	f	2025-06-26 14:17:55.733107	MSSQL
18	collect_metric_mssql_privileged_logins	f	2025-06-28 13:16:27.36425	MSSQL
23	collect_metric_mssql_active_schema	f	2026-01-24 21:21:15.919837	MSSQL
20	collect_all_metrics_mssql_queries	t	2025-07-01 20:04:19.196128	MSSQL
1	active_transactions_mssql	t	2025-04-15 18:15:39.628609	MSSQL
24	collect_all_metrics_MariaDB_queries	t	2026-03-31 17:09:44.792754	MariaDB
25	collect_all_metrics_mysql_queries	t	2026-03-31 19:25:34.531731	mysql
19	collect_metric_postgres_privileged_logins	f	2025-06-28 13:58:54.179067	POSTGRES
22	collect_all_metrics_postgres_queries	t	2025-08-19 14:51:01.441818	POSTGRES
26	collect_all_metrics_oracle_queries	t	2026-04-02 21:31:04.18857	oracle
27	collect_all_metrics_MariaDB_queries	t	2026-04-02 21:32:12.053238	mariadb
\.
INSERT INTO metrics.routines (row_id, routine_name, is_active, entry_date, db_version)
SELECT row_id, routine_name, is_active, entry_date, db_version FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM metrics.routines);
DROP TABLE _stg_load;

SELECT setval('metrics.routines_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM metrics.routines),1), (SELECT count(*) FROM metrics.routines) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'metrics' AND c.relname = 'routines'
          AND con.conname = 'routines_pkey') THEN
        ALTER TABLE ONLY metrics.routines
    ADD CONSTRAINT routines_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
