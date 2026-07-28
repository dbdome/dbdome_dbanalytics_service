-- =============================================================================
-- 7340_partition_alert_log.sql
--
-- Convert alerts.alert_log to a TWO-LEVEL partitioned table:
--     PARTITION BY RANGE (entry_date)         -- monthly, for time pruning + retention
--       -> PARTITION BY HASH (root_cause_id)  -- 4 buckets, per the "by entry_date
--                                                 and root_cause_id" requirement
--
-- Why two-level: entry_date range lets old months be dropped whole (retention) and
-- lets time-window dashboard/incident reads prune by month; hashing root_cause_id
-- keeps each monthly partition balanced across 4 children and lets equality reads
-- on root_cause_id prune to one bucket. A DEFAULT month partition (also hash-
-- subpartitioned) catches any out-of-window date, so an INSERT can NEVER fail with
-- "no partition found" even if forward maintenance lags (unlike the gmmr bug 7320).
--
-- The PK must include every partition-key column, so it widens from (row_id) to
-- (row_id, entry_date, root_cause_id). row_id stays globally unique via its
-- sequence; get_alert_log_resultset_byid(row_id) still works (PK leads with row_id).
--
-- Data is copied BEFORE the 3 INSERT triggers are recreated, so migrating 124k
-- historical rows does NOT re-fire the incident-upsert / fill / skip triggers.
--
-- Idempotent: skips if alert_log is already partitioned. Wrap-in-one-statement DO
-- block => single transaction; an ACCESS EXCLUSIVE lock makes the swap atomic and
-- loses no concurrent collector inserts (they block a few seconds, then hit the
-- new table).
-- =============================================================================
DO $$
DECLARE
    m       date;
    ahead   date := (date_trunc('month', now()) + interval '12 months')::date;
    b       int;
    mname   text;
    is_part boolean;
    v_owner text;
    grec    record;
    v_view_ddl text[];
    stmt    text;
BEGIN
    IF to_regclass('alerts.alert_log') IS NULL THEN
        RAISE NOTICE '7340: alerts.alert_log missing - skip'; RETURN;
    END IF;

    SELECT c.relkind = 'p', pg_get_userbyid(c.relowner)
      INTO is_part, v_owner
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'alerts' AND c.relname = 'alert_log';
    IF is_part THEN
        RAISE NOTICE '7340: alerts.alert_log already partitioned - skip'; RETURN;
    END IF;

    -- Block concurrent inserts for the whole migration (copy + swap).
    LOCK TABLE alerts.alert_log IN ACCESS EXCLUSIVE MODE;

    -- 0) capture recreate-DDL for every view that depends on alert_log (they are
    -- dropped by the CASCADE below and rebuilt against the NEW table). base view
    -- first (oid asc), then owner, then any non-owner grants.
    SELECT array_agg(s.stmt ORDER BY s.sortkey) INTO v_view_ddl FROM (
        WITH RECURSIVE deps AS (
            SELECT DISTINCT r.ev_class AS view_oid
            FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
            WHERE d.refobjid = 'alerts.alert_log'::regclass AND d.deptype = 'n'
              AND r.ev_class <> 'alerts.alert_log'::regclass
            UNION
            SELECT DISTINCT r.ev_class
            FROM deps JOIN pg_depend d ON d.refobjid = deps.view_oid
            JOIN pg_rewrite r ON r.oid = d.objid
            WHERE r.ev_class <> deps.view_oid
        )
        SELECT c.oid::bigint*10+1 AS sortkey,
               format('CREATE OR REPLACE VIEW %I.%I AS %s',
                      n.nspname, c.relname, pg_get_viewdef(c.oid)) AS stmt
        FROM deps JOIN pg_class c ON c.oid=deps.view_oid JOIN pg_namespace n ON n.oid=c.relnamespace
        UNION ALL
        SELECT c.oid::bigint*10+2,
               format('ALTER VIEW %I.%I OWNER TO %I',
                      n.nspname, c.relname, pg_get_userbyid(c.relowner))
        FROM deps JOIN pg_class c ON c.oid=deps.view_oid JOIN pg_namespace n ON n.oid=c.relnamespace
        UNION ALL
        SELECT c.oid::bigint*10+3,
               format('GRANT %s ON %I.%I TO %I', g.privilege_type, n.nspname, c.relname, g.grantee)
        FROM deps JOIN pg_class c ON c.oid=deps.view_oid JOIN pg_namespace n ON n.oid=c.relnamespace
        JOIN information_schema.role_table_grants g
             ON g.table_schema=n.nspname AND g.table_name=c.relname
        WHERE g.grantee <> pg_get_userbyid(c.relowner)
          AND g.grantee IN (SELECT rolname FROM pg_roles)
    ) s;

    -- 1) partitioned shell: same columns/defaults, widened PK ---------------
    CREATE TABLE alerts.alert_log_p (LIKE alerts.alert_log INCLUDING DEFAULTS)
        PARTITION BY RANGE (entry_date);
    -- own it like the original (dbdome_adm) so the row_id sequence (same owner)
    -- can be re-linked and grants line up.
    EXECUTE format('ALTER TABLE alerts.alert_log_p OWNER TO %I', v_owner);
    -- temp constraint name — the old table still holds 'alert_log_pkey' (index
    -- names are schema-unique); renamed to the canonical name after the drop.
    ALTER TABLE alerts.alert_log_p
        ADD CONSTRAINT alert_log_p_pkey PRIMARY KEY (row_id, entry_date, root_cause_id);
    -- access-pattern indexes (created on parent => propagate to every partition)
    CREATE INDEX ix_alert_log_entry_date       ON alerts.alert_log_p (entry_date);
    CREATE INDEX ix_alert_log_srv_rc_date       ON alerts.alert_log_p (server, root_cause_id, entry_date);
    CREATE INDEX ix_alert_log_rc_date           ON alerts.alert_log_p (root_cause_id, entry_date);

    -- 2) monthly partitions (first data month .. +12), each HASH(4) ----------
    m := date_trunc('month', LEAST((SELECT min(entry_date) FROM alerts.alert_log),
                                    now()))::date;
    WHILE m <= ahead LOOP
        mname := 'alert_log_' || to_char(m, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE alerts.%I PARTITION OF alerts.alert_log_p '
            'FOR VALUES FROM (%L) TO (%L) PARTITION BY HASH (root_cause_id)',
            mname, m, (m + interval '1 month')::date);
        FOR b IN 0..3 LOOP
            EXECUTE format(
                'CREATE TABLE alerts.%I PARTITION OF alerts.%I '
                'FOR VALUES WITH (MODULUS 4, REMAINDER %s)',
                mname || '_h' || b, mname, b);
        END LOOP;
        m := (m + interval '1 month')::date;
    END LOOP;

    -- default month (hash-subpartitioned) so any out-of-window date still routes
    CREATE TABLE alerts.alert_log_default PARTITION OF alerts.alert_log_p
        DEFAULT PARTITION BY HASH (root_cause_id);
    FOR b IN 0..3 LOOP
        EXECUTE format(
            'CREATE TABLE alerts.%I PARTITION OF alerts.alert_log_default '
            'FOR VALUES WITH (MODULUS 4, REMAINDER %s)',
            'alert_log_default_h' || b, b);
    END LOOP;

    -- 3) copy data (no triggers on the new table yet => no re-fire) ----------
    INSERT INTO alerts.alert_log_p SELECT * FROM alerts.alert_log;

    -- 4) swap names + keep the sequence + recreate triggers -----------------
    ALTER TABLE alerts.alert_log   RENAME TO alert_log_old;
    ALTER TABLE alerts.alert_log_p RENAME TO alert_log;

    -- keep row_id's sequence; re-own to the new column BEFORE dropping old
    -- (else DROP TABLE old would drop the owned sequence).
    PERFORM setval('alerts.alert_log_row_id_seq',
                   GREATEST((SELECT max(row_id) FROM alerts.alert_log), 1));
    ALTER SEQUENCE alerts.alert_log_row_id_seq OWNED BY alerts.alert_log.row_id;

    CREATE TRIGGER trg_00_skip_excluded_login_alerts BEFORE INSERT ON alerts.alert_log
        FOR EACH ROW EXECUTE FUNCTION alerts.fn_skip_excluded_login_alerts();
    CREATE TRIGGER trg_alert_log_fill_metric_result_id BEFORE INSERT ON alerts.alert_log
        FOR EACH ROW EXECUTE FUNCTION alerts.trg_alert_log_fill_metric_result_id();
    CREATE TRIGGER trg_alert_incident_upsert AFTER INSERT ON alerts.alert_log
        FOR EACH ROW EXECUTE FUNCTION alerts.trg_alert_incident_upsert();

    -- replay the old table's grants onto the new one (a recreated table carries
    -- none) — for every grantee role that still exists.
    FOR grec IN
        SELECT DISTINCT grantee, privilege_type
        FROM information_schema.role_table_grants
        WHERE table_schema = 'alerts' AND table_name = 'alert_log_old'
          AND grantee IN (SELECT rolname FROM pg_roles)
    LOOP
        EXECUTE format('GRANT %s ON alerts.alert_log TO %I',
                       grec.privilege_type, grec.grantee);
    END LOOP;

    -- CASCADE drops the dependent views (now bound to alert_log_old); rebuilt next.
    DROP TABLE alerts.alert_log_old CASCADE;
    -- old 'alert_log_pkey' index is gone now; give the new PK the canonical name
    ALTER INDEX alerts.alert_log_p_pkey RENAME TO alert_log_pkey;

    -- recreate the dependent views against the new partitioned alert_log
    IF v_view_ddl IS NOT NULL THEN
        FOREACH stmt IN ARRAY v_view_ddl LOOP
            EXECUTE stmt;
        END LOOP;
    END IF;

    RAISE NOTICE '7340: alerts.alert_log converted to RANGE(entry_date)->HASH(root_cause_id); % view(s) rebuilt',
                 coalesce(array_length(v_view_ddl,1),0);
END $$;


-- ---------------------------------------------------------------------------
-- Forward maintenance: create months ahead + their hash children, drop months
-- older than the keep window. Call periodically (or from a scheduler process).
-- Not auto-wired here to avoid touching the SECURITY DEFINER gmmr_maintain; the
-- DEFAULT partition means inserts are safe until this runs. Idempotent.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION alerts.alert_log_maintain(p_keep_months integer DEFAULT 12,
                                                     p_ahead_months integer DEFAULT 3)
    RETURNS void LANGUAGE plpgsql AS $fn$
DECLARE
    m      date := date_trunc('month', now())::date;
    ahead  date := (date_trunc('month', now()) + make_interval(months => p_ahead_months))::date;
    cutoff date := (date_trunc('month', now()) - make_interval(months => p_keep_months))::date;
    b      int;
    mname  text;
    r      record;
BEGIN
    IF to_regclass('alerts.alert_log') IS NULL
       OR (SELECT relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE n.nspname='alerts' AND c.relname='alert_log') <> 'p' THEN
        RETURN;   -- not partitioned; nothing to do
    END IF;

    WHILE m <= ahead LOOP
        mname := 'alert_log_' || to_char(m, 'YYYY_MM');
        IF to_regclass('alerts.' || mname) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE alerts.%I PARTITION OF alerts.alert_log '
                'FOR VALUES FROM (%L) TO (%L) PARTITION BY HASH (root_cause_id)',
                mname, m, (m + interval '1 month')::date);
            FOR b IN 0..3 LOOP
                EXECUTE format(
                    'CREATE TABLE alerts.%I PARTITION OF alerts.%I '
                    'FOR VALUES WITH (MODULUS 4, REMAINDER %s)',
                    mname || '_h' || b, mname, b);
            END LOOP;
            RAISE NOTICE 'alert_log_maintain: created %', mname;
        END IF;
        m := (m + interval '1 month')::date;
    END LOOP;

    FOR r IN
        SELECT c.relname
        FROM pg_inherits i
        JOIN pg_class c     ON c.oid = i.inhrelid
        JOIN pg_class p     ON p.oid = i.inhparent
        JOIN pg_namespace n ON n.oid = p.relnamespace
        WHERE n.nspname = 'alerts' AND p.relname = 'alert_log'
          AND c.relname ~ '^alert_log_[0-9]{4}_[0-9]{2}$'
    LOOP
        IF to_date(substring(r.relname FROM 'alert_log_([0-9]{4}_[0-9]{2})'), 'YYYY_MM') < cutoff THEN
            EXECUTE format('DROP TABLE IF EXISTS alerts.%I', r.relname);
            RAISE NOTICE 'alert_log_maintain: dropped old %', r.relname;
        END IF;
    END LOOP;
END $fn$;
