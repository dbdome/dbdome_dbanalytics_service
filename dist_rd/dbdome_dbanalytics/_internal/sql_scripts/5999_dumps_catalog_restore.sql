-- ============================================================
-- Per-metric monthly dump catalog + one-click restore (Retention dashboard).
--
--   * config.dumps(row_id, metric_name, month, year, dump_location, row_count,
--     entry_date): one row per archived (metric, month) dump file.
--   * config.dump_last_month(metric[, month, year]): COPY one calendar month of
--     a metric to a CSV in config.get_dump_location(), record it in config.dumps,
--     then DELETE those rows from monitoring.general_metric_metadata_results.
--     Defaults to the PREVIOUS calendar month; month/year can be passed to dump a
--     specific month.
--   * config.restore_dump(row_id): wipe that metric+month from the live table
--     (clean slate, so re-runs never duplicate) then COPY the dump file back, and
--     remove the catalog row.
--
-- COPY ... TO/FROM touch the PostgreSQL server filesystem, so both functions are
-- SECURITY DEFINER (owned by the privileged installer role) -> the Grafana
-- datasource role can invoke them from a panel without file privileges.
-- The identity column `id` is intentionally excluded from the column list so the
-- restore COPY does not collide with GENERATED ALWAYS. Idempotent.
-- ============================================================

-- ---- catalog table ----
CREATE TABLE IF NOT EXISTS config.dumps (
    row_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    metric_name   varchar(255) NOT NULL,
    month         integer      NOT NULL,
    year          integer      NOT NULL,
    dump_location text         NOT NULL,
    row_count     bigint,
    entry_date    timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_dumps_metric_month_year
    ON config.dumps (metric_name, month, year);

-- ---- dump one month of a metric ----
-- DROP first: CREATE OR REPLACE cannot rename OUT parameters.
DROP FUNCTION IF EXISTS config.dump_last_month(text, integer, integer);
DROP FUNCTION IF EXISTS config.restore_dump(bigint);
CREATE OR REPLACE FUNCTION config.dump_last_month(
    p_metric text, p_month integer DEFAULT NULL, p_year integer DEFAULT NULL)
RETURNS TABLE(out_metric text, out_month integer, out_year integer,
              dumped_rows bigint, dump_file text, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    v_loc   text;
    v_sep   text;
    v_start date;
    v_end   date;
    fpath   text;
    cnt     bigint;
    collist text := 'row_id, server, category_id, metric_name, metric_config, '
                 || 'metric_metadata, entry_date, metric_metadata_vs_expected, server_id';
BEGIN
    out_metric := p_metric;
    IF p_metric IS NULL OR p_metric = '' THEN
        dumped_rows := 0; dump_file := NULL; status := 'no metric'; RETURN NEXT; RETURN;
    END IF;

    -- target month: explicit (month+year) else the previous calendar month
    IF p_month IS NULL OR p_year IS NULL THEN
        v_start := (date_trunc('month', current_date) - interval '1 month')::date;
    ELSE
        v_start := make_date(p_year, p_month, 1);
    END IF;
    v_end := (v_start + interval '1 month')::date;
    out_month := extract(month from v_start)::int;
    out_year  := extract(year  from v_start)::int;

    v_loc := config.get_dump_location();
    IF v_loc IS NULL OR v_loc = '' THEN
        dumped_rows := 0; dump_file := NULL;
        status := 'dump_location not set'; RETURN NEXT; RETURN;
    END IF;
    v_sep := CASE WHEN v_loc ~ '\\' THEN '\' ELSE '/' END;

    EXECUTE format(
        'SELECT count(*) FROM monitoring.general_metric_metadata_results '
        'WHERE metric_name = %L AND entry_date >= %L AND entry_date < %L',
        p_metric, v_start, v_end) INTO cnt;

    IF cnt = 0 THEN
        dumped_rows := 0; dump_file := NULL;
        status := 'nothing to dump for ' || to_char(v_start, 'YYYY-MM');
        RETURN NEXT; RETURN;
    END IF;

    fpath := v_loc || v_sep
          || regexp_replace(p_metric, '[^A-Za-z0-9_-]', '_', 'g')
          || '_' || out_year || '_' || lpad(out_month::text, 2, '0') || '.csv';

    EXECUTE format(
        'COPY (SELECT %s FROM monitoring.general_metric_metadata_results '
        'WHERE metric_name = %L AND entry_date >= %L AND entry_date < %L) '
        'TO %L WITH (FORMAT csv, HEADER true)',
        collist, p_metric, v_start, v_end, fpath);

    INSERT INTO config.dumps (metric_name, month, year, dump_location, row_count)
    VALUES (p_metric, out_month, out_year, fpath, cnt)
    ON CONFLICT (metric_name, month, year)
    DO UPDATE SET dump_location = EXCLUDED.dump_location,
                  row_count     = EXCLUDED.row_count,
                  entry_date    = now();

    EXECUTE format(
        'DELETE FROM monitoring.general_metric_metadata_results '
        'WHERE metric_name = %L AND entry_date >= %L AND entry_date < %L',
        p_metric, v_start, v_end);

    dumped_rows := cnt; dump_file := fpath; status := 'ok';
    RETURN NEXT;
EXCEPTION WHEN OTHERS THEN
    dumped_rows := 0; dump_file := fpath; status := 'ERROR: ' || SQLERRM;
    RETURN NEXT;
END $$;

-- ---- restore a dump ----
CREATE OR REPLACE FUNCTION config.restore_dump(p_row_id bigint)
RETURNS TABLE(out_metric text, out_month integer, out_year integer,
              restored_rows bigint, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE
    d       record;
    v_start date;
    v_end   date;
    cnt     bigint;
    collist text := 'row_id, server, category_id, metric_name, metric_config, '
                 || 'metric_metadata, entry_date, metric_metadata_vs_expected, server_id';
BEGIN
    SELECT * INTO d FROM config.dumps WHERE row_id = p_row_id;
    IF NOT FOUND THEN
        restored_rows := 0; status := 'dump not found'; RETURN NEXT; RETURN;
    END IF;
    out_metric := d.metric_name; out_month := d.month; out_year := d.year;
    v_start := make_date(d.year, d.month, 1);
    v_end   := (v_start + interval '1 month')::date;

    -- clean slate so a repeated restore can never duplicate rows
    EXECUTE format(
        'DELETE FROM monitoring.general_metric_metadata_results '
        'WHERE metric_name = %L AND entry_date >= %L AND entry_date < %L',
        d.metric_name, v_start, v_end);

    EXECUTE format(
        'COPY monitoring.general_metric_metadata_results (%s) FROM %L '
        'WITH (FORMAT csv, HEADER true)', collist, d.dump_location);

    EXECUTE format(
        'SELECT count(*) FROM monitoring.general_metric_metadata_results '
        'WHERE metric_name = %L AND entry_date >= %L AND entry_date < %L',
        d.metric_name, v_start, v_end) INTO cnt;

    DELETE FROM config.dumps WHERE row_id = p_row_id;

    restored_rows := cnt; status := 'ok';
    RETURN NEXT;
EXCEPTION WHEN OTHERS THEN
    restored_rows := 0; status := 'ERROR: ' || SQLERRM; RETURN NEXT;
END $$;
