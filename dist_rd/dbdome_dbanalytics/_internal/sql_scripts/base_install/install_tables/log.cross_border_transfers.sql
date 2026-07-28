-- Idempotent install for log.cross_border_transfers
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS log;

CREATE SEQUENCE IF NOT EXISTS log.cross_border_transfers_transfer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS log.cross_border_transfers (
    transfer_id bigint NOT NULL,
    source_server character varying(200) NOT NULL,
    destination_server character varying(200) NOT NULL,
    source_country character varying(200),
    destination_country character varying(200),
    transfer_mechanism character varying(50),
    has_legal_basis boolean DEFAULT false NOT NULL,
    db_user character varying(200),
    table_name character varying(400),
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    risk_level character varying(20) DEFAULT 'MEDIUM'::character varying NOT NULL
);

ALTER TABLE log.cross_border_transfers ALTER COLUMN transfer_id SET DEFAULT nextval('log.cross_border_transfers_transfer_id_seq'::regclass);
ALTER SEQUENCE log.cross_border_transfers_transfer_id_seq OWNED BY log.cross_border_transfers.transfer_id;

SELECT setval('log.cross_border_transfers_transfer_id_seq', GREATEST((SELECT COALESCE(max(transfer_id),0) FROM log.cross_border_transfers),1), (SELECT count(*) FROM log.cross_border_transfers) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'log' AND c.relname = 'cross_border_transfers'
          AND con.conname = 'cross_border_transfers_pkey') THEN
        ALTER TABLE ONLY log.cross_border_transfers
    ADD CONSTRAINT cross_border_transfers_pkey PRIMARY KEY (transfer_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_cross_border_transfers_detected ON log.cross_border_transfers USING btree (detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_cross_border_transfers_pair ON log.cross_border_transfers USING btree (source_server, destination_server, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_cross_border_transfers_risk ON log.cross_border_transfers USING btree (risk_level, detected_at DESC) WHERE (has_legal_basis = false);
