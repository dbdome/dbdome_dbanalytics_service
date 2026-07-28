-- Idempotent install for monitoring.gmmr_2026_07
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE TABLE IF NOT EXISTS monitoring.gmmr_2026_07 (
    id bigint CONSTRAINT general_metric_metadata_results_id_not_null NOT NULL,
    row_id integer,
    server character varying(50),
    category_id integer,
    metric_name character varying(255),
    metric_config json,
    metric_metadata jsonb,
    entry_date timestamp without time zone DEFAULT now() CONSTRAINT general_metric_metadata_results_entry_date_not_null NOT NULL,
    metric_metadata_vs_expected jsonb,
    server_id uuid
);


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'gmmr_2026_07'
          AND con.conname = 'gmmr_2026_07_pkey') THEN
        ALTER TABLE ONLY monitoring.gmmr_2026_07
    ADD CONSTRAINT gmmr_2026_07_pkey PRIMARY KEY (entry_date, id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS gmmr_2026_07_entry_date_idx ON monitoring.gmmr_2026_07 USING brin (entry_date);
CREATE INDEX IF NOT EXISTS gmmr_2026_07_metric_name_entry_date_idx ON monitoring.gmmr_2026_07 USING btree (metric_name, entry_date DESC);
CREATE INDEX IF NOT EXISTS gmmr_2026_07_server_metric_name_entry_date_idx ON monitoring.gmmr_2026_07 USING btree (server, metric_name, entry_date DESC);


-- Attach to the partitioned parent (pg_dump's "TABLE ATTACH" block was lost by
-- the generator; without this a fresh install leaves the table detached and
-- every collector INSERT fails with "no partition ... found for row").
DO $do$
BEGIN
    IF to_regclass('monitoring.general_metric_metadata_results') IS NOT NULL
       AND to_regclass('monitoring.gmmr_2026_07') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_inherits
                       WHERE inhrelid = 'monitoring.gmmr_2026_07'::regclass) THEN
        ALTER TABLE monitoring.general_metric_metadata_results
            ATTACH PARTITION monitoring.gmmr_2026_07 FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
    END IF;
END $do$;
