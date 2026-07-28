-- Idempotent install for public.resolution_paths
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.resolution_paths_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.resolution_paths (
    id integer NOT NULL,
    root_cause_id integer NOT NULL,
    vendor_id smallint NOT NULL,
    min_version character varying(20),
    max_version character varying(20),
    name character varying(200),
    description text,
    classification character varying(20) NOT NULL,
    risk_level character varying(20) DEFAULT 'medium'::character varying NOT NULL,
    estimated_impact text,
    path_type character varying(20) DEFAULT 'authored'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    preconditions jsonb,
    CONSTRAINT resolution_paths_classification_check CHECK (((classification)::text = ANY (ARRAY[('auto'::character varying)::text, ('supervised'::character varying)::text, ('manual'::character varying)::text]))),
    CONSTRAINT resolution_paths_path_type_check CHECK (((path_type)::text = ANY (ARRAY[('authored'::character varying)::text, ('learned'::character varying)::text, ('hybrid'::character varying)::text]))),
    CONSTRAINT resolution_paths_risk_level_check CHECK (((risk_level)::text = ANY (ARRAY[('low'::character varying)::text, ('medium'::character varying)::text, ('high'::character varying)::text, ('critical'::character varying)::text])))
);

ALTER TABLE public.resolution_paths ALTER COLUMN id SET DEFAULT nextval('public.resolution_paths_id_seq'::regclass);
ALTER SEQUENCE public.resolution_paths_id_seq OWNED BY public.resolution_paths.id;

SELECT setval('public.resolution_paths_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.resolution_paths),1), (SELECT count(*) FROM public.resolution_paths) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_paths'
          AND con.conname = 'resolution_paths_pkey') THEN
        ALTER TABLE ONLY public.resolution_paths
    ADD CONSTRAINT resolution_paths_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_resolution_paths_active ON public.resolution_paths USING btree (root_cause_id, vendor_id, path_type) WHERE ((is_active = true) AND (min_version IS NULL) AND (max_version IS NULL));
CREATE INDEX IF NOT EXISTS idx_resolution_paths_rc ON public.resolution_paths USING btree (root_cause_id);
CREATE INDEX IF NOT EXISTS idx_resolution_paths_rc_vendor ON public.resolution_paths USING btree (root_cause_id, vendor_id);
CREATE INDEX IF NOT EXISTS idx_resolution_paths_vendor ON public.resolution_paths USING btree (vendor_id);
