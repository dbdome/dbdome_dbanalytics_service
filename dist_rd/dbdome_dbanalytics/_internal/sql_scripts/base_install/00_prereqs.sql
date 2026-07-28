-- Prerequisites for the generated per-table install scripts: schemas, extension,
-- and user-defined types that table columns depend on. Idempotent.

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE EXTENSION IF NOT EXISTS file_fdw WITH SCHEMA monitoring;

-- public.metric_type enum (used by metrics.custom_metrics etc.)
DO $do$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public' AND t.typname = 'metric_type'
    ) THEN
        CREATE TYPE public.metric_type AS ENUM ('collect', 'analysis');
    END IF;
END $do$;
