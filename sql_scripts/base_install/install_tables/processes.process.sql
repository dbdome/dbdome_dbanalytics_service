-- Idempotent install for processes.process
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS processes;

CREATE SEQUENCE IF NOT EXISTS processes.process_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS processes.process (
    row_id integer NOT NULL,
    organization_id integer NOT NULL,
    process_name text NOT NULL,
    category text NOT NULL,
    schedule_type text NOT NULL,
    schedule_expr text NOT NULL,
    expected_duration_ms text NOT NULL,
    entry_date timestamp without time zone DEFAULT now(),
    description text,
    process_id uuid DEFAULT gen_random_uuid(),
    server_id integer
);

ALTER TABLE processes.process ALTER COLUMN row_id SET DEFAULT nextval('processes.process_row_id_seq'::regclass);
ALTER SEQUENCE processes.process_row_id_seq OWNED BY processes.process.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE processes.process);
COPY _stg_load (row_id, organization_id, process_name, category, schedule_type, schedule_expr, expected_duration_ms, entry_date, description, process_id, server_id) FROM stdin;
8	1	ממשק העברת  קודי דיווח מהמרינגו לסינריון	batch_job	cron	select * from FX..fx	1800	2026-03-14 12:10:51.757195	import forex rates to database	ff738538-3d6f-4a2d-ad20-834eed604df2	13
4	1	ממשק דיווחים אוטומטי סינריון-מרינגו	batch_job	cron	"select * from FX..fx"	1800	2026-03-23 06:44:09.03931	ממשק דיווחים אוטומטי סינריון-מרינגו	eac02e55-054f-47ee-9aa9-4f2a485588ee	13
3	1	dbexpertAI_test_health	batch_job	cron	select * from FX..fx	1800	2026-03-17 19:25:00.265394	import forex rates to database	b61fb486-8361-4640-9fd5-5d0085fc63a3	13
5	1	dbexpertAI_test_security	batch_job	cron	select * from monitoring.general_metric_metadata_results	12	2026-03-29 20:22:25.045433	Tests Securtiy rules	9b218b50-612d-46fa-940b-815e4920801b	13
6	1	dbexpertAI_test_Performance	batch_job	cron	select * from monitoring.general_metric_metadata_results	12	2026-03-29 20:23:05.474038	Tests Performance  rules	e1c47244-906e-44c4-ba58-8c300e71b24a	13
\.
INSERT INTO processes.process (row_id, organization_id, process_name, category, schedule_type, schedule_expr, expected_duration_ms, entry_date, description, process_id, server_id)
SELECT row_id, organization_id, process_name, category, schedule_type, schedule_expr, expected_duration_ms, entry_date, description, process_id, server_id FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM processes.process);
DROP TABLE _stg_load;

SELECT setval('processes.process_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM processes.process),1), (SELECT count(*) FROM processes.process) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'processes' AND c.relname = 'process'
          AND con.conname = 'pk_process') THEN
        ALTER TABLE ONLY processes.process
    ADD CONSTRAINT pk_process PRIMARY KEY (organization_id, process_name);
    END IF;
END $do$;
