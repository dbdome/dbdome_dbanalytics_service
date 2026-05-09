-- ============================================================
-- Auto-generate monitoring.v_<root_cause_id> views
--
-- For each root_cause with recent data in
-- monitoring.general_metric_metadata_results, this procedure:
--   1. Finds the latest non-empty metric_metadata JSON array.
--   2. Extracts the keys from the first element.
--   3. Builds and executes CREATE OR REPLACE VIEW DDL.
--
-- Resulting view shape:
--   SELECT r.server,
--          (j.value ->> 'key1') AS key1,
--          (j.value ->> 'key2') AS key2,
--          ...,
--          r.entry_date
--   FROM monitoring.general_metric_metadata_results r
--   CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata) j(value)
--   WHERE r.metric_name = '<ROOT_CAUSE_ID>';
--
-- View name rule: 'v_' + lower(replace(root_cause_id, '-', '_'))
-- ============================================================

CREATE OR REPLACE FUNCTION monitoring.view_name_for_rc(p_rc text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT 'v_' || lower(regexp_replace(p_rc, '[^a-zA-Z0-9]+', '_', 'g'))
$$;


CREATE OR REPLACE PROCEDURE monitoring.generate_root_cause_view(
    IN p_root_cause_id text,
    IN p_owner         text DEFAULT 'enterprisedb'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_view_name    text;
    v_full_name    text;
    v_sample       jsonb;
    v_first_elem   jsonb;
    v_keys         text[];
    v_select_cols  text;
    v_ddl          text;
    v_key          text;
BEGIN
    IF p_root_cause_id IS NULL OR length(trim(p_root_cause_id)) = 0 THEN
        RAISE EXCEPTION 'root_cause_id must be provided';
    END IF;

    -- Most recent non-empty metric_metadata array for this root cause
    SELECT r.metric_metadata::jsonb
      INTO v_sample
      FROM monitoring.general_metric_metadata_results r
     WHERE r.metric_name = p_root_cause_id
       AND r.metric_metadata IS NOT NULL
       AND jsonb_typeof(r.metric_metadata::jsonb) = 'array'
       AND jsonb_array_length(r.metric_metadata::jsonb) > 0
     ORDER BY r.entry_date DESC
     LIMIT 1;

    IF v_sample IS NULL THEN
        RAISE NOTICE 'No sample metric_metadata for %, skipping', p_root_cause_id;
        RETURN;
    END IF;

    v_first_elem := v_sample -> 0;
    IF jsonb_typeof(v_first_elem) <> 'object' THEN
        RAISE NOTICE 'metric_metadata[0] for % is not an object, skipping', p_root_cause_id;
        RETURN;
    END IF;

    -- Distinct keys, in insertion order from the sample element
    SELECT array_agg(k ORDER BY k)
      INTO v_keys
      FROM jsonb_object_keys(v_first_elem) k;

    v_view_name := monitoring.view_name_for_rc(p_root_cause_id);
    v_full_name := 'monitoring.' || quote_ident(v_view_name);

    -- Build select list
    v_select_cols := 'r.server';
    FOREACH v_key IN ARRAY v_keys LOOP
        v_select_cols := v_select_cols
            || E',\n       (j.value ->> ' || quote_literal(v_key) || ') AS '
            || quote_ident(v_key);
    END LOOP;
    v_select_cols := v_select_cols || E',\n       r.entry_date';

    v_ddl :=
        'CREATE OR REPLACE VIEW ' || v_full_name || ' AS' || E'\n' ||
        'SELECT ' || v_select_cols || E'\n' ||
        '  FROM monitoring.general_metric_metadata_results r' || E'\n' ||
        '  CROSS JOIN LATERAL jsonb_array_elements(r.metric_metadata::jsonb) j(value)' || E'\n' ||
        ' WHERE r.metric_name = ' || quote_literal(p_root_cause_id);

    EXECUTE v_ddl;

    IF p_owner IS NOT NULL AND length(trim(p_owner)) > 0 THEN
        EXECUTE format('ALTER VIEW %s OWNER TO %I', v_full_name, p_owner);
    END IF;

    RAISE NOTICE 'Created/updated view % (% columns)',
        v_full_name, array_length(v_keys, 1);
END;
$$;


CREATE OR REPLACE PROCEDURE monitoring.generate_all_root_cause_views(
    IN p_owner text DEFAULT 'enterprisedb'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rc text;
    v_count int := 0;
    v_errors int := 0;
BEGIN
    FOR v_rc IN
        SELECT DISTINCT r.metric_name
          FROM monitoring.general_metric_metadata_results r
         WHERE r.metric_metadata IS NOT NULL
           AND jsonb_typeof(r.metric_metadata::jsonb) = 'array'
           AND jsonb_array_length(r.metric_metadata::jsonb) > 0
         ORDER BY r.metric_name
    LOOP
        BEGIN
            CALL monitoring.generate_root_cause_view(v_rc, p_owner);
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Failed for %: %', v_rc, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Generated/refreshed % views (% errors)', v_count, v_errors;
END;
$$;


-- ------------------------------------------------------------
-- "Shell" view: no data yet, so project raw metric_metadata.
-- Used by generate_views_from_rootcause for root causes without
-- any sample data in general_metric_metadata_results.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE monitoring.generate_shell_root_cause_view(
    IN p_root_cause_id text,
    IN p_owner         text DEFAULT 'enterprisedb'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_view_name text;
    v_full_name text;
    v_ddl       text;
BEGIN
    v_view_name := monitoring.view_name_for_rc(p_root_cause_id);
    v_full_name := 'monitoring.' || quote_ident(v_view_name);

    v_ddl :=
        'CREATE OR REPLACE VIEW ' || v_full_name || ' AS' || E'\n' ||
        'SELECT r.server,' || E'\n' ||
        '       r.metric_metadata,' || E'\n' ||
        '       r.entry_date' || E'\n' ||
        '  FROM monitoring.general_metric_metadata_results r' || E'\n' ||
        ' WHERE r.metric_name = ' || quote_literal(p_root_cause_id);

    EXECUTE v_ddl;

    IF p_owner IS NOT NULL AND length(trim(p_owner)) > 0 THEN
        EXECUTE format('ALTER VIEW %s OWNER TO %I', v_full_name, p_owner);
    END IF;
END;
$$;


-- ------------------------------------------------------------
-- Iterate rootcause.root_causes. For each row:
--   * if data exists in general_metric_metadata_results
--     -> introspect JSON keys and build a typed view.
--   * otherwise -> create a shell view.
-- CREATE OR REPLACE VIEW means this can be re-run safely.
-- Existing shell views will be upgraded to typed views once
-- data arrives and the procedure is re-run.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE monitoring.generate_views_from_rootcause(
    IN p_owner text DEFAULT 'enterprisedb'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rc           text;
    v_has_data     boolean;
    v_typed        int := 0;
    v_shell        int := 0;
    v_errors       int := 0;
    v_current_view text;
BEGIN
    FOR v_rc IN
        SELECT root_cause_id FROM rootcause.root_causes ORDER BY root_cause_id
    LOOP
        BEGIN
            v_current_view := monitoring.view_name_for_rc(v_rc);

            SELECT EXISTS (
                SELECT 1
                  FROM monitoring.general_metric_metadata_results r
                 WHERE r.metric_name = v_rc
                   AND r.metric_metadata IS NOT NULL
                   AND jsonb_typeof(r.metric_metadata::jsonb) = 'array'
                   AND jsonb_array_length(r.metric_metadata::jsonb) > 0
                 LIMIT 1
            ) INTO v_has_data;

            -- If a shell view already exists for this RC and we're about
            -- to create a typed one with different columns, drop it first
            -- (CREATE OR REPLACE VIEW refuses column-set changes).
            IF v_has_data THEN
                EXECUTE format('DROP VIEW IF EXISTS monitoring.%I', v_current_view);
                CALL monitoring.generate_root_cause_view(v_rc, p_owner);
                v_typed := v_typed + 1;
            ELSE
                CALL monitoring.generate_shell_root_cause_view(v_rc, p_owner);
                v_shell := v_shell + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Failed for %: %', v_rc, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Generated: % typed, % shell, % errors',
                 v_typed, v_shell, v_errors;
END;
$$;
