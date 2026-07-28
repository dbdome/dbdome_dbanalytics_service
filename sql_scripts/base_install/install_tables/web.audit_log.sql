-- Idempotent install for web.audit_log
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS web;

CREATE SEQUENCE IF NOT EXISTS web.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS web.audit_log (
    id integer NOT NULL,
    event character varying(50) NOT NULL,
    user_id integer,
    detail text DEFAULT ''::text NOT NULL,
    ip_address character varying(45) DEFAULT ''::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE web.audit_log ALTER COLUMN id SET DEFAULT nextval('web.audit_log_id_seq'::regclass);
ALTER SEQUENCE web.audit_log_id_seq OWNED BY web.audit_log.id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE web.audit_log);
COPY _stg_load (id, event, user_id, detail, ip_address, created_at) FROM stdin;
1	login_failed	\N	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-11 16:21:21.734021+03
2	login_failed	\N	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-11 16:21:39.35083+03
3	login_failed	\N	yoram@dbexpert.ai	127.0.0.1	2026-04-11 16:21:52.577967+03
4	login_failed	\N	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-11 16:22:16.774802+03
5	login_failed	\N	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-11 16:34:01.086978+03
6	setup	1	Admin user created: yoram.dan@dbexpert.ai	127.0.0.1	2026-04-13 21:19:41.632375+03
7	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-18 19:01:51.8888+03
8	login_success	1	yoram.dan@dbexpert.ai	77.137.67.228	2026-04-18 20:33:15.579627+03
9	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-19 21:00:04.28902+03
10	login_success	1	yoram.dan@dbexpert.ai	77.137.66.53	2026-04-19 22:00:26.909694+03
11	login_success	1	yoram.dan@dbexpert.ai	77.137.76.13	2026-04-20 04:47:50.957539+03
12	login_success	1	yoram.dan@dbexpert.ai	77.137.67.252	2026-04-20 10:48:47.34563+03
13	login_failed	\N	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-20 23:14:24.571811+03
14	login_failed	\N	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-20 23:14:37.508602+03
15	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-20 23:16:48.95445+03
16	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-23 20:13:10.207838+03
17	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-25 08:48:36.104474+03
18	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-25 21:51:10.716121+03
19	login_success	1	yoram.dan@dbexpert.ai	181.214.214.95	2026-04-27 19:33:03.733045+03
20	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-28 04:41:22.832794+03
21	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-28 12:31:12.632468+03
22	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-04-29 06:17:04.27498+03
23	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-01 15:51:52.815374+03
24	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-01 19:07:21.680618+03
25	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-02 11:43:51.633252+03
26	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-03 22:22:44.104831+03
27	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-05 00:37:37.390357+03
28	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-05 00:48:11.714923+03
29	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-05 05:54:00.794133+03
30	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-05 20:47:33.865518+03
31	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-05 21:20:54.892368+03
32	login_success	1	yoram.dan@dbexpert.ai	127.0.0.1	2026-05-05 21:36:34.241669+03
\.
INSERT INTO web.audit_log (id, event, user_id, detail, ip_address, created_at)
SELECT id, event, user_id, detail, ip_address, created_at FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM web.audit_log);
DROP TABLE _stg_load;

SELECT setval('web.audit_log_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM web.audit_log),1), (SELECT count(*) FROM web.audit_log) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'audit_log'
          AND con.conname = 'audit_log_pkey') THEN
        ALTER TABLE ONLY web.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_audit_log_event ON web.audit_log USING btree (event, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON web.audit_log USING btree (user_id);
