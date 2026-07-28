-- Idempotent install for config.global_params
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.global_params_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.global_params (
    row_id integer NOT NULL,
    key text NOT NULL,
    value text NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE config.global_params ALTER COLUMN row_id SET DEFAULT nextval('config.global_params_row_id_seq'::regclass);
ALTER SEQUENCE config.global_params_row_id_seq OWNED BY config.global_params.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.global_params);
COPY _stg_load (row_id, key, value, entry_date) FROM stdin;
1	disk_size	10000	2026-01-03 20:10:46.570625
3	CategoryDefinitions.json_path	C:\\ProgramData\\DBEXPERT\\dbExpertAI-windows-x64-v1.1.6\\data	2026-02-27 18:51:20.008997
4	DasboardData_folder	C:\\ProgramData\\DBEXPERT\\dbExpertAI-windows-x64-v1.1.6\\client\\DashboardData	2026-02-27 18:52:11.78317
5	INGEST_API_KEY	dbe_VHr3_wxOoiyBdSSlVKTdp-MMQ3I9ZbtUZMkK5QGNoxs	2026-03-06 20:19:52.490197
7	categorydefinitions	C:\\dev\\dbExpertAI-windows-x64-v1.1.6\\data\\CategoryDefinitions.json	2026-04-04 18:18:23.117958
8	dashboarddata	C:\\dev\\dbExpertAI-windows-x64-v1.1.6\\client\\DashboardData	2026-04-04 21:31:43.383463
9	grafana_db	C:\\dev\\dbdome\\data\\grafana.db	2026-04-06 15:00:55.143298
6	INGEST_URL	https://dbexpertai.com/api/ingest	2026-03-06 20:28:28.085089
2	local_ip	191.96.229.121	2026-01-16 21:53:45.845322
10	firewall_audit_retention_days	90	2026-06-13 14:49:20.667401
\.
INSERT INTO config.global_params (row_id, key, value, entry_date)
SELECT row_id, key, value, entry_date FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.global_params);
DROP TABLE _stg_load;

SELECT setval('config.global_params_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.global_params),1), (SELECT count(*) FROM config.global_params) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'global_params'
          AND con.conname = 'global_params_pkey') THEN
        ALTER TABLE ONLY config.global_params
    ADD CONSTRAINT global_params_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
