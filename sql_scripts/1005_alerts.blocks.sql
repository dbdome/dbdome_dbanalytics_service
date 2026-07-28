CREATE TABLE IF NOT EXISTS alerts.blocks
(
    row_id serial primary key not null ,
    metric_result_row_id bigint,
    server character varying(50) COLLATE pg_catalog."default",
    transaction_type character varying(255) COLLATE pg_catalog."default",
    metric_name character varying(255) COLLATE pg_catalog."default",
    body text COLLATE pg_catalog."default",
    recipients text COLLATE pg_catalog."default",
    report_url text COLLATE pg_catalog."default",
    subject text COLLATE pg_catalog."default",
    interval_secs integer,
    start_time time without time zone,
    end_time time without time zone,
    entry_date timestamp without time zone NOT NULL DEFAULT now(),
    login_name text COLLATE pg_catalog."default",
    metric_metadata_json jsonb,
    metric_query jsonb
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS alerts.blocks
    OWNER to postgres;