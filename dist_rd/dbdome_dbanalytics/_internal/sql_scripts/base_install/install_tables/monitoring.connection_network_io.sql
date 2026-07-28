-- Idempotent install for monitoring.connection_network_io
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.connection_network_io_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.connection_network_io (
    row_id integer NOT NULL,
    host_name character varying(50),
    program_name character varying(255),
    client_interface_name character varying(50),
    net_transport character varying(50),
    num_reads integer,
    num_writes integer,
    last_read timestamp without time zone,
    last_write timestamp without time zone,
    net_packet_size integer,
    client_net_address character varying(50),
    login_time timestamp without time zone,
    login_name character varying(50),
    cpu_time integer,
    memory_usage integer,
    total_elapsed_time integer,
    total_scheduled_time integer,
    last_request_end_time timestamp without time zone,
    last_request_start_time timestamp without time zone,
    original_login_name character varying(50),
    database_id integer,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    server character varying(50),
    database_name character varying(50)
);

ALTER TABLE monitoring.connection_network_io ALTER COLUMN row_id SET DEFAULT nextval('monitoring.connection_network_io_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.connection_network_io_row_id_seq OWNED BY monitoring.connection_network_io.row_id;

SELECT setval('monitoring.connection_network_io_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.connection_network_io),1), (SELECT count(*) FROM monitoring.connection_network_io) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'connection_network_io'
          AND con.conname = 'connection_network_io_pkey') THEN
        ALTER TABLE ONLY monitoring.connection_network_io
    ADD CONSTRAINT connection_network_io_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
