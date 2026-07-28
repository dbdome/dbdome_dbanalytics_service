-- Idempotent install for public.detection_events
-- Auto-generated from dbanalytics_install.backup. Safe to re-run (psql -f).

CREATE SCHEMA IF NOT EXISTS public;

CREATE SEQUENCE IF NOT EXISTS public.detection_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

CREATE TABLE IF NOT EXISTS public.detection_events (
    id bigint NOT NULL,
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    root_cause_id integer,
    vendor_id smallint,
    detection_path_id integer,
    target_host character varying(200),
    target_database character varying(200),
    severity character varying(20),
    confidence numeric(3,2),
    evidence jsonb NOT NULL,
    trigger_source character varying(30) NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    resolved_at timestamp with time zone,
    notes text,
    CONSTRAINT detection_events_confidence_check CHECK (((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))
);

ALTER TABLE public.detection_events ALTER COLUMN id SET DEFAULT nextval('public.detection_events_id_seq'::regclass);
ALTER SEQUENCE public.detection_events_id_seq OWNED BY public.detection_events.id;

SELECT setval('public.detection_events_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.detection_events),1), (SELECT count(*) FROM public.detection_events) > 0);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'detection_events'
          AND con.conname = 'detection_events_pkey') THEN
        ALTER TABLE ONLY public.detection_events
    ADD CONSTRAINT detection_events_pkey PRIMARY KEY (id);
    END IF;
END $do$;

CREATE INDEX IF NOT EXISTS idx_detection_events_host ON public.detection_events USING btree (target_host);
CREATE INDEX IF NOT EXISTS idx_detection_events_rc ON public.detection_events USING btree (root_cause_id);
CREATE INDEX IF NOT EXISTS idx_detection_events_time ON public.detection_events USING btree (detected_at);
CREATE INDEX IF NOT EXISTS idx_detection_events_unresolved ON public.detection_events USING btree (detected_at) WHERE (resolved = false);
CREATE INDEX IF NOT EXISTS idx_detection_events_vendor ON public.detection_events USING btree (vendor_id);
