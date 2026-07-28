-- ============================================================
-- Metric dump + prune retention.
--
--   * config.global_params 'dump_location' : folder the dumps are written to
--     (config.get_dump_location / config.set_dump_location read/write it).
--   * config.dump_metrics(row_id, metric_name, retention_months, entry_date):
--     one row per metric to manage.
--   * config.dump_and_prune_metrics(): for each configured metric, COPY the rows
--     older than current_date - retention_months to a CSV in dump_location, then
--     DELETE exactly those rows from monitoring.general_metric_metadata_results.
--
-- Registered as the 'dump_and_prune_metrics' scheduler process. Idempotent.
-- ============================================================

-- ---- dump_location in config.global_params (keyed by `key`, not unique) ----
CREATE OR REPLACE FUNCTION config.get_dump_location()
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT value FROM config.global_params
    WHERE key = 'dump_location' ORDER BY row_id DESC LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION config.set_dump_location(p_path text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM config.global_params WHERE key = 'dump_location') THEN
        UPDATE config.global_params
        SET value = p_path, entry_date = now()
        WHERE key = 'dump_location';
    ELSE
        INSERT INTO config.global_params (key, value) VALUES ('dump_location', p_path);
    END IF;
    RETURN p_path;
END $$;

-- seed a default location once
DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM config.global_params WHERE key = 'dump_location') THEN
        PERFORM config.set_dump_location('C:\ProgramData\DBDOME\dumps');
    END IF;
END $do$;

-- ---- config.dump_metrics ----
CREATE TABLE IF NOT EXISTS config.dump_metrics (
    row_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    metric_name      varchar(255) NOT NULL,
    retention_months integer      NOT NULL DEFAULT 12,
    entry_date       timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_dump_metrics_metric_name
    ON config.dump_metrics (metric_name);

-- ---- dump + prune ----
-- Archives (CSV) and then deletes the rows older than the per-metric retention
-- window. COPY ... TO writes on the PostgreSQL server filesystem, so the role
-- needs superuser / pg_write_server_files and dump_location must exist (the
-- scheduler wrapper creates it). Each metric is isolated so one failure
-- (e.g. missing folder) doesn't abort the rest.
CREATE OR REPLACE FUNCTION config.dump_and_prune_metrics()
RETURNS TABLE(metric_name text, dumped_rows bigint, deleted_rows bigint,
              dump_file text, status text)
LANGUAGE plpgsql AS $$
DECLARE
    v_loc  text;
    v_sep  text;
    m      record;
    cutoff date;
    fpath  text;
    cnt    bigint;
    ts     text := to_char(now(), 'YYYYMMDD_HH24MISS');
BEGIN
    v_loc := config.get_dump_location();
    IF v_loc IS NULL OR v_loc = '' THEN
        RAISE EXCEPTION 'dump_location not set in config.global_params';
    END IF;
    v_sep := CASE WHEN v_loc ~ '\\' THEN '\' ELSE '/' END;   -- windows vs posix

    FOR m IN SELECT dm.metric_name AS mn, dm.retention_months AS rm
             FROM config.dump_metrics dm ORDER BY dm.metric_name
    LOOP
        cutoff := (current_date - make_interval(months => m.rm))::date;
        BEGIN
            EXECUTE format(
                'SELECT count(*) FROM monitoring.general_metric_metadata_results '
                'WHERE metric_name = %L AND entry_date < %L', m.mn, cutoff)
            INTO cnt;

            IF cnt = 0 THEN
                metric_name := m.mn; dumped_rows := 0; deleted_rows := 0;
                dump_file := NULL; status := 'nothing to prune';
                RETURN NEXT; CONTINUE;
            END IF;

            fpath := v_loc || v_sep
                     || regexp_replace(m.mn, '[^A-Za-z0-9_-]', '_', 'g')
                     || '_' || ts || '.csv';

            EXECUTE format(
                'COPY (SELECT * FROM monitoring.general_metric_metadata_results '
                'WHERE metric_name = %L AND entry_date < %L) '
                'TO %L WITH (FORMAT csv, HEADER true)', m.mn, cutoff, fpath);

            EXECUTE format(
                'DELETE FROM monitoring.general_metric_metadata_results '
                'WHERE metric_name = %L AND entry_date < %L', m.mn, cutoff);
            GET DIAGNOSTICS deleted_rows = ROW_COUNT;

            metric_name := m.mn; dumped_rows := cnt;
            dump_file := fpath; status := 'ok';
            RETURN NEXT;
        EXCEPTION WHEN OTHERS THEN
            metric_name := m.mn; dumped_rows := 0; deleted_rows := 0;
            dump_file := fpath; status := 'ERROR: ' || SQLERRM;
            RETURN NEXT;
        END;
    END LOOP;
END $$;

-- ---- register the scheduler process (daily) ----
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'dump_and_prune_metrics', true, 86400,
       'Dump (CSV) + prune metric rows older than per-metric retention (config.dump_metrics)'
WHERE NOT EXISTS (
    SELECT 1 FROM metrics.registered_processes WHERE process_name = 'dump_and_prune_metrics');
