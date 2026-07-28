-- Idempotent install for public.resolution_actions
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.resolution_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.resolution_actions (
    id bigint NOT NULL,
    detection_event_id bigint NOT NULL,
    resolution_path_id integer,
    proposed_at timestamp with time zone DEFAULT now() NOT NULL,
    proposed_by character varying(100) NOT NULL,
    status character varying(20) DEFAULT 'proposed'::character varying NOT NULL,
    status_changed_at timestamp with time zone,
    status_changed_by character varying(100),
    execution_log jsonb,
    rollback_log jsonb,
    verified boolean,
    verified_at timestamp with time zone,
    verified_evidence jsonb,
    notes text,
    CONSTRAINT resolution_actions_status_check CHECK (((status)::text = ANY (ARRAY[('proposed'::character varying)::text, ('accepted'::character varying)::text, ('rejected'::character varying)::text, ('executing'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text, ('rolled_back'::character varying)::text])))
);

ALTER TABLE public.resolution_actions ALTER COLUMN id SET DEFAULT nextval('public.resolution_actions_id_seq'::regclass);
ALTER SEQUENCE public.resolution_actions_id_seq OWNED BY public.resolution_actions.id;

SELECT setval('public.resolution_actions_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.resolution_actions),1), (SELECT count(*) FROM public.resolution_actions) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'resolution_actions'
          AND con.conname = 'resolution_actions_pkey') THEN
        ALTER TABLE ONLY public.resolution_actions
    ADD CONSTRAINT resolution_actions_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_resolution_actions_event ON public.resolution_actions USING btree (detection_event_id);
CREATE INDEX IF NOT EXISTS idx_resolution_actions_status ON public.resolution_actions USING btree (status) WHERE ((status)::text <> ALL (ARRAY[('completed'::character varying)::text, ('rejected'::character varying)::text]));
