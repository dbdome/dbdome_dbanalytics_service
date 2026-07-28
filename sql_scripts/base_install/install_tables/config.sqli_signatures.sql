-- Idempotent install for config.sqli_signatures
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS config;

CREATE SEQUENCE IF NOT EXISTS config.sqli_signatures_row_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS config.sqli_signatures (
    row_id integer NOT NULL,
    pattern text NOT NULL,
    description text NOT NULL,
    severity integer NOT NULL,
    issue_id character varying(50),
    root_cause_number integer
);

ALTER TABLE config.sqli_signatures ALTER COLUMN row_id SET DEFAULT nextval('config.sqli_signatures_row_id_seq'::regclass);
ALTER SEQUENCE config.sqli_signatures_row_id_seq OWNED BY config.sqli_signatures.row_id;

-- data: load only into a freshly-created (empty) table
DROP TABLE IF EXISTS _stg_load;
CREATE TEMP TABLE _stg_load (LIKE config.sqli_signatures);
COPY _stg_load (row_id, pattern, description, severity, issue_id, root_cause_number) FROM stdin;
15	(?i)xp_cmdshell	Shell commands	7	SEC-SQL-THR-001	16
12	(?i)SLEEP	Oracle Wait commands	10	SEC-SQL-THR-001	5
19	(?i)--|/\\*|\\*/	SQL comment injection	3	SEC-SQL-THR-001	2
22	(?i)information_schema|pg_catalog	Metadata probing	3	SEC-SQL-THR-001	5
11	(?i)CONVERT	Error based injection	12	SEC-SQL-THR-001	11
18	(?i)union\\s+select	UNION SELECT injection	4	SEC-SQL-THR-001	3
13	(?i)pg_sleep	postgres Wait commands	9	SEC-SQL-THR-001	7
14	(?i)WAITFOR DELAY	MSSSQL Wait commands	8	SEC-SQL-THR-001	7
16	(?i)DROP TABLE	Drop objects	6	SEC-SQL-THR-001	8
20	(?i);.*(drop|alter|truncate)	Stacked query	5	SEC-SQL-THR-001	8
17	(?i)or\\s+1\\s*=\\s*1	Boolean tautology	4	SEC-SQL-THR-001	6
21	(?i)pg_sleep\\s*\\(	Time-based injection	5	SEC-SQL-THR-001	5
10	(?i)0x414243	Encoding  injection	13	SEC-SQL-THR-001	11
\.
INSERT INTO config.sqli_signatures (row_id, pattern, description, severity, issue_id, root_cause_number)
SELECT row_id, pattern, description, severity, issue_id, root_cause_number FROM _stg_load
WHERE NOT EXISTS (SELECT 1 FROM config.sqli_signatures);
DROP TABLE _stg_load;

SELECT setval('config.sqli_signatures_row_id_seq', GREATEST((SELECT COALESCE(max(row_id),0) FROM config.sqli_signatures),1), (SELECT count(*) FROM config.sqli_signatures) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'config' AND c.relname = 'sqli_signatures'
          AND con.conname = 'pk_sqli_signatures') THEN
        ALTER TABLE ONLY config.sqli_signatures
    ADD CONSTRAINT pk_sqli_signatures PRIMARY KEY (pattern);
    END IF;
END $do$;
