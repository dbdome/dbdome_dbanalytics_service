-- Idempotent install for public.resolution_steps
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.resolution_steps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.resolution_steps (
    id integer NOT NULL,
    vendor_id smallint NOT NULL,
    step_type character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    content jsonb NOT NULL,
    rollback_content jsonb,
    risk_level character varying(20) DEFAULT 'medium'::character varying NOT NULL,
    requires_approval boolean DEFAULT true NOT NULL,
    reversible boolean DEFAULT true NOT NULL,
    estimated_duration interval,
    CONSTRAINT resolution_steps_risk_level_check CHECK (((risk_level)::text = ANY (ARRAY[('low'::character varying)::text, ('medium'::character varying)::text, ('high'::character varying)::text, ('critical'::character varying)::text]))),
    CONSTRAINT resolution_steps_step_type_check CHECK (((step_type)::text = ANY (ARRAY[('execute'::character varying)::text, ('configure'::character varying)::text, ('verify'::character varying)::text, ('instruct'::character varying)::text, ('rollback'::character varying)::text])))
);

ALTER TABLE public.resolution_steps ALTER COLUMN id SET DEFAULT nextval('public.resolution_steps_id_seq'::regclass);
ALTER SEQUENCE public.resolution_steps_id_seq OWNED BY public.resolution_steps.id;

SELECT setval('public.resolution_steps_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.resolution_steps),1), (SELECT count(*) FROM public.resolution_steps) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_steps'
          AND con.conname = 'resolution_steps_pkey') THEN
        ALTER TABLE ONLY public.resolution_steps
    ADD CONSTRAINT resolution_steps_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_resolution_steps_type ON public.resolution_steps USING btree (step_type);
CREATE INDEX IF NOT EXISTS idx_resolution_steps_vendor ON public.resolution_steps USING btree (vendor_id);
