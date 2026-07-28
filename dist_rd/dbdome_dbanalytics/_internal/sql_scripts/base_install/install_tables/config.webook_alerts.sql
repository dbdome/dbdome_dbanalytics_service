-- Idempotent install for config.webook_alerts
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.webook_alerts_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.webook_alerts (
    row_id integer NOT NULL,
    metric_type character varying(50),
    send_mail_alert boolean DEFAULT true NOT NULL,
    send_siem_alert boolean DEFAULT true NOT NULL,
    send_diagnosis_evidence boolean DEFAULT true NOT NULL,
    entry_date timestamp without time zone DEFAULT now() NOT NULL,
    risk_level character(10),
    is_active boolean DEFAULT true,
    recurrency_hours integer,
    blocker boolean DEFAULT false NOT NULL,
    auto_mask boolean DEFAULT false
);

ALTER TABLE config.webook_alerts ALTER COLUMN row_id SET DEFAULT nextval('config.webook_alerts_row_id_seq'::regclass);
ALTER SEQUENCE config.webook_alerts_row_id_seq OWNED BY config.webook_alerts.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.webook_alerts);
COPY _stg_load (row_id, metric_type, send_mail_alert, send_siem_alert, send_diagnosis_evidence, entry_date, risk_level, is_active, recurrency_hours, blocker, auto_mask) FROM stdin;
5	Performance	f	f	t	2026-04-25 18:33:29.224783	low       	t	72	f	f
8	Performance	f	t	t	2026-04-25 18:37:12.877033	high      	t	72	f	f
9	Performance	f	t	t	2026-04-25 18:37:12.877033	critical  	t	72	f	f
11	Health	f	t	t	2026-04-25 18:40:26.577807	medium    	t	72	f	f
12	Health	f	t	t	2026-04-25 18:40:26.577807	high      	t	72	f	f
13	Health	f	t	t	2026-04-25 18:40:26.577807	low       	t	72	f	f
10	Health	f	t	t	2026-04-25 18:37:12.877033	critical  	t	72	f	f
4	Security	f	f	t	2026-04-22 20:58:23.397605	low       	t	72	f	f
3	Security	f	f	t	2026-04-22 20:57:51.724412	medium    	t	72	f	f
1	Security	t	t	t	2026-03-09 19:18:06.158818	critical  	t	1	f	f
15	Performance	f	t	t	2026-04-25 18:40:26.577807	medium    	t	72	f	f
2	Security	f	t	t	2026-04-22 20:56:15.803641	high      	t	72	f	f
\.
INSERT INTO config.webook_alerts (row_id, metric_type, send_mail_alert, send_siem_alert, send_diagnosis_evidence, entry_date, risk_level, is_active, recurrency_hours, blocker, auto_mask)
SELECT row_id, metric_type, send_mail_alert, send_siem_alert, send_diagnosis_evidence, entry_date, risk_level, is_active, recurrency_hours, blocker, auto_mask FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.webook_alerts);
DROP TABLE _stg_load;

SELECT setval('config.webook_alerts_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.webook_alerts),1), (SELECT count(*) FROM config.webook_alerts) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'webook_alerts'
          AND con.conname = 'webook_alerts_pkey') THEN
        ALTER TABLE ONLY config.webook_alerts
    ADD CONSTRAINT webook_alerts_pkey PRIMARY KEY (row_id);
    END IF;
END $do$;
