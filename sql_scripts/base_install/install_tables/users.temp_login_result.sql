-- Idempotent install for users.temp_login_result
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS users;

CREATE TABLE IF NOT EXISTS users.temp_login_result (
    session_id character varying(255) NOT NULL,
    is_valid boolean,
    user_id integer,
    first_name character varying(255),
    last_name character varying(255),
    email character varying(255),
    is_superuser boolean,
    last_login timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'users' AND c.relname = 'temp_login_result'
          AND con.conname = 'temp_login_result_pkey') THEN
        ALTER TABLE ONLY users.temp_login_result
    ADD CONSTRAINT temp_login_result_pkey PRIMARY KEY (session_id);
    END IF;
END $do$;
