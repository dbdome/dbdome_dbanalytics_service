-- ============================================================
-- 6215  monitoring.jsonb_lower_keys(jsonb)
--   Helper that lower-cases the top-level keys of a jsonb object. Used by many
--   rootcause / monitoring views (from 0300 onward) and by the delta scripts
--   6220 / 6230 / 6250, so it must exist BEFORE them.
--
--   It was previously only defined in base_install/95_views_and_functions.sql,
--   so an UPDATE of an existing install (deltas only, no base_install re-run)
--   never (re)created it. This standalone, idempotent migration ensures every
--   environment has it. Numbered 6215 so it runs before its first delta consumer (6220).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS monitoring;

CREATE OR REPLACE FUNCTION monitoring.jsonb_lower_keys(data jsonb)
    RETURNS jsonb
    LANGUAGE sql
    IMMUTABLE STRICT
AS $function$
    SELECT jsonb_object_agg(lower(key), value)
    FROM jsonb_each(data);
$function$;

-- verify
SELECT monitoring.jsonb_lower_keys('{"Foo":1,"BAR":2}'::jsonb) AS lowered;
