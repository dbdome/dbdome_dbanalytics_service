-- Idempotent install for monitoring.siem_active_session_monitoring
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE SEQUENCE IF NOT EXISTS monitoring.siem_active_session_monitoring_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS monitoring.siem_active_session_monitoring (
    row_id integer NOT NULL,
    server character varying(50),
    login_name character varying(50),
    host_name character varying(50),
    program_name character varying(50),
    login_time timestamp without time zone,
    client_interface_name character varying(25),
    nt_domain character varying(25),
    nt_user_name character varying(25),
    status character varying(25),
    cpu_time integer,
    memory_usage integer,
    total_scheduled_time timestamp without time zone,
    total_elapsed_time integer,
    last_request_start_time timestamp without time zone,
    last_request_end_time timestamp without time zone,
    reads integer,
    writes integer,
    logical_reads integer,
    is_user_process bit(1),
    text_size integer,
    lock_timeout integer,
    deadlock_priority integer,
    row_count integer,
    prev_error integer,
    open_transaction_count integer,
    page_server_reads integer,
    entry_date timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE monitoring.siem_active_session_monitoring ALTER COLUMN row_id SET DEFAULT nextval('monitoring.siem_active_session_monitoring_row_id_seq'::regclass);
ALTER SEQUENCE monitoring.siem_active_session_monitoring_row_id_seq OWNED BY monitoring.siem_active_session_monitoring.row_id;

SELECT setval('monitoring.siem_active_session_monitoring_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM monitoring.siem_active_session_monitoring),1), (SELECT count(*) FROM monitoring.siem_active_session_monitoring) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'monitoring' AND c.relname = 'siem_active_session_monitoring'
          AND con.conname = 'siem_active_session_monitoring_pkey') THEN
        ALTER TABLE ONLY monitoring.siem_active_session_monitoring
    ADD CONSTRAINT siem_active_session_monitoring_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
