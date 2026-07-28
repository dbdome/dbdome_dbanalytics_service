-- Idempotent install for public.resolution_path_steps
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.resolution_path_steps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.resolution_path_steps (
    id integer NOT NULL,
    resolution_path_id integer NOT NULL,
    resolution_step_id integer NOT NULL,
    sequence smallint NOT NULL,
    condition jsonb,
    on_success_action character varying(20) DEFAULT 'next'::character varying NOT NULL,
    on_success_goto integer,
    on_failure_action character varying(20) DEFAULT 'stop'::character varying NOT NULL,
    on_failure_goto integer,
    notes text,
    CONSTRAINT resolution_path_steps_on_failure_action_check CHECK (((on_failure_action)::text = ANY (ARRAY[('next'::character varying)::text, ('stop'::character varying)::text, ('goto'::character varying)::text, ('rollback_all'::character varying)::text]))),
    CONSTRAINT resolution_path_steps_on_success_action_check CHECK (((on_success_action)::text = ANY (ARRAY[('next'::character varying)::text, ('done'::character varying)::text, ('goto'::character varying)::text, ('verify'::character varying)::text])))
);

ALTER TABLE public.resolution_path_steps ALTER COLUMN id SET DEFAULT nextval('public.resolution_path_steps_id_seq'::regclass);
ALTER SEQUENCE public.resolution_path_steps_id_seq OWNED BY public.resolution_path_steps.id;

SELECT setval('public.resolution_path_steps_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.resolution_path_steps),1), (SELECT count(*) FROM public.resolution_path_steps) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_path_steps'
          AND con.conname = 'resolution_path_steps_pkey') THEN
        ALTER TABLE ONLY public.resolution_path_steps
    ADD CONSTRAINT resolution_path_steps_pkey PRIMARY KEY (id);
    END IF;
END $do$;
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_path_steps'
          AND con.conname = 'resolution_path_steps_resolution_path_id_sequence_key') THEN
        ALTER TABLE ONLY public.resolution_path_steps
    ADD CONSTRAINT resolution_path_steps_resolution_path_id_sequence_key UNIQUE (resolution_path_id, sequence);
    END IF;
END $do$;
