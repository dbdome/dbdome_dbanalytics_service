-- =============================================================================
-- 7680_migration_engine.sql
--
-- The `migration` schema: source server + database set -> JSON transformation
-- ruleset -> destination server + database set, executed on a schedule.
--
-- HOW THIS FITS WHAT ALREADY EXISTS
--   * Connection identity is NOT duplicated. An endpoint points at
--     metrics.servers.server_id, so host/port/vendor/driver and the enc:v1:
--     credentials keep living where the serverform UI already manages them.
--     metrics.servers.database is a SINGLE column, so the database *set* cannot
--     live there - it is migration.database_map below.
--   * Rules are JSONB rows resolved most-specific-wins, the same idea as
--     config.masking_rules (server, table, column) but one level deeper.
--   * Run accounting copies the alerts.mail_send_log shape: status + STAGE +
--     error class/code, because "it didn't finish" has to be one query.
--   * Scheduling reuses the two schedulers this product already runs:
--       - metrics.registered_processes drives ONE process, 'migration_runner',
--         on an interval (the dispatcher tick). Seeded INACTIVE at the bottom.
--       - per-project cadence lives in migration.schedules, modelled on
--         jobs.job_schedules (last_run / next_run) rather than a third engine.
--
-- WHY THE SCHEDULING TABLES LOOK LIKE THIS
--   A migration is long, stateful and destructive-on-retry, which a report job
--   is not. So the schedule carries what a report schedule never needed:
--     - single-flight: a tick must never start a project that is still running
--       (state + heartbeat_at + a pg advisory lock key),
--     - crash recovery: a service killed mid-run leaves state='running'
--       forever, so a run is declared stale after stale_after_seconds,
--     - windows: big loads run at night, so allow_from/allow_to + days-of-week,
--     - retry with backoff and a cap, instead of hammering a dead source,
--     - catch-up policy: after downtime, run once - never replay every missed
--       slot, which for a migration would mean repeated full loads.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS migration;

-- --------------------------------------------------------------------------
-- 1. Projects: one source server -> one target server, plus defaults
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS migration.projects (
    project_id        bigserial PRIMARY KEY,
    project_name      text        NOT NULL UNIQUE,
    description       text,
    -- both reference metrics.servers.server_id (uuid). Not an FK on purpose:
    -- a server row can be re-created during maintenance and that must not
    -- cascade-delete a migration project's history.
    source_server_id  uuid        NOT NULL,
    target_server_id  uuid        NOT NULL,
    mode              text        NOT NULL DEFAULT 'full'
                       CHECK (mode IN ('full', 'incremental')),
    -- 'all'   = every object in each mapped database except the exclude list
    -- 'listed'= only objects that have an explicit object-scope rule
    object_scope      text        NOT NULL DEFAULT 'listed'
                       CHECK (object_scope IN ('all', 'listed')),
    batch_size        integer     NOT NULL DEFAULT 5000 CHECK (batch_size > 0),
    parallel_databases integer    NOT NULL DEFAULT 1 CHECK (parallel_databases BETWEEN 1 AND 16),
    on_error          text        NOT NULL DEFAULT 'stop_object'
                       CHECK (on_error IN ('stop_object', 'stop_database', 'stop_project', 'continue')),
    -- a run may NEVER write unless this is true: the dry-run gate
    allow_write       boolean     NOT NULL DEFAULT false,
    is_active         boolean     NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN migration.projects.allow_write IS
    'False = dry run only: extract and transform, never write to the target. A new project starts here deliberately.';

-- --------------------------------------------------------------------------
-- 2. The database SET, both sides
--    1:1 rename, subset, and many->one consolidation are all just rows.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS migration.database_map (
    map_id           bigserial PRIMARY KEY,
    project_id       bigint      NOT NULL REFERENCES migration.projects(project_id) ON DELETE CASCADE,
    source_database  text        NOT NULL,
    target_database  text        NOT NULL,
    -- source schema -> target schema, e.g. {"DB2INST1": "public"}
    schema_map       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    load_order       integer     NOT NULL DEFAULT 100,
    is_active        boolean     NOT NULL DEFAULT true,
    entry_date       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (project_id, source_database, target_database)
);

CREATE INDEX IF NOT EXISTS ix_migration_dbmap_project
    ON migration.database_map (project_id, is_active, load_order);

-- --------------------------------------------------------------------------
-- 3. The ruleset. scope + NULLs decide how specific a rule is; the engine
--    merges project -> database -> object -> column, most specific winning.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS migration.rules (
    rule_id        bigserial PRIMARY KEY,
    project_id     bigint      NOT NULL REFERENCES migration.projects(project_id) ON DELETE CASCADE,
    scope          text        NOT NULL CHECK (scope IN ('project', 'database', 'object', 'column')),
    database_name  text,                 -- NULL at project scope
    object_name    text,                 -- NULL at project/database scope
    column_name    text,                 -- NULL unless scope = 'column'
    rule           jsonb       NOT NULL,
    priority       integer     NOT NULL DEFAULT 100,   -- tie-break inside a scope
    version        integer     NOT NULL DEFAULT 1,
    is_active      boolean     NOT NULL DEFAULT true,
    created_by     text,
    entry_date     timestamptz NOT NULL DEFAULT now(),
    -- a scope must carry exactly the keys it needs, no more
    CONSTRAINT ck_migration_rules_scope_keys CHECK (
        (scope = 'project'  AND database_name IS NULL AND object_name IS NULL AND column_name IS NULL) OR
        (scope = 'database' AND database_name IS NOT NULL AND object_name IS NULL AND column_name IS NULL) OR
        (scope = 'object'   AND database_name IS NOT NULL AND object_name IS NOT NULL AND column_name IS NULL) OR
        (scope = 'column'   AND database_name IS NOT NULL AND object_name IS NOT NULL AND column_name IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS ix_migration_rules_lookup
    ON migration.rules (project_id, is_active, scope, database_name, object_name, column_name);
CREATE INDEX IF NOT EXISTS ix_migration_rules_gin
    ON migration.rules USING gin (rule jsonb_path_ops);

COMMENT ON TABLE migration.rules IS
    'JSON transformation ruleset. Resolved project -> database -> object -> column, merged, most specific wins. Changing a mapping is an UPDATE, never a rebuild.';

-- --------------------------------------------------------------------------
-- 4. SCHEDULING
--    4a. the cadence + the guardrails a long destructive job needs
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS migration.schedules (
    schedule_id      bigserial PRIMARY KEY,
    project_id       bigint      NOT NULL REFERENCES migration.projects(project_id) ON DELETE CASCADE,
    is_active        boolean     NOT NULL DEFAULT false,

    -- WHEN. Exactly one kind is used, chosen by schedule_kind.
    schedule_kind    text        NOT NULL DEFAULT 'interval'
                      CHECK (schedule_kind IN ('interval', 'daily', 'weekly', 'monthly', 'cron', 'manual')),
    interval_seconds integer     CHECK (interval_seconds IS NULL OR interval_seconds >= 60),
    occurs_at        time,                       -- daily/weekly/monthly
    day_of_week      smallint[],                 -- 0=Sunday .. 6=Saturday
    day_of_month     smallint    CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31),
    cron_expression  text,                       -- 5-field, when schedule_kind='cron'
    timezone         text        NOT NULL DEFAULT 'UTC',

    -- WINDOW. A migration may only START inside this window; a run already in
    -- progress is not killed at the boundary unless kill_outside_window.
    allow_from       time,
    allow_to         time,
    allow_days       smallint[],
    kill_outside_window boolean  NOT NULL DEFAULT false,

    -- SINGLE-FLIGHT + RECOVERY. The dispatcher must never start a project that
    -- is already running, and must be able to tell "running" from "the service
    -- died holding this row".
    state            text        NOT NULL DEFAULT 'idle'
                      CHECK (state IN ('idle', 'queued', 'running', 'paused', 'error')),
    current_run_id   bigint,
    heartbeat_at     timestamptz,
    stale_after_seconds integer  NOT NULL DEFAULT 1800 CHECK (stale_after_seconds >= 60),
    -- pg_try_advisory_lock key, so two service instances cannot both dispatch
    lock_key         bigint      GENERATED ALWAYS AS (schedule_id + 7680000000) STORED,

    -- RETRY. A dead source should back off, not be hammered every tick.
    max_attempts     integer     NOT NULL DEFAULT 3 CHECK (max_attempts >= 1),
    attempt          integer     NOT NULL DEFAULT 0,
    retry_backoff_seconds integer NOT NULL DEFAULT 900,

    -- CATCH-UP. After downtime a report can replay; a migration must not.
    catchup_policy   text        NOT NULL DEFAULT 'run_once'
                      CHECK (catchup_policy IN ('run_once', 'skip')),

    priority         integer     NOT NULL DEFAULT 100,   -- lower dispatches first
    max_runtime_seconds integer,                          -- abort guard, NULL = unlimited
    last_run         timestamptz,
    next_run         timestamptz,
    last_status      text,
    consecutive_failures integer NOT NULL DEFAULT 0,
    entry_date       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (project_id),
    -- the chosen kind must bring its own parameters
    CONSTRAINT ck_migration_schedule_kind CHECK (
        (schedule_kind = 'interval' AND interval_seconds IS NOT NULL) OR
        (schedule_kind = 'daily'    AND occurs_at IS NOT NULL) OR
        (schedule_kind = 'weekly'   AND occurs_at IS NOT NULL AND day_of_week IS NOT NULL) OR
        (schedule_kind = 'monthly'  AND occurs_at IS NOT NULL AND day_of_month IS NOT NULL) OR
        (schedule_kind = 'cron'     AND cron_expression IS NOT NULL) OR
        (schedule_kind = 'manual')
    )
);

CREATE INDEX IF NOT EXISTS ix_migration_schedules_due
    ON migration.schedules (is_active, state, next_run, priority);

COMMENT ON TABLE migration.schedules IS
    'Per-project cadence and guardrails. The dispatcher process (metrics.registered_processes: migration_runner) ticks, takes an advisory lock on lock_key, and starts only projects that are due, in-window and not already running.';
COMMENT ON COLUMN migration.schedules.stale_after_seconds IS
    'A run whose heartbeat_at is older than this is treated as dead and reset to idle, so a service crash cannot wedge a project in state=running forever.';

--    4b. what the dispatcher opens: exactly what is due right now, and why not
CREATE OR REPLACE VIEW migration.v_schedule_due AS
SELECT s.schedule_id,
       s.project_id,
       p.project_name,
       s.priority,
       s.next_run,
       s.state,
       s.attempt,
       s.max_attempts,
       s.lock_key,
       (s.heartbeat_at IS NOT NULL
        AND s.heartbeat_at < now() - make_interval(secs => s.stale_after_seconds)) AS is_stale,
       CASE
         WHEN NOT p.is_active                      THEN 'project inactive'
         WHEN NOT s.is_active                      THEN 'schedule inactive'
         WHEN s.state = 'paused'                   THEN 'paused'
         WHEN s.state = 'running'
              AND (s.heartbeat_at IS NULL
                   OR s.heartbeat_at >= now() - make_interval(secs => s.stale_after_seconds))
                                                   THEN 'already running'
         WHEN s.attempt >= s.max_attempts          THEN 'retry budget exhausted'
         WHEN s.next_run IS NULL                   THEN 'no next_run computed'
         WHEN s.next_run > now()                   THEN 'not due yet'
         WHEN s.allow_from IS NOT NULL AND s.allow_to IS NOT NULL
              AND NOT ( (localtime BETWEEN s.allow_from AND s.allow_to)
                        OR (s.allow_from > s.allow_to
                            AND (localtime >= s.allow_from OR localtime <= s.allow_to)) )
                                                   THEN 'outside the allowed window'
         WHEN s.allow_days IS NOT NULL
              AND NOT (EXTRACT(dow FROM now())::smallint = ANY (s.allow_days))
                                                   THEN 'not an allowed day'
         ELSE 'due'
       END AS dispatch_decision
FROM migration.schedules s
JOIN migration.projects  p ON p.project_id = s.project_id;

COMMENT ON VIEW migration.v_schedule_due IS
    'Why each project will or will not start on this tick. A skipped migration should never be a mystery.';

-- --------------------------------------------------------------------------
-- 5. Run accounting (shape borrowed from alerts.mail_send_log)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS migration.runs (
    run_id         bigserial PRIMARY KEY,
    project_id     bigint      NOT NULL REFERENCES migration.projects(project_id) ON DELETE CASCADE,
    schedule_id    bigint,
    trigger        text        NOT NULL DEFAULT 'schedule'
                    CHECK (trigger IN ('schedule', 'manual', 'api', 'retry')),
    dry_run        boolean     NOT NULL DEFAULT true,
    status         text        NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'succeeded', 'failed', 'aborted', 'partial')),
    started_at     timestamptz NOT NULL DEFAULT now(),
    finished_at    timestamptz,
    heartbeat_at   timestamptz,
    databases_total integer    NOT NULL DEFAULT 0,
    objects_total   integer    NOT NULL DEFAULT 0,
    rows_read       bigint     NOT NULL DEFAULT 0,
    rows_written    bigint     NOT NULL DEFAULT 0,
    rows_rejected   bigint     NOT NULL DEFAULT 0,
    error_class    text,
    error_text     text,
    host           text                            -- which service instance ran it
);

CREATE INDEX IF NOT EXISTS ix_migration_runs_project ON migration.runs (project_id, started_at DESC);
CREATE INDEX IF NOT EXISTS ix_migration_runs_status  ON migration.runs (status, started_at DESC);

CREATE TABLE IF NOT EXISTS migration.run_items (
    item_id        bigserial PRIMARY KEY,
    run_id         bigint      NOT NULL REFERENCES migration.runs(run_id) ON DELETE CASCADE,
    source_database text       NOT NULL,
    target_database text,
    object_name    text,
    status         text        NOT NULL
                    CHECK (status IN ('pending', 'running', 'succeeded', 'failed', 'skipped')),
    -- where it died: connect | introspect | extract | transform | load | validate
    stage          text,
    skip_reason    text,
    rows_read      bigint      NOT NULL DEFAULT 0,
    rows_written   bigint      NOT NULL DEFAULT 0,
    rows_rejected  bigint      NOT NULL DEFAULT 0,
    batches        integer     NOT NULL DEFAULT 0,
    started_at     timestamptz NOT NULL DEFAULT now(),
    finished_at    timestamptz,
    duration_ms    numeric,
    error_class    text,
    error_code     text,
    error_text     text
);

CREATE INDEX IF NOT EXISTS ix_migration_run_items_run    ON migration.run_items (run_id, status);
CREATE INDEX IF NOT EXISTS ix_migration_run_items_object ON migration.run_items (source_database, object_name, started_at DESC);

-- --------------------------------------------------------------------------
-- 6. Restartability and quarantine
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS migration.watermarks (
    project_id      bigint      NOT NULL REFERENCES migration.projects(project_id) ON DELETE CASCADE,
    source_database text        NOT NULL,
    object_name     text        NOT NULL,
    -- typed loosely on purpose: a watermark may be a timestamp, an id or a key tuple
    watermark_value text,
    watermark_type  text        NOT NULL DEFAULT 'timestamp'
                     CHECK (watermark_type IN ('timestamp', 'numeric', 'text', 'composite')),
    last_key        jsonb,                      -- resume point inside a batch run
    rows_total      bigint      NOT NULL DEFAULT 0,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, source_database, object_name)
);

CREATE TABLE IF NOT EXISTS migration.rejects (
    reject_id      bigserial PRIMARY KEY,
    run_id         bigint      REFERENCES migration.runs(run_id) ON DELETE CASCADE,
    project_id     bigint      NOT NULL,
    source_database text       NOT NULL,
    object_name    text        NOT NULL,
    rule_id        bigint,                      -- the rule that rejected it
    stage          text,
    error_class    text,
    error_text     text,
    source_row     jsonb,                       -- the row as extracted
    entry_date     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_migration_rejects_run ON migration.rejects (run_id, object_name);

-- --------------------------------------------------------------------------
-- 7. Operator views
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW migration.v_run_errors AS
SELECT i.item_id, i.run_id, r.project_id, p.project_name, i.source_database,
       i.target_database, i.object_name, i.status, i.stage, i.skip_reason,
       i.error_class, i.error_code, i.error_text,
       i.rows_read, i.rows_written, i.rows_rejected, i.duration_ms, i.started_at
FROM migration.run_items i
JOIN migration.runs      r ON r.run_id = i.run_id
JOIN migration.projects  p ON p.project_id = r.project_id
WHERE i.status IN ('failed', 'skipped')
ORDER BY i.started_at DESC;

CREATE OR REPLACE VIEW migration.v_run_summary AS
SELECT r.run_id, p.project_name, r.trigger, r.dry_run, r.status,
       r.started_at, r.finished_at,
       round(EXTRACT(epoch FROM (COALESCE(r.finished_at, now()) - r.started_at))::numeric, 1) AS seconds,
       r.databases_total, r.objects_total,
       r.rows_read, r.rows_written, r.rows_rejected,
       count(*) FILTER (WHERE i.status = 'failed')    AS objects_failed,
       count(*) FILTER (WHERE i.status = 'succeeded') AS objects_ok
FROM migration.runs r
JOIN migration.projects p ON p.project_id = r.project_id
LEFT JOIN migration.run_items i ON i.run_id = r.run_id
GROUP BY r.run_id, p.project_name, r.trigger, r.dry_run, r.status, r.started_at,
         r.finished_at, r.databases_total, r.objects_total,
         r.rows_read, r.rows_written, r.rows_rejected
ORDER BY r.started_at DESC;

-- --------------------------------------------------------------------------
-- 8. Register the dispatcher process. INACTIVE, like every other new job here:
--    creating the tables is what makes the feature possible; starting a loop
--    that can write to customer databases is a separate, deliberate act.
-- --------------------------------------------------------------------------
INSERT INTO metrics.registered_processes (process_name, is_active, interval, description)
SELECT 'migration_runner', false, 60,
       'Migration dispatcher: every tick, start the projects that migration.v_schedule_due reports as due, one advisory lock per schedule.'
WHERE NOT EXISTS (SELECT 1 FROM metrics.registered_processes WHERE process_name = 'migration_runner');

-- --------------------------------------------------------------------------
-- 9. Grants (guarded, matching 7670)
-- --------------------------------------------------------------------------
DO $do$
DECLARE r text;
BEGIN
    FOREACH r IN ARRAY ARRAY['dbdome_mon_usr', 'dbdome_engine'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('GRANT USAGE ON SCHEMA migration TO %I', r);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA migration TO %I', r);
            EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA migration TO %I', r);
        END IF;
    END LOOP;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dbdome_grafana_ro') THEN
        EXECUTE 'GRANT USAGE ON SCHEMA migration TO dbdome_grafana_ro';
        EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA migration TO dbdome_grafana_ro';
    END IF;
END
$do$;
