-- =============================================================================
-- 7390_walk_decision_tree_left_join.sql
--
-- rootcause.walk_decision_tree returned NO rows whenever any later step's temp
-- table had no match for the earlier steps (the step tables were combined with
-- INNER JOIN, so one empty/non-matching step wiped the whole tree's output).
-- Fix: combine the step tables with LEFT OUTER JOIN instead, so step-1 rows are
-- always returned and unmatched later steps appear as NULL in the joined_row
-- jsonb (jsonb_build_object stores the key with a null value).
--
-- Otherwise identical to the deployed function (server text/uuid resolution,
-- p_server/p_timefrom/p_timeto literal injection, 5-hop cap, dtw_result temp
-- table). Owner is left as-is per environment (dbdome_mon_usr locally,
-- dbexpert_adm on the dbexpert appliances) -- no ALTER OWNER here.
-- Idempotent. DROP ROUTINE first: some installs (live dbanalytics) carry this
-- as a PROCEDURE, which CREATE OR REPLACE FUNCTION cannot replace ("cannot
-- change routine kind"); DROP ROUTINE removes either kind.
-- =============================================================================

DROP ROUTINE IF EXISTS rootcause.walk_decision_tree(text, timestamp without time zone);

CREATE FUNCTION rootcause.walk_decision_tree(
    p_server text,
    p_timestamp timestamp without time zone)
    RETURNS TABLE(decision_tree_name text, joined_row jsonb)
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
#variable_conflict use_column
DECLARE
    v_tree     text;
    v_step     int;
    v_prev_tgt varchar(50);
    v_edge     rootcause.decision_tree%ROWTYPE;
    v_qsql     text;
    v_tbl      text;
    v_tbls     text[];
    v_items    bigint[];
    v_srcrc    text[];
    v_join     text;
    v_on       text;
    v_objargs  text;
    i          int;
    m          record;
    v_srv_uuid text;
BEGIN
    -- Resolve the server identity ONCE. p_server may be passed as the text server
    -- name OR as a server_id uuid; v_srv_uuid holds the uuid so edges that filter
    -- by server_id get the uuid while edges that filter by the text `server` get
    -- p_server. Unknown server -> v_srv_uuid NULL (harmlessly matches no rows).
    SELECT server_id::text INTO v_srv_uuid
    FROM metrics.servers
    WHERE server = p_server OR server_id::text = p_server
    LIMIT 1;

    CREATE TEMP TABLE IF NOT EXISTS dtw_result (decision_tree_name text, joined_row jsonb);
    TRUNCATE dtw_result;

    FOR v_tree IN
        SELECT DISTINCT decision_tree_name FROM rootcause.decision_tree ORDER BY 1
    LOOP
        v_step := 0; v_prev_tgt := NULL;
        v_tbls := ARRAY[]::text[]; v_items := ARRAY[]::bigint[]; v_srcrc := ARRAY[]::text[];

        LOOP
            IF v_step = 0 THEN
                SELECT * INTO v_edge FROM rootcause.decision_tree dt
                 WHERE dt.decision_tree_name = v_tree
                   AND NOT EXISTS (SELECT 1 FROM rootcause.decision_tree x
                                    WHERE x.decision_tree_name = v_tree
                                      AND x.target_root_cause_id = dt.source_root_cause_id)
                 ORDER BY dt.row_id LIMIT 1;
            ELSE
                SELECT * INTO v_edge FROM rootcause.decision_tree dt
                 WHERE dt.decision_tree_name = v_tree
                   AND dt.source_root_cause_id = v_prev_tgt
                 ORDER BY dt.row_id LIMIT 1;
            END IF;
            EXIT WHEN NOT FOUND;
            EXIT WHEN v_step >= 5;                                  -- up to 5 hops

            v_step := v_step + 1;
            v_tbl  := format('_dtw_%s', v_step);

            -- Inject the procedure's parameters as literals wherever the edge's
            -- source_query references them. Edges use the p_server / p_timefrom /
            -- p_timeto convention; word-bounded (\m..\M) so 'p_server' is not
            -- matched inside other identifiers. ':server'/':timestamp' also work.
            v_qsql := v_edge.source_query;
            -- 'server_id = p_server' -> resolved uuid (NULL matches no rows). MUST
            -- run before the generic p_server replace so the uuid columns get the
            -- uuid, not the text name.
            v_qsql := regexp_replace(v_qsql, 'server_id(\s*=\s*)p_server',
                          'server_id\1' || COALESCE(quote_literal(v_srv_uuid), 'NULL'), 'gi');
            v_qsql := replace(v_qsql, ':server_id', COALESCE(quote_literal(v_srv_uuid), 'NULL'));
            -- remaining p_server -> text server name; time bounds -> params.
            -- case-insensitive: edges vary the casing (p_timefrom vs p_timeFrom).
            v_qsql := regexp_replace(v_qsql, '\mp_server\M',   quote_literal(p_server),         'gi');
            v_qsql := regexp_replace(v_qsql, '\mp_timefrom\M', quote_literal(p_timestamp),      'gi');
            v_qsql := regexp_replace(v_qsql, '\mp_timeto\M',   quote_literal(now()::timestamp), 'gi');
            v_qsql := replace(v_qsql, ':server',    quote_literal(p_server));
            v_qsql := replace(v_qsql, ':timestamp', quote_literal(p_timestamp));
            EXECUTE format('DROP TABLE IF EXISTS %I', v_tbl);
            EXECUTE format('CREATE TEMP TABLE %I AS %s', v_tbl, v_qsql);

            v_tbls  := array_append(v_tbls,  v_tbl);
            v_items := array_append(v_items, v_edge.row_id::bigint);
            v_srcrc := array_append(v_srcrc, v_edge.source_root_cause_id);
            v_prev_tgt := v_edge.target_root_cause_id;
        END LOOP;

        CONTINUE WHEN array_length(v_tbls,1) IS NULL;

        v_join := format('%I s1', v_tbls[1]);
        FOR i IN 1 .. (array_length(v_tbls,1) - 1) LOOP
            v_on := NULL;
            FOR m IN
                SELECT source_param, target_param
                  FROM rootcause.decision_tree_map_compare_columns
                 WHERE decision_tree_item_id = v_items[i]
            LOOP
                v_on := concat_ws(' AND ', v_on,
                          format('s%s.%I = s%s.%I', i, m.source_param, i+1, m.target_param));
            END LOOP;
            -- LEFT OUTER JOIN (was INNER JOIN): a later step with no matching rows
            -- must not erase the earlier steps' evidence from the tree's output.
            v_join := v_join || format(' LEFT OUTER JOIN %I s%s ON %s',
                        v_tbls[i+1], i+1, COALESCE(v_on, 'true'));
        END LOOP;

        v_objargs := array_to_string(ARRAY(
            SELECT format('%L, to_jsonb(s%s)', v_srcrc[g], g)
              FROM generate_subscripts(v_tbls,1) g), ', ');
        EXECUTE format('INSERT INTO dtw_result SELECT %L, jsonb_build_object(%s) FROM %s',
                       v_tree, v_objargs, v_join);

        FOREACH v_tbl IN ARRAY v_tbls LOOP
            EXECUTE format('DROP TABLE IF EXISTS %I', v_tbl);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'decision-tree walk complete (server=%, ts=%).', p_server, p_timestamp;

    -- Return the accumulated results (also left in TEMP TABLE dtw_result).
    RETURN QUERY SELECT d.decision_tree_name, d.joined_row FROM dtw_result d;
END
$BODY$;
