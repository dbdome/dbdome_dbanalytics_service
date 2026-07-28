-- Idempotent install for log.access_review_instances
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.access_review_instances_instance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.access_review_instances (
    instance_id integer NOT NULL,
    cycle_id integer NOT NULL,
    cycle_name character varying(200),
    period_start date NOT NULL,
    period_end date NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    total_items integer DEFAULT 0 NOT NULL,
    reviewed_items integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);

ALTER TABLE log.access_review_instances ALTER COLUMN instance_id SET DEFAULT nextval('log.access_review_instances_instance_id_seq'::regclass);
ALTER SEQUENCE log.access_review_instances_instance_id_seq OWNED BY log.access_review_instances.instance_id;

SELECT setval('log.access_review_instances_instance_id_seq', GREATEST((SELECT COALESCE(max(instance_id),0) FROM log.access_review_instances),1), (SELECT count(*) FROM log.access_review_instances) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'access_review_instances'
          AND con.conname = 'access_review_instances_pkey') THEN
        ALTER TABLE ONLY log.access_review_instances
    ADD CONSTRAINT access_review_instances_pkey PRIMARY KEY (instance_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_access_review_instances_status ON log.access_review_instances USING btree (status, created_at DESC);
