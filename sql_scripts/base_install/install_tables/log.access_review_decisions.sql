-- Idempotent install for log.access_review_decisions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.access_review_decisions_decision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.access_review_decisions (
    decision_id bigint NOT NULL,
    instance_id integer NOT NULL,
    server_name character varying(200) NOT NULL,
    db_user character varying(200) NOT NULL,
    privilege_type character varying(200) NOT NULL,
    object_name character varying(400),
    decision character varying(20) NOT NULL,
    decided_by character varying(200),
    decision_note text,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    regulation character varying(50)
);

ALTER TABLE log.access_review_decisions ALTER COLUMN decision_id SET DEFAULT nextval('log.access_review_decisions_decision_id_seq'::regclass);
ALTER SEQUENCE log.access_review_decisions_decision_id_seq OWNED BY log.access_review_decisions.decision_id;

SELECT setval('log.access_review_decisions_decision_id_seq', GREATEST((SELECT COALESCE(max(decision_id),0) FROM log.access_review_decisions),1), (SELECT count(*) FROM log.access_review_decisions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'access_review_decisions'
          AND con.conname = 'access_review_decisions_pkey') THEN
        ALTER TABLE ONLY log.access_review_decisions
    ADD CONSTRAINT access_review_decisions_pkey PRIMARY KEY (decision_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_access_review_decisions_instance ON log.access_review_decisions USING btree (instance_id, decided_at DESC);
CREATE INDEX IF NOT EXISTS idx_access_review_decisions_user ON log.access_review_decisions USING btree (server_name, db_user, decided_at DESC);
