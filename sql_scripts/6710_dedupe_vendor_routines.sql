-- =============================================================================
-- 6710_dedupe_vendor_routines.sql
--
-- metrics.upsert_monitored_server links routines to a new server with
--   WHERE lower(db_version) = lower(p_db_vendor)
-- so two metrics.routines rows differing only in db_version case (found live:
-- 'mariadb' + 'MariaDB', both collect_all_metrics_MariaDB_queries) get BOTH
-- linked, and the server is collected twice per cycle.
--
-- Keep the lowest row_id per (routine_name, lower(db_version)); repoint any
-- servers_routines links from the duplicates to the keeper (unless the keeper
-- link already exists, then drop), and delete the duplicate routine rows.
-- Idempotent.
-- =============================================================================

DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT row_id AS dup_id,
               min(row_id) OVER (PARTITION BY routine_name, lower(db_version)) AS keep_id
        FROM metrics.routines
    LOOP
        CONTINUE WHEN r.dup_id = r.keep_id;

        -- repoint links to the keeper where the server doesn't already have it
        UPDATE metrics.servers_routines sr
        SET routine_id = r.keep_id
        WHERE sr.routine_id = r.dup_id
          AND NOT EXISTS (
              SELECT 1 FROM metrics.servers_routines k
              WHERE k.server_id = sr.server_id AND k.routine_id = r.keep_id);

        -- remaining links are duplicates of an existing keeper link
        DELETE FROM metrics.servers_routines WHERE routine_id = r.dup_id;

        DELETE FROM metrics.routines WHERE row_id = r.dup_id;
        RAISE NOTICE '6710: removed duplicate routine row_id % (kept %)', r.dup_id, r.keep_id;
    END LOOP;
END $$;
