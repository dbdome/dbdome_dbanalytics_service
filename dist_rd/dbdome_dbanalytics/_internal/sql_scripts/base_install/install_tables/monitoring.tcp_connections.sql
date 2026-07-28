-- Idempotent install for monitoring.tcp_connections
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.tcp_connections_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.tcp_connections (
    row_id integer NOT NULL,
    server character varying(50),
    session_id integer,
    most_recent_session_id integer,
    connect_time timestamp without time zone NOT NULL,
    net_transport character varying(25) NOT NULL,
    protocol_type character varying(25) NOT NULL,
    endpoint_id integer NOT NULL,
    encrypt_option character varying(25),
    auth_scheme character varying(50),
    node_affinity integer NOT NULL,
    num_reads integer NOT NULL,
    num_writes integer NOT NULL,
    last_read timestamp without time zone NOT NULL,
    last_write timestamp without time zone NOT NULL,
    net_packet_size integer NOT NULL,
    client_net_address character varying(25),
    client_tcp_port integer,
    local_net_address character varying(25),
    local_tcp_port integer,
    date_entry timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.tcp_connections ALTER COLUMN row_id SET DEFAULT nextval('monitoring.tcp_connections_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.tcp_connections_row_id_seq OWNED BY monitoring.tcp_connections.row_id;

SELECT setval('monitoring.tcp_connections_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.tcp_connections),1), (SELECT count(*) FROM monitoring.tcp_connections) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'tcp_connections'
          AND con.conname = 'tcp_connections_pkey') THEN
        ALTER TABLE ONLY monitoring.tcp_connections
    ADD CONSTRAINT tcp_connections_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS ix_connect_time ON monitoring.tcp_connections USING btree (connect_time);
