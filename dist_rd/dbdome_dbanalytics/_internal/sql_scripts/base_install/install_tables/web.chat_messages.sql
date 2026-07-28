-- Idempotent install for web.chat_messages
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS web;

CREATE SEQUENCE IF NOT EXISTS web.chat_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS web.chat_messages (
    id integer NOT NULL,
    user_id integer NOT NULL,
    role character varying(20) NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE web.chat_messages ALTER COLUMN id SET DEFAULT nextval('web.chat_messages_id_seq'::regclass);
ALTER SEQUENCE web.chat_messages_id_seq OWNED BY web.chat_messages.id;

SELECT setval('web.chat_messages_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM web.chat_messages),1), (SELECT count(*) FROM web.chat_messages) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'web' AND c.relname = 'chat_messages'
          AND con.conname = 'chat_messages_pkey') THEN
        ALTER TABLE ONLY web.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON web.chat_messages USING btree (user_id);
